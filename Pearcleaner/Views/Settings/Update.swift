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
                    updater.checkForUpdates(sheet: true, force: true)
                } label: {
                    Label("Refresh", systemImage: "arrow.uturn.left.circle")
                }
                    .buttonStyle(ControlGroupButtonStyle(foregroundColor: ThemeColors.shared(for: colorScheme).primaryText, shape: .capsule))


                Button {
                    updater.resetAnnouncementAlert()
                } label: {
                    Label("Announcement", systemImage: "star")
                }
                    .buttonStyle(ControlGroupButtonStyle(foregroundColor: ThemeColors.shared(for: colorScheme).primaryText, shape: .capsule))
                    .sheet(isPresented: $updater.showAnnouncementSheet, content: {
                        updater.getAnnouncementView()
                    })


                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/releases")!)
                } label: {
                    Label("Releases", systemImage: "link")
                }
                    .buttonStyle(ControlGroupButtonStyle(foregroundColor: ThemeColors.shared(for: colorScheme).primaryText, shape: .capsule))

            }

        }

    }
    
}
