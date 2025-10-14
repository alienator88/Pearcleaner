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
    static func checkForUpdates(apps: [AppInfo]) async -> [UpdateableApp] {
        guard !apps.isEmpty else { return [] }

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
        // Query iTunes Search API using bundle ID to get app info (adamID, version, metadata)
        guard let appStoreInfo = await getAppStoreInfo(bundleID: app.bundleIdentifier) else {
            return nil
        }

        // Only add if App Store version is GREATER than installed version
        if appStoreInfo.version > app.appVersion {
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
                releaseDate: appStoreInfo.releaseDate
            )
        }

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
        // Query iTunes Search API using bundle ID to get all app info at once
        guard let endpoint = URL(string: "https://itunes.apple.com/lookup") else {
            return nil
        }

        let languageCode = Locale.current.region?.identifier ?? "US"
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: languageCode),
            URLQueryItem(name: "limit", value: "1")
        ]

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
