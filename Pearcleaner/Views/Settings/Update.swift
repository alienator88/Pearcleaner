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
    @EnvironmentObject var updater: Updater
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {

            // === Frequency ============================================================================================
            PearGroupBox(header: { Text("Update Frequency").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2) }, content: {
                FrequencyView(updater: updater)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            })

            // === Release Notes ========================================================================================
            PearGroupBox(header: { Text("Release Notes").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2) }, content: {
                RecentReleasesView(updater: updater)
                    .frame(height: 380)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            })

            // === Buttons ==============================================================================================

            HStack(alignment: .center, spacing: 20) {

                Button {
                    updater.checkForUpdates(sheet: false)
                } label: { EmptyView() }
                .buttonStyle(SimpleButtonStyle(icon: "arrow.uturn.left.circle", label: String(localized: "Refresh"), help: String(localized: "Refresh updater"), color: ThemeColors.shared(for: colorScheme).primaryText))
                .contextMenu {
                    Button("Force Refresh") {
                        updater.checkForUpdates(sheet: true, force: true)
                    }
                }


                Button {
                    updater.resetAnnouncementAlert()
                } label: { EmptyView() }
                .buttonStyle(SimpleButtonStyle(icon: "star", label: String(localized: "Announcement"), help: String(localized: "Show announcements badge again"), color: ThemeColors.shared(for: colorScheme).primaryText))


                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/releases")!)
                } label: { EmptyView() }
                .buttonStyle(SimpleButtonStyle(icon: "link", label: String(localized: "Releases"), help: String(localized: "View releases on GitHub"), color: ThemeColors.shared(for: colorScheme).primaryText))
            }
            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

        }

    }
    
}
