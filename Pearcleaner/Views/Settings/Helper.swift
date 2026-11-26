//
//  Helper.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/14/25.
//

import SwiftUI
import Foundation

struct HelperSettingsTab: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {

            // === Session privilege ============================================================================================
            PearGroupBox(
                header: {
                    HStack {
                        Text("Management").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2)
                        Spacer()
                    }

                },
                content: {

                    VStack {
                        HStack(spacing: 0) {
                            Image(systemName: "key")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            Text("Run privileged tasks without installing anything")
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                .frame(minWidth: 450, maxWidth: .infinity, alignment: .leading)

                            Button {
                                SessionPrivilegeManager.shared.invalidateSession()
                            } label: {
                                Text("Forget")
                            }
                            .buttonStyle(.borderless)

                        }
                    }
                    .padding(5)

                })

            PearGroupBox(header: {
                Text("Information").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2)
            }, content: {
                let message: LocalizedStringKey = """
                Pearcleaner asks for your administrator password the first time a task needs elevated permissions, and keeps that authorization for the rest of the session while it stays open. No privileged helper is installed, nothing appears in Settings > Login Items, and when Pearcleaner quits the authorization is gone.
                """

                VStack(alignment: .leading, spacing: 20) {
                    Text(message).foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.body).lineSpacing(5)

                    Text("The password prompt is the standard macOS administrator dialog, the same one installers use. Each prompt covers one session; locking the screen or quitting Pearcleaner ends it.").font(.footnote).foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

            })

        }
    }

}