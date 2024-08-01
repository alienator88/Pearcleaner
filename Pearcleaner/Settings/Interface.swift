//
//  Interface.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/18/24.
//


import Foundation
import SwiftUI
import ServiceManagement
import AlinFoundation

struct InterfaceSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var updater: Updater
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var fsm: FolderSettingsManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var windowSettings = WindowSettings()
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @AppStorage("settings.general.miniview") private var miniView: Bool = true
    @AppStorage("settings.interface.selectedMenubarIcon") var selectedMenubarIcon: String = "bubbles.and.sparkles.fill"
    @State private var isLaunchAtLoginEnabled: Bool = false
    @Binding var showPopover: Bool
    @Binding var search: String
    let icons = [ "bubbles.and.sparkles",
                  "bubbles.and.sparkles.fill",
                  "trash",
                  "trash.fill",
                  "xmark.bin",
                  "xmark.bin.fill",
                  "folder",
                  "folder.fill",
                  "folder.badge.minus",
                  "folder.badge.plus",
                  "archivebox",
                  "archivebox.fill"]


    var body: some View {

        VStack {

            HStack() {
                Text("Appearance").font(.title2)
                Spacer()
            }
            .padding(.leading)

            HStack(spacing: 0) {
                Image(systemName: glass ? "cube.transparent" : "cube.transparent.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(glass ? "Transparent material enabled" : "Transparent material disabled")")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }
                Spacer()
                Toggle(isOn: $glass, label: {
                })
                .toggleStyle(.switch)
                .onChange(of: glass) { newVal in
                    MenuBarExtraManager.shared.restartMenuBarExtra()
                }
            }
            .padding(5)
            .padding(.leading)


            HStack(spacing: 0) {
                Image(systemName: "paintbrush")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Theme Mode")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }
                Spacer()
                ThemeSettingsView(opacity: 1)
                    .onChange(of: themeManager.displayMode) { _ in
                        MenuBarExtraManager.shared.restartMenuBarExtra()
                    }
            }
            .padding(5)
            .padding(.leading)



            // === Mini =================================================================================================

            Divider()
                .padding()



            HStack() {
                Text("Mini Configuration").font(.title2)
                Spacer()
            }
            .padding(.leading)

            HStack(spacing: 0) {
                Image(systemName: isVersionOrHigher(version: 14) ? "square.resize.up" : "macwindow.on.rectangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(mini ? "Mini window mode" : "Full size window mode")")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }
                Spacer()
                Toggle(isOn: $mini, label: {
                })
                .toggleStyle(.switch)
                .disabled(menubarEnabled)
                .help(menubarEnabled ? "Disabled when menubar icon is enabled" : "")
                .onChange(of: mini) { newVal in
                    if mini {
                        appState.currentView = miniView ? .apps : .empty
                        showPopover = false
                        windowSettings.newWindow(withView: {
                            MiniMode(search: $search, showPopover: $showPopover)
                                .environmentObject(appState)
                                .environmentObject(locations)
                                .environmentObject(fsm)
                                .environmentObject(themeManager)
                                .environmentObject(updater)
                                .environmentObject(permissionManager)
                                .preferredColorScheme(themeManager.displayMode.colorScheme)
                        })
                    } else {
                        if appState.appInfo.appName.isEmpty {
                            appState.currentView = .empty
                        } else {
                            appState.currentView = .files
                        }
                        windowSettings.newWindow(withView: {
                            RegularMode(search: $search, showPopover: $showPopover)
                                .environmentObject(appState)
                                .environmentObject(locations)
                                .environmentObject(fsm)
                                .environmentObject(themeManager)
                                .environmentObject(updater)
                                .environmentObject(permissionManager)
                                .preferredColorScheme(themeManager.displayMode.colorScheme)
                        }
                        )
                    }


                }
            }
            .padding(5)
            .padding(.leading)


            HStack(spacing: 0) {
                Image(systemName: miniView ? "square.grid.3x3.square" : "plus.square.dashed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(miniView ? "Show apps list on startup" : "Show drop target on startup")")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }

                InfoButton(text: "In mini window mode, you can have Pearcleaner startup to the Apps List view or the Drop Target view.")

                Spacer()
                Toggle(isOn: $miniView, label: {
                })
                .toggleStyle(.switch)
                .onChange(of: miniView) { newVal in
                    appState.currentView = newVal ? .apps : .empty
                }
            }
            .padding(5)
            .padding(.leading)


            HStack(spacing: 0) {
                Image(systemName: popoverStay ? "pin" : "pin.slash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(popoverStay ? "Popover window will stay on top" : "Popover window will not stay on top")")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }

                InfoButton(text: "In mini window mode, if you pin the Files popover on top, clicking away from the window will not dismiss it. Otherwise, it will dismiss by clicking anywhere outside the popover.")

                Spacer()
                Toggle(isOn: $popoverStay, label: {
                })
                .toggleStyle(.switch)
            }
            .padding(5)
            .padding(.leading)


            // === MenuBar===============================================================================================

            Divider()
                .padding()

            HStack() {
                Text("Menubar").font(.title2)
                Spacer()
            }
            .padding(.leading)


            HStack(spacing: 0) {
                Image(systemName: "menubar.rectangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(menubarEnabled ? "Menubar icon enabled" : "Menubar icon disabled")")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }
                InfoButton(text: "When menubar icon is enabled, the main app window and dock icon will be disabled since the app will be put in accessory mode.")
                Spacer()
                Toggle(isOn: $menubarEnabled, label: {
                })
                .toggleStyle(.switch)
                .onChange(of: menubarEnabled) { newVal in
                    if newVal {
                        MenuBarExtraManager.shared.addMenuBarExtra(withView:  {
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
                        findAndHideWindows(named: ["Pearcleaner"])
                    } else {
                        MenuBarExtraManager.shared.removeMenuBarExtra()
                        NSApplication.shared.setActivationPolicy(.regular)
                        if !hasWindowOpen() {
                            if mini {
                                windowSettings.newWindow(withView: {
                                    MiniMode(search: $search, showPopover: $showPopover)
                                        .environmentObject(appState)
                                        .environmentObject(locations)
                                        .environmentObject(fsm)
                                        .environmentObject(themeManager)
                                        .environmentObject(updater)
                                        .environmentObject(permissionManager)
                                        .preferredColorScheme(themeManager.displayMode.colorScheme)
                                })
                            } else {
                                windowSettings.newWindow(withView: {
                                    RegularMode(search: $search, showPopover: $showPopover)
                                        .environmentObject(appState)
                                        .environmentObject(locations)
                                        .environmentObject(fsm)
                                        .environmentObject(themeManager)
                                        .environmentObject(updater)
                                        .environmentObject(permissionManager)
                                        .preferredColorScheme(themeManager.displayMode.colorScheme)
                                })
                            }
                        }

                    }
                }

            }
            .padding(5)
            .padding(.leading)


            HStack(spacing: 0) {
                Image(systemName: isLaunchAtLoginEnabled ? "person.fill" : "person")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(isLaunchAtLoginEnabled ? "Launch at login enabled" : "Launch at login disabled")")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }
                InfoButton(text: "This setting will affect Pearcleaner whether you're running in menubar mode or regular mode. If you disable menubar icon, you might want to disable this as well so Pearcleaner doesn't start on login.")
                Spacer()
                Toggle(isOn: $isLaunchAtLoginEnabled, label: {
                })
                .toggleStyle(.switch)
                .onAppear {
                    isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
                }
                .onChange(of: isLaunchAtLoginEnabled) { newValue in
                    do {
                        if newValue {
                            if SMAppService.mainApp.status == .enabled {
                                try? SMAppService.mainApp.unregister()
                            }

                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        printOS("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
                    }
                }

            }
            .padding(5)
            .padding(.leading)


            HStack(spacing: 0) {
                Image(systemName: "paintbrush")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Menubar icon")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }
                Spacer()
                Picker("", selection: $selectedMenubarIcon) {
                    ForEach(icons, id: \.self) { icon in
                        HStack {
                            Image(systemName: icon)
                                .resizable()
                                .scaledToFit()
                        }
                        .tag(icon)

                    }
                }
                .frame(width: 60)
                .onChange(of: selectedMenubarIcon) { newValue in
                    MenuBarExtraManager.shared.swapMenuBarIcon(icon: newValue)
                }
                .buttonStyle(.borderless)

            }
            .padding(5)
            .padding(.leading)

            Spacer()

        }
        .padding(20)
        .frame(width: 500, height: 540)

    }

}

