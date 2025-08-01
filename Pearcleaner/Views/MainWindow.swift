//
//  AppListH.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI
import AlinFoundation
import FinderSync

struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 265
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @State private var showMenu = false
//    @State var isMenuBar: Bool = false
//    @State private var isExpanded: Bool = false

    var body: some View {

        // Main App Window
        ZStack() {

            HStack(alignment: .center, spacing: 0) {
                LeftNavigationSidebar()
                    .zIndex(1)

                switch appState.currentPage {
                case .applications:
                    HStack(alignment: .center, spacing: 0) {

                        // App List
                        AppSearchView(glass: glass, search: $search)
                            .frame(width: sidebarWidth)
                            .transition(.opacity)

                        SlideableDivider(dimension: $sidebarWidth)
                            .zIndex(3)

                        // Details View
                        HStack(spacing: 0) {
                            Group {
                                switch appState.currentView {
                                case .empty:
                                    AppDetailsEmptyView()
                                case .files:
                                    FilesView(search: $search)
                                        .id(appState.appInfo.id)
                                case .zombie:
                                    ZombieView(search: $search)
                                        .id(appState.appInfo.id)
                                case .terminal:
                                    TerminalSheetView(homebrew: true, caskName: appState.appInfo.cask)
                                        .id(appState.appInfo.id)
                                }
                            }
                            .transition(.opacity)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .zIndex(2)
                    }

                case .orphans:
                    ZombieView(search: $search)
                        .onAppear {
                            if appState.zombieFile.fileSize.keys.isEmpty {
                                appState.showProgress.toggle()
                            }
                            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                if appState.zombieFile.fileSize.keys.isEmpty {
                                    reversePreloader(allApps: appState.sortedApps, appState: appState, locations: locations, fsm: fsm)
                                }
                            }
                        }

                case .development:
                    EnvironmentCleanerView()

                case .lipo:
                    LipoView()
                }
            }
        }
        .background(backgroundView(color: theme(for: colorScheme).backgroundMain))
        .frame(minWidth: appState.currentPage == .orphans ? 700 : 900, minHeight: 600)
        .edgesIgnoringSafeArea(.all)
    }
}






struct AppDetailsEmptyView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .center) {

            Spacer()

//            PearDropView()
            ThemeColorDemo()
            Text("Welcome")
                .frame(width: 500)

            Spacer()

        }
    }
}
