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

class AppPathFinder {
    // Shared properties
    private var appInfo: AppInfo
    private var locations: Locations
    private var containerCollection: [URL] = []
    private let collectionAccessQueue = DispatchQueue(label: "com.alienator88.Pearcleaner.appPathFinder.collectionAccess")
    @AppStorage("settings.general.searchSensitivity") private var sensitivityLevel: SearchSensitivityLevel = .strict
    
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
    private let cachedIdentifiers: (bundleIdentifierL: String, bundle: String, nameL: String, nameLFiltered: String, nameP: String, useBundleIdentifier: Bool)

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
        let bundleIdentifierL = appInfo.bundleIdentifier.pearFormat()
        let bundleComponents = appInfo.bundleIdentifier
            .components(separatedBy: ".")
            .compactMap { $0 != "-" ? $0.lowercased() : nil }
        let bundle = bundleComponents.suffix(2).joined()
        let nameL = appInfo.appName.pearFormat()
        let nameLFiltered = nameL.filter { $0.isLetter }
        let nameP = appInfo.path.lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let useBundleIdentifier = AppPathFinder.isValidBundleIdentifier(appInfo.bundleIdentifier)
        self.cachedIdentifiers = (bundleIdentifierL, bundle, nameL, nameLFiltered, nameP, useBundleIdentifier)
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
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: location) {
            var localResults: [URL] = []
            for item in contents {
                let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
                let itemL: String
                if itemURL.hasDirectoryPath || itemURL.pathExtension.isEmpty {
                    // It's a directory or has no extension - don't remove anything
                    itemL = item.pearFormat()
                } else {
                    // It's a file with an extension - remove the extension
                    itemL = (item as NSString).deletingPathExtension.pearFormat()
                }
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) {
                    if shouldSkipItem(itemL, at: itemURL) { continue }
                    if specificCondition(itemL: itemL, itemURL: itemURL) {
                        localResults.append(itemURL)
                    }
                }
            }
            collectionAccessQueue.sync {
                collectionSet.formUnion(localResults)
            }
        }
    }

    // Asynchronous collection for GUI usage
    private func collectLocations() {
        let dispatchGroup = DispatchGroup()
        for location in self.locations.apps.paths {
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                self.processLocation(location)
                dispatchGroup.leave()
            }
        }
        dispatchGroup.wait()
    }

    // Synchronous collection for CLI usage
    private func collectLocationsCLI() {
        for location in self.locations.apps.paths {
            processLocation(location)
        }
    }

    // Skip items based on conditions and membership in collectionSet
    private func shouldSkipItem(_ itemL: String, at itemURL: URL) -> Bool {
        var containsItem = false
        collectionAccessQueue.sync {
            containsItem = self.collectionSet.contains(itemURL)
        }
        if containsItem {
            return true
        }
        for skipCondition in skipConditions {
            if skipCondition.skipPrefix.contains(where: itemL.hasPrefix) {
                let isAllowed = skipCondition.allowPrefixes.contains(where: itemL.hasPrefix)
                if !isAllowed {
                    return true
                }
            }
        }
        return false
    }

    // Check if an item meets specific conditions using cached identifiers
    private func specificCondition(itemL: String, itemURL: URL) -> Bool {
        let cached = self.cachedIdentifiers
        
        // Special handling for Steam games: also check Desktop for shortcuts
        if itemURL.path.contains("/Desktop/") && itemURL.pathExtension == "app" {
            let desktopAppName = itemURL.deletingPathExtension().lastPathComponent.pearFormat()
            if desktopAppName == cached.nameL || desktopAppName == cached.nameLFiltered {
                return true
            }
        }

        // Special handling for Steam game main folder
        if self.appInfo.steam && itemURL.path.contains("/Library/Application Support/Steam/steamapps/common/") {
            let folderName = itemURL.lastPathComponent.pearFormat()
            // Check if this folder matches the game name
            if folderName == cached.nameL || folderName == cached.nameLFiltered {
                return true
            }
        }

        // Special handling for Steam game manifest files
        if self.appInfo.steam && itemURL.path.contains("/Library/Application Support/Steam/steamapps/") && 
           itemURL.lastPathComponent.hasPrefix("appmanifest_") && itemURL.pathExtension == "acf" {
            
            // Extract the game ID from the filename (e.g., "appmanifest_1289310.acf" -> "1289310")
            let filename = itemURL.lastPathComponent
            if let gameIdFromFile = extractGameId(from: filename) {
                // Get the game ID from the Steam launcher's run.sh file
                if let gameIdFromLauncher = getSteamGameId(from: self.appInfo.path) {
                    return gameIdFromFile == gameIdFromLauncher
                }
            }
        }
        
        for condition in conditions {
            if cached.useBundleIdentifier && cached.bundleIdentifierL.contains(condition.bundle_id) {
                if condition.exclude.contains(where: { itemL.pearFormat().contains($0.pearFormat()) }) {
                    return false
                }
                if condition.include.contains(where: { itemL.pearFormat().contains($0.pearFormat()) }) {
                    return true
                }
            }
        }
        if self.appInfo.webApp {
            return itemL.contains(cached.bundleIdentifierL)
        }
        let bundleMatch = itemL.contains(cached.bundleIdentifierL) || itemL.contains(cached.bundle)
        let sensitivity = effectiveSensitivityLevel == .strict || effectiveSensitivityLevel == .enhanced
        
        // Prevent false matches when cached values are empty strings
        let nameLMatch = !cached.nameL.isEmpty && (sensitivity ? itemL == cached.nameL : itemL.contains(cached.nameL))
        let namePMatch = !cached.nameP.isEmpty && (sensitivity ? itemL == cached.nameP : itemL.contains(cached.nameP))
        let nameLFilteredMatch = !cached.nameLFiltered.isEmpty && (sensitivity ? itemL == cached.nameLFiltered : itemL.contains(cached.nameLFiltered))
        
        return (cached.useBundleIdentifier && bundleMatch) || (nameLMatch || namePMatch || nameLFilteredMatch)
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
        return storedFiles
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
        guard effectiveSensitivityLevel == .enhanced || effectiveSensitivityLevel == .broad else { return [] }
        updateOnMain {
            self.appState?.progressStep = 1
        }
        var results: [URL] = []
        let query = NSMetadataQuery()

        let appName = self.appInfo.appName
        let bundleID = self.appInfo.bundleIdentifier
        query.predicate = NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@ OR kMDItemPath CONTAINS[cd] %@", appName, bundleID)
        query.searchScopes = [NSMetadataQueryUserHomeScope]

        let finishedNotification = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: nil) { _ in
            query.disableUpdates()
            query.stop()
            results = query.results.compactMap {
                ($0 as? NSMetadataItem)?.value(forAttribute: kMDItemPath as String)
            }.compactMap {
                URL(fileURLWithPath: $0 as! String)
            }
            if self.effectiveSensitivityLevel == .strict || self.effectiveSensitivityLevel == .enhanced {
                let nameFormatted = appName.pearFormat()
                let bundleFormatted = bundleID.pearFormat()
                results = results.filter { url in
                    let pathFormatted = url.lastPathComponent.pearFormat()
                    return pathFormatted == nameFormatted || pathFormatted == bundleFormatted
                }
            }
            CFRunLoopStop(CFRunLoopGetCurrent())
        }

        query.start()

        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            CFRunLoopStop(CFRunLoopGetCurrent())
        }

        CFRunLoopRun()

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
            tempCollection.append(contentsOf: self.containerCollection)
            tempCollection.append(contentsOf: outliers)
            // Insert spotlight results before sorting and filtering
            let spotlightResults = self.spotlightSupplementalPaths()
            let spotlightOnly = spotlightResults.filter { !self.collectionSet.contains($0) }
            //            if self.spotlight {
            //                printOS("Spotlight index found: \(spotlightOnly.count)")
            //            }
            tempCollection.append(contentsOf: spotlightOnly)

            let excludePaths = outliersEx.map { $0.path }
            tempCollection.removeAll { url in
                excludePaths.contains(url.path)
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
        var fileSizeLogical: [URL: Int64] = [:]
        var fileIcon: [URL: NSImage?] = [:]
        let chunks = createOptimalChunks(from: tempCollection)
        let queue = DispatchQueue(label: "size-calculation", qos: .userInitiated, attributes: .concurrent)
        let group = DispatchGroup()

        for chunk in chunks {
            group.enter()
            queue.async {
                var localFileSize: [URL: Int64] = [:]
                var localFileSizeLogical: [URL: Int64] = [:]
                var localFileIcon: [URL: NSImage?] = [:]

                for path in chunk {
                    let size = spotlightSizeForURL(path)
                    localFileSize[path] = size.real
                    localFileSizeLogical[path] = size.logical
                    localFileIcon[path] = self.getSmartIcon(for: path)
                }

                // Merge results safely
                DispatchQueue.main.sync {
                    fileSize.merge(localFileSize) { $1 }
                    fileSizeLogical.merge(localFileSizeLogical) { $1 }
                    fileIcon.merge(localFileIcon) { $1 }
                }
                group.leave()
            }
        }
        group.wait()
        //        for path in tempCollection {
        //            let size = spotlightSizeForURL(path)
        //            fileSize[path] = size.real
        //            fileSizeLogical[path] = size.logical
        //            fileIcon[path] = getIconForFileOrFolderNS(atPath: path)
        //        }
        let arch = checkAppBundleArchitecture(at: self.appInfo.path.path)
        var updatedCollection = tempCollection
        if updatedCollection.count == 1, let firstURL = updatedCollection.first, firstURL.path.contains(".Trash") {
            updatedCollection.removeAll()
        }

        DispatchQueue.main.async {
            self.appInfo.fileSize = fileSize
            self.appInfo.fileSizeLogical = fileSizeLogical
            self.appInfo.fileIcon = fileIcon
            self.appInfo.arch = arch
            self.appState?.appInfo = self.appInfo
            if !self.undo {
                self.appState?.selectedItems = Set(updatedCollection)
            }
            self.appState?.progressStep = 0
            self.completion?()
        }
    }

    // Public method for GUI
    func findPaths() {
        Task(priority: .background) {
            if self.appInfo.webApp {
                self.containerCollection = self.getAllContainers(bundleURL: self.appInfo.path)
                self.initialURLProcessing()
                self.finalizeCollection()
            } else {
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
        // Check if this is a .app folder
        if path.pathExtension == "app" {
            // Check if it has a Contents folder (indicating it's a real app bundle)
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
private func spotlightSizeForURL(_ url: URL) -> (real: Int64, logical: Int64) {
    let metadataItem = NSMetadataItem(url: url)
    let real = metadataItem?.value(forAttribute: "kMDItemPhysicalSize") as? Int64
    let logical = metadataItem?.value(forAttribute: "kMDItemLogicalSize") as? Int64

    if let real = real, let logical = logical {
        //        print("Found Spotlight size")
        return (real, logical)
    }

    let fallback = totalSizeOnDisk(for: url)
    //    print("Fallback to manual calculation")
    return (real ?? fallback.real, logical ?? fallback.logical)
}
