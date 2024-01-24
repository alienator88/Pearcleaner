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
                if appState.currentView == .empty {
                    TopBarMini(search: $search, showPopover: $showPopover)
                    MiniEmptyView(showPopover: $showPopover)
                } else if appState.currentView == .files {
                    TopBarMini(search: $search, showPopover: $showPopover)
                    FilesView(showPopover: $showPopover, search: $search)
                        .id(appState.appInfo.id)
                } else if appState.currentView == .apps {
                    TopBarMini(search: $search, showPopover: $showPopover)
                    MiniAppView(search: $search, showPopover: $showPopover)
                }
            }
            //            .padding(.leading, appState.sidebar ? 0 : 10)
            .transition(.move(edge: .leading))
            .popover(isPresented: $showPopover, arrowEdge: .trailing) {
                VStack {
                    FilesView(showPopover: $showPopover, search: $search)
                        .id(appState.appInfo.id)
                }
                .interactiveDismissDisabled(popoverStay)
                .background(
                    Rectangle()
                        .fill(Color("pop"))
                        .padding(-80)
                )
                .frame(minWidth: 600, minHeight: 500)

            }

            
        }
        .frame(minWidth: 300, minHeight: 300)
        .edgesIgnoringSafeArea(.all)
        .background(glass ? GlassEffect(material: .sidebar, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all) : nil)

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
////                        // Check if the file URL has a ".app" extension
////                        if url.pathExtension.lowercased() == "app" {
////                            // Handle the dropped file URL here
////                            print("Dropped .app file URL: \(url)")
////                        } else {
////                            // Print a message for non-.app files
////                            print("Unsupported file type. Only .app files are accepted.")
////                        }
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






struct MiniEmptyView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var animateGradient: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @Binding var showPopover: Bool

    var body: some View {
        VStack() {
            
            Spacer()
            
            DropTarget(appState: appState, showPopover: $showPopover)
                .frame(maxWidth: mini ? 300 : 500)
            
            Text("Drop an app to begin")
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
            
            
        }
//        .padding()
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
    @Binding var showPopover: Bool
    
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
                
                if appState.reload {
                    VStack {
                        Spacer()
                        ProgressView("Refreshing applications")
                        Spacer()
                    }
                    .padding(.vertical)
                } else {
                    VStack(alignment: .center) {
                        
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
                    .padding(.bottom)
                }
                
                
            }
        }
        .transition(.move(edge: .leading))
//        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
//            VStack {
//                FilesView(showPopover: $showPopover)
//                    .id(appState.appInfo.id)
//            }
//            .background(
//                Rectangle()
//                    .fill(Color("pop"))
////                    .background(Color("pop"))
//                    .padding(-80)
//            )
//            .frame(minWidth: 600, minHeight: 500)
//            
//        }
    }
}







