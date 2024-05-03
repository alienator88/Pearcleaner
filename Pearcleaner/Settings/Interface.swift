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
    @EnvironmentObject var fsm: FolderSettingsManager
    @EnvironmentObject var themeSettings: ThemeSettings
    @State private var windowSettings = WindowSettings()
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.general.selectedTab") private var selectedTab: CurrentTabView = .general
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.dark") var isDark: Bool = true
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @AppStorage("settings.general.miniview") private var miniView: Bool = true
    @AppStorage("settings.general.animateLogo") private var animateLogo: Bool = true
    @AppStorage("settings.general.selectedTheme") var selectedTheme: String = "Auto"
    @AppStorage("settings.interface.selectedMenubarIcon") var selectedMenubarIcon: String = "pear-4"
    @State private var isLaunchAtLoginEnabled: Bool = false
    @Binding var showPopover: Bool
    @Binding var search: String
    let icons = ["externaldrive", "trash", "folder", "pear-1", "pear-1.5", "pear-2", "pear-3", "pear-4"]

    var isMacOS14OrHigher: Bool {
        if #available(macOS 14, *) {
            return true
        } else {
            return false
        }
    }

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
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(glass ? "Transparent material enabled" : "Transparent material disabled")")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
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
                    Image(systemName: animateLogo ? "play.fill" : "pause")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(animateLogo ? "Logo animation enabled" : "Logo animation disabled")")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))

                    }
                    if !isMacOS14OrHigher {
                        Text("(macOS 14+)")
                            .font(.footnote)
                            .foregroundStyle(Color("mode").opacity(0.3))
                            .padding(.leading, 5)
                    }
//                    InfoButton(text: "The logo animation is only available in macOS 14 or higher")
                    Spacer()
                    Toggle(isOn: $animateLogo, label: {
                    })
                    .toggleStyle(.switch)
                    .disabled(!isMacOS14OrHigher)
                }
                .padding(5)
                .padding(.leading)




                HStack(spacing: 0) {
                    Image(systemName: "paintbrush")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Application base color")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
                    }
                    InfoButton(text: "When using a custom color, you might need to change the application color mode below to Dark or Light so text is readable")
                    Spacer()


                    HStack(spacing: 10) {
                        Button("") {
                            themeSettings.setPreset(preset: "slate", colorScheme: displayMode)
                        }
                        .buttonStyle(PresetColor(fillColor: themeSettings.getColorForPreset(preset: "slate", colorScheme: displayMode), label: "Slate"))

                        Button("") {
                            themeSettings.setPreset(preset: "dracula", colorScheme: displayMode)
                        }
                        .buttonStyle(PresetColor(fillColor: themeSettings.getColorForPreset(preset: "dracula", colorScheme: displayMode), label: "Dracula"))

                        Button("") {
                            themeSettings.setPreset(preset: "solarized", colorScheme: displayMode)
                            themeSettings.saveThemeColor()
                        }
                        .buttonStyle(PresetColor(fillColor: themeSettings.getColorForPreset(preset: "solarized", colorScheme: displayMode), label: "Solarized"))

                        Button("") {
                            themeSettings.setPreset(preset: "macOS", colorScheme: displayMode)
                            themeSettings.saveThemeColor()
                        }
                        .buttonStyle(PresetColor(fillColor: themeSettings.getColorForPreset(preset: "macOS", colorScheme: displayMode), label: "macOS"))
                    }




                    Spacer()

                    ColorPicker("", selection: $themeSettings.themeColor, supportsOpacity: false)
                        .onChange(of: themeSettings.themeColor) { newValue in
                            themeSettings.saveThemeColor()
                        }
                        .padding(.horizontal, 5)
                    
                    Button("") {
                        themeSettings.resetToDefault(dark: colorScheme == .dark)
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "arrow.uturn.left.circle", help: "Reset color to default"))

                }
                .padding(5)
                .padding(.leading)



                HStack(spacing: 0) {
                    Image(systemName: {
                        switch displayMode {
                        case .dark:
                            return "moon.fill"
                        case .light:
                            return "sun.max.fill"
                        case .system:
                            return "circle.righthalf.filled"
                        }
                    }())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Application color mode")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
                    }
                    InfoButton(text: "Changing the color mode will reset the base color to defaults")
                    Spacer()
                    SegmentedPicker(
                        ["Auto", "Dark", "Light"],
                        selectedIndex: Binding(
                            get: {
                                switch selectedTheme {
                                case "Dark": return 1
                                case "Light": return 2
                                default: return 0
                                }
                            },
                            set: { newIndex in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    switch newIndex {
                                    case 1: selectedTheme = "Dark"
                                    case 2: selectedTheme = "Light"
                                    default: selectedTheme = "Auto"
                                    }
                                }
                            }),
                        selectionAlignment: .bottom,
                        content: { item, isSelected in
                            Text(item)
                                .font(.callout)
                                .foregroundColor(isSelected ? Color("mode") : Color("mode").opacity(0.5) )
                                .padding(.horizontal)
                                .padding(.bottom, 5)
                                .frame(width: 65)
                        },
                        selection: {
                            VStack(spacing: 0) {
                                Spacer()
                                Color("pear").frame(height: 1)
                            }
                        })
                    .onChange(of: selectedTheme) { newTheme in
                        switch newTheme {
                        case "Auto":
                            if isDarkMode() {
                                displayMode.colorScheme = .dark
                            } else {
                                displayMode.colorScheme = .light
                            }
                            themeSettings.resetToDefault(dark: isDarkMode())
                            // Refresh foreground colors
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.selectedTab = .interface
                            }
                            if menubarEnabled{
                                MenuBarExtraManager.shared.restartMenuBarExtra()
                            }
                        case "Dark":
                            displayMode.colorScheme = .dark
                            themeSettings.resetToDefault(dark: true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.selectedTab = .interface
                            }
                            if menubarEnabled{
                                MenuBarExtraManager.shared.restartMenuBarExtra()
                            }
                        case "Light":
                            displayMode.colorScheme = .light
                            themeSettings.resetToDefault(dark: false)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.selectedTab = .interface
                            }
                            if menubarEnabled{
                                MenuBarExtraManager.shared.restartMenuBarExtra()
                            }
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
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(mini ? "Mini window mode" : "Full size window mode")")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
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
                                findAndHideWindows(named: ["Pearcleaner"])
                                windowSettings.newWindow {
                                    MiniMode(search: $search, showPopover: $showPopover)
                                        .environmentObject(locations)
                                        .environmentObject(appState)
                                        .environmentObject(fsm)
                                        .environmentObject(ThemeSettings.shared)
                                        .preferredColorScheme(displayMode.colorScheme)
                                }
                                updateOnMain(after: 0.1, {
                                    resizeWindowAuto(windowSettings: windowSettings, title: "Pearcleaner")
                                })
                            } else {
                                if appState.appInfo.appName.isEmpty {
                                    appState.currentView = .empty
                                } else {
                                    appState.currentView = .files
                                }
                                findAndHideWindows(named: ["Pearcleaner"])
                                windowSettings.newWindow {
                                    RegularMode(search: $search, showPopover: $showPopover)
                                        .environmentObject(locations)
                                        .environmentObject(appState)
                                        .environmentObject(fsm)
                                        .environmentObject(ThemeSettings.shared)
                                        .preferredColorScheme(displayMode.colorScheme)
                                }
                                updateOnMain(after: 0.1, {
                                    resizeWindowAuto(windowSettings: windowSettings, title: "Pearcleaner")
                                })
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
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(miniView ? "Show apps list on startup" : "Show drop target on startup")")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
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
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(popoverStay ? "Popover window will stay on top" : "Popover window will not stay on top")")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
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
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(menubarEnabled ? "Menubar icon enabled" : "Menubar icon disabled")")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
                    }
                    InfoButton(text: "When menubar icon is enabled, the main app window and dock icon will be disabled since the app will be put in accessory mode.")
                    Spacer()
                    Toggle(isOn: $menubarEnabled, label: {
                    })
                    .toggleStyle(.switch)
                    .onChange(of: menubarEnabled) { newVal in
                        if newVal {
                            MenuBarExtraManager.shared.addMenuBarExtra(withView:  {
                                MiniAppView(search: $search, showPopover: $showPopover)
                                    .environmentObject(locations)
                                    .environmentObject(appState)
                                    .environmentObject(fsm)
                                    .environmentObject(ThemeSettings.shared)
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
                                            .environmentObject(fsm)
                                            .environmentObject(ThemeSettings.shared)
                                            .preferredColorScheme(displayMode.colorScheme)
                                    }
                                    resizeWindowAuto(windowSettings: windowSettings, title: "Pearcleaner")
                                } else {
                                    windowSettings.newWindow {
                                        RegularMode(search: $search, showPopover: $showPopover)
                                            .environmentObject(locations)
                                            .environmentObject(appState)
                                            .environmentObject(fsm)
                                            .environmentObject(ThemeSettings.shared)
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
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(isLaunchAtLoginEnabled ? "Launch at login enabled" : "Launch at login disabled")")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
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
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Menubar icon")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
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

                Spacer()
            }

        }
        .padding(20)
        .frame(width: 500, height: 600)

    }

}

