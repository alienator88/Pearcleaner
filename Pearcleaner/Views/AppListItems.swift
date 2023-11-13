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
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    let appInfo: AppInfo
    var isSelected: Bool {
        appState.appInfo == appInfo
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center) {
//                if isHovered || isSelected {
//                    Circle()
//                        .fill(Color("AccentColor"))
//                        .frame(width: 10)
//                        .padding(5)
//                }
                if let appIcon = appInfo.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(appInfo.appName)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 5)
                }
                
                Spacer()
                Text(appInfo.appVersion)
                    .font(.footnote)
                    .foregroundStyle(Color("mode").opacity(0.5))
                
                if isHovered || isSelected {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(isSelected ? Color("AccentColor") : Color("mode").opacity(0.5))
                        .frame(width: isSelected ? 4 : 2, height: 35)
                        .padding(.leading, 5)
                        .offset(x: 20)
                }

            }
            
//            .background(
//                RoundedRectangle(cornerRadius: 6)
//                    .fill(isSelected ? Color("AccentColor").opacity(0.15) : (isHovered ? Color("AccentColor").opacity(0.1) : Color.white.opacity(colorScheme == .dark ? 0.05 : 0.8)))
//                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 6)
//                            .strokeBorder(Color("AccentColor").opacity(isHovered ? 0.7 : 0.1), lineWidth: 1)
//                    )
//            )
            
//            Rectangle()
//                .frame(maxWidth: isSelected ? .infinity : (isHovered ? .infinity : 30), maxHeight: 2)
//                .foregroundStyle(Color("AccentColor"))
            
        }
        .padding(.horizontal, 5)
        .help(appInfo.appName)
        .onHover { hovering in
            withAnimation(Animation.easeIn(duration: 0.2)) {
                self.isHovered = hovering
            }
        }
        .onTapGesture {
            updateOnMain {
                appState.appInfo = appInfo
                findPathsForApp(appState: appState, appInfo: appState.appInfo)
                withAnimation(Animation.easeIn(duration: 0.4)) {
                    appState.currentView = .files
                }
            }
        }
    }
}
