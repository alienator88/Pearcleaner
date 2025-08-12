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
    //MARK: AppStorage
    @AppStorage("settings.general.brew") private var brew: Bool = false
    //MARK: States
    @State private var search = ""

    init() {
        //MARK: GUI or CLI launch mode.
        handleLaunchMode()

        //MARK: Pre-load apps data during app initialization
        let fsm = FolderSettingsManager.shared
        DispatchQueue.global(qos: .userInitiated).async {
            let sortedApps = getSortedApps(paths: fsm.folderPaths)
            DispatchQueue.main.async {
                AppState.shared.sortedApps = sortedApps
            }
        }

        //MARK: Check permissions
        let permissionManager = PermissionManager.shared
        permissionManager.checkPermissions(types: [.fullDiskAccess]) { results in
            permissionManager.results = results
        }
    }

    var body: some Scene {

        WindowGroup {
            MainWindow(search: $search)
                .toolbar { Color.clear }
                .environmentObject(appState)
                .environmentObject(locations)
                .environmentObject(fsm)
                .environmentObject(updater)
                .environmentObject(permissionManager)
                .handlesExternalEvents(preferring: Set(arrayLiteral: "pear"), allowing: Set(arrayLiteral: "*"))
                .onDrop(of: ["public.file-url"], isTargeted: nil) { providers, _ in
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
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(appState: appState, locations: locations, fsm: fsm, updater: updater)
        }


        Settings {
                SettingsView(search: $search)
                    .environmentObject(appState)
                    .environmentObject(locations)
                    .environmentObject(fsm)
                    .environmentObject(updater)
                    .environmentObject(permissionManager)
                    .toolbarBackground(.clear)
                    .movableByWindowBackground()
        }

    }
}




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


}
