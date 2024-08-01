//
//  AppPathsFetch-NEW.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/4/24.
//

import Foundation
import AppKit
import SwiftUI
import AlinFoundation

class AppPathFinder {
    private var appInfo: AppInfo
    private var appState: AppState
    private var locations: Locations
    private var backgroundRun: Bool
//    private var reverseAddon: Bool
    private var undo: Bool
    private var completion: () -> Void = {}
    private var collection: [URL] = []
    private let collectionAccessQueue = DispatchQueue(label: "com.alienator88.Pearcleaner.appPathFinder.collectionAccess")

    init(appInfo: AppInfo = .empty, appState: AppState, locations: Locations, backgroundRun: Bool = false, undo: Bool = false, completion: @escaping () -> Void = {}) {
        self.appInfo = appInfo
        self.appState = appState
        self.locations = locations
        self.backgroundRun = backgroundRun
//        self.reverseAddon = reverseAddon
        self.undo = undo
        self.completion = completion
    }

    func findPaths() {
        Task(priority: .background) {
            if self.appInfo.webApp {
                self.initialURLProcessing()
                self.finalizeCollection()
            } else {
                self.initialURLProcessing()
                self.collectDirectories()
                self.collectFiles()
                self.finalizeCollection()
            }

        }
    }

    private func initialURLProcessing() {
        if let url = URL(string: self.appInfo.path.absoluteString), !url.path.contains(".Trash") {
            let modifiedUrl = url.path.contains("Wrapper") ? url.deletingLastPathComponent().deletingLastPathComponent() : url
            self.collection.append(modifiedUrl)
        }
    }

    private func collectDirectories() {
        let dispatchGroup = DispatchGroup()

        for location in self.locations.apps.paths {
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                self.processDirectoryLocation(location)
                dispatchGroup.leave()
            }
        }

        dispatchGroup.wait()
    }

    private func processDirectoryLocation(_ location: String) {
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: location) {
            for item in contents {
                let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
                let itemL = item.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "").lowercased()

                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    // Perform the check to skip the item if needed
                    if shouldSkipItem(itemL, at: itemURL) {
                        continue
                    }

                    collectionAccessQueue.sync {
                        let alreadyIncluded = self.collection.contains { existingURL in
                            itemURL.path.hasPrefix(existingURL.path)
                        }

                        if !alreadyIncluded && specificCondition(itemL: itemL, itemURL: itemURL) {
                            self.collection.append(itemURL)
                        }
                    }
                }
            }
        }
    }

    private func collectFiles() {
        let dispatchGroup = DispatchGroup()

        for location in self.locations.apps.paths {
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                self.processFileLocation(location)
                dispatchGroup.leave()
            }
        }

        dispatchGroup.wait()
    }

    private func processFileLocation(_ location: String) {
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: location) {
            for item in contents {
                let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
                let itemL = item.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "").lowercased()

                if FileManager.default.fileExists(atPath: itemURL.path),
                   !shouldSkipItem(itemL, at: itemURL),
                   specificCondition(itemL: itemL, itemURL: itemURL) {
                    collectionAccessQueue.sync {
                        self.collection.append(itemURL)
                    }
                }
            }
        }
    }



    private func shouldSkipItem(_ itemL: String, at itemURL: URL) -> Bool {
        var containsItem = false
        collectionAccessQueue.sync {
            containsItem = self.collection.contains(itemURL)
        }
        if containsItem || !isSupportedFileType(at: itemURL.path) {
            return true
        }

        for skipCondition in skipConditions {
            if itemL.hasPrefix(skipCondition.skipPrefix) {
                let isAllowed = skipCondition.allowPrefixes.contains(where: itemL.hasPrefix)
                if !isAllowed {
                    return true // Skip because it starts with a base prefix but is not in the allowed list
                }
            }
        }

        return false
    }



    private func specificCondition(itemL: String, itemURL: URL) -> Bool {
        let bundleIdentifierL = self.appInfo.bundleIdentifier.pearFormat()
        let bundleComponents = self.appInfo.bundleIdentifier.components(separatedBy: ".").compactMap { $0 != "-" ? $0.lowercased() : nil }
        let bundle = bundleComponents.suffix(2).joined()
        let nameL = self.appInfo.appName.pearFormat()
        let nameP = self.appInfo.path.lastPathComponent.replacingOccurrences(of: ".app", with: "")

        for condition in conditions {
            if bundleIdentifierL.contains(condition.bundle_id) {
                // Exclude keywords
                let hasExcludeKeyword = condition.exclude.contains(where: itemL.contains)
                if hasExcludeKeyword {
                    return false
                }
                // Include keywords
                let hasIncludeKeyword = condition.include.contains(where: itemL.contains)
                if hasIncludeKeyword {
                    return true
                }
            }
        }


        if self.appInfo.webApp {
            return itemL.contains(bundleIdentifierL)
        }

        return itemL.contains(bundleIdentifierL) || itemL.contains(bundle) || (nameL.count > 3 && itemL.contains(nameL)) || (nameP.count > 3 && itemL.contains(nameP))

    }


    private func getAllContainers(bundleURL: URL) -> [URL] {
        var containers: [URL] = []

        // Extract bundle identifier from bundleURL
        let bundleIdentifier = Bundle(url: bundleURL)?.bundleIdentifier

        // Ensure the bundleIdentifier is not nil
        guard let containerBundleIdentifier = bundleIdentifier else {
            printOS("Get Containers: No bundle identifier found for the given bundle URL.")
            return containers  // Returns whatever was found so far, possibly empty
        }

        // Get the regular container URL for the extracted bundle identifier
        if let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: containerBundleIdentifier) {
            if FileManager.default.fileExists(atPath: groupContainer.path) {
                containers.append(groupContainer)
            }
        } else {
            printOS("Get Containers: Failed to retrieve container URL for bundle identifier: \(containerBundleIdentifier)")
        }

        let containersPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Containers")

        do {
            let containerDirectories = try FileManager.default.contentsOfDirectory(at: containersPath!, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

            // Define a regular expression to match UUID format
            let uuidRegex = try NSRegularExpression(pattern: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$", options: .caseInsensitive)

            for directory in containerDirectories {
                let directoryName = directory.lastPathComponent

                // Check if the directory name matches the UUID pattern
                if uuidRegex.firstMatch(in: directoryName, options: [], range: NSRange(location: 0, length: directoryName.utf16.count)) != nil {
                    // Attempt to read the metadata plist file
                    let metadataPlistURL = directory.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
                    if let metadataDict = NSDictionary(contentsOf: metadataPlistURL), let applicationBundleID = metadataDict["MCMMetadataIdentifier"] as? String {
                        if applicationBundleID == self.appInfo.bundleIdentifier {
                            containers.append(directory)
                        }
                    }
                }
            }
        } catch {
            printOS("Error accessing the Containers directory: \(error)")
        }

        // Return all found containers
        return containers
    }


    private func handleOutliers(include: Bool = true) -> [URL] {
        var outliers: [URL] = []
        let bundleIdentifier = self.appInfo.bundleIdentifier.pearFormat()

        // Find conditions that match the current app's bundle identifier
        let matchingConditions = conditions.filter { condition in
            bundleIdentifier.contains(condition.bundle_id)
        }


        for condition in matchingConditions {
            if include {
                // Handle includeForce
                if let forceIncludes = condition.includeForce {
                    for path in forceIncludes {
                        outliers.append(path)
                    }
                }
            } else {
                // Handle excludeForce
                if let excludeForce = condition.excludeForce {
                    for path in excludeForce {
                        outliers.append(path)
                    }
                }
            }

        }

        return outliers
    }

    private func finalizeCollection() {
        DispatchQueue.global(qos: .userInitiated).async {
            let allContainers = self.getAllContainers(bundleURL: self.appInfo.path)
            let outliers = self.handleOutliers()
            let outliersEx = self.handleOutliers(include: false)
            var tempCollection: [URL] = []
            self.collectionAccessQueue.sync {
                tempCollection = self.collection
            }
            tempCollection.append(contentsOf: allContainers)
            tempCollection.append(contentsOf: outliers)

            // Remove URLs based on outliersExcludes
            let excludePaths = outliersEx.map { $0.path }
            tempCollection.removeAll { url in
                excludePaths.contains(url.path)
            }

            // Sort and standardize URLs to ensure consistent comparisons
            let sortedCollection = tempCollection.map { $0.standardizedFileURL }.sorted(by: { $0.path < $1.path })
            var filteredCollection: [URL] = []
            var previousUrl: URL?
            for url in sortedCollection {
                if let previousUrl = previousUrl, url.path.hasPrefix(previousUrl.path + "/") {
                    // Current URL is a subdirectory of the previous one, so skip it
                    continue
                }
                // This URL is not a subdirectory of the previous one, so keep it and set it as the previous URL
                filteredCollection.append(url)
                previousUrl = url
            }

            self.handlePostProcessing(sortedCollection: filteredCollection)
        }

    }

    private func handlePostProcessing(sortedCollection: [URL]) {
        // Calculate file details (sizes and icons), update app state, and call completion
        var fileSize: [URL: Int64] = [:]
        var fileSizeLogical: [URL: Int64] = [:]
        var fileIcon: [URL: NSImage?] = [:]

        for path in sortedCollection {
            let size = totalSizeOnDisk(for: path)
            fileSize[path] = size.real
            fileSizeLogical[path] = size.logical
            fileIcon[path] = getIconForFileOrFolderNS(atPath: path)
        }

        let arch = checkAppBundleArchitecture(at: self.appInfo.path.path)

        DispatchQueue.main.async {
            var updatedCollection = sortedCollection
            if updatedCollection.count == 1, let firstURL = updatedCollection.first, firstURL.path.contains(".Trash") {
                updatedCollection.removeAll()
            }

            // Update appInfo and appState with the new values
            self.appInfo.fileSize = fileSize
            self.appInfo.fileSizeLogical = fileSizeLogical
            self.appInfo.fileIcon = fileIcon
            self.appInfo.arch = arch

            if !self.backgroundRun {
                self.appState.appInfo = self.appInfo
                if !self.undo {
                    self.appState.selectedItems = Set(updatedCollection)
                }
            }

            // Append object to store if running reverse search with empty store
//            if self.reverseAddon {
//                self.appState.appInfoStore.append(self.appInfo)
//            }

            self.completion()
        }
    }
}
