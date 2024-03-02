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
        appState.appInfo.path == appInfo.path
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {



            HStack(alignment: .center) {

                if isHovered || isSelected {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(isSelected ? Color("pear") : Color("mode").opacity(0.5))
                        .frame(width: isSelected ? 4 : 2, height: 25)
                        .padding(.trailing, 5)
                }

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

        }
        .padding(.horizontal, 5)
        .help(appInfo.appName)
        .onHover { hovering in
            withAnimation(Animation.easeIn(duration: 0.2)) {
                self.isHovered = hovering
            }
        }
        .onTapGesture {
            showAppInFiles(appInfo: appInfo, mini: mini, appState: appState, locations: locations, showPopover: $showPopover)
        }
    }
}
