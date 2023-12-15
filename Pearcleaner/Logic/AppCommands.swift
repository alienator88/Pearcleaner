//
//  AppCommands.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import SwiftUI

struct AppCommands: Commands {
    
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
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
                    appState.reload.toggle()
                    let sortedApps = getSortedApps()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        appState.sortedApps.userApps = sortedApps.userApps
                        appState.sortedApps.systemApps = sortedApps.systemApps
                        appState.reload.toggle()
                    }
                }
            } label: {
                Text("Refresh Apps")
            }
            .keyboardShortcut("r", modifiers: .command)

            Button {
                uninstallPearcleaner(appState: appState)
            } label: {
                Text("Uninstall Pearcleaner")
            }
//            .keyboardShortcut("C", modifiers: .command)




        }
        
        
        
        // Edit Menu
        CommandGroup(replacing: .undoRedo) {
            Button
            {
                undoTrash(appState: appState) {
                    let sortedApps = getSortedApps()
                    appState.sortedApps.userApps = []
                    appState.sortedApps.systemApps = []
                    appState.sortedApps.userApps = sortedApps.userApps
                    appState.sortedApps.systemApps = sortedApps.systemApps
                }
            } label: {
                Label("Undo Removal", systemImage: "clear")
            }
            .keyboardShortcut("z", modifiers: .command)
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

