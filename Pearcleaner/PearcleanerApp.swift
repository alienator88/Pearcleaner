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
    @StateObject var appState = AppState()
    @StateObject var locations = Locations()
    @StateObject var fsm = FolderSettingsManager()
    @StateObject private var updater = Updater(owner: "alienator88", repo: "Pearcleaner")
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var windowSettings = WindowSettings()
    @AppStorage("settings.permissions.hasLaunched") private var hasLaunched: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.miniview") private var miniView: Bool = true
    @AppStorage("settings.general.brew") private var brew: Bool = false
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.menubar.mainWin") private var mainWinEnabled: Bool = false
    @AppStorage("settings.interface.selectedMenubarIcon") var selectedMenubarIcon: String = "trash"
    @State private var search = ""
    @State private var showPopover: Bool = false
    let conditionManager = ConditionManager.shared


    var body: some Scene {
        WindowGroup {
            Group {
                    if !mini {
                        RegularMode(search: $search, showPopover: $showPopover)
                    } else {
                        MiniMode(search: $search, showPopover: $showPopover)
                    }
            }
            .environmentObject(appState)
            .environmentObject(locations)
            .environmentObject(fsm)
            .environmentObject(themeManager)
            .environmentObject(updater)
            .environmentObject(permissionManager)
            .preferredColorScheme(themeManager.displayMode.colorScheme)
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
            .alert(isPresented: $appState.showUninstallAlert) {
                Alert(
                    title: Text("Warning!"),
                    message: Text("Pearcleaner and all of its files will be cleanly removed, are you sure?"),
                    primaryButton: .destructive(Text("Uninstall")) {
                        uninstallPearcleaner(appState: appState, locations: locations)
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $updater.showSheet, content: {
                /// This will show the update sheet based on the frequency check function only
                updater.getUpdateView()
                    .environmentObject(themeManager)
            })
            .onAppear {

                if miniView {
                    appState.currentView = .apps
                } else {
                    appState.currentView = .empty
                }

                // Disable tabbing
                NSWindow.allowsAutomaticWindowTabbing = false

                // Load apps list on startup
                reloadAppsList(appState: appState, fsm: fsm)


                // Enable menubar item
                if menubarEnabled {
                    MenuBarExtraManager.shared.addMenuBarExtra(withView: {
                        MiniAppView(search: $search, showPopover: $showPopover, isMenuBar: true)
                            .environmentObject(locations)
                            .environmentObject(appState)
                            .environmentObject(fsm)
                            .environmentObject(themeManager)
                            .environmentObject(permissionManager)
                            .preferredColorScheme(themeManager.displayMode.colorScheme)
                    }, icon: selectedMenubarIcon)
                }


#if !DEBUG
                Task {

                    /// This will check for updates on load based on the update frequency
                    updater.checkAndUpdateIfNeeded()

                    /// Get new features
                    updater.checkForAnnouncement()

                    // Make sure App Support folder exists in the future if needed for storage
                    //                    ensureApplicationSupportFolderExists(appState: appState)

                }

#endif
            }
        }
        
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(appState: appState, locations: locations, fsm: fsm, updater: updater, themeManager: themeManager)
//            CommandGroup(replacing: .newItem, addition: { })
            
        }



        
        Settings {
            SettingsView(showPopover: $showPopover, search: $search)
                .environmentObject(appState)
                .environmentObject(locations)
                .environmentObject(fsm)
                .environmentObject(themeManager)
                .environmentObject(updater)
                .environmentObject(permissionManager)
                .toolbarBackground(.clear)
                .preferredColorScheme(themeManager.displayMode.colorScheme)
        }
    }
}




class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var windowSettings = WindowSettings()
    var themeManager = ThemeManager.shared

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let menubarEnabled = UserDefaults.standard.bool(forKey: "settings.menubar.enabled")
        return !menubarEnabled
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menubarEnabled = UserDefaults.standard.bool(forKey: "settings.menubar.enabled")
//        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows" : false])

        findAndSetWindowFrame(named: ["Pearcleaner"], windowSettings: windowSettings)
        
        themeManager.setupAppearance()

        if menubarEnabled {
            findAndHideWindows(named: ["Pearcleaner"])
            NSApplication.shared.setActivationPolicy(.accessory)
        }

    }



    func applicationWillTerminate(_ notification: Notification) {
        // Perform actions on app termination here

    }


    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let windowSettings = WindowSettings()

        if !flag {
            // No visible windows, so let's open a new one
            for window in sender.windows {
                window.title = "Pearcleaner"
                window.makeKeyAndOrderFront(self)
                updateOnMain(after: 0.1, {
                    resizeWindowAuto(windowSettings: windowSettings, title: "Pearcleaner")
                })
            }
            return true // Indicates you've handled the re-open
        }
        // Return true if you want the application to proceed with its default behavior
        return false
    }

}
