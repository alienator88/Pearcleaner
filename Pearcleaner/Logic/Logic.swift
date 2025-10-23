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

/// Load apps from specified folder paths and update AppState
/// This is the main entry point for loading/refreshing apps
func loadApps(folderPaths: [String]) {
    DispatchQueue.global(qos: .userInitiated).async {
        let apps = getSortedApps(paths: folderPaths)

        Task { @MainActor in
            AppState.shared.sortedApps = apps
            AppState.shared.restoreZombieAssociations()
        }
    }
}

// Awaitable version that waits for apps to finish loading
func loadAppsAsync(folderPaths: [String]) async {
    // Load apps on background thread
    let apps = await Task.detached(priority: .userInitiated) {
        getSortedApps(paths: folderPaths)
    }.value

    // Update AppState on MainActor
    await MainActor.run {
        AppState.shared.sortedApps = apps
        AppState.shared.restoreZombieAssociations()
    }
}


// Get all apps from /Applications and ~/Applications
func getSortedApps(paths: [String]) -> [AppInfo] {
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

    // Convert collected paths to string format for metadata query
    let combinedPaths = apps.map { $0.path }

    // Get metadata for all collected app paths
    var metadataDictionary: [String: [String: Any]] = [:]

    if let metadata = getMDLSMetadata(for: combinedPaths) {
        metadataDictionary = metadata
    }

    // Process each app path and construct AppInfo using metadata first, then fallback if necessary
    let appInfos: [AppInfo] = {
        let chunks = createOptimalChunks(from: apps, minChunkSize: 10, maxChunkSize: 40)
        let queue = DispatchQueue(label: "com.pearcleaner.appinfo", qos: .userInitiated, attributes: .concurrent)
        let group = DispatchGroup()

        var allAppInfos: [AppInfo] = []
        let resultsQueue = DispatchQueue(label: "com.pearcleaner.appinfo.results")

        for chunk in chunks {
            group.enter()
            queue.async {
                autoreleasepool {
                    let chunkAppInfos: [AppInfo] = chunk.compactMap { appURL in
                        autoreleasepool {
                            let appPath = appURL.path

                            if let appMetadata = metadataDictionary[appPath] {
                                return MetadataAppInfoFetcher.getAppInfo(fromMetadata: appMetadata, atPath: appURL)
                            } else {
                                return AppInfoFetcher.getAppInfo(atPath: appURL)
                            }
                        }
                    }

                    resultsQueue.sync {
                        allAppInfos.append(contentsOf: chunkAppInfos)
                    }
                }
                group.leave()
            }
        }

        group.wait()
        return allAppInfos
    }()
//    let appInfos: [AppInfo] = apps.compactMap { appURL in
//        let appPath = appURL.path
//
//        if let appMetadata = metadataDictionary[appPath] {
//            // Use `MetadataAppInfoFetcher` first
//            return MetadataAppInfoFetcher.getAppInfo(fromMetadata: appMetadata, atPath: appURL)
//        } else {
//            // Fallback to `AppInfoFetcher` if no metadata found
//            return AppInfoFetcher.getAppInfo(atPath: appURL)
//        }
//
//    }

    // Sort apps by display name
    let sortedApps = appInfos.sorted { $0.appName.lowercased() < $1.appName.lowercased() }

    return sortedApps
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
    appInfo: AppInfo, appState: AppState, locations: Locations, sensitivityOverride: SearchSensitivityLevel? = nil) {
    @AppStorage("settings.interface.animationEnabled") var animationEnabled: Bool = true

    updateOnMain {
        appState.appInfo = .empty
        appState.selectedItems = []

        // When the appInfo is not found, show progress, and search for paths.
        appState.showProgress = true

        // Initialize the path finder and execute its search.
        AppPathFinder(appInfo: appInfo, locations: locations, appState: appState, sensitivityOverride: sensitivityOverride).findPaths()

        appState.appInfo = appInfo

        // Animate the view change and popover display.
        withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
            appState.currentView = .files
        }
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
    appState.reload = true
    updateOnBackground(after: delay) {
        let sortedApps = getSortedApps(paths: fsm.folderPaths)
        // Update UI on the main thread
        updateOnMain {
            appState.sortedApps = sortedApps
            appState.reload = false
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

    if isRunningInTerminal {
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

// Auto-slim: Remove unused architectures and translations (synchronous, runs on app termination)
func performAutoSlim() {
    let currentVersion = Bundle.main.version
    let bundlePath = Bundle.main.bundlePath
    let bundleURL = URL(fileURLWithPath: bundlePath)

    // Slim bundle based on architecture type
    let arch = checkAppBundleArchitecture(at: bundlePath)

    if arch == .universal {
        // Universal: Use ditto copy-replace pattern (safe for binary modification)
        let dittoArch = isOSArm() ? "arm64" : "x86_64"
        let tempDir = FileManager.default.temporaryDirectory
        let tempAppPath = tempDir.appendingPathComponent("Pearcleaner-slim.app")

        do {
            // Remove temp if exists
            try? FileManager.default.removeItem(at: tempAppPath)

            // Use ditto to thin during copy
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["--arch", dittoArch, bundlePath, tempAppPath.path]
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                // Prune translations from temp copy (not running bundle!)
                let semaphore = DispatchSemaphore(value: 0)
                Task {
                    do {
                        try await pruneLanguages(in: tempAppPath.path)
                    } catch {
                        // Silent failure
                    }
                    semaphore.signal()
                }
                semaphore.wait()

                // Replace original with fully-processed temp copy
                // Always use helper to replace bundle (handles both user and root-owned)
                if HelperToolManager.shared.isHelperToolInstalled {
                    let command = "/bin/rm -rf \"\(bundleURL.path)\" && /bin/mv \"\(tempAppPath.path)\" \"\(bundleURL.path)\""
                    let helperSemaphore = DispatchSemaphore(value: 0)
                    var success = false
                    Task {
                        let result = await HelperToolManager.shared.runCommand(command)
                        success = result.0
                        helperSemaphore.signal()
                    }
                    helperSemaphore.wait()

                    if !success {
                        printOS("Auto-slim failed: Could not replace bundle")
                    }
                } else {
                    // Helper required but not installed
                    printOS("Auto-slim failed: Helper tool required. Authorization Services has been removed.")
                    HelperToolManager.shared.triggerHelperRequiredAlert()
                    return
                }
            }
        } catch {
            // Silent failure
        }

    } else {
        // Arch-specific: Prune translations directly from running bundle (safe, no binary modification)
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                try await pruneLanguages(in: bundlePath)
            } catch {
                // Silent failure
            }
            semaphore.signal()
        }
        semaphore.wait()
    }

    // Update version and reset current size (will be recalculated on next launch)
    var stats = AppState.shared.autoSlimStats
    stats.lastRunVersion = currentVersion
    stats.currentSize = 0  // Reset so next launch recalculates the new size
    AppState.shared.autoSlimStats = stats
}

// FinderExtension Sequoia Fix
func manageFinderPlugin(install: Bool) {
    let task = Process()
    task.launchPath = "/usr/bin/pluginkit"

    task.arguments = ["-e", "\(install ? "use" : "ignore")", "-i", "com.alienator88.Pearcleaner"]

    task.launch()
    task.waitUntilExit()
}

// Brew cleanup
func getBrewCleanupCommand(for caskName: String) -> String {
    let brewPath = isOSArm() ? "/opt/homebrew/bin/brew" : "/usr/local/bin/brew"
    return "\(brewPath) uninstall --cask \(caskName) --zap --force && \(brewPath) cleanup && clear; echo '\nHomebrew cleanup was successful, you may close this window..\n'"
}

private var caskLookupTable: [String: String]?
private let caskLookupQueue = DispatchQueue(label: "com.pearcleaner.cask.lookup", attributes: .concurrent)

func getCaskIdentifier(for appName: String) -> String? {
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
        return caskLookupTable?[appName.lowercased()]
    }
}

private func buildCaskLookupTable() -> [String: String] {
    let caskroomPath = isOSArm() ? "/opt/homebrew/Caskroom/" : "/usr/local/Caskroom/"
    let fileManager = FileManager.default
    var appToCask: [String: String] = [:]

    // Add safety checks
    guard fileManager.fileExists(atPath: caskroomPath) else {
        printOS("Caskroom not found at: \(caskroomPath)")
        return [:]
    }

    do {
        let casks = try fileManager.contentsOfDirectory(atPath: caskroomPath).filter { !$0.hasPrefix(".") }

        for cask in casks {
            let caskSubPath = caskroomPath + cask
            let receiptPath = "\(caskSubPath)/.metadata/INSTALL_RECEIPT.json"

            // Try to read INSTALL_RECEIPT.json for fast lookup
            if let receiptData = try? Data(contentsOf: URL(fileURLWithPath: receiptPath)) {
                do {
                    guard let json = try JSONSerialization.jsonObject(with: receiptData) as? [String: Any] else {
                        throw NSError(domain: "JSONParse", code: 1, userInfo: nil)
                    }

                    // Find "app" artifact in uninstall_artifacts array
                    if let artifacts = json["uninstall_artifacts"] as? [[String: Any]] {
                        for artifact in artifacts {
                            if let apps = artifact["app"] as? [String] {
                                for appStr in apps {
                                    let realAppName = appStr.replacingOccurrences(of: ".app", with: "").lowercased()
                                    appToCask[realAppName] = cask
                                }
                            }
                        }
                    }
                } catch {
                    printOS("Error parsing INSTALL_RECEIPT.json for \(cask): \(error)")
                    // Fall through to directory scanning fallback
                }
            } else {
                // Fallback: If INSTALL_RECEIPT.json doesn't exist or can't be read, scan directories
                // (This handles older casks or edge cases)
                guard fileManager.fileExists(atPath: caskSubPath) else { continue }

                do {
                    let versions = try fileManager.contentsOfDirectory(atPath: caskSubPath).filter { !$0.hasPrefix(".") }

                    if let latestVersion = versions.first {
                        let appDirectory = "\(caskSubPath)/\(latestVersion)/"

                        guard fileManager.fileExists(atPath: appDirectory) else { continue }

                        do {
                            let appsInDir = try fileManager.contentsOfDirectory(atPath: appDirectory).filter {
                                !$0.hasPrefix(".") && $0.hasSuffix(".app") && !$0.lowercased().contains("uninstall")
                            }

                            for appFile in appsInDir {
                                let realAppName = appFile.replacingOccurrences(of: ".app", with: "").lowercased()
                                appToCask[realAppName] = cask
                            }
                        } catch {
                            printOS("Error reading app directory \(appDirectory): \(error)")
                            continue
                        }
                    }
                } catch {
                    printOS("Error reading cask directory \(caskSubPath): \(error)")
                    continue
                }
            }
        }
    } catch {
        printOS("Error reading Caskroom: \(error)")
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


// Remove app from cache
func removeApp(appState: AppState, withPath path: URL) {
    @AppStorage("settings.general.brew") var brew: Bool = false
    DispatchQueue.main.async {

        // Remove from sortedApps if found
        if let index = appState.sortedApps.firstIndex(where: { $0.path == path }) {
            appState.sortedApps.remove(at: index)
        }

        if HelperToolManager.shared.isHelperToolInstalled {
            Task {
                let _ = await HelperToolManager.shared.runCommand(
                    "pkgutil --forget \(appState.appInfo.bundleIdentifier)")
            }
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
