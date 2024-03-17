//
//  MiniMode.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/14/23.
//


import Foundation
import SwiftUI

struct MiniMode: View {
    @EnvironmentObject var appState: AppState
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @Binding var showPopover: Bool
    
    
    var body: some View {
        
        HStack(alignment: .center, spacing: 0) {
            
            // Main Mini View
            VStack(spacing: 0) {
                Group {
                    if appState.currentView == .empty {
                        TopBarMini(search: $search, showPopover: $showPopover)
                        MiniEmptyView(showPopover: $showPopover)
                    } else {
                        TopBarMini(search: $search, showPopover: $showPopover)
                        MiniAppView(search: $search, showPopover: $showPopover)
                    }
                }
                .transition(.opacity)
            }
            .popover(isPresented: $showPopover, arrowEdge: .trailing) {
                VStack {
                    if appState.currentView == .files {
                        FilesView(showPopover: $showPopover, search: $search)
                            .id(appState.appInfo.id)
                    } else if appState.currentView == .zombie {
                        ZombieView(showPopover: $showPopover, search: $search)
                            .id(appState.appInfo.id)
                    }

                }
                .interactiveDismissDisabled(popoverStay)
                .background(
                    Rectangle()
                        .fill(Color("pop"))
                        .padding(-80)
                )
                .frame(width: 650, height: 550)

            }

            
        }
        .frame(minWidth: 300, minHeight: 345)
        .edgesIgnoringSafeArea(.all)
        .background(glass ? GlassEffect(material: .sidebar, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all) : nil)
        // MARK: Background for whole app
        //        .background(Color("bg").opacity(1))
        //        .background(VisualEffect(material: .sidebar, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all))
    }
}






struct MiniEmptyView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @State private var animateGradient: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @Binding var showPopover: Bool

    var body: some View {
        VStack() {
            
            Spacer()
            
            ZStack {
                LinearGradient(gradient: Gradient(colors: [.green, .orange]), startPoint: .leading, endPoint: .trailing)
                    .mask(
                        Image(systemName: "plus.square.dashed")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .padding()
                            .fontWeight(.ultraLight)
                    )
                    .frame(width: 160)
            }

            Text("Drop your app here")
                .font(.title3)
                .padding(.bottom, 25)
                .opacity(0.5)


            Spacer()
            

            if appState.isReminderVisible {
                Text("CMD + Z to undo")
                    .font(.title2)
                    .foregroundStyle(Color("mode").opacity(0.5))
                    .fontWeight(.medium)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                updateOnMain {
                                    appState.isReminderVisible = false
                                }
                            }
                        }
                    }
                Spacer()
            }

            Spacer()

            
        }
    }
}





struct MiniAppView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var animateGradient: Bool = false
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.instant") private var instantSearch: Bool = true
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @Binding var showPopover: Bool
    
    var body: some View {
        
        var filteredApps: [AppInfo] {
            if search.isEmpty {
                return appState.sortedApps
            } else {
                return appState.sortedApps.filter { $0.appName.localizedCaseInsensitiveContains(search) }
            }
        }
        
        ZStack {
            HStack(spacing: 0){
                
                if appState.reload {
                    VStack {
                        Spacer()
                        ProgressView(instantSearch ? "Refreshing app list and caching files" : "Refreshing app list")
                        if instantSearch {
                            Image(systemName: "bolt.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(Color("mode").opacity(0.5))
                                .frame(width: 30, height: 30)
                                .padding()
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                } else {
                    VStack(alignment: .center) {

                        AppsListView(search: $search, showPopover: $showPopover, filteredApps: filteredApps)

                        if appState.currentView != .empty {
                            SearchBarMiniBottom(search: $search)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom)
                }
                
                
            }
        }
        .transition(.opacity)
    }
}







