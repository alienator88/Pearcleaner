//
//  PearcleanerApp.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import SwiftUI
import AppKit

@main
struct PearcleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState()
    @AppStorage("settings.updater.updateTimeframe") private var updateTimeframe: Int = 1
    @AppStorage("settings.permissions.disk") private var diskP: Bool = false
    @AppStorage("settings.permissions.events") private var diskE: Bool = false
    @AppStorage("displayMode") var displayMode: DisplayMode = .dark
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @State private var search = ""

    var body: some Scene {
        
        WindowGroup {
            if !mini {
                AppListView(search: $search)
                    .environmentObject(appState)
                    .frame(minWidth: 1020, minHeight: 700)
                    .preferredColorScheme(displayMode.colorScheme)
                    .alert(isPresented: $appState.showAlert) { presentAlert(appState: appState) }
                    .handlesExternalEvents(preferring: Set(arrayLiteral: "pear"), allowing: Set(arrayLiteral: "*"))
                    .onAppear {
                        NSWindow.allowsAutomaticWindowTabbing = false
                        
                        // Get Apps
                        let sortedApps = getSortedApps()
                        appState.sortedApps.userApps = sortedApps.userApps
                        appState.sortedApps.systemApps = sortedApps.systemApps
                        
                        Task {
                            
#if !DEBUG
                            
                            // Make sure App Support folder exists in the future if needed for storage
                            ensureApplicationSupportFolderExists(appState: appState)
                            let fileManager = FileManager.default
                            let destinationURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Pearcleaner").appendingPathComponent("Pearcleaner.zip")
                            try? fileManager.removeItem(at: destinationURL)
                            
                            // Check for updates
                            if diskP && diskE {
                                loadGithubReleases(appState: appState)
                            }
                            
                            // Check for disk/accessibility permissions
                            _ = checkAndRequestFullDiskAccess(appState: appState)
                            
                            
                            // TIMERS ////////////////////////////////////////////////////////////////////////////////////
                            
                            // Check for app updates every 8 hours or whatever user saved setting. Also refresh autosuggestion list
                            let updateSeconds = updateTimeframe.daysToSeconds
                            _ = Timer.scheduledTimer(withTimeInterval: updateSeconds, repeats: true) { _ in
                                DispatchQueue.main.async {
                                    loadGithubReleases(appState: appState)
                                }
                            }
                            
#endif
                        }
                    }
            } else {
                MiniMode(search: $search)
                    .environmentObject(appState)
                    .frame(minWidth: 500, minHeight: 450)
                    .preferredColorScheme(displayMode.colorScheme)
                    .alert(isPresented: $appState.showAlert) { presentAlert(appState: appState) }
                    .handlesExternalEvents(preferring: Set(arrayLiteral: "pear"), allowing: Set(arrayLiteral: "*"))
                    .onAppear {
                        NSWindow.allowsAutomaticWindowTabbing = false
                        
                        // Get Apps
                        let sortedApps = getSortedApps()
                        appState.sortedApps.userApps = sortedApps.userApps
                        appState.sortedApps.systemApps = sortedApps.systemApps
                        
                        Task {
                            
#if !DEBUG
                            
                            // Make sure App Support folder exists in the future if needed for storage
                            ensureApplicationSupportFolderExists(appState: appState)
                            let fileManager = FileManager.default
                            let destinationURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Pearcleaner").appendingPathComponent("Pearcleaner.zip")
                            try? fileManager.removeItem(at: destinationURL)
                            
                            // Check for updates
                            if diskP && diskE {
                                loadGithubReleases(appState: appState)
                            }
                            
                            // Check for disk/accessibility permissions
                            _ = checkAndRequestFullDiskAccess(appState: appState)
                            
                            
                            // TIMERS ////////////////////////////////////////////////////////////////////////////////////
                            
                            // Check for app updates every 8 hours or whatever user saved setting. Also refresh autosuggestion list
                            let updateSeconds = updateTimeframe.daysToSeconds
                            _ = Timer.scheduledTimer(withTimeInterval: updateSeconds, repeats: true) { _ in
                                DispatchQueue.main.async {
                                    loadGithubReleases(appState: appState)
                                }
                            }
                            
#endif
                        }
                    }
            }
            
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(appState: appState)
            CommandGroup(replacing: .newItem, addition: { })
        }
        
        
        Settings {
            SettingsView()
                .environmentObject(appState)
                .toolbarBackground(.clear)
                .preferredColorScheme(displayMode.colorScheme)
        }
    }
}




class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
//    func application(_ sender: NSApplication, open urls: [URL]) {
//        for url in urls {
//            if url.pathExtension == "app" {
//                print("Dropped app path:", url.path)
//            }
//        }
//    }
}

