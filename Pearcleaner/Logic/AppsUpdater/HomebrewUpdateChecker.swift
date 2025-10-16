//
//  HomebrewUpdateChecker.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation

class HomebrewUpdateChecker {
    static func checkForUpdates(apps: [AppInfo]) async -> [UpdateableApp] {
        // Filter apps that have a cask identifier
        let brewApps = apps.filter { $0.cask != nil && !$0.cask!.isEmpty }

        guard !brewApps.isEmpty else { return [] }

        // Get outdated packages from Homebrew
        let outdatedNames = try? await HomebrewController.shared.getOutdatedPackages()

        guard let outdatedNames = outdatedNames, !outdatedNames.isEmpty else { return [] }

        // Match apps with outdated packages
        var updateableApps: [UpdateableApp] = []

        for appInfo in brewApps {
            guard let cask = appInfo.cask else { continue }

            // Check if this cask is in the outdated list
            if outdatedNames.contains(cask) {
                let updateableApp = UpdateableApp(
                    appInfo: appInfo,
                    availableVersion: nil, // We don't have the new version easily available
                    source: .homebrew,
                    adamID: nil,
                    appStoreURL: nil,
                    status: .idle,
                    progress: 0.0,
                    releaseTitle: nil,
                    releaseDescription: nil,
                    releaseNotesLink: nil,
                    releaseDate: nil
                )
                updateableApps.append(updateableApp)
            }
        }

        return updateableApps
    }
}
