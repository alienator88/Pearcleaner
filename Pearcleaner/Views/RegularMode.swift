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

    var body: some View {

        // Main App Window
        VStack(spacing: 0) {

            // Tab View
            CustomTabView(content: [
                (
                    title: "Installed",
                    icon: "externaldrive",
                    view: AnyView (
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
                            .background(backgroundView(themeManager: themeManager, darker: true, glass: glass))
                            .transition(.opacity)

                            SlideableDivider(dimension: $sidebarWidth)
                                .background(backgroundView(themeManager: themeManager))
                                .zIndex(3)


                            // Details View
                            HStack(spacing: 0) {
                                Spacer()
                                Group {
                                    if appState.currentView == .empty || appState.currentView == .apps {
                                        AppDetailsEmptyView(showPopover: $showPopover)
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
                            .background(backgroundView(themeManager: themeManager))
                        }
                    )
                ),
                (
                    title: "Uninstalled",
                    icon: "externaldrive.badge.minus",
                    view: AnyView(
                        ZombieView(showPopover: $showPopover, search: $search)
                            .background(backgroundView(themeManager: themeManager))
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
                    )
                ),
            ])

        }
        .frame(minWidth: 900, minHeight: 600)
        .edgesIgnoringSafeArea(.all)


    }
}






struct AppDetailsEmptyView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    //    @AppStorage("settings.general.animateLogo") private var animateLogo: Bool = true
    @Binding var showPopover: Bool
    //    @State private var animationStart = false

    var body: some View {
        VStack(alignment: .center) {

            Spacer()

            PearDropView()
            //            if #available(macOS 14, *) {
            //                if animateLogo && animationStart {
            //                    PearDropView()
            //                        .phaseAnimator([false, true]) { wwdc24, chromaRotate in
            //                            wwdc24
            //                                .hueRotation(.degrees(chromaRotate ? 420 : 0))
            //                        } animation: { chromaRotate in
            //                                .easeInOut(duration: 6)
            //                        }
            //                } else {
            //                    PearDropView()
            //                }
            //
            //            } else {
            //                PearDropView()
            //            }

            Spacer()

            //            Text("Drop an app here")
            //                .font(.title3)
            //                .padding(.bottom, 25)
            //                .opacity(0.5)
        }
        //        .onAppear {
        //            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        //                animationStart = true
        //            }
        //        }
    }
}
