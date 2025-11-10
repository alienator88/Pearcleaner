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
    @ObservedObject private var permissionManager = PermissionManagerLocal.shared
    @ObservedObject private var helperToolManager = HelperToolManager.shared
    //MARK: StateObjects
    @StateObject var locations = Locations()
    @StateObject var fsm = FolderSettingsManager.shared
    @StateObject private var updater = Updater(owner: "alienator88", repo: "Pearcleaner")

    init() {
        //MARK: GUI or CLI launch mode.
        handleLaunchMode()

        //MARK: Initialize password request handler for SUDO_ASKPASS IPC
        _ = PasswordRequestHandler.shared

        //MARK: Pre-load apps data during app initialization
        let folderPaths = FolderSettingsManager.shared.folderPaths
        loadApps(folderPaths: folderPaths)

        //MARK: Pre-load volume information
        AppState.shared.loadVolumeInfo()

    }

    var body: some Scene {

        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .environmentObject(locations)
                .environmentObject(fsm)
                .environmentObject(updater)
                .environmentObject(permissionManager)

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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false

        ensureApplicationSupportFolderExists()

        // Check permissions once at launch
        PermissionManagerLocal.shared.checkPermissions(types: [.fullDiskAccess]) { results in
            PermissionManagerLocal.shared.results = results
        }

    }

    func applicationWillTerminate(_ notification: Notification) {}

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        return false
    }


}
