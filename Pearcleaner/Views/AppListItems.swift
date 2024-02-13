//
//  AppListDetails.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/10/23.
//

import Foundation
import SwiftUI

struct AppListItems: View {
    @EnvironmentObject var appState: AppState
    @Binding var search: String
    @State private var isHovered = false
    @State private var windowSettings = WindowSettings()
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @Binding var showPopover: Bool
    @EnvironmentObject var locations: Locations
    let itemId = UUID()
    let appInfo: AppInfo
    var isSelected: Bool {
        appState.appInfo == appInfo
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center) {

                if let appIcon = appInfo.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(appInfo.appName)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 5)
                }
                if appInfo.webApp {
                    Text("web")
                        .font(.footnote)
                        .foregroundStyle(Color("mode").opacity(0.5))
                        .frame(minWidth: 30, minHeight: 15)
                        .padding(2)
                        .background(Color("mode").opacity(0.1))
                        .clipShape(.capsule)
                }
                if appInfo.wrapped {
                    Text("iOS")
                        .font(.footnote)
                        .foregroundStyle(Color("mode").opacity(0.5))
                        .frame(minWidth: 30, minHeight: 15)
                        .padding(2)
                        .background(Color("mode").opacity(0.1))
                        .clipShape(.capsule)
                }

                
                Spacer()
                Text(appInfo.appVersion)
                    .font(.footnote)
                    .foregroundStyle(Color("mode").opacity(0.5))
                
                if isHovered || isSelected {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(isSelected ? Color("AccentColor") : Color("mode").opacity(0.5))
                        .frame(width: isSelected ? 4 : 2, height: 30)
                        .padding(.leading, 5)
                        .offset(x: 20)
                }

            }
            
        }
        .padding(.horizontal, 5)
        .help(appInfo.appName)
        .onHover { hovering in
            withAnimation(Animation.easeIn(duration: 0.2)) {
                self.isHovered = hovering
            }
        }
        .onTapGesture {
            showPopover = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                updateOnMain {
                    appState.appInfo = .empty
                    appState.appInfo = appInfo
//                    appState.progressManager.resetProgress()
                    findPathsForApp(appState: appState, locations: locations)
                    withAnimation(Animation.easeIn(duration: 0.4)) {
                        if mini {
                            showPopover.toggle()
                        } else {
                            appState.currentView = .files
                        }
                    }
                }

            }

        }
        .popover(isPresented: Binding(
            get: { showPopover && appState.appInfo.id == appInfo.id},
            set: { _ in showPopover = false}
        ), attachmentAnchor: .rect(.rect(CGRect(x: windowSettings.loadWindowSettings().width - 17, y: 15, width: 0, height: 0))), arrowEdge: .trailing) {

//        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
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
            .frame(minWidth: 650, minHeight: 500)

        }
    }
}
