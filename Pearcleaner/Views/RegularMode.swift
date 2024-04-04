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
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 280
    @AppStorage("settings.general.instant") private var instantSearch: Bool = true
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @Binding var showPopover: Bool
//    @State private var isHovering = false
//    @State private var isHovering2 = false


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
                        ProgressView(instantSearch ? "Refreshing app list and caching files" : "Refreshing app list")
                        if instantSearch {
                            Image(systemName: "bolt")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        }
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
//                    .onHover { hovering in
//                        withAnimation(Animation.easeInOut(duration: 0.4)) {
//                            isHovering = hovering
//                        }
//                    }
//                    .opacity(!isHovering ? 1 : 0.5)

                }


            }
            .background(glass ? GlassEffect(material: .sidebar, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all) : nil)
            .transition(.opacity)

            SlideableDivider(dimension: $sidebarWidth)


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
//            .onHover { hovering in
//                withAnimation(Animation.easeInOut(duration: 0.4)) {
//                    isHovering = hovering
//                }
//            }
//            .opacity((isHovering2 || (!isHovering && !isHovering2)) ? 1 : 0.5)


        }
        .frame(minWidth: 900, minHeight: 600)
        .edgesIgnoringSafeArea(.all)

        // MARK: Background for whole app
//        .background{
//            Image("peakpx")
//                .resizable()
//                .scaledToFill()
//                .edgesIgnoringSafeArea(.all)
//            GlassEffect(material: .sidebar, blendingMode: .withinWindow)
//                .edgesIgnoringSafeArea(.all)
//        }
        //        .background(Color("bg").opacity(1))
        //        .background(VisualEffect(material: .sidebar, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all))
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
    @AppStorage("settings.general.instant") private var instantSearch: Bool = true
    @AppStorage("settings.general.glass") private var glass: Bool = true


    var body: some View {
        HStack {
            Text(title).foregroundStyle(Color("mode")).opacity(0.5)

            HStack {
                if hovered {
                    withAnimation() {
                        Image(systemName: "arrow.circlepath")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 19)
                            .onTapGesture {
                                withAnimation {
                                    // Refresh Apps list
                                    appState.reload.toggle()
                                    showPopover = false
                                    let sortedApps = getSortedApps(paths: fsm.folderPaths, appState: appState)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        appState.sortedApps = sortedApps
                                        if instantSearch {
                                            loadAllPaths(allApps: sortedApps, appState: appState, locations: locations) {
                                                appState.reload.toggle()
                                            }
                                        } else {
                                            appState.reload.toggle()
                                        }

                                    }
                                }
                            }
                            .help("Refresh apps")
                    }
                } else {
                    Text("\(count)")
                        .font(.system(size: 10))
                        .frame(minWidth: count > 99 ? 30 : 20, minHeight: 15)
                        .padding(2)
                        .background(Color("mode").opacity(0.1))
                        .clipShape(.capsule)
                }
            }
            .onHover { hovering in
                withAnimation() {
                    hovered = hovering
                }
            }

            Spacer()

        }
        .padding(.vertical, 9)
        .padding(.leading, 6)
//        .background(!glass ? Color("windowBG") : .clear)
    }
}
