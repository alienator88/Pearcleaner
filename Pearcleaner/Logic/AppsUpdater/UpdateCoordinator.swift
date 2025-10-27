//
//  UpdateCoordinator.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation
import AlinFoundation

class UpdateCoordinator {
    /// Check if an app is a wrapped iPad/iOS app 
    static func isIOSApp(_ app: AppInfo) -> Bool {
        if !app.wrapped { return false }

        // For wrapped apps, app.path points to inner bundle (e.g., /Applications/X.app/Wrapper/Twitter.app/)
        // Go up 2 levels to outer wrapper (e.g., /Applications/X.app/)
        let outerWrapperPath = app.path.deletingLastPathComponent().deletingLastPathComponent()
        let wrappedBundlePath = outerWrapperPath.appendingPathComponent("WrappedBundle")

        // Check if WrappedBundle symlink exists (definitive sign of iOS app)
        return FileManager.default.fileExists(atPath: wrappedBundlePath.path)
    }

    /// Check if an app is from the App Store by verifying receipt existence
    static func isAppStoreApp(_ app: AppInfo) -> Bool {
        // Check for wrapped iPad/iOS app first (use wrapped flag from AppInfo)
        if app.wrapped {
            // For wrapped apps, app.path points to the inner bundle (e.g., /Applications/X.app/Wrapper/Twitter.app/)
            // We need to go up 2 levels to get to the outer wrapper (e.g., /Applications/X.app/)
            let outerWrapperPath = app.path.deletingLastPathComponent().deletingLastPathComponent()
            let iTunesMetadataPath = outerWrapperPath.appendingPathComponent("Wrapper/iTunesMetadata.plist").path
            if FileManager.default.fileExists(atPath: iTunesMetadataPath) {
                return true
            }
        }

        // Check for traditional Mac app receipt
        guard let bundle = Bundle(url: app.path),
              let receiptPath = bundle.appStoreReceiptURL?.path else {
            return false
        }

        return FileManager.default.fileExists(atPath: receiptPath)
    }

    /// Check if app is Pearcleaner (to exclude from update lists - has dedicated UI banner)
    private static func isPearcleaner(_ app: AppInfo) -> Bool {
        return app.bundleIdentifier == "com.alienator88.Pearcleaner"
    }

    static func scanForUpdates(
        apps: [AppInfo],
        checkAppStore: Bool,
        checkHomebrew: Bool,
        checkSparkle: Bool,
        includeSparklePreReleases: Bool,
        includeHomebrewFormulae: Bool
    ) async -> [UpdateSource: [UpdateableApp]] {

        // Run detectors concurrently (only if enabled)
        async let homebrewApps: [UpdateableApp] = {
            guard checkHomebrew else { return [] }
            return await HomebrewUpdateChecker.checkForUpdates(apps: apps, includeFormulae: includeHomebrewFormulae)
        }()

        async let appStoreApps: [UpdateableApp] = {
            guard checkAppStore else { return [] }
            let appStoreApps = apps.filter { isAppStoreApp($0) }
            return await AppStoreUpdateChecker.checkForUpdates(apps: appStoreApps)
        }()

        async let sparkleApps: [UpdateableApp] = {
            guard checkSparkle else { return [] }
            return await SparkleDetector.findSparkleApps(from: apps, includePreReleases: includeSparklePreReleases)
        }()

        // Wait for all results
        let (brew, store, sparkle) = await (homebrewApps, appStoreApps, sparkleApps)

        // Filter out Pearcleaner from all sources (has dedicated banner in UI)
        let filteredBrew = brew.filter { !isPearcleaner($0.appInfo) }
        let filteredStore = store.filter { !isPearcleaner($0.appInfo) }
        let filteredSparkle = sparkle.filter { !isPearcleaner($0.appInfo) }

        // Deduplicate: prioritize Sparkle > Homebrew > App Store
        // Rationale: Sparkle = direct from developer (most up-to-date), Homebrew = community-maintained (lag time), App Store = review lag
        var finalResults: [UpdateSource: [UpdateableApp]] = [
            .homebrew: [],
            .appStore: [],
            .sparkle: []
        ]

        // Track which apps have been added
        var addedPaths = Set<URL>()

        // Add Sparkle apps first (highest priority - direct from developer)
        for app in filteredSparkle {
            addedPaths.insert(app.appInfo.path)
            finalResults[.sparkle]?.append(app)
        }

        // Add Homebrew apps if not already added
        for app in filteredBrew {
            if !addedPaths.contains(app.appInfo.path) {
                addedPaths.insert(app.appInfo.path)
                finalResults[.homebrew]?.append(app)
            }
        }

        // Add App Store apps if not already added (lowest priority)
        for app in filteredStore {
            if !addedPaths.contains(app.appInfo.path) {
                addedPaths.insert(app.appInfo.path)
                finalResults[.appStore]?.append(app)
            }
        }

        // Sort each category alphabetically by app name for consistent display
        for (source, apps) in finalResults {
            finalResults[source] = apps.sorted { $0.appInfo.appName.localizedCaseInsensitiveCompare($1.appInfo.appName) == .orderedAscending }
        }

        return finalResults
    }
}
