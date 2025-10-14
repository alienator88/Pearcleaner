//
//  UpdateCoordinator.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation
import AlinFoundation

class UpdateCoordinator {
    static func scanForUpdates(apps: [AppInfo]) async -> [UpdateSource: [UpdateableApp]] {
        // Run all three detectors concurrently
        async let homebrewApps = HomebrewUpdateChecker.checkForUpdates(apps: apps)

        async let appStoreApps: [UpdateableApp] = {
            // Extract adamIDs directly from apps (pre-loaded during app scan)
            let adamIDs = Dictionary(uniqueKeysWithValues:
                apps.compactMap { app in
                    app.adamID.map { (app.path, $0) }
                }
            )
            let updates = await AppStoreUpdateChecker.checkForUpdates(apps: apps, adamIDs: adamIDs)
            return updates
        }()

        async let sparkleApps = SparkleDetector.findSparkleApps(from: apps)

        // Wait for all results
        let (brew, store, sparkle) = await (homebrewApps, appStoreApps, sparkleApps)

        // Deduplicate: prioritize Homebrew > App Store > Sparkle
        var finalResults: [UpdateSource: [UpdateableApp]] = [
            .homebrew: [],
            .appStore: [],
            .sparkle: []
        ]

        // Track which apps have been added
        var addedPaths = Set<URL>()

        // Add Homebrew apps first (highest priority)
        for app in brew {
            addedPaths.insert(app.appInfo.path)
            finalResults[.homebrew]?.append(app)
        }

        // Add App Store apps if not already added
        for app in store {
            if !addedPaths.contains(app.appInfo.path) {
                addedPaths.insert(app.appInfo.path)
                finalResults[.appStore]?.append(app)
            }
        }

        // Add Sparkle apps if not already added
        for app in sparkle {
            if !addedPaths.contains(app.appInfo.path) {
                addedPaths.insert(app.appInfo.path)
                finalResults[.sparkle]?.append(app)
            }
        }

        return finalResults
    }
}
