//
//  AppCommands.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import SwiftUI

struct AppCommands: Commands {

    let appState: AppState
    let locations: Locations
    let fsm: FolderSettingsManager

    init(appState: AppState, locations: Locations, fsm: FolderSettingsManager) {
        self.appState = appState
        self.locations = locations
        self.fsm = fsm
    }

    var body: some Commands {
        
        // Pearcleaner Menu
        CommandGroup(replacing: .appInfo) {

            Button {
                loadGithubReleases(appState: appState, manual: true)
            } label: {
                Text("Check for Updates")
            }
            .keyboardShortcut("u", modifiers: .command)
            
            Button {
                withAnimation(.easeInOut(duration: 0.5)) {
                    // Refresh Apps list
                    updateOnMain {
                        appState.reload.toggle()
                    }
                    let sortedApps = getSortedApps(paths: fsm.folderPaths, appState: appState)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        appState.sortedApps = []
                        appState.sortedApps = sortedApps
                        appState.reload.toggle()
                    }
                }
            } label: {
                Text("Refresh Apps")
            }
            .keyboardShortcut("r", modifiers: .command)

            Button {
                uninstallPearcleaner(appState: appState, locations: locations)
            } label: {
                Text("Uninstall Pearcleaner")
            }

        }

        
        
        // Edit Menu
        CommandGroup(replacing: .undoRedo) {

            Button
            {
                undoTrash(appState: appState) {
                    let sortedApps = getSortedApps(paths: fsm.folderPaths, appState: appState)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        appState.sortedApps = sortedApps
                        for app in appState.trashedFiles {
                            AppPathFinder(appInfo: app, appState: appState, locations: locations).findPaths()
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

