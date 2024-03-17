//
//  MenuBar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/16/24.
//
import Foundation
import SwiftUI
import ServiceManagement

struct MenuBarSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @State private var isLaunchAtLoginEnabled: Bool = false

    @Binding var showPopover: Bool
    @Binding var search: String

    var body: some View {
        Form {
            VStack {

                HStack() {
                    Text("Configuration").font(.title2)
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
                    Spacer()
                    Toggle(isOn: $menubarEnabled, label: {
                    })
                        .toggleStyle(.switch)
                        .onChange(of: menubarEnabled) { newVal in
                            if newVal {
                                MenuBarExtraManager.shared.addMenuBarExtra {
                                    MenuBarMiniAppView(search: $search, showPopover: $showPopover)
                                        .environmentObject(locations)
                                        .environmentObject(appState)
                                }
                            } else {
                                MenuBarExtraManager.shared.removeMenuBarExtra()
                            }
                        }

                }
                .padding(5)
                .padding(.leading)


                HStack(spacing: 0) {
                    Image(systemName: isLaunchAtLoginEnabled ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
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

                Spacer()
            }

        }
        .padding(20)
        .frame(width: 500, height: 690)

    }

}
