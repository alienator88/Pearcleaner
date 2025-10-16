//
//  SparkleDetector.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation
import SemanticVersion

class SparkleDetector {
    static func findSparkleApps(from apps: [AppInfo], includePreReleases: Bool = false) async -> [UpdateableApp] {
        // Find all apps with Sparkle framework
        var sparkleAppData: [(appInfo: AppInfo, feedURL: String, shortVersion: String, buildVersion: String)] = []

        for appInfo in apps {
            // Read the app's Info.plist
            let infoPlistURL = appInfo.path.appendingPathComponent("Contents/Info.plist")

            guard let infoDict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else {
                continue
            }

            // Check for Sparkle feed URL
            if let feedURLRaw = infoDict["SUFeedURL"] as? String ?? infoDict["SUFeedUrl"] as? String {
                // Remove surrounding quotes/apostrophes (handles malformed Info.plist entries)
                let feedURL = feedURLRaw.unquoted

                // Extract both version types from Info.plist
                let shortVersion = infoDict["CFBundleShortVersionString"] as? String ?? ""
                let buildVersion = infoDict["CFBundleVersion"] as? String ?? ""

                sparkleAppData.append((appInfo, feedURL, shortVersion, buildVersion))
            }
        }

        guard !sparkleAppData.isEmpty else { return [] }

        // Create optimal chunks for concurrent processing
        let chunks = createOptimalChunks(from: sparkleAppData, minChunkSize: 3, maxChunkSize: 10)

        // Process chunks concurrently
        return await withTaskGroup(of: [UpdateableApp].self) { group in
            for chunk in chunks {
                group.addTask {
                    await checkChunk(chunk: chunk, includePreReleases: includePreReleases)
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

    /// Check a chunk of Sparkle apps for updates concurrently
    private static func checkChunk(chunk: [(appInfo: AppInfo, feedURL: String, shortVersion: String, buildVersion: String)], includePreReleases: Bool) async -> [UpdateableApp] {
        await withTaskGroup(of: UpdateableApp?.self) { group in
            for (appInfo, feedURL, shortVersion, buildVersion) in chunk {
                group.addTask {
                    await checkSingleApp(appInfo: appInfo, feedURL: feedURL, shortVersion: shortVersion, buildVersion: buildVersion, includePreReleases: includePreReleases)
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

    /// Check a single Sparkle app for updates
    private static func checkSingleApp(appInfo: AppInfo, feedURL: String, shortVersion: String, buildVersion: String, includePreReleases: Bool) async -> UpdateableApp? {
        guard let url = URL(string: feedURL) else { return nil }

        do {
            // Fetch appcast XML with timeout
            let (data, _) = try await URLSession.shared.data(from: url)

            // Parse ALL items from the appcast
            var items = parseAppcastMetadata(from: data)
            guard !items.isEmpty else { return nil }

            // Filter pre-releases BEFORE finding best item (not after!)
            if !includePreReleases {
                // Stage 1: Filter by channel tag (e.g., BetterDisplay with <sparkle:channel>beta</sparkle:channel>)
                items = items.filter { $0.channel == nil }

                // Stage 2: Filter by SemVer pre-release identifier (e.g., Transmission with version "4.1.0-beta.2")
                items = items.filter { item in
                    let version = item.shortVersionString ?? item.buildVersion
                    guard let semVer = SemanticVersion(version) else { return true }  // Keep if not parseable
                    return !semVer.isPreRelease  // Exclude if pre-release (has -beta, -rc, -alpha, etc.)
                }
            }

            // After filtering, check if we have any items left
            guard !items.isEmpty else { return nil }

            // Find the item with the highest version across all items
            let candidateItem: SparkleMetadata = items.max { item1, item2 in
                let ver1 = item1.shortVersionString ?? item1.buildVersion
                let ver2 = item2.shortVersionString ?? item2.buildVersion

                // Compare using SemanticVersion
                guard let semVer1 = SemanticVersion(ver1),
                      let semVer2 = SemanticVersion(ver2) else {
                    // Fallback to string comparison if parsing fails
                    return ver1 < ver2
                }

                return semVer1 < semVer2
            }!

            // Smart version comparison (matching Latest app's logic):
            // - If appcast has shortVersionString, compare with app's CFBundleShortVersionString
            // - If appcast only has version (build number), compare with app's CFBundleVersion
            // - This prevents false positives like DiskDrill (6.0 vs 6.0.2020)

            let appVersionToCompare: String
            let appcastVersionToCompare: String

            if let appcastShortVersion = candidateItem.shortVersionString {
                // Appcast has shortVersionString - compare user-facing versions
                appVersionToCompare = shortVersion
                appcastVersionToCompare = appcastShortVersion
            } else {
                // Appcast only has build version - compare build numbers
                // But if app's build == short version (no separate build number), use short version
                appVersionToCompare = (buildVersion == shortVersion || buildVersion.isEmpty) ? shortVersion : buildVersion
                appcastVersionToCompare = candidateItem.buildVersion
            }

            // Use SemanticVersion for robust comparison
            guard let installedVer = SemanticVersion(appVersionToCompare),
                  let availableVer = SemanticVersion(appcastVersionToCompare) else {
                return nil  // Invalid version format
            }

            // Only show update if available > installed
            if availableVer > installedVer {
                // Check minimum OS version compatibility
                if let minimumOS = candidateItem.minimumSystemVersion {
                    // Parse minimum OS version (e.g., "13.0", "14.5")
                    if let minOSVersion = parseOperatingSystemVersion(minimumOS) {
                        // Check if current system meets the requirement
                        if !ProcessInfo.processInfo.isOperatingSystemAtLeast(minOSVersion) {
                            // Update requires newer macOS - skip this update
                            return nil
                        }
                    }
                }

                return UpdateableApp(
                    appInfo: appInfo,
                    availableVersion: appcastVersionToCompare,
                    source: .sparkle,
                    adamID: nil,
                    appStoreURL: nil,
                    status: .idle,
                    progress: 0.0,
                    releaseTitle: candidateItem.title,
                    releaseDescription: candidateItem.description,
                    releaseNotesLink: candidateItem.releaseNotesLink,
                    releaseDate: candidateItem.pubDate
                )
            }
        } catch {
            // Network error or parsing failure - silently skip this app
            return nil
        }

        return nil
    }


    /// Parse Sparkle appcast XML to extract all items
    private static func parseAppcastMetadata(from data: Data) -> [SparkleMetadata] {
        let parser = SparkleAppcastParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()

        return parser.items
    }

    /// Parse macOS version string (e.g., "13.0", "14.5.1") into OperatingSystemVersion
    private static func parseOperatingSystemVersion(_ versionString: String) -> OperatingSystemVersion? {
        let components = versionString.split(separator: ".").compactMap { Int($0) }
        guard !components.isEmpty else { return nil }

        return OperatingSystemVersion(
            majorVersion: components.count > 0 ? components[0] : 0,
            minorVersion: components.count > 1 ? components[1] : 0,
            patchVersion: components.count > 2 ? components[2] : 0
        )
    }
}

// Sparkle metadata structure
private struct SparkleMetadata {
    let shortVersionString: String?  // User-facing version (e.g., "6.0")
    let buildVersion: String         // Internal/build version (e.g., "6.0.2020")
    let channel: String?             // Release channel (e.g., "beta", "pre", "internal") - nil means stable/default channel
    let minimumSystemVersion: String? // Minimum macOS version required (e.g., "13.0")
    let title: String?
    let description: String?
    let releaseNotesLink: String?    // Link to release notes page
    let pubDate: String?
}

// XML Parser delegate for Sparkle appcast
private class SparkleAppcastParser: NSObject, XMLParserDelegate {
    var items: [SparkleMetadata] = []  // Collect ALL items

    // Per-item state (reset on each <item>)
    private var shortVersionString: String?
    private var internalVersion: String?
    private var releaseChannel: String?
    private var minimumSystemVersion: String?
    private var releaseTitle: String?
    private var releaseDescription: String?
    private var releaseNotesLink: String?
    private var fullReleaseNotesLink: String?
    private var releaseDate: String?

    private var currentElement = ""
    private var currentText = ""
    private var insideItem = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""

        // Track when we enter an <item>
        if elementName == "item" {
            insideItem = true
            // Reset per-item state
            shortVersionString = nil
            internalVersion = nil
            releaseChannel = nil
            minimumSystemVersion = nil
            releaseTitle = nil
            releaseDescription = nil
            releaseNotesLink = nil
            fullReleaseNotesLink = nil
            releaseDate = nil
        }

        // Check enclosure attributes for version (highest priority, matching Sparkle's behavior)
        if insideItem && elementName == "enclosure" {
            // Try sparkle:shortVersionString attribute (user-facing version)
            if let shortVersion = attributeDict["sparkle:shortVersionString"] {
                if !shortVersion.isEmpty {
                    shortVersionString = shortVersion
                }
            }
            // Also capture sparkle:version attribute (internal/build version)
            if let version = attributeDict["sparkle:version"] {
                if !version.isEmpty {
                    internalVersion = version
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if insideItem {
            // Collect sparkle:shortVersionString element (user-facing version)
            if elementName == "shortVersionString" || elementName == "sparkle:shortVersionString" {
                if !currentText.isEmpty {
                    shortVersionString = currentText
                }
            }
            // Collect sparkle:version element (internal/build version)
            else if elementName == "version" || elementName == "sparkle:version" {
                if !currentText.isEmpty {
                    internalVersion = currentText
                }
            }

            // Extract title
            if elementName == "title" && releaseTitle == nil && !currentText.isEmpty {
                releaseTitle = currentText
            }

            // Extract description (may contain HTML/CDATA)
            if elementName == "description" && releaseDescription == nil && !currentText.isEmpty {
                releaseDescription = currentText
            }

            // Extract release notes link
            if (elementName == "releaseNotesLink" || elementName == "sparkle:releaseNotesLink") && releaseNotesLink == nil && !currentText.isEmpty {
                releaseNotesLink = currentText
            }

            // Extract full release notes link (fallback)
            if (elementName == "fullReleaseNotesLink" || elementName == "sparkle:fullReleaseNotesLink") && fullReleaseNotesLink == nil && !currentText.isEmpty {
                fullReleaseNotesLink = currentText
            }

            // Extract pubDate
            if elementName == "pubDate" && releaseDate == nil && !currentText.isEmpty {
                releaseDate = currentText
            }

            // Extract channel (beta/pre/internal/etc.) - absence means stable/default channel
            if (elementName == "channel" || elementName == "sparkle:channel") && releaseChannel == nil && !currentText.isEmpty {
                releaseChannel = currentText
            }

            // Extract minimum system version
            if (elementName == "minimumSystemVersion" || elementName == "sparkle:minimumSystemVersion") && minimumSystemVersion == nil && !currentText.isEmpty {
                minimumSystemVersion = currentText
            }

            // Exit item - save it if it has a valid version
            if elementName == "item" {
                if let buildVer = internalVersion {
                    // Use releaseNotesLink, fallback to fullReleaseNotesLink
                    let finalReleaseNotesLink = releaseNotesLink ?? fullReleaseNotesLink

                    let metadata = SparkleMetadata(
                        shortVersionString: shortVersionString,
                        buildVersion: buildVer,
                        channel: releaseChannel,
                        minimumSystemVersion: minimumSystemVersion,
                        title: releaseTitle,
                        description: releaseDescription,
                        releaseNotesLink: finalReleaseNotesLink,
                        pubDate: releaseDate
                    )
                    items.append(metadata)
                }
                insideItem = false
                // DO NOT abort - we need to parse all items!
            }
        }

        currentText = ""
    }
}

// MARK: - String Extension
private extension String {
    /// Removes surrounding quotes and apostrophes from the string
    /// Handles malformed Info.plist entries like: "https://example.com" or 'https://example.com'
    var unquoted: String {
        return trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
    }
}
