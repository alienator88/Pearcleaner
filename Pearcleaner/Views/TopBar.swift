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
    @Binding var reload: Bool
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            
            HStack(alignment: .center, spacing: 5) {
//                    Button("") {
//                        withAnimation(.easeInOut(duration: 0.5)) {
//                            appState.sidebar.toggle()
//                            if appState.sidebar {
//                                appState.winWidth += 300
//                            } else {
//                                appState.winWidth -= 300
//                            }
//                        }
//                    }
//                    .buttonStyle(SimpleButtonStyle(icon: "sidebar.left", help: "Toggle Sidebar", color: Color("AccentColor")))
                
                
                Button("") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        // Refresh Apps list
                        reload.toggle()
                        let sortedApps = getSortedApps()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            appState.sortedApps.userApps = sortedApps.userApps
                            appState.sortedApps.systemApps = sortedApps.systemApps
                            reload.toggle()
                        }
                        
                    }
                }
                .buttonStyle(SimpleButtonStyle(icon: "arrow.circlepath", help: "Refresh app list", color: Color("AccentColor")))
                
                Button("") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        openTrash()
                    }
                }
                .buttonStyle(SimpleButtonStyle(icon: "trash", help: "Open Trash", color: Color("AccentColor")))
            }
            
            Spacer()
            
            
            
            if appState.currentView != .empty {
                Button("") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        appState.currentView = .empty
                        appState.appInfo = AppInfo.empty
                    }
                }
                .buttonStyle(SimpleButtonStyle(icon: "house", help: "Home", color: Color("AccentColor")))
            }
            
            
            
            
            Spacer()
            
            HStack(alignment: .center, spacing: 5) {
                
                if sentinel {
                    Button("") {
                        //
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "lock.shield", help: "Sentinel enabled", color: .green, shield: true))
                }
                

                Button("") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        glass.toggle()
                    }
                }
                .buttonStyle(SimpleButtonStyle(icon: glass ? "circle.dashed" : "circle.dashed.inset.filled", help: "Toggle transparency", color: Color("AccentColor")))
                                
                Button("") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        if displayMode.colorScheme == .dark {
                            displayMode.colorScheme = .light
                        } else if displayMode.colorScheme == .light {
                            displayMode.colorScheme = .dark
                        } else {
                            displayMode.colorScheme = .dark
                        }
                    }
                }
                .buttonStyle(SimpleButtonStyle(icon: displayMode.colorScheme == .dark ? "sun.max.fill" : "moon.fill", help: "Toggle appearance", color: Color("AccentColor")))
            }

            
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
    }
}
