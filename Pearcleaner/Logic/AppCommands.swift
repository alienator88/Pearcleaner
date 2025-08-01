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
                updater.checkForUpdates(sheet: true)
            } label: {
                Text("Check for Updates")
            }
            .keyboardShortcut("u", modifiers: .command)

            Button {
                appState.triggerUninstallAlert()
            } label: {
                Text("Uninstall Pearcleaner")
            }

        }

        
        
        // Edit Menu
        CommandGroup(replacing: .undoRedo) {

            Button
            {
                if appState.currentView != .zombie {
                    let result = undoTrash()
                    if result {
                        reloadAppsList(appState: appState, fsm: fsm, delay: 1)
                        if appState.currentView == .files {
                            showAppInFiles(appInfo: appState.appInfo, appState: appState, locations: locations)
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

            Menu("Navigate To") {
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
                    appState.currentPage = .lipo

                } label: {
                    Text("App Lipo")
                }
                .keyboardShortcut("3", modifiers: .command)

                Button
                {
                    appState.currentPage = .orphans

                } label: {
                    Text("Orphaned Files")
                }
                .keyboardShortcut("4", modifiers: .command)
            }

        }


        // Tools Menu
        CommandMenu(Text("Tools", comment: "Tools Menu")) {

            Button {
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                    reloadAppsList(appState: appState, fsm: fsm)
                }
            } label: {
                Text("Refresh Apps")
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
                Text("Debug Console")
            }
            .keyboardShortcut("d", modifiers: .command)



        }

        
        // GitHub Menu
        CommandMenu(Text(verbatim: "GitHub")) {
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
