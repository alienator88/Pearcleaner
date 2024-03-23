//
//  AppPathsFetch.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/20/24.
//

import Foundation
import AppKit
import SwiftUI

class AppPathFinder {
    private var appInfo: AppInfo
    private var appState: AppState
    private var locations: Locations
    private var backgroundRun: Bool
    private var completion: () -> Void = {}
    private var collection: [URL] = []
    private let collectionAccessQueue = DispatchQueue(label: "com.alienator88.Pearcleaner.appPathFinder.collectionAccess")
    @AppStorage("settings.general.instant") var instantSearch: Bool = true

    init(appInfo: AppInfo = .empty, appState: AppState, locations: Locations, backgroundRun: Bool = false, completion: @escaping () -> Void = {}) {
        self.appInfo = appInfo
        self.appState = appState
        self.locations = locations
        self.backgroundRun = backgroundRun
        self.completion = completion
    }

    func findPaths() {
        Task(priority: .background) {
            self.initialURLProcessing()
            let dispatchGroup = DispatchGroup()

            for location in self.locations.apps.paths {
                dispatchGroup.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    self.processLocation(location, with: dispatchGroup)
                    dispatchGroup.leave()
                }
            }

            dispatchGroup.notify(queue: .main) {
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

    private func processLocation(_ location: String, with dispatchGroup: DispatchGroup) {
        // Check if the directory exists before attempting to read its contents
        if FileManager.default.fileExists(atPath: location) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: location)

                for item in contents {
                    let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
                    let itemL = item.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "").lowercased()

                    if shouldSkipItem(itemL, at: itemURL) { continue }

                    if specificCondition(itemL: itemL, itemURL: itemURL) {
                        collectionAccessQueue.async {
                            self.collection.append(itemURL)
                        }
                    }
                }
            } catch {
                // If an error occurs while trying to read the directory's contents, log or handle it here if needed
                printOS("Error processing location: \(location), \(error)")
            }
        } else {
            // The directory does not exist; skip it
        }
    }

    private func shouldSkipItem(_ itemL: String, at itemURL: URL) -> Bool {
        var containsItem = false
        collectionAccessQueue.sync {
            containsItem = self.collection.contains(itemURL)
        }
        return itemL.hasPrefix("comapple") && !["comappleconfigurator", "comappledt", "comappleiwork"].contains(where: itemL.hasPrefix) || containsItem || !isSupportedFileType(at: itemURL.path)
    }

    private func specificCondition(itemL: String, itemURL: URL) -> Bool {
        let bundleIdentifierL = self.appInfo.bundleIdentifier.pearFormat()
        let bundleComponents = self.appInfo.bundleIdentifier.components(separatedBy: ".").compactMap { $0 != "-" ? $0.lowercased() : nil }
        let bundle = bundleComponents.suffix(2).joined()
        let nameL = self.appInfo.appName.pearFormat()
        let nameP = self.appInfo.path.lastPathComponent.replacingOccurrences(of: ".app", with: "")

        if self.appInfo.webApp {
            return itemL.contains(bundleIdentifierL)
        } else {
            if itemL.contains("xcode") && bundleIdentifierL.contains("comappledt") {
                return !(itemURL.path.contains("comrobotsandpencilsxcodesapp") || itemURL.path.contains("comoneminutegamesxcodecleaner") || itemURL.path.contains("iohyperappxcodecleaner") || itemURL.path.contains("xcodesjson")) && (itemL.contains(bundle) || itemL.contains(bundleIdentifierL) || (nameL.count < 6 && itemL.contains(nameL)))
            } else if itemL.contains("xcodes") && bundleIdentifierL.contains("comrobotsandpencilsxcodesapp") {
                return !(itemURL.path.contains("comappledt")) && (itemL.contains(bundle) || itemL.contains(bundleIdentifierL) || (nameL.count > 4 && itemL.contains(nameL)))
            } else {
                return itemL.contains(bundleIdentifierL) || itemL.contains(bundle) || (nameL.count > 3 && itemL.contains(nameL)) || (nameP.count > 3 && itemL.contains(nameP))
            }
        }
    }



    private func filterParentDirectories(in collection: [URL]) -> [URL] {
        // Normalize URLs by removing percent encoding and trailing slashes for accurate comparison
        var filteredURLs: [URL] = []
        let normalizedURLs = collection.map { url -> URL in
            let path = url.path.removingPercentEncoding?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
            return URL(fileURLWithPath: path)
        }

        for url in normalizedURLs {
            // Determine if 'url' is a parent of any path in 'filteredURLs'
            if !filteredURLs.contains(where: { $0.absoluteString.hasPrefix(url.absoluteString) }) {
                filteredURLs.append(url)
            }
        }

        // Remove URLs that are parents of another URL in the list
        filteredURLs = filteredURLs.filter { parentUrl in
            !filteredURLs.contains { childUrl in
                childUrl != parentUrl && childUrl.absoluteString.hasPrefix(parentUrl.absoluteString)
            }
        }

        return filteredURLs
    }


    private func getGroupContainers(bundleURL: URL) -> [URL] {
        // Get group containers
        var staticCode: SecStaticCode?

        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess else {
            return []
        }

        var signingInformation: CFDictionary?

        let status = SecCodeCopySigningInformation(staticCode!, SecCSFlags(), &signingInformation)

        if status != errSecSuccess {
            printOS("Failed to copy signing information. Status: \(status)")
            return []
        }

        guard let topDict = signingInformation as? [String: Any],
              let entitlementsDict = topDict["entitlements-dict"] as? [String: Any],
              let appGroups = entitlementsDict["com.apple.security.application-groups"] as? [String] else {
            //        printOS("No application groups to extract from entitlements for this app.")
            return []
        }

        let groupContainersPath = appGroups.map { URL(fileURLWithPath: "\(home)/Library/Group Containers/" + $0) }
        let existingGroupContainers = groupContainersPath.filter { FileManager.default.fileExists(atPath: $0.path) }

        return existingGroupContainers
    }

    private func finalizeCollection() {
        DispatchQueue.global(qos: .userInitiated).async {
            let groupContainers = self.getGroupContainers(bundleURL: self.appInfo.path)
            var tempCollection: [URL] = []
            self.collectionAccessQueue.sync {
                tempCollection = self.collection
            }
            tempCollection.append(contentsOf: groupContainers)

            // Apply the filter to remove parent directories
            let filteredCollection = self.filterParentDirectories(in: tempCollection)
            
            // Continue with the sorted collection
            let sortedCollection = filteredCollection.sorted(by: { $0.absoluteString < $1.absoluteString })
            self.handlePostProcessing(sortedCollection: sortedCollection)
        }

    }

    private func handlePostProcessing(sortedCollection: [URL]) {
        // Calculate file details (sizes and icons), update app state, and call completion
        var fileSize: [URL: Int64] = [:]
        var fileIcon: [URL: NSImage?] = [:]

        for path in sortedCollection {
            fileSize[path] = totalSizeOnDisk(for: path)
            fileIcon[path] = getIconForFileOrFolderNS(atPath: path)
        }

        DispatchQueue.main.async {
            var updatedCollection = sortedCollection
            if updatedCollection.count == 1, let firstURL = updatedCollection.first, firstURL.path.contains(".Trash") {
                updatedCollection.removeAll()
            }

            // Update appInfo and appState with the new values
            self.appInfo.files = updatedCollection
            self.appInfo.fileSize = fileSize
            self.appInfo.fileIcon = fileIcon

            if !self.backgroundRun {
                self.appState.appInfo = self.appInfo
                self.appState.selectedItems = Set(updatedCollection)
            }

            // Only append object to store if instant search. Same for calculating progress.
            if self.instantSearch {
                self.appState.appInfoStore.append(self.appInfo)
                self.appState.instantProgress += 1
            }

            self.completion()
        }
    }
}



//assert(!Thread.isMainThread, "This method should not run on the main thread")
