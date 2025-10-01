//
//  PearcleanerApp.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import SwiftUI
import SwiftData
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
    //MARK: AppStorage
    @AppStorage("settings.general.brew") private var brew: Bool = false
    //MARK: States
    @State private var search = ""
    @State private var isDraggingOver = false

    // SwiftData model container (macOS 14+ only)
    let modelContainer: Any?

    init() {
        //MARK: Setup SwiftData container (macOS 14+ only)
        if #available(macOS 14.0, *) {
            do {
                let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("Pearcleaner")
                let storeURL = appSupportURL.appendingPathComponent("AppCache.sqlite")

                let config = ModelConfiguration(url: storeURL)
                modelContainer = try ModelContainer(for: CachedAppInfo.self, configurations: config)
                print("✅ SwiftData container initialized at: \(storeURL.path)")
            } catch {
                print("❌ Failed to create ModelContainer: \(error)")
                modelContainer = nil
            }
        } else {
            modelContainer = nil
            print("ℹ️ SwiftData caching not available on macOS 13, using direct scan")
        }

        //MARK: GUI or CLI launch mode.
        handleLaunchMode()

        //MARK: Pre-load apps data during app initialization
        let fsm = FolderSettingsManager.shared
        let container = self.modelContainer
        DispatchQueue.global(qos: .userInitiated).async {
            let sortedApps: Task<[AppInfo], Never>

            // Use caching on macOS 14+, fallback to direct scan on macOS 13
            if #available(macOS 14.0, *), let modelContainer = container as? ModelContainer {
                Task { @MainActor in
                    AppCacheManager.shared.setContainer(modelContainer)
                }
                sortedApps = Task { @MainActor in
                    AppCacheManager.shared.loadAppsWithCache(folderPaths: fsm.folderPaths)
                }
            } else {
                sortedApps = Task {
                    getSortedApps(paths: fsm.folderPaths)
                }
            }

            Task { @MainActor in
                AppState.shared.sortedApps = await sortedApps.value
                // Restore zombie file associations after apps are loaded
                AppState.shared.restoreZombieAssociations()
            }
        }

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
            MainWindow(search: $search, isDraggingOver: $isDraggingOver)
                .environmentObject(appState)
                .environmentObject(locations)
                .environmentObject(fsm)
                .environmentObject(updater)
                .environmentObject(permissionManager)
                .apply { view in
                    if #available(macOS 14.0, *), let container = modelContainer as? ModelContainer {
                        view.modelContainer(container)
                    } else {
                        view
                    }
                }
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

        
        Window("Settings", id: "settings") {
                SettingsView(search: $search)
                    .environmentObject(appState)
                    .environmentObject(locations)
                    .environmentObject(fsm)
                    .environmentObject(updater)
                    .environmentObject(permissionManager)
                    .movableByWindowBackground()
                    .frame(width: 800, height: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)

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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false

        ensureApplicationSupportFolderExists()

    }

    func applicationWillTerminate(_ notification: Notification) {

    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        return false
    }


}
