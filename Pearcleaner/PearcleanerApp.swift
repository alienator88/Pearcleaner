//
//  PearcleanerApp.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import SwiftUI
import AppKit
import AlinFoundation

@main
struct PearcleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    //MARK: ObservedObjects
    @ObservedObject var appState = AppState.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var helperToolManager = HelperToolManager.shared
    //MARK: StateObjects
    @StateObject var locations = Locations()
    @StateObject var fsm = FolderSettingsManager.shared
    @StateObject private var updater = Updater(owner: "alienator88", repo: "Pearcleaner")
    //MARK: States
    @State private var isDraggingOver = false

    init() {
        //MARK: GUI or CLI launch mode.
        handleLaunchMode()

        //MARK: Pre-load apps data during app initialization
        let folderPaths = FolderSettingsManager.shared.folderPaths
        loadApps(folderPaths: folderPaths)

        //MARK: Check permissions
        let permissionManager = PermissionManager.shared
        permissionManager.checkPermissions(types: [.fullDiskAccess]) { results in
            permissionManager.results = results
        }

        //MARK: Pre-load volume information
        AppState.shared.loadVolumeInfo()

    }

    var body: some Scene {

        WindowGroup {
            MainWindow(isDraggingOver: $isDraggingOver)
                .environmentObject(appState)
                .environmentObject(locations)
                .environmentObject(fsm)
                .environmentObject(updater)
                .environmentObject(permissionManager)
                .handlesExternalEvents(preferring: Set(arrayLiteral: "pear"), allowing: Set(arrayLiteral: "*"))
                .onDrop(of: ["public.file-url"], isTargeted: $isDraggingOver) { providers, _ in
                    var droppedURLs: [URL] = []
                    let dispatchGroup = DispatchGroup()

                    for provider in providers {
                        dispatchGroup.enter()
                        provider.loadItem(forTypeIdentifier: "public.file-url") { data, error in
                            if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                                droppedURLs.append(url)
                            }
                            dispatchGroup.leave()
                        }
                    }

                    dispatchGroup.notify(queue: .main) {
                        let deeplinkManager = DeeplinkManager(updater: updater, fsm: fsm)
                        for url in droppedURLs {
                            deeplinkManager.manage(url: url, appState: appState, locations: locations)
                        }
                    }

                    return true
                }
                .onOpenURL(perform: { url in
                    let deeplinkManager = DeeplinkManager(updater: updater, fsm: fsm)
                    deeplinkManager.manage(url: url, appState: appState, locations: locations)
                })
                .alert(isPresented: $appState.showUninstallAlert) {
                    Alert(
                        title: Text("Warning!"),
                        message: Text("Pearcleaner and all of its files will be cleanly removed, are you sure?"),
                        primaryButton: .destructive(Text("Uninstall")) {
                            uninstallPearcleaner(appState: appState, locations: locations)
                        },
                        secondaryButton: .cancel()
                    )
                }
                .sheet(isPresented: $updater.sheet, content: {
                    /// This will show the update sheet based on the frequency check function only
                    updater.getUpdateView()
                })

        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(appState: appState, locations: locations, fsm: fsm, updater: updater)
        }



    }
}




// MARK: - View Extension for Conditional Modifiers

extension View {
    /// Helper to conditionally apply modifiers
    func apply<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> Content {
        transform(self)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    @AppStorage("settings.app.autoSlim") private var autoSlim: Bool = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false

        ensureApplicationSupportFolderExists()

        //MARK: Auto-slim size calculations on launch
        if autoSlim {
            DispatchQueue.global(qos: .utility).async {
                let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)

                // Calculate current size if slimming has been run before but size not yet recorded
                if !AppState.shared.autoSlimStats.lastRunVersion.isEmpty && AppState.shared.autoSlimStats.currentSize == 0 {
                    let currentSize = totalSizeOnDisk(for: bundleURL)
                    DispatchQueue.main.async {
                        var stats = AppState.shared.autoSlimStats
                        stats.currentSize = currentSize
                        AppState.shared.autoSlimStats = stats
                    }
                }
            }
        }

    }

    func applicationWillTerminate(_ notification: Notification) {
        //MARK: Auto-slim on termination if needed (universal or version changed)
        if autoSlim {
            let arch = checkAppBundleArchitecture(at: Bundle.main.bundlePath)
            let currentVersion = Bundle.main.version
            let needsSlim = (arch == .universal) || (AppState.shared.autoSlimStats.lastRunVersion != currentVersion)

            if needsSlim {
                performAutoSlim()
            }
        }
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        return false
    }


}
