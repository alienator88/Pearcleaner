//
//  UpdateCoordinator.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation
import AlinFoundation

class UpdateCoordinator {
    /// Check if an app is from the App Store by verifying receipt existence
    private static func isAppStoreApp(_ app: AppInfo) -> Bool {
        guard let bundle = Bundle(url: app.path),
              let receiptPath = bundle.appStoreReceiptURL?.path else {
            return false
        }
        return FileManager.default.fileExists(atPath: receiptPath)
    }

    static func scanForUpdates(
        apps: [AppInfo],
        checkAppStore: Bool,
        checkHomebrew: Bool,
        checkSparkle: Bool
    ) async -> [UpdateSource: [UpdateableApp]] {

        // Run detectors concurrently (only if enabled)
        async let homebrewApps: [UpdateableApp] = {
            guard checkHomebrew else { return [] }
            return await HomebrewUpdateChecker.checkForUpdates(apps: apps)
        }()

        async let appStoreApps: [UpdateableApp] = {
            guard checkAppStore else { return [] }
            let appStoreApps = apps.filter { isAppStoreApp($0) }
            return await AppStoreUpdateChecker.checkForUpdates(apps: appStoreApps)
        }()

        async let sparkleApps: [UpdateableApp] = {
            guard checkSparkle else { return [] }
            return await SparkleDetector.findSparkleApps(from: apps)
        }()

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
