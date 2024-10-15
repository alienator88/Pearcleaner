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
    @AppStorage("settings.general.glass") private var glass: Bool = false

    var body: some View {
        VStack(spacing: 20) {

            // === Frequency ============================================================================================
            PearGroupBox(header: { Text("Update Frequency").font(.title2) }, content: {
                FrequencyView(updater: updater)
            })

            // === Release Notes ========================================================================================
            PearGroupBox(header: { Text("Release Notes").font(.title2) }, content: {
                ReleasesView(updater: updater)
                    .frame(height: 380)
                    .frame(maxWidth: .infinity)
            })

            // === Buttons ==============================================================================================

            HStack(alignment: .center, spacing: 20) {

                Button(""){
                    updater.checkForUpdatesForce(showSheet: false)
                }
                .buttonStyle(SimpleButtonStyle(icon: "arrow.uturn.left.circle", label: String(localized: "Refresh"), help: String(localized: "Refresh updater")))


                Button(""){
                    updater.resetAnnouncementAlert()
                }
                .buttonStyle(SimpleButtonStyle(icon: "star", label: String(localized: "Announcement"), help: String(localized: "Show announcements badge again")))


                Button(""){
                    NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/releases")!)
                }
                .buttonStyle(SimpleButtonStyle(icon: "link", label: String(localized: "Releases"), help: String(localized: "View releases on GitHub")))
            }

        }

    }
    
}
