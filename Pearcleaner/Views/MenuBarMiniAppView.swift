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
//    @State private var windowSettings = WindowSettings()
    @State private var animateGradient: Bool = false
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.instant") private var instantSearch: Bool = true
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @Binding var showPopover: Bool
    @State private var showMenu = false

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

                            Button("Leftover Files") {
                                showMenu = false
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showPopover = false
                                    updateOnMain() {
                                        appState.appInfo = .empty
                                        appState.selectedZombieItems = []
                                        if appState.zombieFile.fileSize.keys.count == 0 {
                                            appState.currentView = .zombie
                                            appState.showProgress.toggle()
                                            showPopover.toggle()
                                            if instantSearch {
                                                reversePathsSearch(appState: appState, locations: locations)
                                            } else {
                                                loadAllPaths(allApps: appState.sortedApps, appState: appState, locations: locations, reverseAddon: true)
                                            }
                                        } else {
                                            appState.currentView = .zombie
                                            showPopover.toggle()
                                        }
                                    }

                                }
                            }
                            .buttonStyle(SimpleButtonStyle(icon: "clock.arrow.circlepath", help: "Leftover Files", color: Color("mode")))
                            .padding(.leading, 10)

                            SearchBarMiniBottom(search: $search)
//                                .padding(.leading, 20)

                            Button("More") {
                                self.showMenu.toggle()
                            }
                            .padding(.trailing, 10)
                            .buttonStyle(SimpleButtonStyle(icon: "ellipsis.circle", help: "More", color: Color("mode")))
                            .popover(isPresented: $showMenu) {
                                VStack(alignment: .leading) {

                                    if #available(macOS 14.0, *) {
                                        SettingsLink{
                                            Label("Settings", systemImage: "gear")
                                        }
                                        .buttonStyle(SimpleButtonStyle(icon: "gear", label: "Settings", help: "Settings", color: Color("mode")))
                                    } else {
                                        Button("Settings") {
                                            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: NSApp.delegate, from: nil)
                                            showMenu = false
                                        }
                                        .buttonStyle(SimpleButtonStyle(icon: "gear", label: "Settings", help: "Settings", color: Color("mode")))
                                    }



//                                    Button("Leftover Files") {
//                                        showMenu = false
//                                        withAnimation(.easeInOut(duration: 0.5)) {
//                                            showPopover = false
//                                            updateOnMain() {
//                                                appState.appInfo = .empty
//                                                appState.selectedZombieItems = []
//                                                if appState.zombieFile.fileSize.keys.count == 0 {
//                                                    appState.currentView = .zombie
//                                                    appState.showProgress.toggle()
//                                                    showPopover.toggle()
//                                                    if instantSearch {
//                                                        reversePathsSearch(appState: appState, locations: locations)
//                                                    } else {
//                                                        loadAllPaths(allApps: appState.sortedApps, appState: appState, locations: locations, reverseAddon: true)
//                                                    }
//                                                } else {
//                                                    appState.currentView = .zombie
//                                                    showPopover.toggle()
//                                                }
//                                            }
//
//                                        }
//                                    }
//                                    .buttonStyle(SimpleButtonStyle(icon: "clock.arrow.circlepath", label: "Leftover Files", help: "Leftover Files", color: Color("mode")))




                                    Button("Quit") {
                                        NSApp.terminate(nil)
                                    }
                                    .buttonStyle(SimpleButtonStyle(icon: "x.circle.fill", label: "Quit Pearcleaner", help: "Quit Pearcleaner", color: Color("mode")))
                                }
                                .padding()
                                .background(
                                    Group {
                                        if glass {
                                            GlassEffect(material: .sidebar, blendingMode: .behindWindow)
                                                .edgesIgnoringSafeArea(.all)
                                        } else {
                                            Rectangle()
                                                .fill(Color("pop"))
                                                .padding(-80)

                                        }
                                    }
                                )
                            }



                            
                        }
//                        .padding(.horizontal)

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
                    Rectangle()
                        .fill(Color("pop"))
                        .padding(-80)

                }
            }
        )
        .transition(.opacity)
        .popover(isPresented: $showPopover, arrowEdge: .leading) {
            VStack {
                if appState.currentView == .files {
                    FilesView(showPopover: $showPopover, search: $search, regularWin: false)
                        .id(appState.appInfo.id)
                } else if appState.currentView == .zombie {
                    ZombieView(showPopover: $showPopover, search: $search, regularWin: false)
                        .id(appState.appInfo.id)
                }

            }
            .interactiveDismissDisabled(popoverStay)
            .background(
                Group {
                    if glass {
                        GlassEffect(material: .sidebar, blendingMode: .behindWindow)
                            .edgesIgnoringSafeArea(.all)
                    } else {
                        Rectangle()
                            .fill(Color("pop"))
                            .padding(-80)

                    }
                }
            )
            .frame(width: 650, height: 500)

        }
    }
}
