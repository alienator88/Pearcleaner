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
    @Binding var showPopover: Bool
    @EnvironmentObject var locations: Locations
    let itemId = UUID()
    let appInfo: AppInfo
    var isSelected: Bool {
        appState.appInfo.path == appInfo.path
    }
    @State private var hoveredItemPath: URL? = nil
    var body: some View {

            HStack(alignment: .center) {

                if (isHovered || isSelected) && mini {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(isSelected ? Color("pear") : Color("mode").opacity(0.5))
                        .frame(width: isSelected ? 4 : 2, height: 25)
                        .padding(.trailing, 5)
                }

                if let appIcon = appInfo.appIcon {
                    ZStack {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
                    }

                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(appInfo.appName)
                        .font(.system(size: 12))
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
                    .font(.footnote)
                    .foregroundStyle(Color("mode").opacity(0.5))

                if (isHovered || isSelected) && !mini {
                    Triangle()
                        .fill(themeSettings.themeColor)
                        .frame(width: isSelected ? 16 : 8, height: 30)
                        .padding(.leading, 5)
                        .offset(x: 22)
                        .zIndex(5)
                }

            }
            .padding(.horizontal, 5)
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
                        appState.currentView = miniView ? .apps : .empty
                        showPopover = false
                    } else {
                        showAppInFiles(appInfo: appInfo, appState: appState, locations: locations, showPopover: $showPopover)
                    }
                }
            }

    }

    func opacityForItem(_ path: URL) -> Double {
        // Check if any item is selected
        let isAnyItemSelected = appState.sortedApps.contains(where: { $0.path == appState.appInfo.path })

        let isItemSelected = appState.appInfo.path == path
        let isItemHovered = hoveredItemPath == path

        // Logic to determine grayscale level
        if isItemSelected || !isAnyItemSelected || isItemHovered {
            return 0  // No grayscale
        } else {
            return 1.0  // Full grayscale
        }

//        return isAnyItemSelected ? (appState.appInfo.path == appInfo.path ? 0 : 1.0) : 0
    }

}



struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start at the top right
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Add line to the bottom right
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Add line to the left point
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        // Close the path
        path.closeSubpath()

        return path
    }
}
