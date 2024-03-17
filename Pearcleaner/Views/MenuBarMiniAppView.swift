//
//  MenuBarAppsListView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/16/24.
//

import Foundation
import SwiftUI

struct MenuBarMiniAppView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @State private var windowSettings = WindowSettings()
    @State private var animateGradient: Bool = false
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.instant") private var instantSearch: Bool = true
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @Binding var showPopover: Bool

    var body: some View {

        var filteredApps: [AppInfo] {
            if search.isEmpty {
                return appState.sortedApps
            } else {
                return appState.sortedApps.filter { $0.appName.localizedCaseInsensitiveContains(search) }
            }
        }

        ZStack {
            HStack(spacing: 0){

                if appState.reload {
                    VStack {
                        Spacer()
                        ProgressView(instantSearch ? "Refreshing app list and caching files" : "Refreshing app list")
                        if instantSearch {
                            Image(systemName: "bolt.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(Color("mode").opacity(0.5))
                                .frame(width: 30, height: 30)
                                .padding()
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                } else {
                    VStack(alignment: .center) {

                        AppsListView(search: $search, showPopover: $showPopover, filteredApps: filteredApps).padding(0)
                        HStack(spacing: 10) {
                            if #available(macOS 14.0, *) {
                                SettingsLink()
                                    .buttonStyle(SimpleButtonStyle(icon: "gear", help: "Settings", color: Color("mode")))
                            } else {
                                Button("Settings") {
                                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: NSApp.delegate, from: nil)
                                }
                                .buttonStyle(SimpleButtonStyle(icon: "gear", help: "Settings", color: Color("mode")))
                            }

                            SearchBarMiniBottom(search: $search)

                            Button("Main") {
                                windowSettings.newWindow {
                                    MiniMode(search: $search, showPopover: $showPopover)
                                        .environmentObject(locations)
                                        .environmentObject(appState)
                                }
                            }
                            .buttonStyle(SimpleButtonStyle(icon: "macwindow", help: "Show Main Window", color: Color("mode")))

                            Button("Kill") {
                                NSApp.terminate(nil)
                            }
                            .buttonStyle(SimpleButtonStyle(icon: "x.circle.fill", help: "Quit", color: Color("mode")))
                        }
                        .padding(.horizontal)

                    }
                    .padding(.vertical, 5)
                    .padding(.bottom, 8)
                }


            }
        }
        .frame(minWidth: 300, minHeight: 370)
        .edgesIgnoringSafeArea(.all)
        .background(
            Group {
                if glass {
                    GlassEffect(material: .sidebar, blendingMode: .behindWindow)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Color("pop")
                        .padding(-80)
                }
            }
        )
        .transition(.opacity)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack {
                if appState.currentView == .files {
                    FilesView(showPopover: $showPopover, search: $search)
                        .id(appState.appInfo.id)
                } else if appState.currentView == .zombie {
                    ZombieView(showPopover: $showPopover, search: $search)
                        .id(appState.appInfo.id)
                }

            }
            .interactiveDismissDisabled(popoverStay)
            .background(
                Rectangle()
                    .fill(Color("pop"))
                    .padding(-80)
            )
            .frame(width: 650, height: 550)

        }
    }
}
