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
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 300
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
                    AppSearchView(glass: glass, menubarEnabled: menubarEnabled, mini: mini, search: $search, showPopover: $showPopover, isMenuBar: $isMenuBar)
                        .frame(width: sidebarWidth)
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
                            } else if appState.currentView == .terminal {
                                TerminalSheetView(showPopover: $showPopover, homebrew: true, caskName: appState.appInfo.cask)
                                    .id(appState.appInfo.id)
                            }
                        }
                        .transition(.opacity)
                        if appState.currentView != .terminal {
                            Spacer()
                        }
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
            } else if appState.currentPage == .thinning {
                LipoView()
            }



            if appState.currentView != .terminal {
                VStack(spacing: 0) {

                    HStack {

                        Spacer()

                        CustomPickerButton(
                            selectedOption: $appState.currentPage,
                            isExpanded: $isExpanded,
                            options: CurrentPage.allCases.sorted { $0.title < $1.title } // Sort by title
                        )
                        .padding(6)
                    }


                    Spacer()
                }
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
    @EnvironmentObject var appState: AppState
//    @State private var showTerminal: Bool = false
//    @State private var showPopover: Bool = false

    var body: some View {
        VStack(alignment: .center) {

            Spacer()

            PearDropView()

//            Button("Open") {
//                showTerminal.toggle()
//            }

//            GlowGradientButton()

            Spacer()

        }
//        .sheet(isPresented: $showTerminal, content: {
//            VStack {
//                TerminalSheetView(showPopover: $showPopover, title: "Homebrew Cleanup: \(appState.appInfo.appName)", command: getBrewCleanupCommand(for: "appcleaner"))
//                    .id(appState.appInfo.id)
//                Button("Close") {
//                    showTerminal.toggle()
//                }
//            }
//            .frame(width: 600, height: 600)
//
//
//        })
    }
}
