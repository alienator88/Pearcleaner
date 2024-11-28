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
    @EnvironmentObject var windowSettings: WindowSettings
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @AppStorage("settings.general.miniview") private var miniView: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.minimalist") private var minimalEnabled: Bool = true
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
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

        VStack(spacing: 20) {

            // === Appearance =================================================================================================
            PearGroupBox(header: { Text("Appearance").font(.title2) },
                         content: {
                VStack {
                    HStack(spacing: 0) {
                        Image(systemName: glass ? "cube.transparent" : "cube.transparent.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Transparent material")
                                .font(.callout)
                                .foregroundStyle(.primary)
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


                    HStack(spacing: 0) {
                        Image(systemName: animationEnabled ? "play" : "play.slash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(animationEnabled ? String(localized: "Animations enabled") : String(localized: "Animations disabled"))         .font(.callout)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Toggle(isOn: $animationEnabled, label: {
                        })
                        .toggleStyle(.switch)
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: scrollIndicators ? "computermouse.fill" : "computermouse")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(scrollIndicators ? String(localized: "Scrollbar is set to OS preference in lists") : String(localized: "Scrollbar is hidden in lists"))
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Toggle(isOn: $scrollIndicators, label: {
                        })
                        .toggleStyle(.switch)
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: minimalEnabled ? "list.dash.header.rectangle" : "list.bullet.rectangle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(minimalEnabled ? String(localized: "Minimalist app list rows enabled") : String(localized: "Minimalist app list rows disabled"))
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Toggle(isOn: $minimalEnabled, label: {
                        })
                        .toggleStyle(.switch)
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: "paintbrush")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Theme Mode")
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        ThemeSettingsView(opacity: 1)
                            .onChange(of: themeManager.displayMode) { _ in
                                MenuBarExtraManager.shared.restartMenuBarExtra()
                            }
                    }
                    .padding(5)
                }
            })

            // === Mini =======================================================================================================
            PearGroupBox(header: { Text("Mini Configuration").font(.title2) },
                         content: {
                VStack {
                    HStack(spacing: 0) {
                        Image(systemName: isVersionOrHigher(version: 14) ? "square.resize.up" : "macwindow.on.rectangle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Mini window mode")
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                        InfoButton(text: String(localized: "Toggling between modes will reset the window frames to their default size/position"))
                        Spacer()
                        Toggle(isOn: $mini, label: {
                        })
                        .toggleStyle(.switch)
                        .disabled(menubarEnabled)
                        .help(menubarEnabled ? String(localized: "Disabled when menubar icon is enabled") : "")
                        .onChange(of: mini) { newVal in
                            if mini {
                                appState.currentView = miniView ? .apps : .empty
                                showPopover = false
                                windowSettings.newWindow(mini: true, withView: {
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
                                windowSettings.newWindow(mini: false, withView: {
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


                    HStack(spacing: 0) {
                        Image(systemName: miniView ? "square.grid.3x3.square" : "plus.square.dashed")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Show apps list on startup")
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }

                        InfoButton(text: String(localized: "In mini window mode, you can have Pearcleaner startup to the Apps List view or the Drop Target view."))

                        Spacer()
                        Toggle(isOn: $miniView, label: {
                        })
                        .toggleStyle(.switch)
                        .onChange(of: miniView) { newVal in
                            appState.currentView = newVal ? .apps : .empty
                        }
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: popoverStay ? "pin" : "pin.slash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Pin popover window on top")
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }

                        InfoButton(text: String(localized: "In mini window mode, if you pin the Files popover on top, clicking away from the window will not dismiss it. Otherwise, it will dismiss by clicking anywhere outside the app."))

                        Spacer()
                        Toggle(isOn: $popoverStay, label: {
                        })
                        .toggleStyle(.switch)
                    }
                    .padding(5)
                }
            })

            // === Menubar ====================================================================================================
            PearGroupBox(header: { Text("Menubar").font(.title2) },
                         content: {
                VStack {
                    HStack(spacing: 0) {
                        Image(systemName: "menubar.rectangle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Menubar icon mode")
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                        InfoButton(text: String(localized: "When menubar icon is enabled, the main app window and dock icon will be disabled since the app will be put in accessory mode."))
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
                                findAndHideWindows(named: ["Pearcleaner", ""])
                            } else {
                                MenuBarExtraManager.shared.removeMenuBarExtra()
                                NSApplication.shared.setActivationPolicy(.regular)

                                if mini {
                                    windowSettings.newWindow(mini: true, withView: {
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
                                    windowSettings.newWindow(mini: false, withView: {
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
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: isLaunchAtLoginEnabled ? "person.fill" : "person")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Launch Pearcleaner at login")
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                        InfoButton(text: String(localized: "This setting will affect Pearcleaner whether you're running in menubar mode or regular mode. If you disable menubar icon, you might want to disable this as well so Pearcleaner doesn't start on login."))
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


                    HStack(spacing: 0) {
                        Image(systemName: "paintbrush")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Menubar icon preference")
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Picker(selection: $selectedMenubarIcon) {
                            ForEach(icons, id: \.self) { icon in
                                HStack {
                                    Image(systemName: icon)
                                        .resizable()
                                        .scaledToFit()
                                }
                                .tag(icon)

                            }
                        } label: { EmptyView() }
                        .frame(width: 60)
                        .onChange(of: selectedMenubarIcon) { newValue in
                            MenuBarExtraManager.shared.swapMenuBarIcon(icon: newValue)
                        }
                        .buttonStyle(.borderless)

                    }
                    .padding(5)
                }
            })

        }

    }

}

