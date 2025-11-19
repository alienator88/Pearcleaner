//
//  Logic.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import AlinFoundation
import Foundation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

// MARK: - String Sorting Extension

extension String {
    /// Returns a normalized sort key that handles Chinese characters via pinyin transformation
    /// Only applies expensive transformation when CJK characters are detected
    var sortKey: String {
        // Check if string contains CJK characters
        let containsCJK = self.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||  // CJK Unified Ideographs
            (0x3400...0x4DBF).contains(scalar.value) ||  // CJK Extension A
            (0x20000...0x2A6DF).contains(scalar.value)   // CJK Extension B
        }

        if containsCJK {
            // Apply pinyin transformation for Chinese characters
            let latin = self.applyingTransform(.toLatin, reverse: false) ?? self
            let noTone = latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin
            return noTone.lowercased()
        } else {
            // Fast path for non-CJK strings
            return self.lowercased()
        }
    }
}

/// Creates optimally-sized chunks for parallel processing based on system capabilities
/// - Parameters:
///   - array: The array to chunk
///   - minChunkSize: Minimum size per chunk (default: 10)
///   - maxChunkSize: Maximum size per chunk (default: 50)
/// - Returns: Array of chunks optimized for the current system
func createOptimalChunks<T>(from array: [T], minChunkSize: Int = 10, maxChunkSize: Int = 50) -> [[T]] {
    let coreCount = ProcessInfo.processInfo.activeProcessorCount
    let chunkSize = min(max(array.count / coreCount, minChunkSize), maxChunkSize)
    return array.chunked(into: chunkSize)
}

/// Flush bundle caches for the given app paths to ensure fresh version info
/// - Parameter apps: Array of AppInfo objects whose bundles should have caches flushed
/// - Discussion: (NS)Bundle caches Info.plist data. After app updates, old version info may be
///               returned. Flushing the cache using private API ensures current data is read.
func flushBundleCaches(for apps: [AppInfo]) {
    for app in apps {
        autoreleasepool {
            guard let bundle = Bundle(url: app.path) else { return }
            if let bundleRef = CFBundleCreate(nil, bundle.bundleURL as CFURL) {
                _CFBundleFlushBundleCaches(bundleRef)
            }
        }
    }
}

/// Flush bundle cache for a specific path (without requiring AppInfo object)
/// Used when loading newly installed apps where bundle cache might be stale
func flushBundleCache(for path: URL) {
    autoreleasepool {
        if let bundleRef = CFBundleCreate(nil, path as CFURL) {
            _CFBundleFlushBundleCaches(bundleRef)
        }
    }
}

/// Load apps from specified folder paths and update AppState
/// This is the main entry point for loading/refreshing apps
/// Apps stream into AppState.shared.sortedApps progressively as chunks complete
/// - Parameter useStreaming: If true, uses two-phase streaming (fast initial load). If false, loads full AppInfo immediately.
func loadApps(folderPaths: [String], useStreaming: Bool = false) {
    // Clear array immediately before loading
    Task { @MainActor in
        AppState.shared.sortedApps = []
    }

    DispatchQueue.global(qos: .userInitiated).async {
        // getSortedApps now streams results to AppState.shared.sortedApps (or returns full array if not streaming)
        let apps = getSortedApps(paths: folderPaths, useStreaming: useStreaming)

        // If not streaming, update AppState with sorted results
        if !useStreaming {
            Task { @MainActor in
                AppState.shared.sortedApps = apps
            }
        }

        Task { @MainActor in
            AppState.shared.restoreZombieAssociations()
        }
    }
}

// Awaitable version that waits for apps to finish loading
// Note: With streaming, this still clears and starts loading but doesn't wait for completion
func loadAppsAsync(folderPaths: [String], useStreaming: Bool = false) async {
    // Clear array immediately before loading
    await MainActor.run {
        AppState.shared.sortedApps = []
    }

    // Load apps on background thread (streams results or returns full array)
    let apps = await Task.detached(priority: .userInitiated) {
        getSortedApps(paths: folderPaths, useStreaming: useStreaming)
    }.value

    // If not streaming, update AppState with sorted results
    if !useStreaming {
        await MainActor.run {
            AppState.shared.sortedApps = apps
        }
    }

    // Update AppState on MainActor
    await MainActor.run {
        AppState.shared.restoreZombieAssociations()
    }
}


// Get all apps from /Applications and ~/Applications
/// - Parameter useStreaming: If true, uses two-phase streaming (AppInfoMini → full AppInfo). If false, loads full AppInfo immediately.
/// - Returns: Array of AppInfo. Empty if streaming (results delivered via AppState updates), populated if not streaming.
func getSortedApps(paths: [String], useStreaming: Bool = false) -> [AppInfo] {
    let fileManager = FileManager.default
    var apps: [URL] = []

    func collectAppPaths(at directoryPath: String) {
        let queue = DispatchQueue(label: "com.pearcleaner.filetree", qos: .userInitiated, attributes: .concurrent)
        let group = DispatchGroup()
        let appsQueue = DispatchQueue(label: "com.pearcleaner.apps.collection")

        func collectAppPathsParallel(at directoryPath: String) {
            do {
                let appURLs = try fileManager.contentsOfDirectory(
                    at: URL(fileURLWithPath: directoryPath),
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                    options: [])

                var foundApps: [URL] = []
                var subdirectories: [URL] = []

                // Separate apps from subdirectories in one pass
                for appURL in appURLs {
                    let resourceValues = try? appURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    let isDirectory = resourceValues?.isDirectory ?? false
                    let isSymlink = resourceValues?.isSymbolicLink ?? false

                    if appURL.pathExtension == "app" && !isRestricted(atPath: appURL) && !isSymlink {
                        foundApps.append(appURL)
                    } else if isDirectory && !isSymlink {
                        subdirectories.append(appURL)
                    }
                }

                // Add found apps to the main collection
                if !foundApps.isEmpty {
                    appsQueue.sync {
                        apps.append(contentsOf: foundApps)
                    }
                }

                // Process subdirectories in parallel
                for subdirectory in subdirectories {
                    group.enter()
                    queue.async {
                        collectAppPathsParallel(at: subdirectory.path)
                        group.leave()
                    }
                }

            } catch {
                printOS("Error: \(error)")
            }
        }

        // Start the parallel collection
        group.enter()
        queue.async {
            collectAppPathsParallel(at: directoryPath)
            group.leave()
        }

        group.wait()
    }

    // Collect system applications
    paths.forEach { path in
        if fileManager.fileExists(atPath: path) {
            collectAppPaths(at: path)
        }
    }

    // === DEBUG: Duplicate AppCleaner for testing high app counts ===
#if DEBUG
//    if let appCleanerURL = apps.first(where: { $0.lastPathComponent == "AppCleaner.app" }) {
//        print("🧪 TEST MODE: Duplicating AppCleaner 150 times for stress testing")
//        // Simply add the same URL 150 times - they'll get unique UUIDs but share metadata
//        for _ in 1...150 {
//            apps.append(appCleanerURL)
//        }
//        print("🧪 Total apps after duplication: \(apps.count)")
//    }
#endif
    // === END DEBUG ===

    // Convert collected paths to string format for metadata query
    let combinedPaths = apps.map { $0.path }

    // Get metadata for all collected app paths
    var metadataDictionary: [String: [String: Any]] = [:]

    if let metadata = getMDLSMetadata(for: combinedPaths) {
        metadataDictionary = metadata
    }

    if useStreaming {
        // === STREAMING MODE: Two-phase streaming for fast initial load ===
        // === PHASE 1: Stream AppInfoMini as chunks complete (progressive loading) ===
        Task.detached(priority: .userInitiated) {
            let chunks = createOptimalChunks(from: apps, minChunkSize: 10, maxChunkSize: 40)
            let queue = DispatchQueue(label: "com.pearcleaner.appinfo.mini", qos: .userInitiated, attributes: .concurrent)
            let group = DispatchGroup()

            var allMiniInfos: [AppInfoMini] = []
            let resultsQueue = DispatchQueue(label: "com.pearcleaner.appinfo.mini.results")

            for chunk in chunks {
                group.enter()
                queue.async {
                    autoreleasepool {
                        let chunkMiniInfos: [AppInfoMini] = chunk.compactMap { appURL in
                            autoreleasepool {
                                let appPath = appURL.path

                                // Use mini version for fast initial load
                                if let appMetadata = metadataDictionary[appPath] {
                                    return MetadataAppInfoFetcher.getAppInfoMini(fromMetadata: appMetadata, atPath: appURL)
                                } else {
                                    // Fallback to full version if no metadata
                                    return AppInfoFetcher.getAppInfo(atPath: appURL)?.toMini()
                                }
                            }
                        }

                        resultsQueue.sync {
                            allMiniInfos.append(contentsOf: chunkMiniInfos)
                        }

                        // Stream to UI as each chunk completes
                        let currentBatch = chunkMiniInfos.map { $0.toAppInfo() }
                        Task { @MainActor in
                            AppState.shared.sortedApps.append(contentsOf: currentBatch)
                            // Sort after each addition to maintain alphabetical order
                            AppState.shared.sortedApps.sort { $0.appName.sortKey < $1.appName.sortKey }
                        }
                    }
                    group.leave()
                }
            }

            // Wait for all chunks to complete before launching Phase 2
            group.notify(queue: DispatchQueue.global(qos: .utility)) {
                // === PHASE 2: Background upgrade to full AppInfo (expensive operations) ===
                for mini in allMiniInfos {
                    autoreleasepool {
                        // Upgrade mini to full AppInfo with all expensive properties
                        let fullAppInfo = MetadataAppInfoFetcher.upgradeToFullAppInfo(mini: mini)

                        // Update sorted array on main thread using path as stable identifier
                        Task { @MainActor in
                            if let targetIndex = AppState.shared.sortedApps.firstIndex(where: { $0.path == mini.path }) {
                                AppState.shared.sortedApps[targetIndex] = fullAppInfo
                            }
                        }
                    }
                }
            }
        }

        // Return empty array - results will stream in via AppState updates
        return []
    } else {
        // === FULL MODE: Load complete AppInfo immediately (for Updater, post-uninstall, etc.) ===
        let chunks = createOptimalChunks(from: apps, minChunkSize: 10, maxChunkSize: 40)
        let queue = DispatchQueue(label: "com.pearcleaner.appinfo.full", qos: .userInitiated, attributes: .concurrent)
        let group = DispatchGroup()

        var allFullInfos: [AppInfo] = []
        let resultsQueue = DispatchQueue(label: "com.pearcleaner.appinfo.full.results")

        for chunk in chunks {
            group.enter()
            queue.async {
                autoreleasepool {
                    let chunkFullInfos: [AppInfo] = chunk.compactMap { appURL in
                        autoreleasepool {
                            let appPath = appURL.path

                            // Load full AppInfo with all expensive properties
                            if let appMetadata = metadataDictionary[appPath],
                               let mini = MetadataAppInfoFetcher.getAppInfoMini(fromMetadata: appMetadata, atPath: appURL) {
                                return MetadataAppInfoFetcher.upgradeToFullAppInfo(mini: mini)
                            } else {
                                // Fallback to direct full version
                                return AppInfoFetcher.getAppInfo(atPath: appURL)
                            }
                        }
                    }

                    resultsQueue.sync {
                        allFullInfos.append(contentsOf: chunkFullInfos)
                    }
                }
                group.leave()
            }
        }

        group.wait()

        // Sort alphabetically and return
        return allFullInfos.sorted { $0.appName.sortKey < $1.appName.sortKey }
    }
}

// Get directory path for darwin cache and temp directories
func darwinCT() -> (String, String) {
    let command = "echo $(getconf DARWIN_USER_CACHE_DIR) $(getconf DARWIN_USER_TEMP_DIR)"
//    let command = "echo $(realpath $(getconf DARWIN_USER_CACHE_DIR)) $(realpath $(getconf DARWIN_USER_TEMP_DIR))"
    let process = Process()
    process.launchPath = "/bin/bash"
    process.arguments = ["-c", command]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
            in: .whitespacesAndNewlines)
    else {
        printOS("Could not get DARWIN_USER_CACHE_DIR or DARWIN_USER_TEMP_DIR")
        return ("", "")
    }

    let paths = output.split(separator: " ").map(String.init)
    guard paths.count >= 2 else {
        printOS("Could not parse DARWIN_USER_CACHE_DIR or DARWIN_USER_TEMP_DIR")
        return ("", "")
    }
    return (
        paths[0].trimmingCharacters(in: .whitespaces), paths[1].trimmingCharacters(in: .whitespaces)
    )
}

func listAppSupportDirectories() -> [String] {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser
    let appSupportLocation = home.appendingPathComponent("Library/Application Support").path
    let exclusions = Set([
        "MobileSync", ".DS_Store", "Xcode", "SyncServices", "networkserviceproxy", "DiskImages",
        "CallHistoryTransactions", "App Store", "CloudDocs", "icdd", "iCloud", "Instruments",
        "AddressBook", "FaceTime", "AskPermission", "CallHistoryDB",
    ])
    let exclusionRegex = try! NSRegularExpression(pattern: "\\bcom\\.apple\\b", options: [])

    do {
        let directoryContents = try fileManager.contentsOfDirectory(atPath: appSupportLocation)

        return directoryContents.compactMap { directoryName in
            let fullPath = appSupportLocation.appending("/\(directoryName)")
            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else {
                return nil
            }

            // Check for exclusions using regex and provided list
            let excludeByRegex =
            exclusionRegex.firstMatch(
                in: directoryName, options: [],
                range: NSRange(location: 0, length: directoryName.utf16.count)) != nil
            if exclusions.contains(directoryName) || excludeByRegex {
                return nil
            }
            return directoryName
        }
    } catch {
        printOS("Error listing AppSupport directories: \(error.localizedDescription)")
        return []
    }
}

// Load app paths on launch
func reversePreloader(
    allApps: [AppInfo], appState: AppState, locations: Locations, fsm: FolderSettingsManager,
    completion: @escaping () -> Void = {}
) {
    @AppStorage("settings.interface.animationEnabled") var animationEnabled: Bool = true

    updateOnMain {
        appState.leftoverProgress.0 = String(localized: "Finding orphaned files, please wait...")
    }
    ReversePathsSearcher(appState: appState, locations: locations, fsm: fsm, sortedApps: allApps)
        .reversePathsSearch {
            updateOnMain {
                //            printOS("Reverse search processed successfully")
                appState.showProgress = false
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                    appState.leftoverProgress.1 = 0.0
                }
                appState.leftoverProgress.0 = String(
                    localized: "Reverse search completed successfully")
            }
            completion()
        }
}

// Load item in Files view
func showAppInFiles(
    appInfo: AppInfo, appState: AppState, locations: Locations) {
    @AppStorage("settings.interface.animationEnabled") var animationEnabled: Bool = true
    @AppStorage("settings.general.searchSensitivity") var globalSensitivityLevel: SearchSensitivityLevel = .strict

    updateOnMain {
        appState.showProgress = true
        appState.appInfo = .empty
        appState.selectedItems = []

        // Initialize per-app sensitivity from global setting if not already set
        if appState.perAppSensitivity[appInfo.path.path] == nil {
            appState.perAppSensitivity[appInfo.path.path] = globalSensitivityLevel
        }

        // Initialize the path finder and execute its search.
        AppPathFinder(appInfo: appInfo, locations: locations, appState: appState, sensitivityOverride: appState.perAppSensitivity[appInfo.path.path]).findPaths()

        appState.appInfo = appInfo

        appState.currentView = .files
    }
}

// Move files to trash using Authorization Services so it asks for user password if needed
func moveFilesToTrash(appState: AppState, at fileURLs: [URL]) -> Bool {

    let validFileURLs = filterValidFiles(fileURLs: fileURLs)  // Filter invalid files

    // Check if there are any valid files to delete
    guard !validFileURLs.isEmpty else {
        printOS("No valid files to move to Trash.")
        return false
    }

    let result = FileManagerUndo.shared.deleteFiles(at: validFileURLs)

    return result
}

func moveFilesToTrashCLI(at fileURLs: [URL]) -> Bool {

    let validFileURLs = filterValidFiles(fileURLs: fileURLs)  // Filter invalid files

    // Check if there are any valid files to delete
    guard !validFileURLs.isEmpty else {
        printOS("No valid files to move to Trash.")
        return false
    }

    let result = FileManagerUndo.shared.deleteFiles(at: validFileURLs, isCLI: true)

    return result
}

func filterValidFiles(fileURLs: [URL]) -> [URL] {
    let fileManager = FileManager.default
    return fileURLs.filter { url in

        // Check if file or folder exists
        guard fileManager.fileExists(atPath: url.path) else {
            printOS("Skipping \(url.path): File or folder does not exist.")
            return false
        }

        // Unlock the file or folder if it is locked
        if url.isFileLocked {
            do {
                try removeImmutableAttribute(from: url)
                printOS("Unlocked \(url.path).")
            } catch {
                printOS("Skipping \(url.path): Failed to unlock file or folder (\(error)).")
                return false
            }
        }

        return true
    }
}

extension URL {
    var isFileLocked: Bool {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: self.path)
            if let isLocked = fileAttributes[.immutable] as? Bool {
                return isLocked
            }
        } catch {
            printOS("Error checking lock status for \(self.path): \(error)")
        }
        return false
    }
}

func removeImmutableAttribute(from url: URL) throws {
    let attributes = [FileAttributeKey.immutable: false]
    try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
}

// Undo trash action
func undoTrash() -> Bool {
    // Check if an undo action is available
    if FileManagerUndo.shared.undoManager.canUndo {
        FileManagerUndo.shared.undoManager.undo()
        playTrashSound(undo: true)
        return true
    } else {
        printOS("Undo Trash Error: No undo action available.")
        return false
    }
}

// Reload apps list
func reloadAppsList(
    appState: AppState, fsm: FolderSettingsManager, delay: Double = 0.0,
    completion: @escaping () -> Void = {}
) {
    updateOnBackground(after: delay) {
        // Clear array before reload
        updateOnMain {
            appState.sortedApps = []
        }

        // Use non-streaming mode for reloads (needs full AppInfo immediately)
        let apps = getSortedApps(paths: fsm.folderPaths, useStreaming: false)

        // Update appState with sorted results
        updateOnMain {
            appState.sortedApps = apps
            completion()
        }
    }
}

// Process CLI // ========================================================================================================

func handleLaunchMode() {
    var arguments = CommandLine.arguments
    // Filter out arguments that break CLI commands on startup
    arguments = arguments.filter {
        !["-NSDocumentRevisionsDebugMode", "YES", "-AppleTextDirection", "NO"].contains($0)
    }

    if let langIndex = arguments.firstIndex(of: "-AppleLanguages"), langIndex + 1 < arguments.count {
        arguments.remove(at: langIndex)
        arguments.remove(at: langIndex)
    }

    let termType = ProcessInfo.processInfo.environment["TERM"]
    let isRunningInTerminal = termType != nil && termType != "dumb"

    // Check if any CLI command arguments are present (even if not in terminal)
    // This handles cases like SUDO_ASKPASS where the app is launched without a terminal
    let cliCommands = ["uninstall", "list", "search", "help", "ask-password"]
    let hasCLICommand = arguments.dropFirst().contains { arg in
        cliCommands.contains(arg) || arg.hasPrefix("--")
    }

    if isRunningInTerminal || hasCLICommand {
        let locations = Locations()
        let fsm = FolderSettingsManager()
        PearCLI.setupDependencies(locations: locations, fsm: fsm)
        do {
            // Drop the program name as to not interfere with argument parsing
            let args = Array(arguments.dropFirst())
            var command = try PearCLI.parseAsRoot(args)

            // Run the command if no errors in parsing were caught
            try command.run()
        } catch {
            PearCLI.exit(withError: error)  // Cli exit
        }
    }

}

// MARK: - Translation Pruning

/// Information about a language translation in an app bundle
struct LanguageInfo: Identifiable, Hashable {
    let id = UUID()
    let code: String                // e.g., "en", "es", "en-GB"
    let displayName: String         // Localized language name
    let isPreferred: Bool           // Is in user's macOS preferred languages
    let fileCount: Int              // Number of files in .lproj folder
    let lprojPaths: [URL]           // All .lproj folder paths for this language
}

/// Find all available language translations in an app bundle
/// - Parameter appBundlePath: Path to .app bundle
/// - Returns: Array of LanguageInfo for all languages found (excludes Base.lproj)
func findAvailableLanguages(in appBundlePath: String) async -> [LanguageInfo] {
    let fileManager = FileManager.default

    // Find all .lproj folders in Resources, PlugIns, and Frameworks
    let searchPaths = ["Contents/Resources", "Contents/PlugIns", "Contents/Frameworks"]
    var lprojPathsByLang: [String: [URL]] = [:]

    for searchPath in searchPaths {
        let fullSearchPath = URL(fileURLWithPath: appBundlePath).appendingPathComponent(searchPath)
        guard fileManager.fileExists(atPath: fullSearchPath.path),
              let enumerator = fileManager.enumerator(at: fullSearchPath, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }

        while let fileURL = enumerator.nextObject() as? URL {
            if fileURL.pathExtension == "lproj" {
                let langCode = fileURL.deletingPathExtension().lastPathComponent
                // Skip Base.lproj - never removable
                if langCode != "Base" {
                    lprojPathsByLang[langCode, default: []].append(fileURL)
                }
            }
        }
    }

    guard !lprojPathsByLang.isEmpty else { return [] }

    // Get user's preferred language codes (e.g., ["en-US", "fr-FR"])
    let preferredLanguages = Locale.preferredLanguages

    // Extract full language codes and base codes separately
    let preferredFullCodes = Set(preferredLanguages)  // e.g., ["en-US", "fr-FR"]
    let preferredBaseCodes = Set(preferredLanguages.map { String($0.prefix(2)) })  // e.g., ["en", "fr"]

    // Check if user has region-specific preferences (e.g., "en-US" vs just "en")
    let hasRegionalPreferences = preferredLanguages.contains { $0.contains("-") }

    // Build LanguageInfo for each language
    var languages: [LanguageInfo] = []

    for (langCode, paths) in lprojPathsByLang {
        // Get base language code (e.g., "en" from "en-GB")
        let baseLangCode = String(langCode.prefix(2))

        // Check if this is a preferred language
        // Keep if:
        // 1. Exact match with user's preferred language (e.g., "en-US" matches "en-US")
        // 2. Base language with no region specifier (e.g., "en" when user has "en-US")
        // 3. User has base-only preference (e.g., user has "en", keep all "en*" variants)
        let isPreferred: Bool
        if preferredFullCodes.contains(langCode) {
            // Exact match (e.g., user has "en-US", language is "en-US")
            isPreferred = true
        } else if !langCode.contains("-") && preferredBaseCodes.contains(langCode) {
            // Base language without region (e.g., "en" when user has "en-US")
            isPreferred = true
        } else if !hasRegionalPreferences && preferredBaseCodes.contains(baseLangCode) {
            // User has base-only preference (e.g., user has "en", keep all "en*")
            isPreferred = true
        } else {
            isPreferred = false
        }

        // Count files in first .lproj folder (representative)
        let fileCount = (try? fileManager.contentsOfDirectory(atPath: paths[0].path))?.count ?? 0

        // Get localized display name
        let displayName = Locale.current.localizedString(forLanguageCode: langCode) ?? langCode

        languages.append(LanguageInfo(
            code: langCode,
            displayName: displayName,
            isPreferred: isPreferred,
            fileCount: fileCount,
            lprojPaths: paths
        ))
    }

    // Sort: preferred first, then alphabetically
    return languages.sorted { first, second in
        if first.isPreferred != second.isPreferred {
            return first.isPreferred
        }
        return first.displayName.localizedCaseInsensitiveCompare(second.displayName) == .orderedAscending
    }
}

/// Remove translation files manually based on user selection
/// - Parameter languagesToRemove: Array of LanguageInfo objects to remove
func pruneLanguagesManual(languagesToRemove: [LanguageInfo]) async throws {
    guard !languagesToRemove.isEmpty else { return }

    // Flatten all lproj paths from all languages
    let lprojsToRemove = languagesToRemove.flatMap { $0.lprojPaths }

    // Get app name from AppState (always available since pruning is from selected app)
    let appName = AppState.shared.appInfo.appName

    // Use FileManagerUndo which automatically handles:
    // - Protected/system-owned files via privileged helper
    // - Bundled trash organization
    // - Undo support
    let bundleName = "\(appName) - Translations"
    let success = FileManagerUndo.shared.deleteFiles(at: lprojsToRemove, bundleName: bundleName)

    if !success {
        throw NSError(
            domain: "com.pearcleaner.prune",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to remove translation files."]
        )
    }
}

// Remove translations that are not in use (AUTO mode - keeps user's macOS preferred languages)
/// - Parameters:
///   - appBundlePath: Path to .app bundle
///   - showAlert: Whether to show success alert (default: false for silent background operation)
func pruneLanguages(in appBundlePath: String, showAlert: Bool = false) async throws {
    // Use helper to get all languages with URLs and preferred status
    let allLanguages = await findAvailableLanguages(in: appBundlePath)
    guard !allLanguages.isEmpty else { return }

    // Filter to non-preferred languages (auto-prune keeps only preferred)
    var languagesToRemove = allLanguages.filter { !$0.isPreferred }

    // If no preferred languages found, keep English as fallback
    if allLanguages.allSatisfy({ !$0.isPreferred }) {
        // None are preferred - keep English if it exists, remove all others
        languagesToRemove = allLanguages.filter { language in
            !language.code.hasPrefix("en")
        }
    }

    // If we're removing everything, keep English as absolute fallback
    if languagesToRemove.count == allLanguages.count {
        if let english = allLanguages.first(where: { $0.code.hasPrefix("en") }) {
            languagesToRemove.removeAll { $0.code == english.code }
        }
    }

    // Delegate to manual prune (reuses same deletion logic)
    try await pruneLanguagesManual(languagesToRemove: languagesToRemove)

    // Show success alert if requested (for UI-triggered pruning)
    if showAlert {
        let removedCount = languagesToRemove.count
        let keptCount = allLanguages.count - removedCount
        await MainActor.run {
            showCustomAlert(
                title: "Translations Pruned",
                message: "Successfully removed \(removedCount) language\(removedCount == 1 ? "" : "s"). Kept \(keptCount) language\(keptCount == 1 ? "" : "s").",
                style: .informational
            )
        }
    }
}

// FinderExtension Sequoia Fix
func manageFinderPlugin(install: Bool) {
    let task = Process()
    task.launchPath = "/usr/bin/pluginkit"

    task.arguments = ["-e", "\(install ? "use" : "ignore")", "-i", "com.alienator88.Pearcleaner.FinderOpen"]

    task.launch()
    task.waitUntilExit()
}

// Brew cleanup
//func getBrewCleanupCommand(for caskName: String) -> String {
//    let brewPath = isOSArm() ? "/opt/homebrew/bin/brew" : "/usr/local/bin/brew"
//    return "\(brewPath) uninstall --cask \(caskName) --zap --force && \(brewPath) cleanup && clear; echo '\nHomebrew cleanup was successful, you may close this window..\n'"
//}

// MARK: - Cask Lookup Cache

/// Metadata extracted from Homebrew cask JSON files
struct CaskMetadata {
    let caskName: String      // from "full_token" field in cask JSON
    let autoUpdates: Bool?    // from "auto_updates" field in cask JSON
}

private var caskLookupTable: [String: CaskMetadata]?  // appName → CaskMetadata
private let caskLookupQueue = DispatchQueue(label: "com.pearcleaner.cask.lookup", attributes: .concurrent)

/// Get full cask metadata including auto_updates flag
/// Returns CaskMetadata with cask name and auto_updates flag from Homebrew cask JSON
/// - Parameters:
///   - appName: The display name from kMDItemDisplayName (e.g., "Yandex Disk")
///   - appPath: Optional app path URL to extract actual filename if display name doesn't match
func getCaskInfo(for appName: String, appPath: URL? = nil, bundleId: String? = nil) -> CaskMetadata? {
    // First, try a read-only access
    let existingTable = caskLookupQueue.sync {
        return caskLookupTable
    }

    // If table doesn't exist, build it with a barrier write
    if existingTable == nil {
        caskLookupQueue.sync(flags: .barrier) {
            // Double-check inside the barrier to avoid duplicate work
            if caskLookupTable == nil {
                caskLookupTable = buildCaskLookupTable()
            }
        }
    }

    // Now safely read the result
    return caskLookupQueue.sync {
        // Try with display name first (from kMDItemDisplayName)
        if let result = caskLookupTable?[appName.lowercased()] {
            return result
        }

        // If not found, try with actual filename (handles localized names)
        // Example: Display name "Yandex Disk" won't match, but filename "Yandex.Disk.2" will
        if let appPath = appPath {
            let filename = appPath.lastPathComponent.replacingOccurrences(of: ".app", with: "").lowercased()
            if let result = caskLookupTable?[filename] {
                return result
            }
        }

        // Fallback: Try with bundle ID (for PKG-based casks like Google Drive)
        if let bundleId = bundleId, !bundleId.isEmpty {
            if let result = caskLookupTable?[bundleId.lowercased()] {
                return result
            }
        }

        return nil
    }
}

/// Invalidate cask lookup cache (call after installing/uninstalling casks)
/// Next call to getCaskInfo will rebuild the table with updated cask metadata
func invalidateCaskLookupCache() {
    caskLookupQueue.sync(flags: .barrier) {
        caskLookupTable = nil
    }
}

/// Get cask identifier (name) for an app
/// Legacy function for backward compatibility - returns only cask name
func getCaskIdentifier(for appName: String) -> String? {
    return getCaskInfo(for: appName)?.caskName
}

/// Build lookup table mapping app names to cask metadata
/// Uses glob pattern to find all cask JSON files and extracts full_token, artifacts, and auto_updates
private func buildCaskLookupTable() -> [String: CaskMetadata] {
    let caskroomPath = isOSArm() ? "/opt/homebrew/Caskroom/" : "/usr/local/Caskroom/"
    let fileManager = FileManager.default
    var appToCask: [String: CaskMetadata] = [:]

    // Safety check
    guard fileManager.fileExists(atPath: caskroomPath) else {
        printOS("Caskroom not found at: \(caskroomPath)")
        return [:]
    }

    // Single glob pattern to find ALL cask JSON files at once
    // Pattern: /opt/homebrew/Caskroom/*/.metadata/*/*/Casks/*.json
    let globPattern = "\(caskroomPath)*/.metadata/*/*/Casks/*.json"

    var globResult = glob_t()
    defer { globfree(&globResult) }

    guard glob(globPattern, 0, nil, &globResult) == 0 else {
        printOS("Glob pattern failed: \(globPattern)")
        return [:]
    }

    // Process each found JSON file
    let pathCount = Int(globResult.gl_pathc)
    for i in 0..<pathCount {
        guard let cPath = globResult.gl_pathv[i],
              let jsonPath = String(validatingUTF8: cPath) else {
            continue
        }

        // Read and parse JSON
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            continue
        }

        // Extract cask ID from "full_token" field (authoritative cask identifier)
        guard let caskName = json["full_token"] as? String else {
            continue
        }

        // Extract auto_updates flag (for smart Sparkle filtering)
        let autoUpdates = json["auto_updates"] as? Bool

        // Extract app artifacts (array of dictionaries, each may have "app" key)
        guard let artifacts = json["artifacts"] as? [[String: Any]] else {
            continue
        }

        // Find "app" artifacts and build appName → CaskMetadata mapping
        var foundAppArtifact = false
        for artifact in artifacts {
            if let apps = artifact["app"] as? [Any] {
                foundAppArtifact = true
                for app in apps {
                    if let appStr = app as? String {
                        // Direct app name (e.g., "Telegram.app")
                        let realAppName = appStr
                            .replacingOccurrences(of: ".app", with: "")
                            .lowercased()
                        appToCask[realAppName] = CaskMetadata(
                            caskName: caskName,
                            autoUpdates: autoUpdates
                        )
                    } else if let appDict = app as? [String: Any],
                              let targetName = appDict["target"] as? String {
                        // Renamed app (e.g., {"target": "Telegram Desktop.app"})
                        let realAppName = targetName
                            .replacingOccurrences(of: ".app", with: "")
                            .lowercased()
                        appToCask[realAppName] = CaskMetadata(
                            caskName: caskName,
                            autoUpdates: autoUpdates
                        )
                    }
                }
            }
        }

        // Also match via "name" property (handles renamed apps, localized names, PKG-based casks)
        // Examples: Telegram Desktop (renamed), Yandex Disk (localized), Google Drive (PKG-based)
        if let names = json["name"] as? [String] {
            for name in names {
                let normalizedName = name.lowercased()
                appToCask[normalizedName] = CaskMetadata(
                    caskName: caskName,
                    autoUpdates: autoUpdates
                )
            }
        }

        // Additional fallback: Match via "uninstall" → "quit" bundle IDs
        // This helps match apps where the display name differs from cask name
        if !foundAppArtifact {
            for artifact in artifacts {
                if let uninstalls = artifact["uninstall"] as? [[String: Any]] {
                    for uninstall in uninstalls {
                        // Extract bundle IDs from "quit" directive
                        if let quitBundleIds = uninstall["quit"] as? [String] {
                            for bundleId in quitBundleIds {
                                // Store bundle ID → cask mapping for later matching
                                let normalizedBundleId = bundleId.lowercased()
                                appToCask[normalizedBundleId] = CaskMetadata(
                                    caskName: caskName,
                                    autoUpdates: autoUpdates
                                )
                            }
                        }

                        // PKG-based casks: Extract app bundles from package receipts
                        // Uses private PackageKit framework to avoid Process() overhead
                        if let pkgutilID = uninstall["pkgutil"] as? String {
                            // Find package receipt by ID
                            let allPackages = PKGManager.getAllPackages(volume: "/")
                            if let receipt = allPackages.first(where: { $0.packageIdentifier() as? String == pkgutilID }) {
                                // Get package info to determine install location
                                guard let packageInfo = PKGManager.getPackageInfo(from: receipt) else {
                                    continue
                                }

                                // Get all files installed by this package
                                let installedFiles = PKGManager.getPackageFiles(
                                    receipt: receipt,
                                    installLocation: packageInfo.installLocation
                                )

                                // Extract .app bundles from Applications directory
                                let appBundles = installedFiles.filter { path in
                                    path.contains("/Applications/") && path.hasSuffix(".app/Contents")
                                }.compactMap { path -> String? in
                                    // Extract app name from path like "/Applications/VeraCrypt.app/Contents"
                                    let components = path.components(separatedBy: "/")
                                    if let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) {
                                        return components[appIndex]
                                            .replacingOccurrences(of: ".app", with: "")
                                            .lowercased()
                                    }
                                    return nil
                                }

                                // Add each discovered app to lookup table
                                for appName in Set(appBundles) {  // Use Set to avoid duplicates
                                    appToCask[appName] = CaskMetadata(
                                        caskName: caskName,
                                        autoUpdates: autoUpdates
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Fallback for tap casks without .json files (only .rb files)
    // Use directory name as cask identifier
    let allCaskDirs = (try? fileManager.contentsOfDirectory(atPath: caskroomPath)) ?? []

    for caskDirName in allCaskDirs where !caskDirName.hasPrefix(".") {
        let receiptPath = "\(caskroomPath)\(caskDirName)/.metadata/INSTALL_RECEIPT.json"

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: receiptPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let artifacts = json["uninstall_artifacts"] as? [[String: Any]] else {
            continue
        }

        // Extract auto_updates flag
        let autoUpdates = json["auto_updates"] as? Bool

        // Extract app names from uninstall_artifacts
        for artifact in artifacts {
            if let apps = artifact["app"] as? [String] {
                for appStr in apps {
                    let realAppName = appStr
                        .replacingOccurrences(of: ".app", with: "")
                        .lowercased()

                    // Only add if not already in lookup table (JSON takes precedence)
                    if appToCask[realAppName] == nil {
                        // Use directory name as cask identifier
                        appToCask[realAppName] = CaskMetadata(
                            caskName: caskDirName,  // e.g., "battery-toolkit"
                            autoUpdates: autoUpdates
                        )
                    }
                }
            }
        }
    }

    return appToCask
}

//func getCaskIdentifier(for appName: String) -> String? {
//    let caskroomPath = isOSArm() ? "/opt/homebrew/Caskroom/" : "/usr/local/Caskroom/"
//    let fileManager = FileManager.default
//    let lowercasedAppName = appName.lowercased()
//
//    do {
//        // Get all cask directories from Caskroom, ignoring hidden files
//        let casks = try fileManager.contentsOfDirectory(atPath: caskroomPath).filter {
//            !$0.hasPrefix(".")
//        }
//
//        for cask in casks {
//            // Construct the path to the cask directory
//            let caskSubPath = caskroomPath + cask
//
//            // Get all version directories for this cask, ignoring hidden files
//            let versions = try fileManager.contentsOfDirectory(atPath: caskSubPath).filter {
//                !$0.hasPrefix(".")
//            }
//
//            // Only check the first valid version directory to improve efficiency
//            if let latestVersion = versions.first {
//                let appDirectory = "\(caskSubPath)/\(latestVersion)/"
//
//                // List all files in the version directory and check for .app file
//                //                let appsInDir = try fileManager.contentsOfDirectory(atPath: appDirectory).filter { !$0.hasPrefix(".") }
//                let appsInDir = try fileManager.contentsOfDirectory(atPath: appDirectory).filter {
//                    !$0.hasPrefix(".") && $0.hasSuffix(".app")
//                    && !$0.lowercased().contains("uninstall")
//                }
//                if let appFile = appsInDir.first(where: { $0.hasSuffix(".app") }) {
//                    let realAppName = appFile.replacingOccurrences(of: ".app", with: "")
//                        .lowercased()
//                    // Compare the lowercased app names for case-insensitive match
//                    if realAppName == lowercasedAppName {
//                        return realAppName.replacingOccurrences(of: " ", with: "-").lowercased()
//                    }
//                }
//            }
//        }
//    } catch let error as NSError {
//        if !(error.domain == NSCocoaErrorDomain && error.code == 260) {
//            printOS("Cask Identifier: \(error)")
//        }
//    }
//
//    // If no match is found, return nil
//    return nil
//}

// Print list of files locally
func saveURLsToFile(appState: AppState, copy: Bool = false) {
    let urls = Set(appState.selectedItems)

    if copy {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        var fileContent = ""
        let sortedUrls = urls.sorted { $0.path < $1.path }

        for url in sortedUrls {
            let pathWithTilde = url.path.replacingOccurrences(of: homeDirectory, with: "~")
            fileContent += "\(pathWithTilde)\n"
        }
        copyToClipboard(fileContent)
    } else {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK, let selectedFolder = panel.url {
            let filePath = selectedFolder.appendingPathComponent(
                "Export-\(appState.appInfo.appName)(v\(appState.appInfo.appVersion)).txt")
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            var fileContent = ""
            let sortedUrls = urls.sorted { $0.path < $1.path }

            for url in sortedUrls {
                let pathWithTilde = url.path.replacingOccurrences(of: homeDirectory, with: "~")
                fileContent += "\(pathWithTilde)\n"
            }

            do {
                try fileContent.write(to: filePath, atomically: true, encoding: .utf8)
                printOS("File saved successfully at \(filePath.path)")
                // Open Finder and select the file
                NSWorkspace.shared.selectFile(
                    filePath.path,
                    inFileViewerRootedAtPath: filePath.deletingLastPathComponent().path)
            } catch {
                printOS("Error saving file: \(error)")
            }

        } else {
            printOS("Folder selection was canceled.")
        }
    }

}

/// Export debug information to a file with conditional content based on app context
func exportDebugInfo(appState: AppState) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Select Folder"

    if panel.runModal() == .OK, let selectedFolder = panel.url {
        // Determine filename based on context
        let filename: String
        if appState.currentView == .files && !appState.appInfo.bundleIdentifier.isEmpty {
            // App-specific debug
            filename = "Debug-\(appState.appInfo.appName)(v\(appState.appInfo.appVersion)).txt"
        } else {
            // System-only debug
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = dateFormatter.string(from: Date())
            filename = "PearcleanerDiagnostics-\(timestamp).txt"
        }

        let filePath = selectedFolder.appendingPathComponent(filename)

        // Generate debug content based on context
        let debugContent: String
        if appState.currentView == .files && !appState.appInfo.bundleIdentifier.isEmpty {
            // Full debug: AppInfo + System
            debugContent = appState.appInfo.getDebugString() + "\n" + getSystemDebugString()
        } else {
            // System-only debug
            debugContent = getSystemDebugString()
        }

        do {
            try debugContent.write(to: filePath, atomically: true, encoding: .utf8)
            printOS("Debug info saved successfully at \(filePath.path)")
            // Open Finder and select the file
            NSWorkspace.shared.selectFile(
                filePath.path,
                inFileViewerRootedAtPath: filePath.deletingLastPathComponent().path)
        } catch {
            printOS("Error saving debug info: \(error)")
        }
    } else {
        printOS("Folder selection was canceled.")
    }
}

func exportUpdaterDebugInfo() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Select Folder"

    if panel.runModal() == .OK, let selectedFolder = panel.url {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "UpdaterDebugLog-\(timestamp).txt"
        let filePath = selectedFolder.appendingPathComponent(filename)

        let systemInfo = getSystemDebugString()
        let updaterLogs = UpdaterDebugLogger.shared.generateDebugReport()
        let debugContent = systemInfo + "\n\n" + updaterLogs

        do {
            try debugContent.write(to: filePath, atomically: true, encoding: .utf8)
            printOS("Updater debug log saved successfully at \(filePath.path)")
            // Open Finder and select the file
            NSWorkspace.shared.selectFile(
                filePath.path,
                inFileViewerRootedAtPath: filePath.deletingLastPathComponent().path)
            // Clear logs after successful export
            UpdaterDebugLogger.shared.clearLogs()
        } catch {
            printOS("Error saving updater debug log: \(error)")
        }
    } else {
        printOS("Folder selection was canceled.")
    }
}


// Remove app from cache
func removeApp(appState: AppState, withPath path: URL) async {
    @AppStorage("settings.general.brew") var brew: Bool = false
    await MainActor.run {

        // Remove from sortedApps if found
        if let index = appState.sortedApps.firstIndex(where: { $0.path == path }) {
            appState.sortedApps.remove(at: index)
        }
    }
}

// --- Remove bundle(s) from menubar items by patching the inner binary blob only ---
//func removeBundles(_ bundleIDs: [String]) throws {
//    let plistPath = NSHomeDirectory() + "/Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist"
//    let plistURL = URL(fileURLWithPath: plistPath)
//
//    // Load outer plist and inner blob
//    let outerData = try Data(contentsOf: plistURL)
//    var outerFormat: PropertyListSerialization.PropertyListFormat = .binary
//    guard var outerPlist = try PropertyListSerialization.propertyList(from: outerData,
//                                                                      options: .mutableContainersAndLeaves,
//                                                                      format: &outerFormat) as? [String: Any],
//          let trackedBlob = outerPlist["trackedApplications"] as? Data else {
//        throw NSError(domain: "PlistError", code: 1,
//                      userInfo: [NSLocalizedDescriptionKey: "Invalid plist structure"])
//    }
//
//    // Decode trackedApplications
//    var innerFormat: PropertyListSerialization.PropertyListFormat = .binary
//    guard var innerList = try PropertyListSerialization.propertyList(from: trackedBlob,
//                                                                     options: .mutableContainersAndLeaves,
//                                                                     format: &innerFormat) as? [[String: Any]] else {
//        throw NSError(domain: "PlistError", code: 2,
//                      userInfo: [NSLocalizedDescriptionKey: "Invalid inner plist structure"])
//    }
//
//    // Remove any entries with a matching bundle at any level
//    innerList.removeAll { entry in
//        // Top-level bundle
//        if let bundle = (entry["bundle"] as? [String: Any])?["_0"] as? String {
//            if bundleIDs.contains(where: { bundle.caseInsensitiveCompare($0) == .orderedSame }) {
//                return true
//            }
//        }
//        // Nested bundle under location -> menuItemLocations
//        if let location = entry["location"] as? [String: Any],
//           let menuItems = location["menuItemLocations"] as? [[String: Any]] {
//            for menuItem in menuItems {
//                if let bundle = (menuItem["bundle"] as? [String: Any])?["_0"] as? String {
//                    if bundleIDs.contains(where: { bundle.caseInsensitiveCompare($0) == .orderedSame }) {
//                        return true
//                    }
//                }
//            }
//        }
//        return false
//    }
//
//    // Re-encode and save
//    let newTrackedBlob = try PropertyListSerialization.data(fromPropertyList: innerList,
//                                                            format: .binary,
//                                                            options: 0)
//    outerPlist["trackedApplications"] = newTrackedBlob
//    let newOuterData = try PropertyListSerialization.data(fromPropertyList: outerPlist,
//                                                          format: .binary,
//                                                          options: 0)
//    try newOuterData.write(to: plistURL, options: .atomic)
//}

// --- Pearcleaner Uninstall ---
func uninstallPearcleaner(appState: AppState, locations: Locations) {

    // Unload Sentinel Monitor if running
    launchctl(load: false)

    // Get app info for Pearcleaner
    let appInfo = AppInfoFetcher.getAppInfo(atPath: Bundle.main.bundleURL)

    // Find application files for Pearcleaner
    AppPathFinder(
        appInfo: appInfo!, locations: locations, appState: appState,
        completion: {
            // Kill Pearcleaner and tell Finder to trash the files
            let selectedItemsArray = Array(appState.selectedItems).filter {
                !$0.path.contains(".Trash")
            }
            let result = FileManagerUndo.shared.deleteFiles(at: selectedItemsArray)

            if result {
                playTrashSound()
            }
            exit(0)
        }
    ).findPaths()
}

// --- Load Plist file with SMAppService ---
func launchctl(load: Bool, completion: @escaping () -> Void = {}) {
    let service = SMAppService.agent(plistName: "com.alienator88.PearcleanerSentinel.plist")

    if load {
        do {
            try service.register()
        } catch let error as NSError {
            printOS("Error registering PearcleanerSentinel: \(error)")
        }
    } else {
        do {
            try service.unregister()
        } catch let error as NSError {
            printOS("Error unregistering PearcleanerSentinel: \(error)")
        }
    }

    completion()
}

func createTarArchive(appState: AppState) {
    // Filter the array to include only paths under /Users/, /Applications/, or /Library/
    let allowedPaths = Array(appState.selectedItems).filter {
        $0.path.starts(with: "/Users/") || $0.path.starts(with: "/Applications/")
    }

    guard !allowedPaths.isEmpty else {
        printOS("No valid paths provided.")
        return
    }

    // Create save panel
    let savePanel = NSSavePanel()
    //    savePanel.allowedContentTypes = [.zip]
    savePanel.canCreateDirectories = true
    savePanel.showsTagField = false

    // Set default filename
    savePanel.nameFieldStringValue = "Bundle-\(appState.appInfo.appName).tar"
    savePanel.allowedContentTypes = [UTType(filenameExtension: "tar")!]

    // Show save panel
    let response = savePanel.runModal()
    guard response == .OK, let finalDestination = savePanel.url else {
        printOS("Archive export cancelled.")
        return
    }

    do {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "Bundle-" + appState.appInfo.appName)

        // Create a temporary directory to organize the paths
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true, attributes: nil)

        for path in allowedPaths {
            // Compute the relative path for each file
            let relativePath: String
            if path.path.starts(with: "/Users/") {
                relativePath = String(path.path.dropFirst("/Users/".count))
            } else if path.path.starts(with: "/Applications/") {
                relativePath = "Applications/" + String(path.path.dropFirst("/Applications/".count))
            } else {
                continue
            }

            // Create subdirectories as needed in the temporary directory
            let destinationPath = tempDir.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: destinationPath.deletingLastPathComponent(), withIntermediateDirectories: true,
                attributes: nil)

            // Copy the file to the corresponding relative path in the temporary directory
            try FileManager.default.copyItem(at: path, to: destinationPath)
        }

        // Use `ditto` to create the tar archive
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k", "--sequesterRsrc", "--keepParent", tempDir.path, finalDestination.path,
        ]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        // Check for process errors
        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "com.alienator88.Pearcleaner.archiveExport",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Clean up the temporary directory
        try FileManager.default.removeItem(at: tempDir)

        printOS("Archive created successfully at \(finalDestination.path)")

    } catch {
        printOS("Error creating tar archive: \(error)")
    }
}
