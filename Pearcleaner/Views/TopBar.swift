//
//  TopBar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/10/23.
//

import Foundation
import SwiftUI

struct TopBar: View {
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.instant") private var instantSearch: Bool = true
    @EnvironmentObject var appState: AppState
    @Binding var showPopover: Bool
    @EnvironmentObject var locations: Locations

    var body: some View {
        HStack(alignment: .center, spacing: 0) {

            Spacer()

            if appState.isReminderVisible {
                Text("CMD + Z to undo")
                    .font(.title2)
                    .foregroundStyle(Color("mode").opacity(0.5))
                    .fontWeight(.medium)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                appState.isReminderVisible = false
                            }
                        }
                    }
            }

            Spacer()

            HStack() {
                Spacer()

                if appState.currentView != .zombie {
                    Button("") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            updateOnMain {
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
                }
                

                if appState.currentView == .files || appState.currentView == .zombie {
                    Button("") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            appState.currentView = .empty
                            appState.appInfo = AppInfo.empty
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "plus.square.dashed", help: "Drop Target", color: Color("mode")))

                }


            }


 
        }
        .padding(.horizontal, 10)
        .padding(.top, 15)
    }
}
