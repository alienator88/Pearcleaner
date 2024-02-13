//
//  AppListH.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI

struct AppListView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
//    @State private var sidebar: Bool = true
    @Binding var showPopover: Bool
    
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
    
    var body: some View {
        
        HStack(alignment: .center, spacing: 0) {
            // App List
            if appState.sidebar {
                ZStack {
                    HStack(spacing: 0){
                        
                        if appState.reload {
                            VStack {
                                Spacer()
                                ProgressView("Refreshing applications")
                                Spacer()
                            }
                            .frame(width: 250)
                            .padding(.vertical)
                        } else {
                            VStack(alignment: .center) {
                                
                                VStack(alignment: .center, spacing: 20) {
                                    HStack {
                                        SearchBar(search: $search)

//                                        Button("") {
//                                            withAnimation(.easeInOut(duration: 0.5)) {
//                                                // Refresh Apps list
//                                                reload.toggle()
//                                                let sortedApps = getSortedApps()
//                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                                                    appState.sortedApps.userApps = sortedApps.userApps
//                                                    appState.sortedApps.systemApps = sortedApps.systemApps
//                                                    reload.toggle()
//                                                }
//                                                
//                                            }
//                                        }
//                                        .buttonStyle(SimpleButtonStyle(icon: "arrow.triangle.2.circlepath", help: "Refresh app list", color: Color("mode")))
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 20)
                                .padding(.bottom)
                                
                                ScrollView {
                                    
                                    VStack(alignment: .leading) {
                                        
                                        if filteredUserApps.count > 0 {
                                            VStack {
                                                Header(title: "User", count: filteredUserApps.count)
                                                ForEach(filteredUserApps, id: \.self) { appInfo in
                                                    AppListItems(search: $search, showPopover: $showPopover, appInfo: appInfo)
                                                    if appInfo != filteredUserApps.last {
                                                        Divider().padding(.horizontal, 5)
                                                    }
                                                }
//                                                .padding(.bottom)
                                            }
                                            
                                        }
                                        
                                        if filteredSystemApps.count > 0 {
                                            VStack {
                                                Header(title: "System", count: filteredSystemApps.count)
                                                ForEach(filteredSystemApps, id: \.self) { appInfo in
                                                    AppListItems(search: $search, showPopover: $showPopover, appInfo: appInfo)
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
                            .frame(width: 250)
                            .padding(.vertical)
                        }
                        
                        
                        Divider()
                    }
                }
                .background(glass ? GlassEffect(material: .sidebar, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all) : nil)
                .transition(.move(edge: .leading))
                
                Spacer()
            }
            
            
            // Details View
            VStack(spacing: 0) {
                if appState.currentView == .empty {
                    TopBar()
                    AppDetailsEmptyView(showPopover: $showPopover)
                } else if appState.currentView == .files {
                    TopBar()
                    FilesView(showPopover: $showPopover, search: $search)
                        .id(appState.appInfo.id)
                }
            }
//            .padding(.leading, appState.sidebar ? 0 : 10)
            .transition(.move(edge: .leading))
            
            Spacer()
        }
        .frame(minWidth: 700, minHeight: 500)
        .edgesIgnoringSafeArea(.all)
//        .onOpenURL(perform: { url in
//            let deeplinkManager = DeeplinkManager()
//            deeplinkManager.manage(url: url, appState: appState)
//        })
//        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers, _ in
//            for provider in providers {
//                provider.loadItem(forTypeIdentifier: "public.file-url") { data, error in
//                    if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
//                        let deeplinkManager = DeeplinkManager()
//                        deeplinkManager.manage(url: url, appState: appState)
//                        //                        // Check if the file URL has a ".app" extension
//                        //                        if url.pathExtension.lowercased() == "app" {
//                        //                            // Handle the dropped file URL here
//                        //                            print("Dropped .app file URL: \(url)")
//                        //                        } else {
//                        //                            // Print a message for non-.app files
//                        //                            print("Unsupported file type. Only .app files are accepted.")
//                        //                        }
//                    }
//                }
//            }
//            return true
//        }
        // MARK: Background for whole app
        //        .background(Color("bg").opacity(1))
        //        .background(VisualEffect(material: .sidebar, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all))
    }
}






struct AppDetailsEmptyView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @State private var animateGradient: Bool = false
    @Binding var showPopover: Bool

    var body: some View {
        VStack() {
            
            Spacer()
            
            DropTarget(appState: appState, locations: locations, showPopover: $showPopover)

            Spacer()
            
//            if appState.isReminderVisible {
//                Text("􀆔 + Z to undo")
//                    .font(.title2)
//                    .foregroundStyle(Color("AccentColor").opacity(0.5))
//                    .fontWeight(.medium)
//                    .onAppear {
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                            withAnimation {
//                                appState.isReminderVisible = false
//                            }
//                        }
//                    }
//                Spacer()
//            }
            
            Text("Drop an app above or select one from the list to begin")
                .font(.title3)
                .padding(.bottom, 25)
                .opacity(0.5)
        }
    }
}


struct SearchBar: View {
    @Binding var search: String
    
    var body: some View {
        HStack {
            TextField("Search", text: $search)
                .textFieldStyle(SimpleSearchStyle(icon: Image(systemName: "magnifyingglass"),trash: true, text: $search))
        }
        .frame(height: 30)
    }
}


struct Header: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(title).opacity(0.5)
            Spacer()
            Text("\(count)")
                .font(.system(size: 10))
                .frame(minWidth: count > 99 ? 30 : 20, minHeight: 15)
                .padding(2)
                .background(Color("mode").opacity(0.1))
                .clipShape(.capsule)
            //                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(4)
    }
}
