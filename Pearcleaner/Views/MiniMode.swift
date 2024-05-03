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
    @EnvironmentObject var themeSettings: ThemeSettings
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
        .background(backgroundView(themeSettings: themeSettings, glass: glass))
        
    }
}






struct MiniEmptyView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @State private var animateGradient: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.animateLogo") private var animateLogo: Bool = true
    @Binding var showPopover: Bool
    @State private var animationStart = false

    var body: some View {
        VStack(alignment: .center) {

            Spacer()
            
            if #available(macOS 14, *) {
                if animateLogo && animationStart {
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
                        .phaseAnimator([false, true]) { wwdc24, chromaRotate in
                            wwdc24
                                .hueRotation(.degrees(chromaRotate ? 420 : 0))
                        } animation: { chromaRotate in
                                .easeInOut(duration: 6)
                        }
                } else {
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
                }
            } else {
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
            }

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
            withAnimation(.easeInOut(duration: 0.5)) {
                appState.currentView = .apps
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                animationStart = true
            }
        }
    }
}





struct MiniAppView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var themeSettings: ThemeSettings
    @State private var animateGradient: Bool = false
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

    var body: some View {


        ZStack {

            if appState.reload {
                VStack {
                    Spacer()
                    ProgressView("Refreshing app list")
                    Spacer()
                }
                .padding(.vertical)
            } else {
                Searchbar(glass: glass, sidebarWidth: sidebarWidth, menubarEnabled: menubarEnabled, mini: mini, search: $search, showPopover: $showPopover)
            }

        }
        .transition(.opacity)
        .frame(minWidth: 300, minHeight: 370)
        .edgesIgnoringSafeArea(.all)
        .background(backgroundView(themeSettings: themeSettings, glass: glass).padding(-80))
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
            .background(backgroundView(themeSettings: themeSettings, glass: glass).padding(-80))
            .frame(width: 650, height: 500)

        }
    }
}







