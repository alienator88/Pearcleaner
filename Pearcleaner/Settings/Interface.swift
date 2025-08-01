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
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.minimalist") private var minimalEnabled: Bool = true
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @Binding var search: String

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
                        .toggleStyle(SettingsToggle())
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
                        .toggleStyle(SettingsToggle())
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
                        .toggleStyle(SettingsToggle())
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
                        .toggleStyle(SettingsToggle())
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
//                        ThemeSettingsView(opacity: 1)
                    }
                    .padding(5)
                }
            })
        }

    }

}

