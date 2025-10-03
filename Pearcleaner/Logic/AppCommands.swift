//
//  AppCommands.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import SwiftUI
import AlinFoundation

struct AppCommands: Commands {

    let appState: AppState
    let locations: Locations
    let fsm: FolderSettingsManager
    let updater: Updater
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.general.selectedTab") private var selectedTab: CurrentTabView = .general
    @State private var windowController = WindowManager()

    init(appState: AppState, locations: Locations, fsm: FolderSettingsManager, updater: Updater) {
        self.appState = appState
        self.locations = locations
        self.fsm = fsm
        self.updater = updater
    }

    var body: some Commands {
        
        // Pearcleaner Menu
        CommandGroup(replacing: .appInfo) {

            Button {
//                selectedTab = .about
                openAppSettingsWindow(tab: .about)
            } label: {
                Label("About \(Bundle.main.name)", systemImage: "info.circle.fill")
            }

            Divider()

            Button {
                openAppSettingsWindow()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button {
                updater.checkForUpdates(sheet: true, force: true)
            } label: {
                Label("Check for Updates", systemImage: "tray.and.arrow.down.fill")
            }
            .keyboardShortcut("u", modifiers: .command)

            Button {
                appState.triggerUninstallAlert()
            } label: {
                Label("Uninstall Pearcleaner", systemImage: "trash.fill")
            }

        }

        
        
        // Edit Menu
        CommandGroup(replacing: .undoRedo) {

            Button
            {
                if appState.currentView != .zombie {
                    let result = undoTrash()
                    if result {
                        if appState.currentPage == .plugins {
                            // For plugins view, post notification to refresh
                            NotificationCenter.default.post(name: NSNotification.Name("PluginsViewShouldRefresh"), object: nil)
                        } else if appState.currentPage == .fileSearch {
                            // For file search view, post notification to refresh
                            NotificationCenter.default.post(name: NSNotification.Name("FileSearchViewShouldRefresh"), object: nil)
                        } else {
                            if #available(macOS 14.0, *) {
                                Task { @MainActor in
                                    AppCacheManager.loadAndUpdateApps(
                                        modelContainer: appState.modelContainer,
                                        folderPaths: fsm.folderPaths
                                    ) {
                                        // After reload completes, if we're viewing files, refresh the file view
                                        if appState.currentView == .files {
                                            showAppInFiles(appInfo: appState.appInfo, appState: appState, locations: locations)
                                        }
                                    }
                                }
                            } else {
                                reloadAppsList(appState: appState, fsm: fsm, delay: 1)
                                if appState.currentView == .files {
                                    showAppInFiles(appInfo: appState.appInfo, appState: appState, locations: locations)
                                }
                            }
                        }
                    }
                }

            } label: {
                Label("Undo Removal", systemImage: "clear")
            }
            .keyboardShortcut("z", modifiers: .command)


        }


        // Window Menu
        CommandGroup(after: .sidebar) {

            Menu {
                Button
                {
                    appState.currentPage = .applications

                } label: {
                    Text("Applications")
                }
                .keyboardShortcut("1", modifiers: .command)

                Button
                {
                    appState.currentPage = .development

                } label: {
                    Text("Development")
                }
                .keyboardShortcut("2", modifiers: .command)

                Button
                {
                    appState.currentPage = .fileSearch

                } label: {
                    Text("File Search")
                }
                .keyboardShortcut("3", modifiers: .command)

                Button
                {
                    appState.currentPage = .homebrew

                } label: {
                    Text("Homebrew")
                }
                .keyboardShortcut("4", modifiers: .command)

                Button
                {
                    appState.currentPage = .lipo

                } label: {
                    Text("App Lipo")
                }
                .keyboardShortcut("5", modifiers: .command)

                Button
                {
                    appState.currentPage = .orphans

                } label: {
                    Text("Orphaned Files")
                }
                .keyboardShortcut("6", modifiers: .command)

                Button
                {
                    appState.currentPage = .packages

                } label: {
                    Text("Packages")
                }
                .keyboardShortcut("7", modifiers: .command)

                Button
                {
                    appState.currentPage = .plugins

                } label: {
                    Text("Plugins")
                }
                .keyboardShortcut("8", modifiers: .command)

                Button
                {
                    appState.currentPage = .services

                } label: {
                    Text("Services")
                }
                .keyboardShortcut("9", modifiers: .command)

            } label: {
                Label("Navigate To", systemImage: "location.north.fill")
            }

        }


        // Tools Menu
        CommandMenu(Text("Tools", comment: "Tools Menu")) {

            Button {
                // Check if caching is enabled
                let cacheEnabled = UserDefaults.standard.bool(forKey: "settings.cache.enabled")

                if #available(macOS 14.0, *), cacheEnabled {
                    Task { @MainActor in
                        withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                            AppCacheManager.loadAndUpdateApps(
                                modelContainer: appState.modelContainer,
                                folderPaths: fsm.folderPaths
                            )
                        }
                    }
                } else {
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        reloadAppsList(appState: appState, fsm: fsm)
                    }
                }
            } label: {
                Label("Refresh Apps", systemImage: "arrow.counterclockwise.circle")
            }
            .keyboardShortcut("r", modifiers: .command)

            Button
            {
                if !appState.selectedItems.isEmpty {
                    createTarArchive(appState: appState)
                }
            } label: {
                Label("Bundle Files...", systemImage: "archivebox")
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(appState.selectedItems.isEmpty)

            Button
            {
                if !appState.appInfo.bundleIdentifier.isEmpty {
                    saveURLsToFile(appState: appState)
                }
            } label: {
                Label("Export File Paths...", systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(appState.selectedItems.isEmpty)

            Button
            {
                if !appState.appInfo.bundleIdentifier.isEmpty {
                    saveURLsToFile(appState: appState, copy: true)
                }
            } label: {
                Label("Copy File Paths", systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(appState.selectedItems.isEmpty)

            Button {
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                    windowController.open(with: ConsoleView(), width: 600, height: 400)
                }
            } label: {
                Label("Debug Console", systemImage: "ladybug")
            }
            .keyboardShortcut("d", modifiers: .command)

        }

        CommandGroup(after: .help) {
            // GitHub Menu
            Button
            {
                NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner")!)
            } label: {
                Label("View Repository", systemImage: "paperplane")
            }


            Button
            {
                NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/releases")!)
            } label: {
                Label("View Releases", systemImage: "paperplane")
            }


            Button
            {
                NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/issues")!)
            } label: {
                Label("View Issues", systemImage: "paperplane")
            }


            Divider()


            Button
            {
                NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/issues/new/choose")!)
            } label: {
                Label("Submit New Issue", systemImage: "paperplane")
            }
        }


    }
}
