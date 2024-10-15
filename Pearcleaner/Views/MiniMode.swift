//
//  MiniMode.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/14/23.
//


import Foundation
import SwiftUI
import AlinFoundation

struct MiniMode: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @Binding var showPopover: Bool
    
    
    var body: some View {
        
        HStack(alignment: .center, spacing: 0) {
            
            // Main Mini View
            VStack(spacing: 0) {
                Group {
                    if appState.currentView == .empty {
                        MiniEmptyView(showPopover: $showPopover)
                    } else {
                        MiniAppView(search: $search, showPopover: $showPopover)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: 300, minHeight: 345)
        .edgesIgnoringSafeArea(.all)
        .background(backgroundView(themeManager: themeManager, glass: glass))
        
    }
}






struct MiniEmptyView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @Binding var showPopover: Bool

    var body: some View {
        VStack(alignment: .center) {

            Spacer()

            LinearGradient(gradient: Gradient(colors: [.green, .orange]), startPoint: .leading, endPoint: .trailing)
                .mask(
                    Image(systemName: "plus.square.dashed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120, alignment: .center)
                        .padding()
                        .fontWeight(.ultraLight)
                        .offset(x: 5, y: 5)
                )

            Text("Drop an app here")
                .font(.title3)
                .opacity(0.7)

            Text("Click for apps list")
                .font(.footnote)
                .padding(.bottom, 25)
                .opacity(0.5)

            Spacer()

            
        }
        .onTapGesture {
            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                appState.currentView = .apps
            }
        }
    }
}





struct MiniAppView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 280
    @Binding var showPopover: Bool
    @State private var showMenu = false
    @State var isMenuBar: Bool = false

    var body: some View {


        ZStack {

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
                .padding(.vertical)
            } else {
                AppSearchView(glass: glass, menubarEnabled: menubarEnabled, mini: mini, search: $search, showPopover: $showPopover, isMenuBar: $isMenuBar)
            }

        }
        .transition(.opacity)
        .frame(minWidth: 300, minHeight: 370)
        .edgesIgnoringSafeArea(.all)
        .background(backgroundView(themeManager: themeManager, glass: glass).padding(-80))
        .transition(.opacity)
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
            .background(backgroundView(themeManager: themeManager, glass: glass).padding(-80))
            .frame(width: 650, height: 500)

        }
    }
}
