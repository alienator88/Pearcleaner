//
//  Update.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//


import SwiftUI
import Foundation
import AlinFoundation

struct UpdateSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var updater: Updater

    var body: some View {
        VStack {

            FrequencyView(updater: updater)
                .padding(5)
                .padding(.horizontal)

            ReleasesView(updater: updater)
                .frame(height: 400)
                .frame(maxWidth: .infinity)
                .backgroundAF(opacity: 0.5)
            
            
            HStack(alignment: .center, spacing: 20) {

                Button(""){
                    updater.checkForUpdates(showSheet: false)
                }
                .buttonStyle(SimpleButtonStyle(icon: "arrow.uturn.left.circle", label: "Refresh", help: "Refresh updater"))


                Button(""){
                    updater.resetAnnouncementAlert()
                }
                .buttonStyle(SimpleButtonStyle(icon: "star", label: "Announcement", help: "Show announcements badge again"))


                Button(""){
                    NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/releases")!)
                }
                .buttonStyle(SimpleButtonStyle(icon: "link", label: "Releases", help: "View releases on GitHub"))

            }
            .padding()
            
        }
        .padding(20)
        .frame(width: 500)
    }
    
}
