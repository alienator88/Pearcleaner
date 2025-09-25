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
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.glassEffect") private var glassEffect: String = "Regular"
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.minimalist") private var minimalEnabled: Bool = true
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.interface.multiSelect") private var multiSelect: Bool = false
    @AppStorage("settings.interface.greetingEnabled") private var greetingEnabled: Bool = true

    @Binding var search: String

    var body: some View {

        VStack(spacing: 20) {

            // === Appearance =================================================================================================
            PearGroupBox(header: { Text("Appearance").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2) },
                         content: {
                VStack {

                    if #unavailable(macOS 26.0) {
                        HStack(spacing: 0) {
                            Image(systemName: glass ? "cube.transparent" : "cube.transparent.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Transparent sidebar")
                                    .font(.callout)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            }
                            Spacer()
                            Toggle(isOn: $glass, label: {
                            })
                            .toggleStyle(SettingsToggle())
                        }
                        .padding(5)
                    } else {
                        HStack(spacing: 0) {
                            Image(systemName: "cube.transparent")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Glass Effect")
                                    .font(.callout)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            }
                            Spacer()
                            Picker(selection: $glassEffect) {
                                Text("Regular")
                                    .tag("Regular")
                                Text("Clear")
                                    .tag("Clear")
                            } label: { EmptyView() }
                                .buttonStyle(.borderless)
                        }
                        .padding(5)
                    }




                    HStack(spacing: 0) {
                        Image(systemName: animationEnabled ? "play" : "play.slash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(animationEnabled ? String(localized: "Transition animations enabled") : String(localized: "Transition animations disabled"))
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        Spacer()
                        Toggle(isOn: $animationEnabled, label: {
                        })
                        .toggleStyle(SettingsToggle())
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: scrollIndicators ? "computermouse.fill" : "computermouse")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(scrollIndicators ? String(localized: "Scrollbar is set to OS preference in lists") : String(localized: "Scrollbar is hidden in lists"))
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        Spacer()
                        Toggle(isOn: $scrollIndicators, label: {
                        })
                        .toggleStyle(SettingsToggle())
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: minimalEnabled ? "list.dash.header.rectangle" : "list.bullet.rectangle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(minimalEnabled ? String(localized: "Simple app list enabled") : String(localized: "Simple app list disabled"))
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        Spacer()
                        Toggle(isOn: $minimalEnabled, label: {
                        })
                        .toggleStyle(SettingsToggle())
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: multiSelect ? "checkmark.square.fill" : "square")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(multiSelect ? String(localized: "Multi-select enabled in sidebar app list") : String(localized: "Multi-select disabled in sidebar app list"))
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        Spacer()
                        Toggle(isOn: $multiSelect, label: {
                        })
                        .toggleStyle(SettingsToggle())
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: greetingEnabled ? "hand.raised.fill" : "hand.raised")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(greetingEnabled ? String(localized: "Greeting enabled on main page") : String(localized: "Greeting disabled on main page"))
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        Spacer()
                        Toggle(isOn: $greetingEnabled, label: {
                        })
                        .toggleStyle(SettingsToggle())
                    }
                    .padding(5)

                }
            })

            PearGroupBox(header: { Text("Theme").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2) }, content: {
                ThemeCustomizationView()
            })
        }

    }

}

