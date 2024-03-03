//
//  General.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI

struct GeneralSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var windowSettings = WindowSettings()
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.dark") var isDark: Bool = true
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @AppStorage("settings.general.miniview") private var miniView: Bool = true
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 280
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.instant") private var instantSearch: Bool = true
    @AppStorage("settings.general.selectedTheme") var selectedTheme: String = "Auto"
    @State private var diskStatus: Bool = false
    @State private var accessStatus: Bool = false
    private let themes = ["Auto", "Dark", "Light"]
    @Binding var showPopover: Bool

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
                    InfoButton(text: "When transparent material is enabled, sticky section headers (User/System) in app list are disabled to keep from showing app name text overlayed under the section header text with no background to separate the two.", color: nil)
                    Spacer()
                    Toggle(isOn: $glass, label: {
                    })
                    .toggleStyle(.switch)
                }
                .padding(5)
                .padding(.leading)


                HStack(spacing: 0) {
                    Image(systemName: instantSearch ? "bolt" : "bolt.slash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(instantSearch ? "Instant search is enabled" : "Instant search is disabled")")
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }

                    InfoButton(text: "When instant search is enabled, all application files are gathered and cached for later use on startup instead of on each app click. There might be a slight delay of a few seconds when launching Pearcleaner depending on the amount of apps you have installed.", color: nil)

                    Spacer()
                    Toggle(isOn: $instantSearch, label: {
                    })
                    .toggleStyle(.switch)
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
                        Text("Set application color mode")
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
                            } else {
                                displayMode.colorScheme = .light
                            }
                        case "Dark":
                            displayMode.colorScheme = .dark
                        case "Light":
                            displayMode.colorScheme = .light
                        default:
                            break
                        }
                    }
                }
                .padding(5)
                .padding(.leading)

                // =========================================================================================================

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
                        Text("\(mini ? "Mini window mode selected" : "Full size window mode selected")")
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Toggle(isOn: $mini, label: {
                    })
                    .toggleStyle(.switch)
                    .onChange(of: mini) { newVal in
                        if mini {
                            appState.currentView = miniView ? .apps : .empty
                            showPopover = false
                            resizeWindowAuto(windowSettings: windowSettings)
                        } else {
                            resizeWindowAuto(windowSettings: windowSettings)
                            if appState.appInfo.appName.isEmpty {
                                appState.currentView = .empty
                            } else {
                                appState.currentView = .files
                            }
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

                    InfoButton(text: "In mini window mode, you can have Pearcleaner startup to the Apps List view or the Drop Target view.", color: nil)

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

                    InfoButton(text: "In mini window mode, if you pin the Files popover on top, clicking away from the window will not dismiss it. Otherwise, it will dismiss by clicking anywhere outside the popover.", color: nil)

                    Spacer()
                    Toggle(isOn: $popoverStay, label: {
                    })
                    .toggleStyle(.switch)
                }
                .padding(5)
                .padding(.leading)


                // =========================================================================================================


                Divider()
                    .padding()




                HStack() {
                    Text("Permissions").font(.title2)
                    Spacer()
                }
                .padding(.leading)

                HStack(spacing: 0) {
                    Image(systemName: diskStatus ? "externaldrive" : "externaldrive")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(diskStatus ? .green : .red)
                        .saturation(displayMode.colorScheme == .dark ? 0.5 : 1)
                    Text(diskStatus ? "Full Disk permission granted" : "Full Disk permission **NOT** granted")
                        .font(.callout)
                        .foregroundStyle(.gray)
                    Spacer()

                    Button("") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "folder", help: "View disk permissions pane", color: Color("mode")))

                }
                .padding(5)
                .padding(.leading)


                HStack(spacing: 0) {
                    Image(systemName: accessStatus ? "accessibility" : "accessibility")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(accessStatus ? .green : .red)
                        .saturation(displayMode.colorScheme == .dark ? 0.5 : 1)
                    Text(accessStatus ? "Accessibility permission granted" : "Accessibility permission **NOT** granted")
                        .font(.callout)
                        .foregroundStyle(.gray)
                    Spacer()

                    Button("") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "folder", help: "View accessibility permissions pane", color: Color("mode")))

                }
                .padding(5)
                .padding(.leading)


                // =========================================================================================================

                Divider()
                    .padding()

                HStack() {
                    Text("Sentinel Monitor").font(.title2)
                    Spacer()
                }
                .padding(.leading)

                HStack(spacing: 0) {
                    Image(systemName: sentinel ? "eye.circle" : "eye.slash.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(sentinel ? .green : .red)
                        .saturation(displayMode.colorScheme == .dark ? 0.5 : 1)
                    Text(sentinel ? "Detecting when apps are moved to Trash" : "**NOT** detecting when apps are moved to Trash")
                        .font(.callout)
                        .foregroundStyle(.gray)
                    Spacer()

                    Toggle(isOn: $sentinel, label: {
                    })
                    .toggleStyle(.switch)
                    .onChange(of: sentinel) { newValue in
                        if newValue {
                            launchctl(load: true)
                        } else {
                            launchctl(load: false)
                        }
                    }

                }
                .padding(5)
                .padding(.leading)







                Spacer()
            }
            .onAppear {
                diskStatus = checkAndRequestFullDiskAccess(appState: appState, skipAlert: true)
                accessStatus = checkAndRequestAccessibilityAccess(appState: appState)
//                if displayMode.colorScheme == .dark {
//                    selectedTheme = "Dark"
//                } else if displayMode.colorScheme == .light {
//                    selectedTheme = "Light"
//                }
            }

        }
        .padding(20)
        .frame(width: 500, height: 650)

    }
    
}
