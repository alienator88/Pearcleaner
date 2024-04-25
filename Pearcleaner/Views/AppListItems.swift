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
    @EnvironmentObject var themeSettings: ThemeSettings
    @Binding var search: String
    @State private var isHovered = false
    @State private var windowSettings = WindowSettings()
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.general.miniview") private var miniView: Bool = true
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @Binding var showPopover: Bool
    @EnvironmentObject var locations: Locations
    let itemId = UUID()
    let appInfo: AppInfo
    var isSelected: Bool {
        appState.appInfo.id == appInfo.id
    }
    @State private var hoveredItemPath: URL? = nil
    var body: some View {

        ZStack() {

            HStack(alignment: .center) {

                if let appIcon = appInfo.appIcon {
                    ZStack {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: (isHovered || isSelected) ? 32 : 30, height: (isHovered || isSelected) ? 32 : 30)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
//                            .shadow(color: Color("pop").opacity(0.8), radius: isSelected ? 2 : 0)
                    }

                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(appInfo.appName)
                        .font(.system(size: (isHovered || isSelected) ? 14 : 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 5)
                }



                Spacer()

                if appInfo.webApp {
                    Text("web")
                        .font(.footnote)
                        .foregroundStyle(Color("mode").opacity(0.3))
                        .frame(minWidth: 30, minHeight: 15)
                        .padding(2)
                        .background(
                            Capsule().strokeBorder(Color("mode").opacity(0.3), lineWidth: 1)
                        )
                }
                if appInfo.wrapped {
                    Text("iOS")
                        .font(.footnote)
                        .foregroundStyle(Color("mode").opacity(0.3))
                        .frame(minWidth: 30, minHeight: 15)
                        .padding(2)
                        .background(
                            Capsule().strokeBorder(Color("mode").opacity(0.3), lineWidth: 1)
                        )
                }

                Text(appInfo.appVersion)
                    .font(.system(size: (isHovered || isSelected) ? 12 : 10))
                    .foregroundStyle(Color("mode").opacity(0.5))

//                if (isHovered || isSelected) {
//                    RoundedRectangle(cornerRadius: 50)
//                        .fill(isSelected ? Color("pear") : Color("mode").opacity(0.5))
//                        .frame(width: isSelected ? 4 : 2, height: 25)
//                        .padding(.trailing, 5)
//                }

            }

        }
        .frame(height: 35)
        .padding(.horizontal)
        .padding(.vertical, 5)
        .help(appInfo.appName)
        .onHover { hovering in
            withAnimation(Animation.easeIn(duration: 0.2)) {
                self.isHovered = hovering
                self.hoveredItemPath = isHovered ? appInfo.path : nil
            }
        }
        .onTapGesture {
            withAnimation(Animation.easeInOut(duration: 0.4)) {
                if isSelected {
                    appState.appInfo = .empty
                    appState.selectedItems = []
                    appState.currentView = miniView ? .apps : .empty
                    showPopover = false
                } else {
                    showAppInFiles(appInfo: appInfo, appState: appState, locations: locations, showPopover: $showPopover)
                }
            }
        }
        .background{
            Rectangle()
                .fill(isSelected && !glass ? themeSettings.themeColor : .clear)
        }
        .overlay{
            if (isHovered || isSelected) {
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 50)
                        .fill(isSelected ? Color("pear") : Color("mode").opacity(0.5))
                        .frame(width: isSelected ? 4 : 2, height: 25)
                        .padding(.trailing, 5)
                }

            }
        }

    }

}
