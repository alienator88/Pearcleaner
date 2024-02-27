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
    @Binding var search: String
    @Binding var showPopover: Bool
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations

    var body: some View {
        HStack(alignment: .center, spacing: 5) {

            Spacer()

//            if appState.currentView == .apps {
//                Button("") {
//                    withAnimation(.easeInOut(duration: 0.5)) {
//                        //                        updateOnMain {
//                        appState.currentView = .empty
//                        appState.appInfo = AppInfo.empty
//                        showPopover = false
//                        //                        }
//                    }
//                }
//                .buttonStyle(SimpleButtonStyle(icon: "arrow.backward.square", help: "Back to Drop Zone", color: Color("mode")))
//            } else 
            if appState.currentView == .empty {
                Button("") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        //                        updateOnMain {
                        appState.currentView = .apps
                        //                        }
                    }
                }
                .buttonStyle(SimpleButtonStyle(icon: "list.dash", help: "Apps List", color: Color("mode")))
            } 
//            else if appState.currentView == .files {
//                Button("") {
//                    withAnimation(.easeInOut(duration: 0.5)) {
//                        //                        updateOnMain {
//                        appState.currentView = .empty
//                        appState.appInfo = AppInfo.empty
//                        //                        }
//
//                    }
//                }
//                .buttonStyle(SimpleButtonStyle(icon: "plus.square.dashed", help: "Drop Target", color: Color("mode")))
//                Button("") {
//                    withAnimation(.easeInOut(duration: 0.5)) {
//                        //                        updateOnMain {
//                        appState.currentView = .apps
//                        //                        }
//                    }
//                }
//                .buttonStyle(SimpleButtonStyle(icon: "list.dash", help: "Apps List", color: Color("mode")))
//            }

            if appState.currentView != .empty {
                HStack {
                    Spacer()

//                    SearchBarMini(search: $search)
//                        .frame(width: 150)
//                        .offset(x: 20)
//                        .padding(.horizontal, 30)
//                        .padding(.top, 5)

                    Button("") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            //                        updateOnMain {
                            appState.currentView = .empty
                            appState.appInfo = AppInfo.empty
                            showPopover = false
                            //                        }
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "plus.square.dashed", help: "Drop Target", color: Color("mode")))

                    Button("") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            updateOnMain {
                                if appState.zombieFile.fileSize.keys.count == 0 {
                                    appState.currentView = .zombie
                                    appState.showProgress.toggle()
                                    showPopover.toggle()
                                    reversePathsSearch(appState: appState, locations: locations)
                                } else {
                                    appState.currentView = .zombie
                                    showPopover.toggle()
                                }
                            }

                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "clock.arrow.circlepath", help: "Leftover Files", color: Color("mode")))

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
            //                .textFieldStyle(SimpleSearchStyle(trash: true, reload: $reload, text: $search))
        }
                .frame(height: 20)
    }
}

struct SearchBarMiniBottom: View {
    @Binding var search: String
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            TextField(" Search", text: $search)
                .textFieldStyle(SimpleSearchStyle(trash: true, text: $search))
        }
        .padding(.horizontal)
        .padding(.bottom, 0)
    }
}
