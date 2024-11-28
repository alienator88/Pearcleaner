//
//  AppListH.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI
import AlinFoundation

struct RegularMode: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 280
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @Binding var showPopover: Bool
    @State private var showMenu = false
    @State var isMenuBar: Bool = false
    @State private var isExpanded: Bool = false

    var body: some View {

        // Main App Window
        ZStack() {

            if appState.currentPage == .applications {
                HStack(alignment: .center, spacing: 0) {

                    // App List
                    HStack(spacing: 0){

                        if appState.reload {
                            VStack {
                                Spacer()
                                ProgressView() {
                                    Text("Gathering app details")
                                        .font(.callout)
                                        .foregroundStyle(.primary.opacity(0.5))
                                        .padding(5)
                                }
                                Spacer()
                            }
                            .frame(width: sidebarWidth)
                            .padding(.vertical)
                        } else {
                            AppSearchView(glass: glass, menubarEnabled: menubarEnabled, mini: mini, search: $search, showPopover: $showPopover, isMenuBar: $isMenuBar)
                                .frame(width: sidebarWidth)

                        }

                    }
                    .transition(.opacity)

                    SlideableDivider(dimension: $sidebarWidth)
                        .zIndex(3)


                    // Details View
                    HStack(spacing: 0) {
                        Spacer()
                        Group {
                            if appState.currentView == .empty || appState.currentView == .apps {
                                AppDetailsEmptyView()
                            } else if appState.currentView == .files {
                                FilesView(showPopover: $showPopover, search: $search)
                                    .id(appState.appInfo.id)
                            } else if appState.currentView == .zombie {
                                ZombieView(showPopover: $showPopover, search: $search)
                                    .id(appState.appInfo.id)
                            }
                        }
                        .transition(.opacity)
                        Spacer()
                    }
                    .zIndex(2)
                }

            } else if appState.currentPage == .orphans {
                ZombieView(showPopover: $showPopover, search: $search)
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
            } else if appState.currentPage == .development {
                EnvironmentCleanerView()
            }

#if DEBUG
            VStack(spacing: 0) {
                HStack {
                    Text("DEBUG").foregroundStyle(.orange).bold().help("VERSION: \(Bundle.main.version) | BUILD: \(Bundle.main.buildVersion)")
                    Spacer()
                }
                Spacer()
            }
            .padding(5.25)
            .padding(.leading, 62)
#endif

            VStack(spacing: 0) {

                HStack {
                    Spacer()
                    CustomPickerButton(
                        selectedOption: $appState.currentPage,
                        isExpanded: $isExpanded,
                        options: CurrentPage.allCases.sorted { $0.title < $1.title } // Sort by title
                    )
                    .padding(2)
                    .padding(.vertical, 2)

                }
                .padding(6)


                Spacer()
            }

        }
        .background(backgroundView(themeManager: themeManager))
        .frame(minWidth: appState.currentPage == .orphans ? 700 : 900, minHeight: 600)
        .edgesIgnoringSafeArea(.all)
        .onTapGesture {
            withAnimation(Animation.spring(duration: animationEnabled ? 0.35 : 0)) {
                if isExpanded {
                    isExpanded = false
                }
            }

        }


    }
}






struct AppDetailsEmptyView: View {

    var body: some View {
        VStack(alignment: .center) {

            Spacer()

            PearDropView()

//            GlowGradientButton()

            Spacer()

        }

    }
}
