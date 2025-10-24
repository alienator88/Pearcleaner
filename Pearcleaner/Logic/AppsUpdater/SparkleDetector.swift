//
//  SparkleDetector.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation

class SparkleDetector {
    static func findSparkleApps(from apps: [AppInfo], includePreReleases: Bool = false) async -> [UpdateableApp] {
        // Find all apps with Sparkle framework
        // Track extracted URLs for showing warning + URL picker UI
        var sparkleAppData: [(appInfo: AppInfo, feedURL: String, shortVersion: String, buildVersion: String, extractedURLs: [String]?)] = []

        for appInfo in apps {
            // Step 1: Check for Sparkle.framework
            guard hasSparkleFramework(appPath: appInfo.path) else {
                continue
            }

            // Read the app's Info.plist
            let infoPlistURL = appInfo.path.appendingPathComponent("Contents/Info.plist")

            guard let infoDict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else {
                continue
            }

            // Step 2: Try traditional SUFeedURL first (covers ~95% of Sparkle apps)
            var feedURL: String? = infoDict["SUFeedURL"] as? String ?? infoDict["SUFeedUrl"] as? String
            var extractedURLs: [String]? = nil

            // Step 3: If no SUFeedURL but has signature key, try binary extraction
            // This handles apps like Ghostty that use SPUUpdaterDelegate's feedURLString(for:)
            if feedURL == nil && hasSparkleSignatureKey(infoDict: infoDict) {
                // Get executable name from Info.plist
                if let executableName = infoDict["CFBundleExecutable"] as? String {
                    let urls = await extractFeedURLFromBinary(appPath: appInfo.path, executable: executableName)
                    if let firstURL = urls.first {
                        feedURL = firstURL
                        extractedURLs = urls  // Store all URLs for picker
                    }
                }
            }

            // Step 4: If we have a feed URL (from either method), add to processing queue
            if let feedURL = feedURL?.unquoted, !feedURL.isEmpty {
                // Extract both version types from Info.plist
                let shortVersion = infoDict["CFBundleShortVersionString"] as? String ?? ""
                let buildVersion = infoDict["CFBundleVersion"] as? String ?? ""

                sparkleAppData.append((appInfo, feedURL, shortVersion, buildVersion, extractedURLs))
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
    private static func checkChunk(chunk: [(appInfo: AppInfo, feedURL: String, shortVersion: String, buildVersion: String, extractedURLs: [String]?)], includePreReleases: Bool) async -> [UpdateableApp] {
        await withTaskGroup(of: UpdateableApp?.self) { group in
            for (appInfo, feedURL, shortVersion, buildVersion, extractedURLs) in chunk {
                group.addTask {
                    await checkSingleApp(appInfo: appInfo, feedURL: feedURL, shortVersion: shortVersion, buildVersion: buildVersion, extractedURLs: extractedURLs, currentFeedURL: feedURL, includePreReleases: includePreReleases)
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

    /// Public wrapper to check a single Sparkle app with a specific feed URL
    /// Used for refreshing an app's update check with an alternate URL
    static func checkSingleAppWithURL(appInfo: AppInfo, feedURL: String, includePreReleases: Bool, preserveExtractedURLs: [String]? = nil, currentFeedURL: String) async -> UpdateableApp? {
        // Read the app's Info.plist
        let infoPlistURL = appInfo.path.appendingPathComponent("Contents/Info.plist")

        guard let infoDict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else {
            return nil
        }

        let shortVersion = infoDict["CFBundleShortVersionString"] as? String ?? ""
        let buildVersion = infoDict["CFBundleVersion"] as? String ?? ""

        // Check for updates with the specified URL
        // Pass through the extracted URLs to preserve binary extraction metadata
        return await checkSingleApp(
            appInfo: appInfo,
            feedURL: feedURL,
            shortVersion: shortVersion,
            buildVersion: buildVersion,
            extractedURLs: preserveExtractedURLs,
            currentFeedURL: currentFeedURL,
            includePreReleases: includePreReleases
        )
    }

    /// Check a single Sparkle app for updates
    private static func checkSingleApp(appInfo: AppInfo, feedURL: String, shortVersion: String, buildVersion: String, extractedURLs: [String]?, currentFeedURL: String, includePreReleases: Bool) async -> UpdateableApp? {
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

                // Stage 2: Filter by version string pre-release patterns (e.g., Transmission with version "4.1.0-beta.2")
                items = items.filter { item in
                    let version = item.shortVersionString ?? item.buildVersion
                    return !isPreReleaseVersion(version)  // Exclude if pre-release (has -beta, -rc, -alpha, etc.)
                }
            }

            // Stage 3: Smart commit hash filtering
            // If ALL items are commit hashes → tip/nightly feed → keep them
            // If feed has MIX of commit hashes and semantic versions → filter out commit hashes
            let allItemsAreCommitHashes = items.allSatisfy { item in
                let version = item.shortVersionString ?? item.buildVersion
                return isCommitHashVersion(version)
            }

            // Only filter commit hashes if feed has BOTH commit hashes and semantic versions
            if !allItemsAreCommitHashes {
                items = items.filter { item in
                    let version = item.shortVersionString ?? item.buildVersion
                    return !isCommitHashVersion(version)
                }
            }

            // After filtering, check if we have any items left
            guard !items.isEmpty else { return nil }

            // Find the most recent item by version comparison (primary), pubDate (fallback)
            // Version-first handles most apps correctly (including pre-releases)
            // pubDate fallback handles edge cases like Ghostty with commit hash versions
            let candidateItem: SparkleMetadata = items.max { item1, item2 in
                // PRIMARY: Compare by version
                let ver1 = item1.shortVersionString ?? item1.buildVersion
                let ver2 = item2.shortVersionString ?? item2.buildVersion
                let version1 = Version(versionNumber: ver1, buildNumber: nil)
                let version2 = Version(versionNumber: ver2, buildNumber: nil)

                // If BOTH versions are valid and different, compare by version
                // This handles semantic versions, pre-releases, multi-component versions
                if !version1.isEmpty && !version2.isEmpty && version1 != version2 {
                    return version1 < version2
                }

                // FALLBACK: If one/both versions are invalid/equal, use pubDate
                // This handles commit hashes, "tip"/"nightly" labels, equal versions
                if let date1 = parsePubDate(item1.pubDate),
                   let date2 = parsePubDate(item2.pubDate) {
                    return date1 < date2
                }

                return false
            }!

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

            // Use Version for robust comparison (supports 2, 3, 4+ component versions)
            let installedVer = Version(versionNumber: appVersionToCompare, buildNumber: nil)
            let availableVer = Version(versionNumber: appcastVersionToCompare, buildNumber: nil)

            // Skip if versions are empty/invalid
            guard !installedVer.isEmpty && !availableVer.isEmpty else {
                return nil
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

                // Determine if this is a pre-release update
                let isPreRelease: Bool = {
                    // Check if has channel tag (e.g., "beta", "pre", "internal")
                    if candidateItem.channel != nil {
                        return true
                    }
                    // Check if version has pre-release identifier (e.g., "4.1.0-beta.2", "1.0rc1")
                    if isPreReleaseVersion(appcastVersionToCompare) {
                        return true
                    }
                    return false
                }()

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
                    releaseDate: candidateItem.pubDate,
                    isPreRelease: isPreRelease,
                    isIOSApp: false,  // Sparkle apps are never iOS apps
                    extractedFromBinary: extractedURLs != nil,
                    alternateSparkleURLs: extractedURLs,
                    currentFeedURL: currentFeedURL
                )
            }
        } catch {
            // Network error or parsing failure - silently skip this app
            return nil
        }

        return nil
    }


    /// Check if a version string is a commit hash (e.g., "663205b5 (2024-12-20)")
    private static func isCommitHashVersion(_ version: String) -> Bool {
        let commitHashPattern = "^[0-9a-f]{8,}.*$"
        guard let regex = try? NSRegularExpression(pattern: commitHashPattern, options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(version.startIndex..<version.endIndex, in: version)
        return regex.firstMatch(in: version, range: range) != nil
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

    /// Parse RFC 822 date format from Sparkle appcast (e.g., "Fri, 20 Dec 2024 21:34:26 +0000")
    private static func parsePubDate(_ pubDateString: String?) -> Date? {
        guard let dateString = pubDateString else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        return formatter.date(from: dateString)
    }

    /// Check if app has Sparkle.framework in Contents/Frameworks
    private static func hasSparkleFramework(appPath: URL) -> Bool {
        let frameworkPath = appPath.appendingPathComponent("Contents/Frameworks/Sparkle.framework")
        return FileManager.default.fileExists(atPath: frameworkPath.path)
    }

    /// Check if Info.plist has Sparkle signature verification keys
    private static func hasSparkleSignatureKey(infoDict: [String: Any]) -> Bool {
        return infoDict["SUPublicEDKey"] != nil || infoDict["SUPublicDSAKeyFile"] != nil
    }

    /// Extract ALL appcast URLs from binary using strings command
    /// Returns array of all found URLs (not just first one) to support URL picker
    private static func extractFeedURLFromBinary(appPath: URL, executable: String) async -> [String] {
        let executablePath = appPath.appendingPathComponent("Contents/MacOS/\(executable)")

        // Verify executable exists
        guard FileManager.default.fileExists(atPath: executablePath.path) else {
            return []
        }

        // Run strings command asynchronously in background to avoid blocking UI
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .utility) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/strings")
                process.arguments = [executablePath.path]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe() // Discard errors

                do {
                    try process.run()

                    // Set timeout (2 seconds) to prevent indefinite hanging
                    let timer = DispatchSource.makeTimerSource(queue: .global())
                    timer.schedule(deadline: .now() + 2.0)
                    timer.setEventHandler {
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                    timer.resume()

                    // Wait for process to complete
                    process.waitUntilExit()
                    timer.cancel()

                    // Read output
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    guard let output = String(data: data, encoding: .utf8) else {
                        continuation.resume(returning: [])
                        return
                    }

                    // Filter for appcast URLs using regex
                    // Pattern matches: https?://[non-whitespace]+.(xml|appcast)
                    let urlPattern = #"https?://[^\s]+\.(xml|appcast)"#
                    let regex = try NSRegularExpression(pattern: urlPattern, options: [])
                    let range = NSRange(output.startIndex..., in: output)

                    // Find all matches
                    var urls: [String] = []
                    regex.enumerateMatches(in: output, range: range) { match, _, _ in
                        if let match = match,
                           let range = Range(match.range, in: output) {
                            let url = String(output[range])
                            // Additional validation: must contain "appcast" or end with ".xml"
                            if url.contains("appcast") || url.hasSuffix(".xml") {
                                urls.append(url)
                            }
                        }
                    }

                    // Remove duplicates while preserving order
                    let uniqueURLs = Array(NSOrderedSet(array: urls)) as! [String]

                    // Return all unique URLs (not just first)
                    continuation.resume(returning: uniqueURLs)

                } catch {
                    // Process execution failed - return empty array
                    continuation.resume(returning: [])
                }
            }
        }
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
