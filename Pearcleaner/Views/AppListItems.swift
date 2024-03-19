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
//    @AppStorage("settings.general.mini") private var mini: Bool = false
//    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @Binding var showPopover: Bool
    @EnvironmentObject var locations: Locations
    let itemId = UUID()
    let appInfo: AppInfo
    var isSelected: Bool {
        appState.appInfo.path == appInfo.path
    }
    
    var body: some View {
//        VStack(alignment: .leading, spacing: 5) {



            HStack(alignment: .center) {

                if isHovered || isSelected {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(isSelected ? Color("pear") : Color("mode").opacity(0.5))
                        .frame(width: isSelected ? 4 : 2, height: 25)
                        .padding(.trailing, 5)
                }

                if let appIcon = appInfo.appIcon {
                    ZStack {
//                        RoundedRectangle(cornerRadius: 8)
//                            .fill(Color(appIcon.averageColor!))
//                            .frame(width: 35, height: 35)
//                            .saturation(3)
//                            .opacity(0.5)
////                            .brightness(displayMode.colorScheme == .dark ? 0 : 0.5)
////                            .shadow(color: .black, radius: 1, y: 2)
//                        RoundedRectangle(cornerRadius: 8)
//                            .strokeBorder(Color("mode").opacity(0.1), lineWidth: 1)
//                            .frame(width: 35, height: 35)
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
//                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
//                            .grayscale(opacityForItem())
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

            }
            .padding(.horizontal, 5)
            .help(appInfo.appName)
            .onHover { hovering in
                withAnimation(Animation.easeIn(duration: 0.2)) {
                    self.isHovered = hovering
                }
            }
            .onTapGesture {
                withAnimation(Animation.easeInOut(duration: 0.4)) {
                    showAppInFiles(appInfo: appInfo, appState: appState, locations: locations, showPopover: $showPopover)
                }
            }

    }

    func opacityForItem() -> Double {
        // Check if any item is selected
        let isAnyItemSelected = appState.sortedApps.contains(where: { $0.path == appState.appInfo.path })
        // If this item is selected or no items are selected, keep full opacity
        // Otherwise, reduce opacity
        return isAnyItemSelected ? (appState.appInfo.path == appInfo.path ? 0 : 1.0) : 0
    }

}



