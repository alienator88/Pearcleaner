//
//  Interface.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/18/24.
//


import Foundation
import SwiftUI
import ServiceManagement

struct InterfaceSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @State private var windowSettings = WindowSettings()
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.general.dark") var isDark: Bool = true
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @AppStorage("settings.general.miniview") private var miniView: Bool = true
    @AppStorage("settings.general.selectedTheme") var selectedTheme: String = "Auto"
    @AppStorage("settings.interface.selectedMenubarIcon") var selectedMenubarIcon: String = "pear-4"
    private let themes = ["Auto", "Dark", "Light"]
    @State private var isLaunchAtLoginEnabled: Bool = false
    let icons = ["externaldrive", "trash", "folder", "pear-1", "pear-1.5", "pear-2", "pear-3", "pear-4"]

    @Binding var showPopover: Bool
    @Binding var search: String

    var body: some View {
        Form {
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
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(glass ? "Transparent material enabled" : "Transparent material disabled")")
                            .font(.callout)
                            .foregroundStyle(.gray)
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
                    Image(systemName: displayMode.colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Application color mode")
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Picker("", selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                    .onChange(of: selectedTheme) { newTheme in
                        switch newTheme {
                        case "Auto":
                            displayMode.colorScheme = nil
                            if isDarkModeEnabled() {
                                displayMode.colorScheme = .dark
                                MenuBarExtraManager.shared.restartMenuBarExtra()
                            } else {
                                displayMode.colorScheme = .light
                                MenuBarExtraManager.shared.restartMenuBarExtra()
                            }
                        case "Dark":
                            displayMode.colorScheme = .dark
                            MenuBarExtraManager.shared.restartMenuBarExtra()
                        case "Light":
                            displayMode.colorScheme = .light
                            MenuBarExtraManager.shared.restartMenuBarExtra()
                        default:
                            break
                        }
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
                    Image(systemName: mini ? "square.resize.up" : "square.resize.down")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(mini ? "Mini window mode" : "Full size window mode")")
                            .font(.callout)
                            .foregroundStyle(.gray)
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
                                windowSettings.newWindow {
                                    MiniMode(search: $search, showPopover: $showPopover)
                                        .environmentObject(locations)
                                        .environmentObject(appState)
                                        .preferredColorScheme(displayMode.colorScheme)
                                }
                                resizeWindowAuto(windowSettings: windowSettings, title: "Pearcleaner")
                            } else {
                                if appState.appInfo.appName.isEmpty {
                                    appState.currentView = .empty
                                } else {
                                    appState.currentView = .files
                                }
                                windowSettings.newWindow {
                                    RegularMode(search: $search, showPopover: $showPopover)
                                        .environmentObject(locations)
                                        .environmentObject(appState)
                                        .preferredColorScheme(displayMode.colorScheme)
                                }
                                resizeWindowAuto(windowSettings: windowSettings, title: "Pearcleaner")
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
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(miniView ? "Show apps list on startup" : "Show drop target on startup")")
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }

                    InfoButton(text: "In mini window mode, you can have Pearcleaner startup to the Apps List view or the Drop Target view.", color: nil, label: "")

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
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(popoverStay ? "Popover window will stay on top" : "Popover window will not stay on top")")
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }

                    InfoButton(text: "In mini window mode, if you pin the Files popover on top, clicking away from the window will not dismiss it. Otherwise, it will dismiss by clicking anywhere outside the popover.", color: nil, label: "")

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
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(menubarEnabled ? "Menubar icon enabled" : "Menubar icon disabled")")
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }
                    InfoButton(text: "When menubar icon is enabled, the main app window and dock icon will be disabled since the app will be put in accessory mode.", color: nil, label: "")
                    Spacer()
                    Toggle(isOn: $menubarEnabled, label: {
                    })
                    .toggleStyle(.switch)
                    .onChange(of: menubarEnabled) { newVal in
                        if newVal {
                            MenuBarExtraManager.shared.addMenuBarExtra(withView:  {
                                MenuBarMiniAppView(search: $search, showPopover: $showPopover)
                                    .environmentObject(locations)
                                    .environmentObject(appState)
                                    .preferredColorScheme(displayMode.colorScheme)
                            }, icon: selectedMenubarIcon)
                            NSApplication.shared.setActivationPolicy(.accessory)
                            findAndHideWindows(named: ["Pearcleaner"])
//                            findAndShowWindows(named: ["Pearcleaner", "Interface"])
                        } else {
                            MenuBarExtraManager.shared.removeMenuBarExtra()
                            NSApplication.shared.setActivationPolicy(.regular)
                            if !hasWindowOpen() {
                                if mini {
                                    windowSettings.newWindow {
                                        MiniMode(search: $search, showPopover: $showPopover)
                                            .environmentObject(locations)
                                            .environmentObject(appState)
                                            .preferredColorScheme(displayMode.colorScheme)
                                    }
                                    resizeWindowAuto(windowSettings: windowSettings, title: "Pearcleaner")
                                } else {
                                    windowSettings.newWindow {
                                        RegularMode(search: $search, showPopover: $showPopover)
                                            .environmentObject(locations)
                                            .environmentObject(appState)
                                            .preferredColorScheme(displayMode.colorScheme)
                                    }
                                    resizeWindowAuto(windowSettings: windowSettings, title: "Pearcleaner")
                                }
                            }

                        }
                    }

                }
                .padding(5)
                .padding(.leading)


                HStack(spacing: 0) {
                    Image(systemName: isLaunchAtLoginEnabled ? "person" : "person.slash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(isLaunchAtLoginEnabled ? "Launch at login enabled" : "Launch at login disabled")")
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }
                    InfoButton(text: "This setting will affect Pearcleaner whether you're running in menubar mode or regular mode. If you disable menubar icon, you might want to disable this as well so Pearcleaner doesn't start on login.", color: nil, label: "")
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
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Menubar icon")
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Picker("", selection: $selectedMenubarIcon) {
                        ForEach(icons, id: \.self) { icon in
                            HStack {
                                if icon.contains("pear") {
                                    Image(icon)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Image(systemName: icon)
                                        .resizable()
                                        .scaledToFit()
                                }
                            }
                            .tag(icon)

                        }
                    }
                    .frame(width: 60)
                    .onChange(of: selectedMenubarIcon) { newValue in
                        MenuBarExtraManager.shared.swapMenuBarIcon(icon: newValue)
                    }

                }
                .padding(5)
                .padding(.leading)

//                HStack(spacing: 0) {
//                    Image(systemName: "dock.rectangle")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 20, height: 20)
//                        .padding(.trailing)
//                        .foregroundStyle(.gray)
//                    VStack(alignment: .leading, spacing: 5) {
//                        Text("\(dockEnabled ? "Show dock icon" : "Hide dock icon")")
//                            .font(.callout)
//                            .foregroundStyle(.gray)
//                    }
//                    InfoButton(text: "This setting only affects Pearcleaner when the menubar icon is enabled, otherwise the dock icon will always show", color: nil, label: "")
//                    Spacer()
//                    Toggle(isOn: $dockEnabled, label: {
//                    })
//                    .toggleStyle(.switch)
//                    .onChange(of: dockEnabled) { newValue in
//                        if newValue {
//                            NSApplication.shared.setActivationPolicy(.regular)
//                        } else {
//                            if menubarEnabled {
//                                NSApplication.shared.setActivationPolicy(.accessory)
//                            }
//
//                        }
//                    }
//
//                }
//                .padding(5)
//                .padding(.leading)

                Spacer()
            }

        }
        .padding(20)
        .frame(width: 500, height: 520)

    }

}

