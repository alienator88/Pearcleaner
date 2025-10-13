//
//  SparkleDetector.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation

class SparkleDetector {
    static func findSparkleApps(from apps: [AppInfo]) async -> [UpdateableApp] {
        // Find all apps with Sparkle framework
        var sparkleAppData: [(appInfo: AppInfo, feedURL: String)] = []

        for appInfo in apps {
            // Read the app's Info.plist
            let infoPlistURL = appInfo.path.appendingPathComponent("Contents/Info.plist")

            guard let infoDict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else {
                continue
            }

            // Check for Sparkle feed URL
            if let feedURL = infoDict["SUFeedURL"] as? String ?? infoDict["SUFeedUrl"] as? String {
                sparkleAppData.append((appInfo, feedURL))
            }
        }

        guard !sparkleAppData.isEmpty else { return [] }

        // Create optimal chunks for concurrent processing
        let chunks = createOptimalChunks(from: sparkleAppData, minChunkSize: 3, maxChunkSize: 10)

        // Process chunks concurrently
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

    /// Check a chunk of Sparkle apps for updates concurrently
    private static func checkChunk(chunk: [(appInfo: AppInfo, feedURL: String)]) async -> [UpdateableApp] {
        await withTaskGroup(of: UpdateableApp?.self) { group in
            for (appInfo, feedURL) in chunk {
                group.addTask {
                    await checkSingleApp(appInfo: appInfo, feedURL: feedURL)
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
    private static func checkSingleApp(appInfo: AppInfo, feedURL: String) async -> UpdateableApp? {
        guard let url = URL(string: feedURL) else { return nil }

        do {
            // Fetch appcast XML with timeout
            let (data, _) = try await URLSession.shared.data(from: url)

            // Parse XML to extract all metadata
            guard let metadata = parseAppcastMetadata(from: data) else {
                return nil
            }

            // Compare versions - only return if appcast version is GREATER than installed version
            if metadata.version > appInfo.appVersion {
                return UpdateableApp(
                    appInfo: appInfo,
                    availableVersion: metadata.version,
                    source: .sparkle,
                    adamID: nil,
                    appStoreURL: nil,
                    status: .idle,
                    progress: 0.0,
                    releaseTitle: metadata.title,
                    releaseDescription: metadata.description,
                    releaseDate: metadata.pubDate
                )
            }
        } catch {
            // Network error or parsing failure - silently skip this app
            return nil
        }

        return nil
    }

    /// Parse Sparkle appcast XML to extract metadata from the first <item>
    private static func parseAppcastVersion(from data: Data) -> String? {
        let parser = SparkleAppcastParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.latestVersion
    }

    /// Parse Sparkle appcast XML to extract all metadata from the first <item>
    private static func parseAppcastMetadata(from data: Data) -> SparkleMetadata? {
        let parser = SparkleAppcastParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()

        guard let version = parser.latestVersion else { return nil }

        return SparkleMetadata(
            version: version,
            title: parser.releaseTitle,
            description: parser.releaseDescription,
            pubDate: parser.releaseDate
        )
    }
}

// Sparkle metadata structure
private struct SparkleMetadata {
    let version: String
    let title: String?
    let description: String?
    let pubDate: String?
}

// XML Parser delegate for Sparkle appcast
private class SparkleAppcastParser: NSObject, XMLParserDelegate {
    var latestVersion: String?
    var releaseTitle: String?
    var releaseDescription: String?
    var releaseDate: String?
    private var currentElement = ""
    private var currentText = ""
    private var insideFirstItem = false
    private var foundFirstItem = false

    // Track both version types separately to prioritize shortVersionString
    private var shortVersionString: String?
    private var internalVersion: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""

        // Track when we enter the first <item>
        if elementName == "item" && !foundFirstItem {
            insideFirstItem = true
            foundFirstItem = true
        }

        // Check enclosure attributes for version (highest priority, matching Sparkle's behavior)
        if insideFirstItem && elementName == "enclosure" {
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
        if insideFirstItem {
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

            // Extract pubDate
            if elementName == "pubDate" && releaseDate == nil && !currentText.isEmpty {
                releaseDate = currentText
            }

            // Exit first item - prioritize shortVersionString over internalVersion
            if elementName == "item" {
                // Always prefer shortVersionString if available, fall back to internalVersion
                latestVersion = shortVersionString ?? internalVersion
                insideFirstItem = false
                parser.abortParsing() // Stop parsing after first item
            }
        }

        currentText = ""
    }
}
