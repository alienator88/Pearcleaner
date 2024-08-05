//
//  ReversePathsFetch.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/20/24.
//

import Foundation
import AppKit
import AlinFoundation

class ReversePathsSearcher {
    private let appState: AppState
    private let locations: Locations
    private let fsm: FolderSettingsManager
    private let fileManager = FileManager.default
    private var collection: [URL] = []
    private var fileSize: [URL: Int64] = [:]
    private var fileSizeLogical: [URL: Int64] = [:]
    private var fileIcon: [URL: NSImage?] = [:]
    private let dispatchGroup = DispatchGroup()
    private let sortedApps: [AppInfo]

    init(appState: AppState, locations: Locations, fsm: FolderSettingsManager, sortedApps: [AppInfo]) {
        self.appState = appState
        self.locations = locations
        self.fsm = fsm
        self.sortedApps = sortedApps
    }

    func reversePathsSearch(completion: @escaping () -> Void = {}) {
        Task(priority: .high) {
            self.processLocations()
            self.calculateFileDetails()
            self.updateAppState()
            completion()
        }
    }

    private func processLocations() {

        for location in locations.reverse.paths where fileManager.fileExists(atPath: location) {

            dispatchGroup.enter()
            processLocation(location)
            dispatchGroup.leave()

        }
    }

    private func processLocation(_ location: String) {

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: location)
            contents.forEach { itemName in
                let itemURL = URL(fileURLWithPath: location).appendingPathComponent(itemName)
                processItem(itemName, itemURL: itemURL)
            }
        } catch {
            printOS("Error processing location: \(location), error: \(error)")
        }
    }

    private func processItem(_ itemName: String, itemURL: URL) {
        let itemPath = itemURL.path.pearFormat()
        let exclusionList = fsm.fileFolderPathsZ.map { $0.pearFormat() }

        if exclusionList.contains(itemPath) || itemPath.contains("dsstore") || itemPath.contains("daemonnameoridentifierhere") {
            return
        }

        guard !skipReverse.contains(where: { itemName.pearFormat().contains($0) }),
              isSupportedFileType(at: itemURL.path),
              !isRelatedToInstalledApp(itemURL: itemURL),
        !isExcludedByConditions(itemPath: itemPath) else {

            return
        }

        collection.append(itemURL)
    }

    private func isRelatedToInstalledApp(itemURL: URL) -> Bool {
        let itemPath = itemURL.path.pearFormat()

        for app in sortedApps {
            if itemPath.contains(app.bundleIdentifier.pearFormat()) || 
                itemPath.contains(app.appName.pearFormat()) {
                return true
            }

            // Check if the path contains /Containers or /Group Containers
            if itemURL.path.contains("/Containers/") {
                let containerName = itemURL.containerNameByUUID().pearFormat()
                if containerName.contains(app.bundleIdentifier.pearFormat()) {
                    return true
                }
            }
        }
        return false
    }

    private func isExcludedByConditions(itemPath: String) -> Bool {

        for condition in conditions {
            // Include keywords
            if condition.include.contains(where: { itemPath.contains($0.pearFormat()) }) {
                return true
            }
            // Include force
            if let includeForce = condition.includeForce,
               includeForce.contains(where: { itemPath.contains($0.path.pearFormat()) }) {
                return true
            }
        }

        return false
    }

    private func calculateFileDetails() {
        collection.forEach { path in
            let size = totalSizeOnDisk(for: path)
            fileSize[path] = size.real
            fileSizeLogical[path] = size.logical
            fileIcon[path] = getIconForFileOrFolderNS(atPath: path)
        }
    }

    private func updateAppState() {
        dispatchGroup.notify(queue: .main) {
            var updatedZombieFile = ZombieFile.empty
            updatedZombieFile.fileSize = self.fileSize
            updatedZombieFile.fileSizeLogical = self.fileSizeLogical
            updatedZombieFile.fileIcon = self.fileIcon
            self.appState.zombieFile = updatedZombieFile
            self.appState.showProgress = false
        }
    }

}


