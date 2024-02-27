//
//  TopBar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/10/23.
//

import Foundation
import SwiftUI

struct TopBar: View {
    //    @Binding var sidebar: Bool
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @EnvironmentObject var appState: AppState
    @Binding var showPopover: Bool
    @EnvironmentObject var locations: Locations

    var body: some View {
        HStack(alignment: .center, spacing: 10) {

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

            if appState.currentView != .empty {//|| appState.currentView != .apps {
                Button("") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        appState.currentView = .empty
                        appState.appInfo = AppInfo.empty
                    }
                }
                .buttonStyle(SimpleButtonStyle(icon: "house", help: "Home", color: Color("mode")))
                
            }

            if appState.currentView != .zombie {
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


            
            
//            Spacer()
            
            
            
//            if sentinel {
//                Button("") {
//                    //
//                }
//                .buttonStyle(SimpleButtonStyle(icon: "lock.shield", help: "Sentinel enabled", color: .green, shield: true))
//            }
            
            
            
        }
        .padding(.horizontal, 5)
        .padding(.top, 10)
    }
}
