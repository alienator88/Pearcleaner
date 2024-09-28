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
    let themeManager: ThemeManager
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    init(appState: AppState, locations: Locations, fsm: FolderSettingsManager, updater: Updater, themeManager: ThemeManager) {
        self.appState = appState
        self.locations = locations
        self.fsm = fsm
        self.updater = updater
        self.themeManager = themeManager
    }

    var body: some Commands {
        
        // Pearcleaner Menu
        CommandGroup(replacing: .appInfo) {

            Button {
                updater.checkForUpdatesForce(showSheet: true)
            } label: {
                Text("Check for Updates")
            }
            .keyboardShortcut("u", modifiers: .command)
            
            Button {
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                    reloadAppsList(appState: appState, fsm: fsm)
                }
            } label: {
                Text("Refresh Apps")
            }
            .keyboardShortcut("r", modifiers: .command)

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
                    undoTrash(appState: appState) {
                        reloadAppsList(appState: appState, fsm: fsm)
                        for app in appState.trashedFiles {
                            AppPathFinder(appInfo: app, locations: locations, appState: appState, undo: true).findPaths()
                        }
                    }
                }

            } label: {
                Label("Undo Removal", systemImage: "clear")
            }
            .keyboardShortcut("z", modifiers: .command)


//            Button
//            {
//                updateOnMain {
//                    appState.currentView = .zombie
//                }
//            } label: {
//                Label("Zombie", systemImage: "clear")
//            }
//            .keyboardShortcut("f", modifiers: .command)


        }
        

        // Tools Menu
        CommandMenu(Text("Tools", comment: "Tools Menu")) {

            Button
            {
                if !appState.appInfo.bundleIdentifier.isEmpty {
                    appState.showConditionBuilder = true
                }
            } label: {
                Label("Condition Builder", systemImage: "hammer")
            }
            .keyboardShortcut("b", modifiers: .command)

            Button
            {
                if !appState.appInfo.bundleIdentifier.isEmpty {
                    saveURLsToFile(urls: appState.selectedItems, appState: appState)
                }
            } label: {
                Label("Export File Paths", systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("e", modifiers: .command)

            Button
            {
                if !appState.appInfo.bundleIdentifier.isEmpty {
                    saveURLsToFile(urls: appState.selectedItems, appState: appState, copy: true)
                }
            } label: {
                Label("Copy File Paths", systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("c", modifiers: [.command, .option])


        }

        
        // GitHub Menu
        CommandMenu(Text("GitHub", comment: "Github Repo")) {
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

