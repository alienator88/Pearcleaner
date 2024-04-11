//
//  AppPathsFetch-NEW.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/4/24.
//

import Foundation
import AppKit
import SwiftUI

class AppPathFinder {
    private var appInfo: AppInfo
    private var appState: AppState
    private var locations: Locations
    private var backgroundRun: Bool
    private var reverseAddon: Bool
    private var completion: () -> Void = {}
    private var collection: [URL] = []
    private let collectionAccessQueue = DispatchQueue(label: "com.alienator88.Pearcleaner.appPathFinder.collectionAccess")
    @AppStorage("settings.general.instant") var instantSearch: Bool = true

    init(appInfo: AppInfo = .empty, appState: AppState, locations: Locations, backgroundRun: Bool = false, reverseAddon: Bool = false, completion: @escaping () -> Void = {}) {
        self.appInfo = appInfo
        self.appState = appState
        self.locations = locations
        self.backgroundRun = backgroundRun
        self.reverseAddon = reverseAddon
        self.completion = completion
    }

    func findPaths() {
        Task(priority: .background) {
            self.initialURLProcessing()
            self.collectDirectories()
            self.collectFiles()
            self.finalizeCollection()
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
        return itemL.hasPrefix("comapple") && !["comappleconfigurator", "comappledt", "comappleiwork", "comapplesfsymbols", "comappletestflight"].contains(where: itemL.hasPrefix) || containsItem || !isSupportedFileType(at: itemURL.path)
    }





    private func specificCondition(itemL: String, itemURL: URL) -> Bool {
        let bundleIdentifierL = self.appInfo.bundleIdentifier.pearFormat()
        let bundleComponents = self.appInfo.bundleIdentifier.components(separatedBy: ".").compactMap { $0 != "-" ? $0.lowercased() : nil }
        let bundle = bundleComponents.suffix(2).joined()
        let nameL = self.appInfo.appName.pearFormat()
        let nameP = self.appInfo.path.lastPathComponent.replacingOccurrences(of: ".app", with: "")

        let exclusions = [
            "comappledtxcode": ["comrobotsandpencilsxcodesapp", "comoneminutegamesxcodecleaner", "iohyperappxcodecleaner", "xcodesjson"],
            "comrobotsandpencilsxcodesapp": ["comappledtxcode", "comoneminutegamesxcodecleaner", "iohyperappxcodecleaner"],
            "iohyperappxcodecleaner": ["comrobotsandpencilsxcodesapp", "comoneminutegamesxcodecleaner", "comappledtxcode", "xcodesjson"]
        ]

        if let excludedApps = exclusions[bundleIdentifierL], excludedApps.contains(where: { itemL.contains($0) }) {
            return false
        }

        if bundleIdentifierL.contains("comappledtxcode") {
            // Include items that are part of the Xcode ecosystem
            if itemL.contains("comappledt") || itemL.contains("xcode") || itemL.contains("simulator") {
                return true
            }
        }

        if bundleIdentifierL.contains("uszoomxos") {
            // Include items for Zoom that are not similar to the app name and/or bundle id
            if itemL.contains("zoom") {
                return true
            }
        }

        if bundleIdentifierL.contains("combravebrowser") {
            // Include items for Brave that are not similar to the app name and/or bundle id
            if itemL.contains("brave") {
                return true
            }
        }

        if bundleIdentifierL.contains("comgooglechrome") {
            // Include items for Chrome that are not similar to the app name and/or bundle id
            if (itemL.contains("google") && !itemL.contains("iterm")) || (itemL.contains("chrome")  && !itemL.contains("chromefeaturestate")) {
                return true
            }
        }

        if bundleIdentifierL.contains("commicrosoftedgemac") {
            // Include items for Edge that are not similar to the app name and/or bundle id
            let exclusions = ["vscode","rdc","appcenter","office","oneauth"]
            if itemL.contains("microsoft") && !exclusions.contains(where: itemL.contains) {
                return true
            }
        }

        if bundleIdentifierL.contains("orgmozillafirefox") {
            // Include items for Firefox that are not similar to the app name and/or bundle id
            if itemL.contains("mozilla") {
                return true
            }
        }

        if bundleIdentifierL.contains("comlogioptionsplus") {
            // Include items for Zoom that are not similar to the app name and/or bundle id
            if itemL.contains("logi") && !itemL.contains("login") && !itemL.contains("logic") {
                return true
            }
        }

        if bundleIdentifierL.contains("commicrosoftvscode") {
            // Include items for vscode
            if itemL.contains("vscode") {
                return true
            }
        }


        if bundleIdentifierL.contains("comfacebookarchondeveloperid") {
            // Include items for FB Messenger
            if itemL.contains("archonloginhelper") {
                return true
            }
        }

        if bundleIdentifierL.contains("euexelbanstats") {
            // Include items for Stats that are not similar to the app name and/or bundle id
            if itemL.contains("video") {
                return false
            }
        }


        if self.appInfo.webApp {
            return itemL.contains(bundleIdentifierL)
        }

        return itemL.contains(bundleIdentifierL) || itemL.contains(bundle) || (nameL.count > 3 && itemL.contains(nameL)) || (nameP.count > 3 && itemL.contains(nameP))

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


    private func handleOutliers() -> [URL] {
        var outliers: [URL] = []

        // Handle VSCode folder
        if self.appInfo.bundleIdentifier.pearFormat().contains("commicrosoftvscode") {
            let appSupportCodePath = "\(home)/Library/Application Support/Code"
            if let codeDirectoryURL = URL(string: appSupportCodePath), FileManager.default.fileExists(atPath: codeDirectoryURL.path) {
                outliers.append(codeDirectoryURL)
            }
        }

        // Handle Xcode folder
        if self.appInfo.bundleIdentifier.pearFormat().contains("comappledtxcode") {
            let simulators = "\(home)/Library/Containers/com.apple.iphonesimulator.ShareExtension"
            if let simulatorsURL = URL(string: simulators), FileManager.default.fileExists(atPath: simulatorsURL.path) {
                outliers.append(simulatorsURL)
            }
        }

        // Add other outlier cases here as needed

        return outliers
    }

    private func finalizeCollection() {
        DispatchQueue.global(qos: .userInitiated).async {
            let groupContainers = self.getGroupContainers(bundleURL: self.appInfo.path)
            let outliers = self.handleOutliers()
            var tempCollection: [URL] = []
            self.collectionAccessQueue.sync {
                tempCollection = self.collection
            }
            tempCollection.append(contentsOf: groupContainers)
            tempCollection.append(contentsOf: outliers)

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

            // Append object to store if running reverse search with empty store
            if self.reverseAddon {
                self.appState.appInfoStore.append(self.appInfo)
            }

            self.completion()
        }
    }
}
