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
    @AppStorage("settings.permissions.hasLaunched") private var hasLaunched: Bool = false
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @State private var search = ""
    @State private var showPopover: Bool = false
    
    var body: some Scene {

        WindowGroup {
            Group {
                
                if !mini {
                    AppListView(search: $search, showPopover: $showPopover)
                        .frame(minWidth: 800, minHeight: 500)
                } else {
                    MiniMode(search: $search, showPopover: $showPopover)
                        .frame(minWidth: 300, minHeight: 300)
                }
                
            }
            .environmentObject(appState)
            .preferredColorScheme(displayMode.colorScheme)
            .alert(isPresented: $appState.showAlert) { presentAlert(appState: appState) }
            .handlesExternalEvents(preferring: Set(arrayLiteral: "pear"), allowing: Set(arrayLiteral: "*"))
            .onOpenURL(perform: { url in
                let deeplinkManager = DeeplinkManager()
                deeplinkManager.manage(url: url, appState: appState)
            })
            .onDrop(of: ["public.file-url"], isTargeted: nil) { providers, _ in
                for provider in providers {
                    provider.loadItem(forTypeIdentifier: "public.file-url") { data, error in
                        if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            let deeplinkManager = DeeplinkManager()
                            deeplinkManager.manage(url: url, appState: appState)
                            //                        // Check if the file URL has a ".app" extension
                            //                        if url.pathExtension.lowercased() == "app" {
                            //                            // Handle the dropped file URL here
                            //                            print("Dropped .app file URL: \(url)")
                            //                        } else {
                            //                            // Print a message for non-.app files
                            //                            print("Unsupported file type. Only .app files are accepted.")
                            //                        }
                        }
                    }
                }
                return true
            }
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
                    
                    // Check for updates 1 minute after app launch
                    if diskP {
                        loadGithubReleases(appState: appState)
                    }

                    // Check for disk/accessibility permissions just once on initial app launch
                    if !hasLaunched {
                        _ = checkAndRequestFullDiskAccess(appState: appState)
                        hasLaunched = true
                    }
                    
                    
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
        .windowStyle(.hiddenTitleBar)
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
//                writeLog(string: url.path)
//                print("Dropped app path:", url.path)
//            }
//        }
//    }

}

