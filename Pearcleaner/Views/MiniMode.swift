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
    @State private var reload: Bool = false
    
    
    
    var body: some View {
        
        HStack(alignment: .center, spacing: 0) {
            
            // Main Mini View
            VStack(spacing: 0) {
                if appState.currentView == .empty {
                    TopBarMini(reload: $reload, search: $search)
                    AppDetailsEmptyView()
                } else if appState.currentView == .files {
                    TopBarMini(reload: $reload, search: $search)
                    FilesView()
                        .id(appState.appInfo.id)
                } else if appState.currentView == .apps {
                    TopBarMini(reload: $reload, search: $search)
                    MiniAppView(search: $search, reload: $reload)
                }
            }
            //            .padding(.leading, appState.sidebar ? 0 : 10)
            .transition(.move(edge: .leading))
            
        }
        .edgesIgnoringSafeArea(.all)
        .onOpenURL(perform: { url in
            let deeplinkManager = DeeplinkManager()
            deeplinkManager.manage(url: url, appState: appState)
        })
        // MARK: Background for whole app
        //        .background(Color("bg").opacity(1))
        //        .background(VisualEffect(material: .sidebar, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all))
    }
}






struct MiniEmptyView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var animateGradient: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    
    var body: some View {
        VStack() {
            
            Spacer()
            
            DropTarget(appState: appState)
                .frame(maxWidth: mini ? 300 : 500)
            
            Spacer()
            
            if appState.isReminderVisible {
                Text("CMD + Z to undo")
                    .font(.title2)
                    .foregroundStyle(Color("AccentColor").opacity(0.5))
                    .fontWeight(.medium)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                appState.isReminderVisible = false
                            }
                        }
                    }
                Spacer()
            }
            
            Text("Drop an app above or select one from the list to begin")
                .font(.title3)
                .padding(.bottom, 25)
                .opacity(0.5)
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
    @Binding var reload: Bool
    @AppStorage("settings.general.mini") private var mini: Bool = false
    
    var body: some View {
        
        var filteredUserApps: [AppInfo] {
            if search.isEmpty {
                return appState.sortedApps.userApps
            } else {
                return appState.sortedApps.userApps.filter { $0.appName.localizedCaseInsensitiveContains(search) }
            }
        }
        
        var filteredSystemApps: [AppInfo] {
            if search.isEmpty {
                return appState.sortedApps.systemApps
            } else {
                return appState.sortedApps.systemApps.filter { $0.appName.localizedCaseInsensitiveContains(search) }
            }
        }
        
        ZStack {
            HStack(spacing: 0){
                
                if reload {
                    VStack {
                        Spacer()
                        ProgressView("Refreshing applications")
                        Spacer()
                    }
                    .padding(.vertical)
                } else {
                    VStack(alignment: .center) {
                        
//                        VStack(alignment: .center, spacing: 20) {
//                            HStack {
//                                SearchBar(search: $search)
//                            }
//                        }
//                        .padding(.horizontal, 5)
//                        .padding(.bottom)
                        
                        ScrollView {
                            
                            VStack(alignment: .leading) {
                                
                                if filteredUserApps.count > 0 {
                                    VStack {
                                        Header(title: "User", count: filteredUserApps.count)
                                        ForEach(filteredUserApps, id: \.self) { appInfo in
                                            AppListItems(appInfo: appInfo)
                                            if appInfo != filteredUserApps.last {
                                                Divider().padding(.horizontal, 5)
                                            }
                                        }
                                        .padding(.bottom)
                                    }
                                    
                                }
                                
                                if filteredSystemApps.count > 0 {
                                    VStack {
                                        Header(title: "System", count: filteredSystemApps.count)
                                        ForEach(filteredSystemApps, id: \.self) { appInfo in
                                            AppListItems(appInfo: appInfo)
                                            if appInfo != filteredSystemApps.last {
                                                Divider().padding(.horizontal, 5)
                                            }
                                        }
                                    }
                                }
                                
                            }
                            .padding(.horizontal)
                            
                        }
                        .scrollIndicators(.never)
                        
                    }
                    .padding(.vertical)
                }
                
                
            }
        }
        .transition(.move(edge: .leading))
    }
}







