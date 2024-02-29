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
    @State private var diskStatus: Bool = false
    @State private var accessStatus: Bool = false
    @State private var selectedTheme = "Auto"
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
                    Spacer()
                    Toggle(isOn: $glass, label: {
                    })
                    .toggleStyle(.switch)
                }
                .padding(5)
                .padding(.leading)


                HStack(spacing: 0) {
                    Image(systemName: "sidebar.left")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(.gray)
                    Text("Adjust sidebar width")
                        .font(.callout)
                        .foregroundStyle(.gray)
                    Spacer()
                    Slider(value: $sidebarWidth, in: 200...360) {
//                        Text("\(Int(sidebarWidth))")
                    }
                    .padding(.horizontal)
                    .frame(width: 185)
                    Button("") {
                        sidebarWidth = 280
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "arrow.uturn.left.circle", help: "Reset to default size", color: Color("mode")))
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
                        Text("Set color mode")
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
                        Text("\(mini ? "Mini window mode" : "Full size window mode")")
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
                        Text("\(popoverStay ? "Popover window doesn't hide on outside click" : "Popover window hides on outside click")")
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }
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
            }

        }
        .padding(20)
        .frame(width: 500, height: 650)

    }
    
}
