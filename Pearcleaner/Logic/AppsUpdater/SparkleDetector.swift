//
//  SparkleDetector.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation

class SparkleDetector {
    private static let logger = UpdaterDebugLogger.shared

    static func findSparkleApps(from apps: [AppInfo], includePreReleases: Bool = false) async -> [UpdateableApp] {
        logger.log(.sparkle, "Starting Sparkle update check for \(apps.count) apps (includePreReleases: \(includePreReleases))")

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

            logger.log(.sparkle, "Checking: \(appInfo.appName)")

            // Step 2: Try traditional SUFeedURL first (covers ~95% of Sparkle apps)
            var feedURL: String? = infoDict["SUFeedURL"] as? String ?? infoDict["SUFeedUrl"] as? String
            var extractedURLs: [String]? = nil

            if let plistURL = feedURL {
                logger.log(.sparkle, "  ✓ Found SUFeedURL in Info.plist: \(plistURL)")
            }

            // Step 3: If no SUFeedURL but has signature key, try binary extraction
            // This handles apps like Ghostty that use SPUUpdaterDelegate's feedURLString(for:)
            if feedURL == nil && hasSparkleSignatureKey(infoDict: infoDict) {
                logger.log(.sparkle, "  ⚙️ No SUFeedURL but has signature key - extracting from binary...")
                // Get executable name from Info.plist
                if let executableName = infoDict["CFBundleExecutable"] as? String {
                    let urls = await extractFeedURLFromBinary(appPath: appInfo.path, executable: executableName)
                    if let firstURL = urls.first {
                        feedURL = firstURL
                        extractedURLs = urls  // Store all URLs for picker
                        logger.log(.sparkle, "  ✓ Extracted \(urls.count) URL(s) from binary: \(firstURL)")
                    } else {
                        logger.log(.sparkle, "  ❌ Binary extraction failed")
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

            logger.log(.sparkle, "Found \(allUpdates.count) Sparkle updates available")
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
        logger.log(.sparkle, "  Fetching appcast: \(feedURL)")
        guard let url = URL(string: feedURL) else {
            logger.log(.sparkle, "  ❌ Invalid feed URL")
            return nil
        }

        do {
            // Fetch appcast XML with timeout
            let (data, _) = try await URLSession.shared.data(from: url)

            // Parse ALL items from the appcast
            var items = parseAppcastMetadata(from: data)
            guard !items.isEmpty else {
                logger.log(.sparkle, "  ❌ No items found in appcast")
                return nil
            }

            logger.log(.sparkle, "  Parsed \(items.count) item(s) from appcast")

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

            logger.log(.sparkle, "  Comparing versions - Installed: \(appVersionToCompare), Available: \(appcastVersionToCompare)")

            // Only show update if available > installed
            if availableVer > installedVer {
                logger.log(.sparkle, "  📦 UPDATE AVAILABLE: \(appVersionToCompare) → \(appcastVersionToCompare)")

                // Check minimum OS version compatibility
                if let minimumOS = candidateItem.minimumSystemVersion {
                    // Parse minimum OS version (e.g., "13.0", "14.5")
                    if let minOSVersion = parseOperatingSystemVersion(minimumOS) {
                        // Check if current system meets the requirement
                        if !ProcessInfo.processInfo.isOperatingSystemAtLeast(minOSVersion) {
                            // Update requires newer macOS - skip this update
                            logger.log(.sparkle, "  ⚠️ Skipped - requires macOS \(minimumOS)")
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

            logger.log(.sparkle, "  ✓ Up to date")
        } catch {
            // Network error or parsing failure - silently skip this app
            logger.log(.sparkle, "  ❌ Error fetching/parsing appcast: \(error.localizedDescription)")
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

    /// Collect binaries to scan for appcast URLs
    /// Returns array of binary paths to scan in priority order: main executable, top 5 frameworks, top 5 plugins
    private static func collectBinariesToScan(appPath: URL, executable: String) -> [URL] {
        var binaries: [URL] = []
        let fm = FileManager.default

        // 1. Main executable (highest priority)
        let mainBinary = appPath.appendingPathComponent("Contents/MacOS/\(executable)")
        if fm.fileExists(atPath: mainBinary.path) {
            binaries.append(mainBinary)
            logger.log(.sparkle, "    • Main executable: \(executable)")
        }

        // 2. Custom frameworks (top 5 by size)
        let frameworksFolder = appPath.appendingPathComponent("Contents/Frameworks")
        if let frameworkContents = try? fm.contentsOfDirectory(at: frameworksFolder, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
            // Filter for .framework bundles, excluding Sparkle itself (it only contains Sparkle's own URLs, not the app's appcast)
            let frameworks = frameworkContents.filter {
                $0.pathExtension == "framework" &&
                !$0.lastPathComponent.lowercased().hasPrefix("sparkle")
            }

            // Sort by size (largest first) and take top 5
            let sortedFrameworks = frameworks
                .compactMap { frameworkBundle -> (URL, Int)? in
                    // Find the actual binary inside: Versions/A/{FrameworkName}
                    let frameworkName = frameworkBundle.deletingPathExtension().lastPathComponent
                    let binaryPath = frameworkBundle.appendingPathComponent("Versions/A/\(frameworkName)")

                    // Get file size
                    guard let attributes = try? fm.attributesOfItem(atPath: binaryPath.path),
                          let fileSize = attributes[.size] as? Int else {
                        return nil
                    }

                    return (binaryPath, fileSize)
                }
                .sorted { $0.1 > $1.1 }  // Sort by size descending
                .prefix(5)               // Take top 5

            for (frameworkBinary, size) in sortedFrameworks {
                binaries.append(frameworkBinary)
                let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                logger.log(.sparkle, "    • Framework: \(frameworkBinary.lastPathComponent) (\(sizeStr))")
            }
        }

        // 3. Plugins (smart filtering: UI-related names first, then by size)
        let pluginsFolder = appPath.appendingPathComponent("Contents/MacOS/plugins")
        if let pluginContents = try? fm.contentsOfDirectory(at: pluginsFolder, includingPropertiesForKeys: [.fileSizeKey]) {
            // Filter for .dylib files
            let plugins = pluginContents.filter { $0.pathExtension == "dylib" }

            // Get all plugins with size info
            let pluginsWithSize = plugins.compactMap { pluginPath -> (URL, Int)? in
                guard let attributes = try? fm.attributesOfItem(atPath: pluginPath.path),
                      let fileSize = attributes[.size] as? Int else {
                    return nil
                }
                return (pluginPath, fileSize)
            }

            // UI-related name patterns (likely to contain appcast URLs)
            let uiPatterns = ["macosx", "cocoa", "ui", "qt", "update", "sparkle"]

            // Priority tier: Plugins with UI-related names (sorted by size)
            let priorityPlugins = pluginsWithSize
                .filter { (url, _) in
                    let name = url.lastPathComponent.lowercased()
                    return uiPatterns.contains { name.contains($0) }
                }
                .sorted { $0.1 > $1.1 }  // Sort by size descending

            // Fallback tier: Remaining plugins by size
            let remainingPlugins = pluginsWithSize
                .filter { (url, _) in
                    let name = url.lastPathComponent.lowercased()
                    return !uiPatterns.contains { name.contains($0) }
                }
                .sorted { $0.1 > $1.1 }  // Sort by size descending

            // Combine: priority first, then fallback (total limit: 5)
            let selectedPlugins = (priorityPlugins + remainingPlugins).prefix(5)

            for (pluginPath, size) in selectedPlugins {
                binaries.append(pluginPath)
                let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                let isPriority = uiPatterns.contains { pluginPath.lastPathComponent.lowercased().contains($0) }
                let marker = isPriority ? "🎯" : "  "
                logger.log(.sparkle, "    \(marker) Plugin: \(pluginPath.lastPathComponent) (\(sizeStr))")
            }
        }

        return binaries
    }

    /// Extract Sparkle feed URL from app binaries (main executable, frameworks, plugins)
    /// Scans main executable first (no timeout), then frameworks/plugins concurrently (with timeout)
    /// Returns array of unique URLs found (or empty array if none found)
    private static func extractFeedURLFromBinary(appPath: URL, executable: String) async -> [String] {
        logger.log(.sparkle, "  🔍 Scanning binaries for appcast URLs...")

        // Collect all binaries to scan (main, frameworks, plugins)
        let binaries = collectBinariesToScan(appPath: appPath, executable: executable)

        guard !binaries.isEmpty else {
            logger.log(.sparkle, "    ❌ No binaries found to scan")
            return []
        }

        logger.log(.sparkle, "    Found \(binaries.count) binaries to scan")

        // Separate main executable from others
        let mainBinaryPath = appPath.appendingPathComponent("Contents/MacOS/\(executable)")
        let otherBinaries = binaries.filter { $0 != mainBinaryPath }

        // STEP 1: Scan main executable first (no size limit)
        if binaries.contains(mainBinaryPath) {
            logger.log(.sparkle, "    [1/\(binaries.count)] Scanning: \(executable) (main)")
            let urls = await scanBinaryForAppcastURLs(binaryPath: mainBinaryPath, sizeLimit: nil)

            if !urls.isEmpty {
                logger.log(.sparkle, "    ✓ Found \(urls.count) URL(s) in \(executable):")
                for url in urls {
                    logger.log(.sparkle, "      - \(url)")
                }
                return urls  // Early exit - found in main executable
            } else {
                logger.log(.sparkle, "      No URLs found")
            }
        }

        // STEP 2: Scan frameworks/plugins concurrently (with size limits)
        guard !otherBinaries.isEmpty else {
            logger.log(.sparkle, "    ❌ No appcast URLs found in any binary")
            return []
        }

        // Create optimal chunks for concurrent processing
        let chunks = createOptimalChunks(from: otherBinaries, minChunkSize: 2, maxChunkSize: 5)
        logger.log(.sparkle, "    Scanning \(otherBinaries.count) frameworks/plugins concurrently...")

        // Scan chunks concurrently and collect ALL URLs from ALL binaries
        return await withTaskGroup(of: [(String, String)].self) { group in
            for chunk in chunks {
                group.addTask {
                    var chunkResults: [(String, String)] = []  // (binaryName, url) pairs

                    // Scan each binary in chunk sequentially
                    for binaryPath in chunk {
                        let binaryName = binaryPath.lastPathComponent

                        // Determine size limit based on binary type:
                        // - Frameworks: 30 MB limit (allows UI frameworks, skips bloated libraries like ChatGPT 62 MB)
                        // - Plugins: 15 MB limit (allows UI plugins, skips large codec/network libraries)
                        let isPlugin = binaryPath.path.contains("/plugins/")
                        let sizeLimit = isPlugin ? 15_000_000 : 30_000_000

                        let urls = await scanBinaryForAppcastURLs(binaryPath: binaryPath, sizeLimit: sizeLimit)

                        if !urls.isEmpty {
                            logger.log(.sparkle, "    ✓ Found \(urls.count) URL(s) in \(binaryName):")
                            for url in urls {
                                logger.log(.sparkle, "      - \(url)")
                                chunkResults.append((binaryName, url))
                            }
                        }
                    }
                    return chunkResults
                }
            }

            // Collect ALL URLs from ALL chunks
            var allResults: [(String, String)] = []
            for await chunkResults in group {
                allResults.append(contentsOf: chunkResults)
            }

            guard !allResults.isEmpty else {
                logger.log(.sparkle, "    ❌ No appcast URLs found in any binary")
                return []
            }

            // Extract unique URLs (C function already sorted by priority)
            let allURLs = Array(Set(allResults.map { $0.1 }))

            // Filter by architecture if multiple URLs found
            if allURLs.count > 1 {
                #if arch(arm64)
                let archKeywords = ["arm64", "apple"]  // Apple Silicon
                #elseif arch(x86_64)
                let archKeywords = ["intel", "x86_64", "x64"]  // Intel
                #else
                let archKeywords: [String] = []
                #endif

                // Find architecture-specific URLs
                let archSpecificURLs = allURLs.filter { url in
                    let lowercased = url.lowercased()
                    return archKeywords.contains { lowercased.contains($0) }
                }

                // If we found arch-specific URLs, use only those
                if !archSpecificURLs.isEmpty {
                    return archSpecificURLs
                }
            }

            return allURLs
        }
    }

    /// Scan a single binary file for appcast URLs using C implementation
    /// Returns array of found URLs from the binary (priority sorted: release URLs first)
    /// - Parameters:
    ///   - binaryPath: Path to binary file to scan
    ///   - sizeLimit: Optional size limit in bytes (nil = no limit)
    private static func scanBinaryForAppcastURLs(binaryPath: URL, sizeLimit: Int?) async -> [String] {
        // Verify binary exists and get file size
        guard FileManager.default.fileExists(atPath: binaryPath.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: binaryPath.path),
              let fileSize = attributes[.size] as? Int else {
            return []
        }

        // Skip binaries larger than size limit (if specified)
        if let maxFileSize = sizeLimit, fileSize > maxFileSize {
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
            let limitStr = ByteCountFormatter.string(fromByteCount: Int64(maxFileSize), countStyle: .file)
            logger.log(.sparkle, "        Skipped (file too large: \(sizeStr) > \(limitStr))")
            return []
        }

        // Call C function to extract appcast URLs directly from binary
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .utility) {
                var output: UnsafeMutablePointer<CChar>? = nil
                var outputLen: size_t = 0

                let result = binaryPath.path.withCString { path in
                    extract_appcast_urls(path, &output, &outputLen)
                }

                guard result == 0, let outputPtr = output, outputLen > 0 else {
                    continuation.resume(returning: [])
                    return
                }

                defer { free(outputPtr) }

                // Convert C string to Swift String
                // Create a Data object from the buffer, which will copy the bytes
                let data = Data(bytes: outputPtr, count: outputLen)
                let outputString = String(data: data, encoding: .utf8) ?? ""

                // Split by newlines to get individual URLs
                // URLs are already deduplicated and priority-sorted by C function
                let urls = outputString
                    .split(separator: "\n")
                    .map { String($0) }
                    .filter { !$0.isEmpty }

                continuation.resume(returning: urls)
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
