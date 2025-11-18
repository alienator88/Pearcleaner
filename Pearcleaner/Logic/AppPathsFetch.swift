//
//  AppPathsFetch.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 2/6/25.
//

import Foundation
import AppKit
import SwiftUI
import AlinFoundation

extension String {
    /// Strips trailing version numbers and digits from app names
    /// "Bartender 6" → "Bartender"
    /// "Firefox 120.0" → "Firefox"
    func strippingTrailingDigits() -> String {
        return self.replacingOccurrences(
            of: #"\s+\d+(\.\d+)*\s*$"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
    }
}

class AppPathFinder {
    // Shared properties
    private var appInfo: AppInfo
    private var locations: Locations
    private var containerCollection: [URL] = []
    private let collectionAccessQueue = DispatchQueue(label: "com.alienator88.Pearcleaner.appPathFinder.collectionAccess")
    @AppStorage("settings.general.searchSensitivity") private var sensitivityLevel: SearchSensitivityLevel = .strict
    @AppStorage("settings.general.searchTextContent") private var searchTextContent: Bool = false

    // Optional override sensitivity level for per-app settings
    private var overrideSensitivityLevel: SearchSensitivityLevel?

    // GUI-specific properties (can be nil for CLI)
    private var appState: AppState?
    private var undo: Bool = false
    private var completion: (() -> Void)?

    // Use a Set for fast membership testing
    private var collectionSet: Set<URL> = []

    // Precompiled UUID regex
    private static let uuidRegex: NSRegularExpression = {
        return try! NSRegularExpression(
            pattern: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$",
            options: .caseInsensitive
        )
    }()

    // Change from lazy var to regular property initialized in init
    private let cachedIdentifiers: (formattedBundleId: String, bundleLastTwoComponents: String, formattedAppName: String, formattedAppNameStripped: String?, appNameLettersOnly: String, pathComponentName: String, useBundleIdentifier: Bool, formattedCompanyName: String?, formattedEntitlements: [String], formattedTeamIdentifier: String?, formattedBaseBundleId: String?)

    // Exclusion list for app file search (computed property to always get current list)
    private var formattedAppExclusionList: [String] {
        return FolderSettingsManager.shared.fileFolderPathsApps.map { $0.pearFormat() }
    }

    // Computed property to get the effective sensitivity level
    private var effectiveSensitivityLevel: SearchSensitivityLevel {
        return overrideSensitivityLevel ?? sensitivityLevel
    }

    // Initializer for both CLI and GUI
    init(appInfo: AppInfo, locations: Locations, appState: AppState? = nil, undo: Bool = false, sensitivityOverride: SearchSensitivityLevel? = nil, completion: (() -> Void)? = nil) {
        self.appInfo = appInfo
        self.locations = locations
        self.appState = appState
        self.undo = undo
        self.overrideSensitivityLevel = sensitivityOverride
        self.completion = completion

        // Initialize cachedIdentifiers eagerly and thread-safely
        let formattedBundleId = appInfo.bundleIdentifier.pearFormat()
        let bundleComponents = appInfo.bundleIdentifier
            .components(separatedBy: ".")
            .compactMap { $0 != "-" ? $0.lowercased() : nil }
        let bundleLastTwoComponents = bundleComponents.suffix(2).joined()
        let formattedAppName = appInfo.appName.pearFormat()
        let appNameLettersOnly = formattedAppName.filter { $0.isLetter }
        let pathComponentName = appInfo.path.lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let useBundleIdentifier = AppPathFinder.isValidBundleIdentifier(appInfo.bundleIdentifier)

        // Extract company/dev name from 3-component bundle IDs (e.g., "com.knollsoft.Rectangle" -> "knollsoft")
        let formattedCompanyName: String?
        let rawComponents = appInfo.bundleIdentifier.components(separatedBy: ".")
        if rawComponents.count == 3 {
            formattedCompanyName = rawComponents[1].pearFormat()
        } else {
            formattedCompanyName = nil
        }

        // Pre-format entitlements once to avoid repeated formatting in the hot path
        let formattedEntitlements: [String] = appInfo.entitlements?.compactMap { entitlement in
            let formatted = entitlement.pearFormat()
            return formatted.isEmpty ? nil : formatted
        } ?? []

        // Pre-format team identifier once
        let formattedTeamIdentifier = appInfo.teamIdentifier?.pearFormat()

        // Create base bundle ID by stripping common suffixes (for matching launch daemons/agents)
        // e.g., "com.objective-see.blockblock.helper" -> "com.objective-see.blockblock"
        let formattedBaseBundleId: String?
        let commonSuffixes = ["helper", "agent", "daemon", "service", "xpc", "launcher", "updater", "installer", "uninstaller", "login", "extension", "plugin"]
        if rawComponents.count >= 4 {
            let lastComponent = rawComponents.last?.lowercased() ?? ""
            if commonSuffixes.contains(lastComponent) {
                // Remove last component and format
                let baseBundleId = rawComponents.dropLast().joined(separator: ".")
                formattedBaseBundleId = baseBundleId.pearFormat()
            } else {
                formattedBaseBundleId = nil
            }
        } else {
            formattedBaseBundleId = nil
        }

        // Strip trailing digits from app name for Enhanced/Deep mode matching
        // "Bartender 6" → "bartender6" (regular) + "bartender" (stripped)
        let appNameStripped = appInfo.appName.strippingTrailingDigits()
        let formattedAppNameStripped: String? = {
            let stripped = appNameStripped.pearFormat()
            // Only use if different from regular formatted name and not empty
            return (stripped != formattedAppName && !stripped.isEmpty) ? stripped : nil
        }()

        self.cachedIdentifiers = (formattedBundleId, bundleLastTwoComponents, formattedAppName, formattedAppNameStripped, appNameLettersOnly, pathComponentName, useBundleIdentifier, formattedCompanyName, formattedEntitlements, formattedTeamIdentifier, formattedBaseBundleId)
    }

    // Process the initial URL
    private func initialURLProcessing() {
        if let url = URL(string: self.appInfo.path.absoluteString), !url.path.contains(".Trash") {
            let modifiedUrl = url.path.contains("Wrapper") ? url.deletingLastPathComponent().deletingLastPathComponent() : url
            collectionSet.insert(modifiedUrl)
        }
    }

    // Get all container URLs
    private func getAllContainers(bundleURL: URL) -> [URL] {
        var containers: [URL] = []
        let bundleIdentifier = Bundle(url: bundleURL)?.bundleIdentifier

        guard let containerBundleIdentifier = bundleIdentifier else {
            return containers
        }

        if let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: containerBundleIdentifier) {
            if FileManager.default.fileExists(atPath: groupContainer.path) {
                containers.append(groupContainer)
                Task { @MainActor in
                    GlobalConsoleManager.shared.appendOutput("Found group container: \(groupContainer.lastPathComponent)\n", source: CurrentPage.applications.title)
                }
            }
        }

        if let containersPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Containers") {
            do {
                let containerDirectories = try FileManager.default.contentsOfDirectory(at: containersPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                for directory in containerDirectories {
                    let directoryName = directory.lastPathComponent
                    if AppPathFinder.uuidRegex.firstMatch(in: directoryName, options: [], range: NSRange(location: 0, length: directoryName.utf16.count)) != nil {
                        let metadataPlistURL = directory.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
                        if let metadataDict = NSDictionary(contentsOf: metadataPlistURL),
                           let applicationBundleID = metadataDict["MCMMetadataIdentifier"] as? String {
                            if applicationBundleID == self.appInfo.bundleIdentifier {
                                containers.append(directory)
                                Task { @MainActor in
                                    GlobalConsoleManager.shared.appendOutput("Found app container: \(directoryName)\n", source: CurrentPage.applications.title)
                                }
                            }
                        }
                    }
                }
            } catch {
                printOS("Error accessing Containers directory: \(error)")
            }
        }
        return containers
    }

    // Combined processing for directories and files
    private func processLocation(_ location: String) {
        processLocation(location, currentDepth: 0, maxDepth: 1, isLibraryRootSearch: false)
    }

    private func processLocation(_ location: String, currentDepth: Int, maxDepth: Int, isLibraryRootSearch: Bool = false) {
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: location) {
            var localResults: [URL] = []
            var subdirectoriesToSearch: [URL] = []

            for scannedItem in contents {
                let scannedItemURL = URL(fileURLWithPath: location).appendingPathComponent(scannedItem)
                let normalizedItemName: String
                if scannedItemURL.hasDirectoryPath || scannedItemURL.pathExtension.isEmpty {
                    // It's a directory or has no extension - don't remove anything
                    normalizedItemName = scannedItem.pearFormat()
                } else {
                    // It's a file with an extension - remove the extension
                    normalizedItemName = (scannedItem as NSString).deletingPathExtension.pearFormat()
                }
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: scannedItemURL.path, isDirectory: &isDirectory) {
                    if shouldSkipItem(normalizedItemName, at: scannedItemURL) { continue }

                    if specificCondition(normalizedItemName: normalizedItemName, scannedItemURL: scannedItemURL) {
                        // Determine what to add: matched item or its parent (for vendor folders)
                        let itemToAdd: URL

                        // For depth=2 matches in Library root searches, check if parent is a vendor folder
                        if isLibraryRootSearch && currentDepth == 2 {
                            let parentURL = scannedItemURL.deletingLastPathComponent()
                            let parentName = parentURL.lastPathComponent

                            // Add parent directory if it's NOT a standard macOS directory
                            // This captures vendor folders like /Library/Objective-See/ instead of /Library/Objective-See/LuLu/
                            if !Locations.standardLibrarySubdirectories.contains(parentName) {
                                itemToAdd = parentURL
                            } else {
                                itemToAdd = scannedItemURL
                            }
                        } else {
                            itemToAdd = scannedItemURL
                        }

                        localResults.append(itemToAdd)
                    }

                    // If this is a directory and we haven't reached max depth, mark for recursive search
                    if isDirectory.boolValue && currentDepth < maxDepth {
                        subdirectoriesToSearch.append(scannedItemURL)
                    }
                }
            }

            collectionAccessQueue.sync {
                collectionSet.formUnion(localResults)
            }

            // Recursively search subdirectories if we haven't reached max depth
            if currentDepth < maxDepth {
                for subdirectory in subdirectoriesToSearch {
                    processLocation(subdirectory.path, currentDepth: currentDepth + 1, maxDepth: maxDepth, isLibraryRootSearch: isLibraryRootSearch)
                }
            }
        }
    }

    // Asynchronous collection for GUI usage
    private func collectLocations() {
        let dispatchGroup = DispatchGroup()
        for location in self.locations.apps.paths {
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                // Use depth=2 for Library directories to find files in vendor subdirectories
                // Example: /Library/Objective-See/LuLu, ~/Library/Microsoft/Edge
                let isLibRoot = self.isLibraryDirectory(location)
                let maxDepth = isLibRoot ? 2 : 1
                self.processLocation(location, currentDepth: 0, maxDepth: maxDepth, isLibraryRootSearch: isLibRoot)
                dispatchGroup.leave()
            }
        }
        dispatchGroup.wait()
    }

    // Synchronous collection for CLI usage
    private func collectLocationsCLI() {
        for location in self.locations.apps.paths {
            // Use depth=2 for Library directories to find files in vendor subdirectories
            let isLibRoot = isLibraryDirectory(location)
            let maxDepth = isLibRoot ? 2 : 1
            processLocation(location, currentDepth: 0, maxDepth: maxDepth, isLibraryRootSearch: isLibRoot)
        }
    }

    // Helper to determine if a location is a Library directory
    private func isLibraryDirectory(_ location: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return location == "\(home)/Library" || location == "/Library"
    }

    // Skip items based on conditions and membership in collectionSet
    private func shouldSkipItem(_ normalizedItemName: String, at scannedItemURL: URL) -> Bool {
        var containsItem = false
        collectionAccessQueue.sync {
            containsItem = self.collectionSet.contains(scannedItemURL)
        }
        if containsItem {
            return true
        }
        for skipCondition in skipConditions {
            // Check path-based exclusions first
            for skipPath in skipCondition.skipPaths {
                if scannedItemURL.path.hasPrefix(skipPath) {
                    return true
                }
            }

            // Check prefix-based exclusions
            if skipCondition.skipPrefix.contains(where: normalizedItemName.hasPrefix) {
                let isAllowed = skipCondition.allowPrefixes.contains(where: normalizedItemName.hasPrefix)
                if !isAllowed {
                    return true
                }
            }
        }
        return false
    }

    // Check if an item meets specific conditions using cached identifiers
    private func specificCondition(normalizedItemName: String, scannedItemURL: URL) -> Bool {
        let cached = self.cachedIdentifiers

        // Special handling for Steam games: also check Desktop for shortcuts
        if scannedItemURL.path.contains("/Desktop/") && scannedItemURL.pathExtension == "app" {
            let desktopAppName = scannedItemURL.deletingPathExtension().lastPathComponent.pearFormat()
            if desktopAppName == cached.formattedAppName || desktopAppName == cached.appNameLettersOnly {
                return true
            }
        }

        // Special handling for Steam game main folder
        if self.appInfo.steam && scannedItemURL.path.contains("/Library/Application Support/Steam/steamapps/common/") {
            let folderName = scannedItemURL.lastPathComponent.pearFormat()
            // Check if this folder matches the game name
            if folderName == cached.formattedAppName || folderName == cached.appNameLettersOnly {
                return true
            }
        }

        // Special handling for Steam game manifest files
        if self.appInfo.steam && scannedItemURL.path.contains("/Library/Application Support/Steam/steamapps/") &&
           scannedItemURL.lastPathComponent.hasPrefix("appmanifest_") && scannedItemURL.pathExtension == "acf" {

            // Extract the game ID from the filename (e.g., "appmanifest_1289310.acf" -> "1289310")
            let filename = scannedItemURL.lastPathComponent
            if let gameIdFromFile = extractGameId(from: filename) {
                // Get the game ID from the Steam launcher's run.sh file
                if let gameIdFromLauncher = getSteamGameId(from: self.appInfo.path) {
                    return gameIdFromFile == gameIdFromLauncher
                }
            }
        }

        // Check entitlements-based matching (using pre-formatted entitlements)
        // Strict: exact match only, Enhanced/Deep: contains match
        for entitlementFormatted in cached.formattedEntitlements {
            let isMatch = effectiveSensitivityLevel == .strict
                ? normalizedItemName == entitlementFormatted
                : normalizedItemName.contains(entitlementFormatted)

            if isMatch {
                return true
            }
        }

        for condition in conditions {
            if cached.useBundleIdentifier && cached.formattedBundleId.contains(condition.bundle_id) {
                if condition.exclude.contains(where: { normalizedItemName.contains($0) }) {
                    return false
                }
                if condition.include.contains(where: { normalizedItemName.contains($0) }) {
                    return true
                }
            }
        }
        if self.appInfo.webApp {
            return normalizedItemName.contains(cached.formattedBundleId)
        }

        let fullBundleMatch = normalizedItemName.contains(cached.formattedBundleId)
        let sensitivity = effectiveSensitivityLevel == .strict

        // Prevent false matches when cached values are empty strings
        let appNameMatch = !cached.formattedAppName.isEmpty && (sensitivity ? normalizedItemName == cached.formattedAppName : normalizedItemName.contains(cached.formattedAppName))
        let pathNameMatch = !cached.pathComponentName.isEmpty && (sensitivity ? normalizedItemName == cached.pathComponentName : normalizedItemName.contains(cached.pathComponentName))
        let appNameLettersMatch = !cached.appNameLettersOnly.isEmpty && (sensitivity ? normalizedItemName == cached.appNameLettersOnly : normalizedItemName.contains(cached.appNameLettersOnly))

        // Bundle ID component matching (Enhanced/Deep levels only)
        let twoComponentMatch: Bool
        if effectiveSensitivityLevel != .strict {
            twoComponentMatch = normalizedItemName.contains(cached.bundleLastTwoComponents)
        } else {
            twoComponentMatch = false
        }

        // Company name matching (Deep level only)
        let companyMatch: Bool
        if effectiveSensitivityLevel == .deep, let company = cached.formattedCompanyName, !company.isEmpty {
            companyMatch = normalizedItemName.contains(company)
        } else {
            companyMatch = false
        }

        // Team identifier matching (Deep level only)
        let teamIdMatch: Bool
        if effectiveSensitivityLevel == .deep, let teamId = cached.formattedTeamIdentifier, !teamId.isEmpty {
            teamIdMatch = normalizedItemName.contains(teamId)
        } else {
            teamIdMatch = false
        }

        // Base bundle ID matching (for apps with .helper/.agent/etc. suffixes)
        // Matches launch daemons/agents that use base bundle ID without suffix
        let baseBundleIdMatch: Bool
        if let baseBundleId = cached.formattedBaseBundleId, !baseBundleId.isEmpty {
            baseBundleIdMatch = normalizedItemName.contains(baseBundleId)
        } else {
            baseBundleIdMatch = false
        }

        // Stripped app name matching (Enhanced/Deep only)
        // Matches files with version-stripped names: "Bartender 6" → also matches "bartender" files
        let strippedAppNameMatch: Bool
        if effectiveSensitivityLevel != .strict, let stripped = cached.formattedAppNameStripped, !stripped.isEmpty {
            strippedAppNameMatch = normalizedItemName.contains(stripped)
        } else {
            strippedAppNameMatch = false
        }

        return (cached.useBundleIdentifier && fullBundleMatch) || (appNameMatch || pathNameMatch || appNameLettersMatch) || twoComponentMatch || companyMatch || teamIdMatch || baseBundleIdMatch || strippedAppNameMatch
    }
    
    // Helper function to extract game ID from manifest filename
    private func extractGameId(from filename: String) -> String? {
        // Extract from "appmanifest_1289310.acf" -> "1289310"
        let components = filename.components(separatedBy: "_")
        if components.count >= 2 {
            let gameIdWithExtension = components[1]
            return gameIdWithExtension.components(separatedBy: ".").first
        }
        return nil
    }
    
    // Helper function to get Steam game ID from the launcher's run.sh file
    private func getSteamGameId(from appPath: URL) -> String? {
        let runShPath = appPath.appendingPathComponent("Contents/MacOS/run.sh")
        
        guard FileManager.default.fileExists(atPath: runShPath.path) else {
            return nil
        }
        
        do {
            let content = try String(contentsOf: runShPath, encoding: .utf8)
            // Look for "steam://run/" pattern and extract the number after it
            if let range = content.range(of: "steam://run/") {
                let afterRun = String(content[range.upperBound...])
                // Extract the number (game ID) which should be at the beginning
                let gameId = afterRun.components(separatedBy: CharacterSet.decimalDigits.inverted).first
                return gameId?.isEmpty == false ? gameId : nil
            }
        } catch {
            printOS("Error reading run.sh file: \(error)")
        }
        
        return nil
    }

    // Check for associated zombie files
    private func fetchAssociatedZombieFiles() -> [URL] {
        let storedFiles = ZombieFileStorage.shared.getAssociatedFiles(for: self.appInfo.path)

        // Only return files that actually exist on disk
        // Keep associations in storage so they can be restored if file comes back
        return storedFiles.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    // Helper method to check bundle identifier validity - now static
    private static func isValidBundleIdentifier(_ bundleIdentifier: String) -> Bool {
        let components = bundleIdentifier.components(separatedBy: ".")
        if components.count == 1 {
            return bundleIdentifier.count >= 5
        }
        return true
    }

    // Check spotlight index for leftovers missed by manual search
    private func spotlightSupplementalPaths() -> [URL] {
        // Spotlight enabled for all levels with sensitivity-appropriate matching
        // Strict: Exact matches only (via ==[cd] predicate and post-filter)
        // Enhanced/Deep: Contains matches (via CONTAINS[cd] predicate)
        updateOnMain {
            self.appState?.progressStep = 1
        }
        var results: [URL] = []
        let query = NSMetadataQuery()

        let appName = self.appInfo.appName
        let bundleID = self.appInfo.bundleIdentifier

        // Build predicate based on sensitivity level
        switch self.effectiveSensitivityLevel {
        case .strict:
            // Strict: Only exact filename matches
            query.predicate = NSPredicate(format:
                "kMDItemDisplayName ==[cd] %@ OR kMDItemDisplayName ==[cd] %@",
                appName, bundleID)

        case .enhanced:
            // Enhanced: Partial matching in name and path
            query.predicate = NSPredicate(format:
                "kMDItemDisplayName CONTAINS[cd] %@ OR kMDItemPath CONTAINS[cd] %@",
                appName, bundleID)

        case .deep:
            // Deep: Fuzzy search with metadata and AND logic for multi-word names
            var subpredicates: [NSPredicate] = [
                // DisplayName: appName OR bundleID
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@", appName),
                    NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@", bundleID)
                ]),
                // Path: appName OR bundleID
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "kMDItemPath CONTAINS[cd] %@", appName),
                    NSPredicate(format: "kMDItemPath CONTAINS[cd] %@", bundleID)
                ]),
                // Comment: appName OR bundleID
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "kMDItemComment CONTAINS[cd] %@", appName),
                    NSPredicate(format: "kMDItemComment CONTAINS[cd] %@", bundleID)
                ]),
                // Creator: appName OR bundleID
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "kMDItemCreator ==[cd] %@", appName),
                    NSPredicate(format: "kMDItemCreator ==[cd] %@", bundleID)
                ]),
                // Copyright: appName OR bundleID (often contains developer/company info)
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "kMDItemCopyright CONTAINS[cd] %@", appName),
                    NSPredicate(format: "kMDItemCopyright CONTAINS[cd] %@", bundleID)
                ]),
                // EncodingApplications: appName only (array of apps that processed the file)
                NSPredicate(format: "kMDItemEncodingApplications CONTAINS[cd] %@", appName)
            ]

            // TextContent: appName OR bundleID (optional, controlled by user setting)
            if searchTextContent {
                subpredicates.append(
                    NSCompoundPredicate(orPredicateWithSubpredicates: [
                        NSPredicate(format: "kMDItemTextContent CONTAINS[cd] %@", appName),
                        NSPredicate(format: "kMDItemTextContent CONTAINS[cd] %@", bundleID)
                    ])
                )
            }

            // Add wildcard predicate: ALL name parts must be present (AND logic)
            let nameParts = appName.split(separator: " ")
            if nameParts.count > 1 {
                // For multi-word names: each part must appear in display name OR path
                let partPredicates = nameParts.map { part in
                    NSCompoundPredicate(orPredicateWithSubpredicates: [
                        NSPredicate(format: "kMDItemDisplayName LIKE[cd] %@", "*\(part)*"),
                        NSPredicate(format: "kMDItemPath LIKE[cd] %@", "*\(part)*")
                    ])
                }
                // All parts must be present (AND)
                let allPartsPresent = NSCompoundPredicate(andPredicateWithSubpredicates: partPredicates)
                subpredicates.append(allPartsPresent)
            } else {
                // Single word: just add LIKE for that word
                subpredicates.append(NSPredicate(format: "kMDItemDisplayName LIKE[cd] %@", "*\(appName)*"))
            }

            // Combine all conditions with OR (any match wins)
            query.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
        }

        query.searchScopes = [NSMetadataQueryUserHomeScope]

        let currentRunLoop = CFRunLoopGetCurrent()

        let finishedNotification = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: query, queue: nil) { _ in
            query.disableUpdates()
            query.stop()
            results = query.results.compactMap {
                ($0 as? NSMetadataItem)?.value(forAttribute: kMDItemPath as String)
            }.compactMap {
                URL(fileURLWithPath: $0 as! String)
            }

            // Post-filter: Only for Strict level
            if self.effectiveSensitivityLevel == .strict {
                let nameFormatted = appName.pearFormat()
                let bundleFormatted = bundleID.pearFormat()
                results = results.filter { url in
                    let pathFormatted = url.lastPathComponent.pearFormat()
                    return pathFormatted == nameFormatted || pathFormatted == bundleFormatted
                }
            }

            CFRunLoopStop(currentRunLoop)
        }

        query.start()

        // Timeout after 5 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            CFRunLoopStop(currentRunLoop)
        }

        CFRunLoopRun()

        // Limit results to prevent excessive post-processing delays
        if results.count > 500 {
            results = Array(results.prefix(500))
        }

        NotificationCenter.default.removeObserver(finishedNotification)
        return results
    }

    // Finalize the collection for GUI usage
    private func finalizeCollection() {
        DispatchQueue.global(qos: .userInitiated).async {
            let outliers = self.handleOutliers()
            let outliersEx = self.handleOutliers(include: false)
            var tempCollection: [URL] = []
            self.collectionAccessQueue.sync {
                tempCollection = Array(self.collectionSet)
            }

            Task { @MainActor in
                GlobalConsoleManager.shared.appendOutput("Found \(tempCollection.count) files from manual search\n", source: CurrentPage.applications.title)
            }

            tempCollection.append(contentsOf: self.containerCollection)
            tempCollection.append(contentsOf: outliers)

            // Insert spotlight results before sorting and filtering
            Task { @MainActor in
                GlobalConsoleManager.shared.appendOutput("Running Spotlight supplemental search...\n", source: CurrentPage.applications.title)
            }
            let spotlightResults = self.spotlightSupplementalPaths()
            let spotlightOnly = spotlightResults.filter { !self.collectionSet.contains($0) }

            if spotlightOnly.count > 0 {
                Task { @MainActor in
                    GlobalConsoleManager.shared.appendOutput("Spotlight found \(spotlightOnly.count) additional files\n", source: CurrentPage.applications.title)
                }
            }

            tempCollection.append(contentsOf: spotlightOnly)

            let excludePaths = outliersEx.map { $0.path }
            tempCollection.removeAll { url in
                excludePaths.contains(url.path)
            }

            // Apply app exclusion filter to ALL discovered files (from all code paths)
            tempCollection.removeAll { fileURL in
                let normalizedPath = fileURL.standardizedFileURL.path.pearFormat()
                return self.formattedAppExclusionList.contains(normalizedPath) ||
                self.formattedAppExclusionList.contains(where: { normalizedPath.contains($0) })
            }

            let sortedCollection = tempCollection.map { $0.standardizedFileURL }.sorted(by: { $0.path < $1.path })
            var filteredCollection: [URL] = []
            for url in sortedCollection {
                // Remove any existing child paths of the current URL
                filteredCollection.removeAll { $0.path.hasPrefix(url.path + "/") }

                // Only add if it's not already a subpath of an existing item
                if !filteredCollection.contains(where: { url.path.hasPrefix($0.path + "/") }) {
                    filteredCollection.append(url)
                }
            }

            Task { @MainActor in
                GlobalConsoleManager.shared.appendOutput("Calculating file sizes for \(filteredCollection.count) items...\n", source: CurrentPage.applications.title)
            }

            self.handlePostProcessing(sortedCollection: filteredCollection)
        }
    }

    // Finalize the collection for CLI usage
    private func finalizeCollectionCLI() -> Set<URL> {
        let outliers = handleOutliers()
        let outliersEx = handleOutliers(include: false)
        var tempCollection: [URL] = []
        self.collectionAccessQueue.sync {
            tempCollection = Array(self.collectionSet)
        }
        tempCollection.append(contentsOf: self.containerCollection)
        tempCollection.append(contentsOf: outliers)
        // Insert spotlight results before sorting and filtering
        let spotlightResults = self.spotlightSupplementalPaths()
        let spotlightOnly = spotlightResults.filter { !self.collectionSet.contains($0) }
        //        printOS("Spotlight index found: \(spotlightOnly.count)")
        tempCollection.append(contentsOf: spotlightOnly)

        let excludePaths = outliersEx.map { $0.path }
        tempCollection.removeAll { url in
            excludePaths.contains(url.path)
        }

        // Apply app exclusion filter to ALL discovered files (from all code paths)
        tempCollection.removeAll { fileURL in
            let normalizedPath = fileURL.standardizedFileURL.path.pearFormat()
            return formattedAppExclusionList.contains(normalizedPath) ||
                   formattedAppExclusionList.contains(where: { normalizedPath.contains($0) })
        }

        let sortedCollection = tempCollection.map { $0.standardizedFileURL }.sorted(by: { $0.path < $1.path })
        var filteredCollection: [URL] = []
        var previousUrl: URL?
        for url in sortedCollection {
            if let previousUrl = previousUrl, url.path.hasPrefix(previousUrl.path + "/") {
                continue
            }
            filteredCollection.append(url)
            previousUrl = url
        }
        if filteredCollection.count == 1, let firstURL = filteredCollection.first, firstURL.path.contains(".Trash") {
            filteredCollection.removeAll()
        }
        return Set(filteredCollection)
    }

    // Handle outlier paths based on conditions
    private func handleOutliers(include: Bool = true) -> [URL] {
        var outliers: [URL] = []
        let bundleIdentifier = self.appInfo.bundleIdentifier.pearFormat()
        let matchingConditions = conditions.filter { condition in
            bundleIdentifier.contains(condition.bundle_id)
        }
        for condition in matchingConditions {
            if include {
                if let forceIncludes = condition.includeForce {
                    for path in forceIncludes {
                        outliers.append(path)
                    }
                }
            } else {
                if let excludeForce = condition.excludeForce {
                    for path in excludeForce {
                        outliers.append(path)
                    }
                }
            }
        }
        return outliers
    }

    // Post-processing: calculate file details, update state, and call completion
    private func handlePostProcessing(sortedCollection: [URL]) {
        // Fetch associated zombie files and add them to the collection
        var tempCollection = sortedCollection
        let associatedFiles = fetchAssociatedZombieFiles()
        for file in associatedFiles {
            if !tempCollection.contains(file) {
                tempCollection.append(file) // Now it's properly included
            }
        }

        var fileSize: [URL: Int64] = [:]
        var fileIcon: [URL: NSImage?] = [:]
        let chunks = createOptimalChunks(from: tempCollection)
        let queue = DispatchQueue(label: "size-calculation", qos: .userInitiated, attributes: .concurrent)
        let group = DispatchGroup()

        for chunk in chunks {
            group.enter()
            queue.async {
                var localFileSize: [URL: Int64] = [:]
                var localFileIcon: [URL: NSImage?] = [:]

                for path in chunk {
                    let size = spotlightSizeForURL(path)
                    localFileSize[path] = size
                    localFileIcon[path] = self.getSmartIcon(for: path)
                }

                // Merge results safely
                DispatchQueue.main.sync {
                    fileSize.merge(localFileSize) { $1 }
                    fileIcon.merge(localFileIcon) { $1 }
                }
                group.leave()
            }
        }
        group.wait()
        let arch = checkAppBundleArchitecture(at: self.appInfo.path.path)
        var updatedCollection = tempCollection
        if updatedCollection.count == 1, let firstURL = updatedCollection.first, firstURL.path.contains(".Trash") {
            updatedCollection.removeAll()
        }

        DispatchQueue.main.async {
            self.appInfo.fileSize = fileSize
            self.appInfo.fileIcon = fileIcon
            self.appInfo.arch = arch
            self.appState?.appInfo = self.appInfo
            if !self.undo {
                self.appState?.selectedItems = Set(updatedCollection)
            }
            self.appState?.progressStep = 0
            self.appState?.showProgress = false

            let totalSize = fileSize.values.reduce(0, +)
            let sizeString = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
            GlobalConsoleManager.shared.appendOutput("✓ Found \(updatedCollection.count) items (\(sizeString))\n", source: CurrentPage.applications.title)

            self.completion?()
        }
    }

    // Public method for GUI
    func findPaths() {
        Task(priority: .background) {
            await GlobalConsoleManager.shared.appendOutput("Searching for files related to \(self.appInfo.appName)...\n", source: CurrentPage.applications.title)

            if self.appInfo.webApp {
                await GlobalConsoleManager.shared.appendOutput("Detected web app, scanning containers...\n", source: CurrentPage.applications.title)
                self.containerCollection = self.getAllContainers(bundleURL: self.appInfo.path)
                self.initialURLProcessing()
                self.finalizeCollection()
            } else {
                await GlobalConsoleManager.shared.appendOutput("Scanning \(self.locations.apps.paths.count) system locations...\n", source: CurrentPage.applications.title)
                self.containerCollection = self.getAllContainers(bundleURL: self.appInfo.path)
                self.initialURLProcessing()
                self.collectLocations()
                self.finalizeCollection()
            }
        }
    }

    // Public method for CLI
    func findPathsCLI() -> Set<URL> {
        if self.appInfo.webApp {
            self.containerCollection = self.getAllContainers(bundleURL: self.appInfo.path)
            self.initialURLProcessing()
            return finalizeCollectionCLI()
        } else {
            self.containerCollection = self.getAllContainers(bundleURL: self.appInfo.path)
            self.initialURLProcessing()
            self.collectLocationsCLI()
            return finalizeCollectionCLI()
        }
    }

    // Custom icon function that handles .app folders intelligently
    private func getSmartIcon(for path: URL) -> NSImage? {
        // For wrapped apps, check if this is the container path
        if self.appInfo.wrapped {
            // Get container path from inner app path
            let containerPath = self.appInfo.path
                .deletingLastPathComponent()  // Remove ActualApp.app
                .deletingLastPathComponent()  // Remove Wrapper -> get Container.app

            // If the current path matches the container, use the app's icon
            if path.absoluteString == containerPath.absoluteString {
                return self.appInfo.appIcon
            }
        }

        // Regular logic for all other files
        if path.pathExtension == "app" {
            let contentsPath = path.appendingPathComponent("Contents")
            var isDirectory: ObjCBool = false

            if FileManager.default.fileExists(atPath: contentsPath.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                // It's a real app bundle, get the app icon
                return getIconForFileOrFolderNS(atPath: path)
            } else {
                // It's just a folder that ends with .app, get the folder icon
                return NSWorkspace.shared.icon(for: .folder)
            }
        } else {
            // For all other files/folders, use the standard function
            return getIconForFileOrFolderNS(atPath: path)
        }
    }
}

// Get size using Spotlight metadata, fallback to manual calculation if needed
private func spotlightSizeForURL(_ url: URL) -> Int64 {
    // Check if this is a directory (not a bundle like .app)
    var isDirectory: ObjCBool = false
    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

    // For plain directories, Spotlight metadata is unreliable (reports wrong size)
    // Skip to manual calculation for directories (Containers, regular folders, etc.)
    if isDirectory.boolValue {
        return totalSizeOnDisk(for: url)
    }

    // For files and bundles (.app, .framework), use Spotlight metadata
    let metadataItem = NSMetadataItem(url: url)
    if let logical = metadataItem?.value(forAttribute: "kMDItemLogicalSize") as? Int64 {
        return logical
    }

    // Fallback to manual calculation if Spotlight has no data
    return totalSizeOnDisk(for: url)
}
