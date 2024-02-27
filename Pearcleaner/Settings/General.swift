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
    @State private var selectedTheme = "Auto"
    private let themes = ["Auto", "Dark", "Light"]
    
    var body: some View {
        Form {
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Transparency").font(.title2)
                        Text("Toggles transparent material")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Toggle(isOn: $glass, label: {
                    })
                    .toggleStyle(.switch)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Sidebar").font(.title2)
                        Text("Adjust sidebar width")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Slider(value: $sidebarWidth, in: 200...400) {
                        Text("\(Int(sidebarWidth))")
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Appearance").font(.title2)
                        Text("Toggles color mode")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    Picker("", selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
//                    .padding()
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
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )


                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Mini").font(.title2)
                        Text("Toggles a smaller, unified view with hidden app list")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Toggle(isOn: $mini, label: {
                    })
                    .toggleStyle(.switch)
                    .onChange(of: mini) { newVal in
                        if mini {
                            resizeWindowAuto(windowSettings: windowSettings)
//                            showPopover = false
//                            appState.currentView = miniView ? .apps : .empty
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
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )


                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Mini - \(miniView ? "Apps List" : "Drop Target")").font(.title2)
                        Text("Toggles drop target or apps list view on launch")
                            .font(.footnote)
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
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Mini - \(popoverStay ? "Popover on Top" : "Popover not on Top")").font(.title2)
                        Text("Keeps file search popover on top in mini mode")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Toggle(isOn: $popoverStay, label: {
                    })
                    .toggleStyle(.switch)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )




                Spacer()
            }

        }
        .padding(20)
        .frame(width: 400, height: 500)

    }
    
}
