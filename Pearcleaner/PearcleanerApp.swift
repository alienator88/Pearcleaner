//
//  PearcleanerApp.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import SwiftUI
import AppKit
import ServiceManagement

@main
struct PearcleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState()
    @StateObject var locations = Locations()
    @State private var windowSettings = WindowSettings()
    @AppStorage("settings.updater.updateTimeframe") private var updateTimeframe: Int = 1
    @AppStorage("settings.permissions.disk") private var diskP: Bool = false
    @AppStorage("settings.permissions.events") private var diskE: Bool = false
    @AppStorage("settings.permissions.hasLaunched") private var hasLaunched: Bool = false
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.miniview") private var miniView: Bool = true
    @AppStorage("settings.general.instant") private var instantSearch: Bool = true
    @AppStorage("settings.general.features") private var features: String = ""
    @AppStorage("settings.general.brew") private var brew: Bool = false
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.menubar.mainWin") private var mainWinEnabled: Bool = false

    @State private var search = ""
    @State private var showPopover: Bool = false
    @State private var showFeature: Bool = false



    var body: some Scene {

        WindowGroup {
            Group {
                ZStack() {
                    if !mini {
                        RegularMode(search: $search, showPopover: $showPopover)
                            .environmentObject(locations)
                    } else {
                        MiniMode(search: $search, showPopover: $showPopover)
                            .environmentObject(locations)
                    }
                    
                    if showFeature {
                        NewFeatureView(text: features, mini: mini, showFeature: $showFeature)
                            .transition(.opacity)
                    }

                }


            }
            .environmentObject(appState)
            .preferredColorScheme(displayMode.colorScheme)
//            .alert(isPresented: $appState.showAlert) { presentAlert(appState: appState) }
            .handlesExternalEvents(preferring: Set(arrayLiteral: "pear"), allowing: Set(arrayLiteral: "*"))
            .onOpenURL(perform: { url in
                let deeplinkManager = DeeplinkManager(showPopover: $showPopover)
                deeplinkManager.manage(url: url, appState: appState, locations: locations)
            })
            .onDrop(of: ["public.file-url"], isTargeted: nil) { providers, _ in
                for provider in providers {
                    provider.loadItem(forTypeIdentifier: "public.file-url") { data, error in
                        if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            let deeplinkManager = DeeplinkManager(showPopover: $showPopover)
                            deeplinkManager.manage(url: url, appState: appState, locations: locations)
                        }
                    }
                }
                return true
            }
            // Save window size on window dimension change
            .onChange(of: NSApplication.shared.windows.first?.frame) { newFrame in
                if let newFrame = newFrame {
                    windowSettings.saveWindowSettings(frame: newFrame)
                }
            }
            .onAppear {

                if miniView {
                    appState.currentView = .apps
                } else {
                    appState.currentView = .empty
                }

                // Disable tabbing
                NSWindow.allowsAutomaticWindowTabbing = false

                // Set window size on load
                let frame = windowSettings.loadWindowSettings()
                NSApplication.shared.windows.first?.setFrame(frame, display: true)

                // Get Apps
                let sortedApps = getSortedApps()
                appState.sortedApps = sortedApps


                // Find all app paths/information on load if instantSearch is enabled
                if instantSearch {
                    loadAllPaths(allApps: sortedApps, appState: appState, locations: locations)
                }

                if menubarEnabled {
                    MenuBarExtraManager.shared.addMenuBarExtra {
                        MenuBarMiniAppView(search: $search, showPopover: $showPopover)
                            .environmentObject(locations)
                            .environmentObject(appState)
                    }
                }



#if !DEBUG
                Task {


                    // Make sure App Support folder exists in the future if needed for storage
                    ensureApplicationSupportFolderExists(appState: appState)

                    // Check for updates after app launch
                    if diskP {
                        loadGithubReleases(appState: appState)
                        getFeatures(appState: appState, show: $showFeature, features: $features)
                    }

                    // Check for disk/accessibility permissions just once on initial app launch
                    if !hasLaunched {
                        _ = checkAndRequestFullDiskAccess(appState: appState)
                        hasLaunched = true
                    }


                    // TIMERS ////////////////////////////////////////////////////////////////////////////////////

                    // Check for app updates every 8 hours or whatever user saved setting.
                    let updateSeconds = updateTimeframe.daysToSeconds
                    _ = Timer.scheduledTimer(withTimeInterval: updateSeconds, repeats: true) { _ in
                        DispatchQueue.main.async {
                            loadGithubReleases(appState: appState)
                        }
                    }
                }

#endif
            }
        }
        
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(appState: appState, locations: locations)
            CommandGroup(replacing: .newItem, addition: { })
            
        }



        
        Settings {
            SettingsView(showPopover: $showPopover, search: $search, showFeature: $showFeature)
                .environmentObject(appState)
                .environmentObject(locations)
                .toolbarBackground(.clear)
                .preferredColorScheme(displayMode.colorScheme)
        }
    }
}




class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let menubarEnabled = UserDefaults.standard.bool(forKey: "settings.menubar.enabled")
        return !menubarEnabled
    }


    func applicationDidFinishLaunching(_ notification: Notification) {
        let menubarEnabled = UserDefaults.standard.bool(forKey: "settings.menubar.enabled")

#if !DEBUG
        if menubarEnabled {
            NSApp.windows.first?.close()
            NSApplication.shared.setActivationPolicy(.accessory)
        }
#endif

    }

}

