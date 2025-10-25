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
    @ObservedObject private var debugLogger = UpdaterDebugLogger.shared

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
                openAppSettingsWindow(tab: .about, updater: updater)
            } label: {
                Label("About \(Bundle.main.name)", systemImage: "info.circle.fill")
            }

            Divider()

            Button {
                openAppSettingsWindow(updater: updater)
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
                showCustomAlert(
                    title: "Warning!",
                    message: "Pearcleaner and all of its files will be cleanly removed, are you sure?",
                    okText: "Uninstall",
                    style: .warning,
                    onOk: {
                        uninstallPearcleaner(appState: appState, locations: locations)
                    }
                )
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
                            // For plugins view, post notification to undo
                            NotificationCenter.default.post(name: NSNotification.Name("PluginsViewShouldUndo"), object: nil)
                        } else if appState.currentPage == .fileSearch {
                            // For file search view, post notification to undo
                            NotificationCenter.default.post(name: NSNotification.Name("FileSearchViewShouldUndo"), object: nil)
                        } else if appState.currentPage == .orphans {
                            // For orphans view, post notification to undo
                            NotificationCenter.default.post(name: NSNotification.Name("ZombieViewShouldUndo"), object: nil)
                        } else if appState.currentPage == .packages {
                            // For packages view, post notification to undo
                            NotificationCenter.default.post(name: NSNotification.Name("PackagesViewShouldUndo"), object: nil)
                        } else {
                            loadApps(folderPaths: fsm.folderPaths)
                            // After reload, if we're viewing files, refresh the file view
                            if appState.currentView == .files {
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 500_000_000)
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

                Button
                {
                    appState.currentPage = .updater

                } label: {
                    Text("Updater")
                }
                .keyboardShortcut("0", modifiers: .command)

            } label: {
                Label("Navigate To", systemImage: "location.north.fill")
            }

        }


        // Tools Menu
        CommandMenu(Text("Tools", comment: "Tools Menu")) {

            Button {
                Task { @MainActor in
                    switch appState.currentPage {
                    case .applications:
                        if appState.currentView == .files {
                            // User is viewing an app's files - refresh the files list
                            let currentAppInfo = appState.appInfo
                            updateOnMain {
                                appState.selectedItems = []
                            }
                            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                showAppInFiles(appInfo: currentAppInfo, appState: appState, locations: locations)
                            }
                        } else {
                            // User is on empty view or app list - refresh the app list
                            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                // Flush bundle caches before reloading to ensure fresh version info
                                flushBundleCaches(for: appState.sortedApps)
                                loadApps(folderPaths: fsm.folderPaths)
                            }
                        }
                    case .development:
                        NotificationCenter.default.post(name: NSNotification.Name("DevelopmentViewShouldRefresh"), object: nil)
                    case .fileSearch:
                        NotificationCenter.default.post(name: NSNotification.Name("FileSearchViewShouldRefresh"), object: nil)
                    case .homebrew:
                        NotificationCenter.default.post(name: NSNotification.Name("HomebrewViewShouldRefresh"), object: nil)
                    case .lipo:
                        NotificationCenter.default.post(name: NSNotification.Name("LipoViewShouldRefresh"), object: nil)
                    case .orphans:
                        NotificationCenter.default.post(name: NSNotification.Name("ZombieViewShouldRefresh"), object: nil)
                    case .packages:
                        NotificationCenter.default.post(name: NSNotification.Name("PackagesViewShouldRefresh"), object: nil)
                    case .plugins:
                        NotificationCenter.default.post(name: NSNotification.Name("PluginsViewShouldRefresh"), object: nil)
                    case .services:
                        NotificationCenter.default.post(name: NSNotification.Name("DaemonViewShouldRefresh"), object: nil)
                    case .updater:
                        NotificationCenter.default.post(name: NSNotification.Name("UpdaterViewShouldRefresh"), object: nil)
                    }
                }
            } label: {
                Label("Refresh", systemImage: "arrow.counterclockwise.circle")
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

        }

        CommandGroup(after: .help) {
            // Debug options
            Button {
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                    windowController.open(with: ConsoleView(), width: 600, height: 400)
                }
            } label: {
                Label("Debug Console", systemImage: "ladybug")
            }
            .keyboardShortcut("d", modifiers: .command)

            Button {
                // Export debug info to file
                exportDebugInfo(appState: appState)
            } label: {
                Label("Export Debug Info...", systemImage: "info.circle")
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            // Updater debug log export (only visible on Updater page)
            if appState.currentPage == .updater {
                Button {
                    exportUpdaterDebugInfo()
                } label: {
                    Label("Export Updater Debug Log...", systemImage: "arrow.triangle.2.circlepath.circle")
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .disabled(!debugLogger.hasLogs)
            }

            Divider()

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
