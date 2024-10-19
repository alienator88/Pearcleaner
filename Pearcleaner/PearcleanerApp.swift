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
    @StateObject private var windowSettings = WindowSettings.shared
    @AppStorage("settings.permissions.hasLaunched") private var hasLaunched: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.miniview") private var miniView: Bool = true
    @AppStorage("settings.general.brew") private var brew: Bool = false
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.menubar.mainWin") private var mainWinEnabled: Bool = false
    @State private var search = ""
    @State private var showPopover: Bool = false
    let conditionManager = ConditionManager.shared

    init() {
        let arguments = CommandLine.arguments
        let filteredArguments = arguments.filter { !["-NSDocumentRevisionsDebugMode", "YES"].contains($0) }
        let isRunningInTerminal = isatty(STDIN_FILENO) != 0

        // If running from terminal and no arguments are provided
        if isRunningInTerminal && arguments.count == 1 {
            displayHelp()
            exit(0)  // Exit without launching the GUI
        }

        // The first argument is always the binary path, so check if there are more than 1 arguments
        if filteredArguments.count > 1 {
            // Process the CLI options
            processCLI(arguments: arguments, appState: appState, locations: locations, fsm: fsm)
        }
    }

    var body: some Scene {

        
        WindowGroup {
            Group {
                if mini {
                    MiniMode(search: $search, showPopover: $showPopover)
                } else {
                    RegularMode(search: $search, showPopover: $showPopover)
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

                // Enable menubar item
                if menubarEnabled {
                    MenuBarExtraManager.shared.addMenuBarExtra(withView: {
                        MiniAppView(search: $search, showPopover: $showPopover, isMenuBar: true)
                            .environmentObject(appState)
                            .environmentObject(locations)
                            .environmentObject(fsm)
                            .environmentObject(themeManager)
                            .environmentObject(updater)
                            .environmentObject(permissionManager)
                            .preferredColorScheme(themeManager.displayMode.colorScheme)
                    })
                    NSApplication.shared.setActivationPolicy(.accessory)
                    windowSettings.trackMainWindow()
                    findAndHideWindows(named: ["Pearcleaner", ""])
                    // Catch windows in case something gets opened from SwiftUI lifecycle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                        findAndHideWindows(named: ["Pearcleaner", ""])
                    })
                }

                // Set mini view
                if mini && miniView {
                    appState.currentView = .apps
                } else {
                    appState.currentView = .empty
                }

                // Disable tabbing
                NSWindow.allowsAutomaticWindowTabbing = false

                // Load apps list on startup
                reloadAppsList(appState: appState, fsm: fsm)

                if !menubarEnabled {
                    Task {
                        // Track main window within windowSettings class
                        windowSettings.trackMainWindow()
                    }
                }


            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(appState: appState, locations: locations, fsm: fsm, updater: updater, themeManager: themeManager)            
        }



        
        Settings {
                SettingsView(showPopover: $showPopover, search: $search)
                    .environmentObject(appState)
                    .environmentObject(locations)
                    .environmentObject(fsm)
                    .environmentObject(themeManager)
                    .environmentObject(updater)
                    .environmentObject(permissionManager)
                    .environmentObject(windowSettings)
                    .preferredColorScheme(themeManager.displayMode.colorScheme)
                    .toolbarBackground(.clear)
                    .movableByWindowBackground()
        }

    }
}




class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let windowSettings = WindowSettings.shared
    var themeManager = ThemeManager.shared
    var windowCloseObserver: NSObjectProtocol?
    var windowFrameObserver: NSObjectProtocol?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let menubarEnabled = UserDefaults.standard.bool(forKey: "settings.menubar.enabled")
        return !menubarEnabled
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menubarEnabled = UserDefaults.standard.bool(forKey: "settings.menubar.enabled")

        if !menubarEnabled {
            findAndSetWindowFrame(named: ["Pearcleaner"], windowSettings: windowSettings)
        }

        themeManager.setupAppearance()

        windowFrameObserver = NotificationCenter.default.addObserver(forName: nil, object: nil, queue: nil) { notification in
            if let window = notification.object as? NSWindow, window.title == "Pearcleaner" {
                if notification.name == NSWindow.didEndLiveResizeNotification || notification.name == NSWindow.didMoveNotification {
                    self.windowSettings.saveWindowSettings(frame: window.frame)
                }
            }
        }

        windowCloseObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: nil) { notification in
            if let window = notification.object as? NSWindow, window.title == "Pearcleaner" {
                // Save window settings before removal (existing logic)
                self.windowSettings.saveWindowSettings(frame: window.frame)
            }
        }

        ensureApplicationSupportFolderExists()


    }



    func applicationWillTerminate(_ notification: Notification) {
        // Remove the observers
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        if let observer = windowFrameObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }



    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let windowSettings = WindowSettings.shared

        if !flag {
            // No visible windows, so let's open a new one
            for window in sender.windows {
                window.title = "Pearcleaner"
                window.makeKeyAndOrderFront(self)
                window.setFrame(windowSettings.loadWindowSettings(), display: true, animate: true)
            }
            return true // Indicates you've handled the re-open
        }
        // Return true if you want the application to proceed with its default behavior
        return false
    }

}
