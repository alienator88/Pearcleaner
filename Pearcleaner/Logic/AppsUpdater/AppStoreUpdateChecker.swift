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
    static func checkForUpdates(apps: [AppInfo], adamIDs: [URL: UInt64]) async -> [UpdateableApp] {
        guard !adamIDs.isEmpty else { return [] }

        // Convert dictionary to array for chunking
        let adamIDArray = Array(adamIDs)

        // Create optimal chunks based on CPU cores (smaller chunks for App Store API calls)
        let chunks = createOptimalChunks(from: adamIDArray, minChunkSize: 3, maxChunkSize: 10)

        // Process chunks concurrently using TaskGroup
        return await withTaskGroup(of: [UpdateableApp].self) { group in
            for chunk in chunks {
                group.addTask {
                    await checkChunk(chunk: chunk, apps: apps)
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
    private static func checkChunk(chunk: [(URL, UInt64)], apps: [AppInfo]) async -> [UpdateableApp] {
        await withTaskGroup(of: UpdateableApp?.self) { group in
            for (url, adamID) in chunk {
                group.addTask {
                    await checkSingleApp(url: url, adamID: adamID, apps: apps)
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
    private static func checkSingleApp(url: URL, adamID: UInt64, apps: [AppInfo]) async -> UpdateableApp? {
        guard let appInfo = apps.first(where: { $0.path == url }) else { return nil }

        // First check if app still exists in App Store to avoid popup
        guard let metadata = await getAppStoreInfo(adamID: adamID) else {
            return nil
        }

        do {
            // Check for update using mas CLI approach: start download, check metadata, cancel immediately
            let version = try await checkVersion(for: adamID, currentVersion: appInfo.appVersion)

            // Only add if App Store version is GREATER than installed version
            if let availableVersion = version, availableVersion > appInfo.appVersion {
                return UpdateableApp(
                    appInfo: appInfo,
                    availableVersion: availableVersion,
                    source: .appStore,
                    adamID: adamID,
                    appStoreURL: metadata.appStoreURL,
                    status: .idle,
                    progress: 0.0,
                    releaseTitle: nil,
                    releaseDescription: metadata.releaseNotes,
                    releaseDate: metadata.releaseDate
                )
            }
        } catch {
            // Catch errors like "no downloads" or network errors
            return nil
        }

        return nil
    }

    private struct AppStoreMetadata {
        let appStoreURL: String
        let releaseNotes: String?
        let releaseDate: String?
    }

    private static func getAppStoreInfo(adamID: UInt64) async -> AppStoreMetadata? {
        // Query iTunes Search API to check if app is still available and get its URL + metadata
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(adamID)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resultCount = json["resultCount"] as? Int,
               resultCount > 0,
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let trackViewUrl = firstResult["trackViewUrl"] as? String {

                // Extract release notes and date if available
                let releaseNotes = firstResult["releaseNotes"] as? String
                let releaseDate = firstResult["currentVersionReleaseDate"] as? String

                return AppStoreMetadata(
                    appStoreURL: trackViewUrl,
                    releaseNotes: releaseNotes,
                    releaseDate: releaseDate
                )
            }
        } catch {
            // Error checking availability - silently fail
        }

        return nil
    }

    private static func checkVersion(for adamID: UInt64, currentVersion: String) async throws -> String? {
        // Use iTunes Search API instead of CommerceKit to avoid triggering App Store popup
        // This is a simple HTTP request that doesn't initiate any purchase operations
        guard let endpoint = URL(string: "https://itunes.apple.com/lookup") else {
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorUnsupportedURL, userInfo: nil)
        }

        let languageCode = Locale.current.regionCode ?? "US"
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "id", value: "\(adamID)"),
            URLQueryItem(name: "country", value: languageCode)
        ]

        guard let url = components?.url else {
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorUnsupportedURL, userInfo: nil)
        }

        // Perform HTTP request (no CommerceKit, no purchase operation, no popup)
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        let (data, _) = try await URLSession.shared.data(for: request)

        // Parse JSON response
        let json = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
        guard let result = json.results.first else { return nil }

        return result.version
    }
}

// MARK: - iTunes Search API Models

/// Response from iTunes Search API
private struct iTunesSearchResponse: Codable {
    let results: [iTunesApp]
}

/// App information from iTunes Search API
private struct iTunesApp: Codable {
    let version: String
}
