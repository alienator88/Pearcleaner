////
////  AppPathsFetch-Async.swift
////  Pearcleaner
////
////  Created by Alin Lupascu on 6/27/24.
////
//
//import Foundation
//import AppKit
//import SwiftUI
//
//actor PathFinderState {
//    var fileSize: [URL: Int64] = [:]
//    var fileIconData: [URL: Data?] = [:]
//
//    func setFileDetails(for path: URL, size: Int64, icon: Data?) {
//        fileSize[path] = size
//        fileIconData[path] = icon
//    }
//
//    func getFileSize() -> [URL: Int64] {
//        return fileSize
//    }
//
//    func getFileIconData() -> [URL: Data?] {
//        return fileIconData
//    }
//}
//
//class AppPathFinderAsync {
//    private var appInfo: AppInfo
//    private var appState: AppState
//    private var locations: Locations
//    private var backgroundRun: Bool
//    private var reverseAddon: Bool
//    private var undo: Bool
//    private var completion: () -> Void = {}
//    private var collection: [URL] = []
//    private let collectionAccessQueue = DispatchQueue(label: "com.alienator88.Pearcleaner.appPathFinder.collectionAccess")
//    private var state = PathFinderState() // Actor instance
//
//    init(appInfo: AppInfo = .empty, appState: AppState, locations: Locations, backgroundRun: Bool = false, reverseAddon: Bool = false, undo: Bool = false, completion: @escaping () -> Void = {}) {
//        self.appInfo = appInfo
//        self.appState = appState
//        self.locations = locations
//        self.backgroundRun = backgroundRun
//        self.reverseAddon = reverseAddon
//        self.undo = undo
//        self.completion = completion
//    }
//
//    func findPaths() async {
//        await initialURLProcessing()
//        await withTaskGroup(of: Void.self) { group in
//            for location in self.locations.apps.paths {
//                group.addTask {
//                    await self.processDirectoryLocation(location)
//                }
//            }
//        }
//        await withTaskGroup(of: Void.self) { group in
//            for location in self.locations.apps.paths {
//                group.addTask {
//                    await self.processFileLocation(location)
//                }
//            }
//        }
//        await finalizeCollection()
//    }
//
//    private func initialURLProcessing() async {
//        if let url = URL(string: self.appInfo.path.absoluteString), !url.path.contains(".Trash") {
//            let modifiedUrl = url.path.contains("Wrapper") ? url.deletingLastPathComponent().deletingLastPathComponent() : url
//            collectionAccessQueue.sync {
//                self.collection.append(modifiedUrl)
//            }
//        }
//    }
//
//    private func processDirectoryLocation(_ location: String) async {
//        do {
//            let contents = try FileManager.default.contentsOfDirectory(atPath: location)
//            for item in contents {
//                let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
//                let itemL = item.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "").lowercased()
//
//                var isDirectory: ObjCBool = false
//                if FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
//                    if shouldSkipItem(itemL, at: itemURL) {
//                        continue
//                    }
//
//                    collectionAccessQueue.sync {
//                        let alreadyIncluded = self.collection.contains { existingURL in
//                            itemURL.path.hasPrefix(existingURL.path)
//                        }
//
//                        if !alreadyIncluded && specificCondition(itemL: itemL, itemURL: itemURL) {
//                            self.collection.append(itemURL)
//                        }
//                    }
//                }
//            }
//        } catch {
//            print("Error processing directory location: \(location), error: \(error)")
//        }
//    }
//
//    private func processFileLocation(_ location: String) async {
//        do {
//            let contents = try FileManager.default.contentsOfDirectory(atPath: location)
//            for item in contents {
//                let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
//                let itemL = item.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "").lowercased()
//
//                if FileManager.default.fileExists(atPath: itemURL.path),
//                   !shouldSkipItem(itemL, at: itemURL),
//                   specificCondition(itemL: itemL, itemURL: itemURL) {
//                    collectionAccessQueue.sync {
//                        self.collection.append(itemURL)
//                    }
//                }
//            }
//        } catch {
//            print("Error processing file location: \(location), error: \(error)")
//        }
//    }
//
//    private func shouldSkipItem(_ itemL: String, at itemURL: URL) -> Bool {
//        var containsItem = false
//        collectionAccessQueue.sync {
//            containsItem = self.collection.contains(itemURL)
//        }
//        if containsItem || !isSupportedFileType(at: itemURL.path) {
//            return true
//        }
//
//        for skipCondition in skipConditions {
//            if itemL.hasPrefix(skipCondition.skipPrefix) {
//                let isAllowed = skipCondition.allowPrefixes.contains(where: itemL.hasPrefix)
//                if !isAllowed {
//                    return true
//                }
//            }
//        }
//
//        return false
//    }
//
//    private func specificCondition(itemL: String, itemURL: URL) -> Bool {
//        let bundleIdentifierL = self.appInfo.bundleIdentifier.pearFormat()
//        let bundleComponents = self.appInfo.bundleIdentifier.components(separatedBy: ".").compactMap { $0 != "-" ? $0.lowercased() : nil }
//        let bundle = bundleComponents.suffix(2).joined()
//        let nameL = self.appInfo.appName.pearFormat()
//        let nameP = self.appInfo.path.lastPathComponent.replacingOccurrences(of: ".app", with: "")
//
//        for condition in conditions {
//            if bundleIdentifierL.contains(condition.bundle_id) {
//                let hasIncludeKeyword = condition.include.contains(where: itemL.contains)
//                let hasExcludeKeyword = condition.exclude.contains(where: itemL.contains)
//
//                if hasExcludeKeyword {
//                    return false
//                }
//                if hasIncludeKeyword {
//                    if !condition.exclude.contains(where: itemL.contains) {
//                        return true
//                    }
//                }
//            }
//        }
//
//        if self.appInfo.webApp {
//            return itemL.contains(bundleIdentifierL)
//        }
//
//        return itemL.contains(bundleIdentifierL) || itemL.contains(bundle) || (nameL.count > 3 && itemL.contains(nameL)) || (nameP.count > 3 && itemL.contains(nameP))
//    }
//
//    func getAllContainers(bundleURL: URL) async -> [URL] {
//        await withCheckedContinuation { continuation in
//            var containers: [URL] = []
//
//            let bundleIdentifier = Bundle(url: bundleURL)?.bundleIdentifier
//
//            guard let containerBundleIdentifier = bundleIdentifier else {
//                printOS("Get Containers: No bundle identifier found for the given bundle URL.")
//                continuation.resume(returning: containers)
//                return
//            }
//
//            if let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: containerBundleIdentifier) {
//                if FileManager.default.fileExists(atPath: groupContainer.path) {
//                    containers.append(groupContainer)
//                }
//            } else {
//                printOS("Get Containers: Failed to retrieve container URL for bundle identifier: \(containerBundleIdentifier)")
//            }
//
//            let containersPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Containers")
//
//            do {
//                let containerDirectories = try FileManager.default.contentsOfDirectory(at: containersPath!, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
//
//                let uuidRegex = try NSRegularExpression(pattern: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$", options: .caseInsensitive)
//
//                for directory in containerDirectories {
//                    let directoryName = directory.lastPathComponent
//
//                    if uuidRegex.firstMatch(in: directoryName, options: [], range: NSRange(location: 0, length: directoryName.utf16.count)) != nil {
//                        let metadataPlistURL = directory.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
//                        if let metadataDict = NSDictionary(contentsOf: metadataPlistURL), let applicationBundleID = metadataDict["MCMMetadataIdentifier"] as? String {
//                            if applicationBundleID == self.appInfo.bundleIdentifier {
//                                containers.append(directory)
//                            }
//                        }
//                    }
//                }
//            } catch {
//                printOS("Error accessing the Containers directory: \(error)")
//            }
//
//            continuation.resume(returning: containers)
//        }
//    }
//
//    private func handleOutliers(include: Bool = true) -> [URL] {
//        var outliers: [URL] = []
//        let bundleIdentifier = self.appInfo.bundleIdentifier.pearFormat()
//
//        let matchingConditions = conditions.filter { condition in
//            bundleIdentifier.contains(condition.bundle_id)
//        }
//
//        for condition in matchingConditions {
//            if include {
//                if let forceIncludes = condition.includeForce {
//                    for path in forceIncludes {
//                        outliers.append(path)
//                    }
//                }
//            } else {
//                if let excludeForce = condition.excludeForce {
//                    for path in excludeForce {
//                        outliers.append(path)
//                    }
//                }
//            }
//        }
//
//        return outliers
//    }
//
//    private func finalizeCollection() async {
//        let allContainers = await getAllContainers(bundleURL: self.appInfo.path)
//        let outliers = handleOutliers()
//        let outliersEx = handleOutliers(include: false)
//        var tempCollection: [URL] = []
//        collectionAccessQueue.sync {
//            tempCollection = self.collection
//        }
//        tempCollection.append(contentsOf: allContainers)
//        tempCollection.append(contentsOf: outliers)
//
//        let excludePaths = outliersEx.map { $0.path }
//        tempCollection.removeAll { url in
//            excludePaths.contains(url.path)
//        }
//
//        let sortedCollection = tempCollection.map { $0.standardizedFileURL }.sorted(by: { $0.path < $1.path })
//        var filteredCollection: [URL] = []
//        var previousUrl: URL?
//        for url in sortedCollection {
//            if let previousUrl = previousUrl, url.path.hasPrefix(previousUrl.path + "/") {
//                continue
//            }
//            filteredCollection.append(url)
//            previousUrl = url
//        }
//
//        await handlePostProcessing(sortedCollection: filteredCollection)
//    }
//
//    private func handlePostProcessing(sortedCollection: [URL]) async {
//        for path in sortedCollection {
//            let size = totalSizeOnDisk(for: path)
//            if let icon = getIconForFileOrFolderNS(atPath: path) {
//                let iconData = serializeImage(icon)
//                await state.setFileDetails(for: path, size: size.real, icon: iconData)
//            } else {
//                await state.setFileDetails(for: path, size: size.real, icon: nil)
//            }
//        }
//        await updateAppState(with: sortedCollection)
//    }
//
//    private func updateAppState(with sortedCollection: [URL]) async {
//        let fileSize = await self.state.getFileSize()
//        let fileIconData = await self.state.getFileIconData()
//        let fileIcons = fileIconData.mapValues { deserializeImage($0) }
//        let arch = checkAppBundleArchitecture(at: self.appInfo.path.path)
//
//        self.appInfo.fileSize = fileSize
//        self.appInfo.fileIcon = fileIcons
//        self.appInfo.arch = arch
//
//        await MainActor.run {
//            if !self.backgroundRun {
//                self.appState.appInfo = self.appInfo
//                if !self.undo {
//                    self.appState.selectedItems = Set(sortedCollection)
//                }
//            }
//
//            if self.reverseAddon {
//                self.appState.appInfoStore.append(self.appInfo)
//            }
//
//            self.completion()
//        }
//    }
//}
//
//func serializeImage(_ image: NSImage?) -> Data? {
//    guard let image = image else { return nil }
//    guard let tiffData = image.tiffRepresentation else { return nil }
//    let bitmapImage = NSBitmapImageRep(data: tiffData)
//    return bitmapImage?.representation(using: .png, properties: [:])
//}
//
//func deserializeImage(_ data: Data?) -> NSImage? {
//    guard let data = data else { return nil }
//    return NSImage(data: data)
//}
