//
//  AppListH.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI

struct RegularMode: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeSettings: ThemeSettings
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 280
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @Binding var showPopover: Bool


    var filteredApps: [AppInfo] {
        if search.isEmpty {
            return appState.sortedApps
        } else {
            return appState.sortedApps.filter { $0.appName.localizedCaseInsensitiveContains(search) }
        }
    }


    var body: some View {

        HStack(alignment: .center, spacing: 0) {
            // App List
            HStack(spacing: 0){

                if appState.reload {
                    VStack {
                        Spacer()
                        ProgressView("Refreshing app list")
                        Spacer()
                    }
                    .frame(width: sidebarWidth)
                    .padding(.vertical)
                } else {
                    VStack(alignment: .center) {

                        VStack(alignment: .center, spacing: 20) {
                            HStack {
                                SearchBarMiniBottom(search: $search)
                                    .padding(.horizontal)

                            }
                        }
                        .padding(.top, 20)


                        AppsListView(search: $search, showPopover: $showPopover, filteredApps: filteredApps)

                    }
                    .frame(width: sidebarWidth)
                    .padding(.vertical)
                }


            }
            .background(backgroundView(themeSettings: themeSettings, darker: true, glass: glass))
            .transition(.opacity)

            SlideableDivider(dimension: $sidebarWidth)
                .background(backgroundView(themeSettings: themeSettings))
                .zIndex(3)


            // Details View
            VStack(spacing: 0) {
                Group {
                    if appState.currentView == .empty || appState.currentView == .apps {
                        TopBar(showPopover: $showPopover)
                        AppDetailsEmptyView(showPopover: $showPopover)
                    } else if appState.currentView == .files {
                        TopBar(showPopover: $showPopover)
                        FilesView(showPopover: $showPopover, search: $search, regularWin: true)
                            .id(appState.appInfo.id)
                    } else if appState.currentView == .zombie {
                        TopBar(showPopover: $showPopover)
                        ZombieView(showPopover: $showPopover, search: $search, regularWin: true)
                            .id(appState.appInfo.id)
                    }
                }
                .transition(.opacity)
            }
            .zIndex(2)
            .background(backgroundView(themeSettings: themeSettings))
        }
        .frame(minWidth: 900, minHeight: 600)
        .edgesIgnoringSafeArea(.all)
    }
}






struct AppDetailsEmptyView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @State private var animateGradient: Bool = false
    @Binding var showPopover: Bool

    var body: some View {
        VStack(alignment: .center) {

            Spacer()

            PearDropView()

            Spacer()

            Text("Drop your app here or select one from the list")
                .font(.title3)
                .padding(.bottom, 25)
                .opacity(0.5)
        }
    }
}


struct SearchBar: View {
    @Binding var search: String

    var body: some View {
        HStack {
            TextField("Search", text: $search)
                .textFieldStyle(SimpleSearchStyle(icon: Image(systemName: "magnifyingglass"),trash: true, text: $search))
        }
        .frame(height: 30)
    }
}


struct Header: View {
    let title: String
    let count: Int
    @State private var hovered = false
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @Binding var showPopover: Bool
    @AppStorage("settings.general.glass") private var glass: Bool = true


    var body: some View {
        HStack {
            Text("\(title)").foregroundStyle(Color("mode")).opacity(0.5)

            Text("\(count)")
                .font(.system(size: 10))
                .monospacedDigit()
                .frame(minWidth: count > 99 ? 30 : 24, minHeight: 17)
                .background(Color("mode").opacity(0.1))
                .clipShape(.capsule)
                .padding(.leading, 2)

            Spacer()

            if hovered {
                Text("REFRESH")
                    .font(.system(size: 10))
                    .monospaced()
                    .foregroundStyle(Color("mode").opacity(0.8))
            }

        }
        .onHover { hovering in
            withAnimation() {
                hovered = hovering
            }
        }
        .onTapGesture {
            withAnimation {
                // Refresh Apps list
                appState.reload.toggle()
                showPopover = false
                let sortedApps = getSortedApps(paths: fsm.folderPaths, appState: appState)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    appState.sortedApps = sortedApps
                    appState.reload.toggle()
                }
            }
        }
        .frame(minHeight: 20)
        .help("Click header or ⌘+R to refresh apps list")
        .padding(5)
    }
}
