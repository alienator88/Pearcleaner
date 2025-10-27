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
        includeHomebrewFormulae: Bool,
        showAutoUpdatesInHomebrew: Bool = true
    ) async -> [UpdateSource: [UpdateableApp]] {

        // Run detectors concurrently (only if enabled)
        // Apps are pre-categorized during load (hasSparkle, isAppStore flags in AppInfo)
        async let homebrewApps: [UpdateableApp] = {
            guard checkHomebrew else { return [] }
            return await HomebrewUpdateChecker.checkForUpdates(apps: apps, includeFormulae: includeHomebrewFormulae, showAutoUpdatesInHomebrew: showAutoUpdatesInHomebrew)
        }()

        async let appStoreApps: [UpdateableApp] = {
            guard checkAppStore else { return [] }
            // Filter to App Store apps using pre-detected flag (instant check vs expensive receipt verification)
            let appStoreApps = apps.filter { $0.isAppStore }
            return await AppStoreUpdateChecker.checkForUpdates(apps: appStoreApps)
        }()

        async let sparkleApps: [UpdateableApp] = {
            guard checkSparkle else { return [] }

            // Smart source filtering based on app origin and auto-update capability
            let sparkleApps = apps.filter { app in
                // Skip App Store apps (can't have Sparkle - App Store enforces its own updates)
                guard !app.isAppStore else { return false }

                // Skip apps without Sparkle
                guard app.hasSparkle else { return false }

                // Homebrew cask smart filtering:
                // - auto_updates=false → Skip Sparkle (app can't self-update, only Homebrew should check)
                // - auto_updates=true → Check Sparkle (app CAN self-update via Sparkle)
                // - auto_updates=nil → Check Sparkle (unknown state or not a Homebrew cask, be safe)
                if app.cask != nil, let autoUpdates = app.autoUpdates {
                    return autoUpdates  // Only check if explicitly true
                }

                // Non-Homebrew app with Sparkle, or unknown auto_updates state
                return true
            }

            return await SparkleDetector.findSparkleApps(from: sparkleApps, includePreReleases: includeSparklePreReleases)
        }()

        // Wait for all results
        let (brew, store, sparkle) = await (homebrewApps, appStoreApps, sparkleApps)

        // Filter out Pearcleaner from App Store and Sparkle sources (has dedicated banner in UI)
        // Note: Homebrew filtering happens in HomebrewController.getOutdatedPackagesHybrid()
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

        // Add Homebrew apps if not already added (Pearcleaner already filtered at source)
        for app in brew {
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
