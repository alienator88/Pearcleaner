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

    /// Fallback regions to check if app not found in primary region
    /// Ordered by usage: CN, US, HK, JP, KR, SG
    private static let fallbackRegions = ["CN", "US", "HK", "JP", "KR", "SG"]

    /// Check if an app is a wrapped iPad/iOS app
    /// app.wrapped is already set correctly during app launch
    private static func isIOSApp(_ app: AppInfo) -> Bool {
        return app.wrapped
    }

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
                // Check for cancellation between chunks
                if Task.isCancelled {
                    break
                }
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

        // Query iTunes Search API using bundle ID to get app info (adamID, version, metadata) and region
        guard let result = await getAppStoreInfo(bundleID: app.bundleIdentifier) else {
            logger.log(.appStore, "  ❌ API lookup failed - not found in App Store")
            return nil
        }

        let (appStoreInfo, foundRegion) = result
        logger.log(.appStore, "  ✅ Found in App Store: v\(appStoreInfo.version) (adamID: \(appStoreInfo.adamID)) in region: \(foundRegion)")

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
        let isIOSApp = Self.isIOSApp(app)

        // Only add if App Store version is GREATER than installed version
        if availableVer > installedVer {
            logger.log(.appStore, "  📦 UPDATE AVAILABLE: \(app.appVersion) → \(appStoreInfo.version)\(isIOSApp ? " (iOS app)" : "")")
            return UpdateableApp(
                appInfo: app,
                availableVersion: appStoreInfo.version,
                availableBuildNumber: nil,  // App Store doesn't provide separate build numbers
                source: .appStore,
                adamID: appStoreInfo.adamID,
                appStoreURL: appStoreInfo.appStoreURL,
                status: .idle,
                progress: 0.0,
                isSelectedForUpdate: true,
                releaseTitle: nil,
                releaseDescription: appStoreInfo.releaseNotes,
                releaseNotesLink: nil,
                releaseDate: appStoreInfo.releaseDate,
                isPreRelease: false,  // App Store updates are not pre-releases
                isIOSApp: isIOSApp,
                foundInRegion: foundRegion
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

    private static func getAppStoreInfo(bundleID: String) async -> (info: AppStoreInfo, region: String)? {
        // Get user's primary region
        let primaryRegion = await getAppStoreRegion()
        logger.log(.appStore, "    Primary region: \(primaryRegion)")

        // Try primary region first with all entity types
        if let info = await tryAllEntities(bundleID: bundleID, region: primaryRegion) {
            return (info, primaryRegion)
        }

        // If not found, try fallback regions
        logger.log(.appStore, "    Not found in primary region, trying fallback regions...")
        for region in fallbackRegions where region != primaryRegion {
            logger.log(.appStore, "    Trying region: \(region)")
            if let info = await tryAllEntities(bundleID: bundleID, region: region) {
                logger.log(.appStore, "    ✓ Found in region: \(region)")
                return (info, region)
            }
        }

        logger.log(.appStore, "    ❌ Not found in any region")
        return nil
    }

    /// Try all entity types for a given region
    private static func tryAllEntities(bundleID: String, region: String) async -> AppStoreInfo? {
        // 1. Try desktopSoftware first (Mac-native apps - most accurate)
        // 2. Fallback to macSoftware (broader: includes Catalyst and iOS apps)
        // 3. Fallback to software (all platforms: catches iPad/iOS apps that run via "Designed for iPad")

        logger.log(.appStore, "      Trying entity: desktopSoftware")
        if let info = await fetchAppStoreInfo(bundleID: bundleID, region: region, entity: "desktopSoftware") {
            logger.log(.appStore, "      ✓ Found with desktopSoftware")
            return info
        }

        logger.log(.appStore, "      Trying entity: macSoftware")
        if let info = await fetchAppStoreInfo(bundleID: bundleID, region: region, entity: "macSoftware") {
            logger.log(.appStore, "      ✓ Found with macSoftware")
            return info
        }

        logger.log(.appStore, "      Trying entity: software")
        if let info = await fetchAppStoreInfo(bundleID: bundleID, region: region, entity: "software") {
            logger.log(.appStore, "      ✓ Found with software")
            return info
        }

        return nil
    }

    private static func fetchAppStoreInfo(bundleID: String, region: String, entity: String?) async -> AppStoreInfo? {
        // Query iTunes Search API using bundle ID
        guard let endpoint = URL(string: "https://itunes.apple.com/lookup") else {
            return nil
        }

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

    // MARK: - Private Helpers

    /// Get the user's App Store region (2-letter ISO 3166-1 alpha-2 code)
    /// Locale.region.identifier already returns alpha-2 codes (e.g., "US", "GB", "FR")
    private static func getAppStoreRegion() async -> String {
        return Locale.autoupdatingCurrent.region?.identifier ?? "US"
    }
}
