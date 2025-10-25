//
//  AppStoreUpdateChecker.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation
import CommerceKit
import StoreFoundation
import AlinFoundation

class AppStoreUpdateChecker {
    private static let logger = UpdaterDebugLogger.shared

    static func checkForUpdates(apps: [AppInfo]) async -> [UpdateableApp] {
        guard !apps.isEmpty else { return [] }

        logger.log(.appStore, "Starting App Store update check for \(apps.count) apps")

        // Create optimal chunks based on CPU cores (smaller chunks for App Store API calls)
        let chunks = createOptimalChunks(from: apps, minChunkSize: 3, maxChunkSize: 10)

        // Process chunks concurrently using TaskGroup
        return await withTaskGroup(of: [UpdateableApp].self) { group in
            for chunk in chunks {
                group.addTask {
                    await checkChunk(chunk: chunk)
                }
            }

            // Collect results from all chunks
            var allUpdates: [UpdateableApp] = []
            for await chunkUpdates in group {
                allUpdates.append(contentsOf: chunkUpdates)
            }

            logger.log(.appStore, "Found \(allUpdates.count) available App Store updates")
            return allUpdates
        }
    }

    /// Check a chunk of apps for updates concurrently
    private static func checkChunk(chunk: [AppInfo]) async -> [UpdateableApp] {
        await withTaskGroup(of: UpdateableApp?.self) { group in
            for app in chunk {
                group.addTask {
                    await checkSingleApp(app: app)
                }
            }

            // Collect non-nil results
            var updates: [UpdateableApp] = []
            for await update in group {
                if let update = update {
                    updates.append(update)
                }
            }

            return updates
        }
    }

    /// Check a single app for updates
    private static func checkSingleApp(app: AppInfo) async -> UpdateableApp? {
        logger.log(.appStore, "Checking: \(app.appName) (\(app.bundleIdentifier))")

        // Query iTunes Search API using bundle ID to get app info (adamID, version, metadata)
        guard let appStoreInfo = await getAppStoreInfo(bundleID: app.bundleIdentifier) else {
            logger.log(.appStore, "  ❌ API lookup failed - not found in App Store")
            return nil
        }

        logger.log(.appStore, "  ✅ Found in App Store: v\(appStoreInfo.version) (adamID: \(appStoreInfo.adamID))")

        // Use Version for robust comparison (handles 1, 2, 3+ component versions)
        let installedVer = Version(versionNumber: app.appVersion, buildNumber: nil)
        let availableVer = Version(versionNumber: appStoreInfo.version, buildNumber: nil)

        // Skip if versions are empty/invalid
        guard !installedVer.isEmpty && !availableVer.isEmpty else {
            logger.log(.appStore, "  ⚠️ Skipped - empty/invalid version (Installed: \(app.appVersion), Available: \(appStoreInfo.version))")
            return nil
        }

        logger.log(.appStore, "  Comparing versions - Installed: \(app.appVersion), Available: \(appStoreInfo.version)")

        // Detect if this is a wrapped iOS app
        let isIOSApp = UpdateCoordinator.isIOSApp(app)

        // Only add if App Store version is GREATER than installed version
        if availableVer > installedVer {
            logger.log(.appStore, "  📦 UPDATE AVAILABLE: \(app.appVersion) → \(appStoreInfo.version)\(isIOSApp ? " (iOS app)" : "")")
            return UpdateableApp(
                appInfo: app,
                availableVersion: appStoreInfo.version,
                source: .appStore,
                adamID: appStoreInfo.adamID,
                appStoreURL: appStoreInfo.appStoreURL,
                status: .idle,
                progress: 0.0,
                releaseTitle: nil,
                releaseDescription: appStoreInfo.releaseNotes,
                releaseNotesLink: nil,
                releaseDate: appStoreInfo.releaseDate,
                isPreRelease: false,  // App Store updates are not pre-releases
                isIOSApp: isIOSApp,
                extractedFromBinary: false,
                alternateSparkleURLs: nil,
                currentFeedURL: nil
            )
        }

        logger.log(.appStore, "  ✓ Up to date")
        return nil
    }

    private struct AppStoreInfo {
        let adamID: UInt64
        let version: String
        let appStoreURL: String
        let releaseNotes: String?
        let releaseDate: String?
    }

    private static func getAppStoreInfo(bundleID: String) async -> AppStoreInfo? {
        // 1. Try desktopSoftware first (Mac-native apps - most accurate)
        // 2. Fallback to macSoftware (broader: includes Catalyst and iOS apps)
        // 3. Fallback to software (all platforms: catches iPad/iOS apps that run via "Designed for iPad")

        logger.log(.appStore, "    Trying entity: desktopSoftware")
        if let info = await fetchAppStoreInfo(bundleID: bundleID, entity: "desktopSoftware") {
            logger.log(.appStore, "    ✓ Found with desktopSoftware")
            return info
        }

        // Fallback to broader entity type
        logger.log(.appStore, "    Trying entity: macSoftware")
        if let info = await fetchAppStoreInfo(bundleID: bundleID, entity: "macSoftware") {
            logger.log(.appStore, "    ✓ Found with macSoftware")
            return info
        }

        // Final fallback for iPad/iOS apps
        logger.log(.appStore, "    Trying entity: software")
        if let info = await fetchAppStoreInfo(bundleID: bundleID, entity: "software") {
            logger.log(.appStore, "    ✓ Found with software")
            return info
        }

        logger.log(.appStore, "    ❌ Not found in any entity type")
        return nil
    }

    private static func fetchAppStoreInfo(bundleID: String, entity: String?) async -> AppStoreInfo? {
        // Query iTunes Search API using bundle ID
        guard let endpoint = URL(string: "https://itunes.apple.com/lookup") else {
            return nil
        }

        // Get user's actual App Store region (uses Storefront API > StoreKit > Locale)
        let region = await getAppStoreRegion()
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)

        var queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: region),
            URLQueryItem(name: "limit", value: "1")
        ]

        // Add entity parameter if provided (desktopSoftware or macSoftware)
        if let entity = entity {
            queryItems.append(URLQueryItem(name: "entity", value: entity))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            return nil
        }

        do {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
            let (data, _) = try await URLSession.shared.data(for: request)

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resultCount = json["resultCount"] as? Int,
               resultCount > 0,
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let trackId = firstResult["trackId"] as? UInt64,
               let version = firstResult["version"] as? String,
               let trackViewUrl = firstResult["trackViewUrl"] as? String {

                // Extract optional metadata
                let releaseNotes = firstResult["releaseNotes"] as? String
                let releaseDate = firstResult["currentVersionReleaseDate"] as? String

                return AppStoreInfo(
                    adamID: trackId,
                    version: version,
                    appStoreURL: trackViewUrl,
                    releaseNotes: releaseNotes,
                    releaseDate: releaseDate
                )
            }
        } catch {
            // Error querying iTunes API - silently fail
        }

        return nil
    }
}
