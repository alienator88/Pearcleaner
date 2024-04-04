//
//  TopBarMini.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/14/23.
//

import Foundation
import SwiftUI

struct TopBarMini: View {
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.instant") private var instantSearch: Bool = true
    @Binding var search: String
    @Binding var showPopover: Bool
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations

    var body: some View {
        HStack(alignment: .center, spacing: 0) {

            Spacer()

            if appState.currentView == .empty {

                HStack {
                    Spacer()

                    Button("") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showPopover = false
                            updateOnMain {
                                if appState.zombieFile.fileSize.keys.count == 0 {
                                    appState.currentView = .zombie
                                    appState.showProgress.toggle()
                                    showPopover.toggle()
                                    if instantSearch {
                                        let reverse = ReversePathsSearcher(appState: appState, locations: locations)
                                        reverse.reversePathsSearch()
//                                        reversePathsSearch(appState: appState, locations: locations)
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

                    Button("") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            appState.currentView = .apps
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "square.grid.3x3.square", help: "Apps List", color: Color("mode")))


                }

            }

            if appState.currentView != .empty {
                HStack {
                    Spacer()

                    Button("") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showPopover = false
                            updateOnMain {
                                appState.appInfo = .empty
                                appState.selectedZombieItems = []
                                if appState.zombieFile.fileSize.keys.count == 0 {
                                    appState.currentView = .zombie
                                    appState.showProgress.toggle()
                                    showPopover.toggle()
                                    if instantSearch {
                                        let reverse = ReversePathsSearcher(appState: appState, locations: locations)
                                        reverse.reversePathsSearch()
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

                    Button("") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            appState.currentView = .empty
                            appState.appInfo = AppInfo.empty
                            showPopover = false
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "plus.square.dashed", help: "Drop Target", color: Color("mode")))
                }
            }


        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 5)
    }
}


struct SearchBarMini: View {
    @Binding var search: String

    var body: some View {
        HStack {
            TextField("Search", text: $search)
                .textFieldStyle(AnimatedSearchStyle(text: $search))
        }
        .frame(height: 20)
    }
}

struct SearchBarMiniBottom: View {
    @Binding var search: String
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            TextField("\(appState.instantTotal > appState.instantProgress ? " Searching the file system" : " Search")", text: $search)
                .textFieldStyle(SimpleSearchStyle(trash: true, text: $search))
        }
    }
}
