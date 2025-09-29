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
    private let appState: AppState?
    private let locations: Locations
    private let fsm: FolderSettingsManager
    private let fileManager = FileManager.default
    private var collection: [URL] = []
    private var fileSize: [URL: Int64] = [:]
    private var fileSizeLogical: [URL: Int64] = [:]
    private var fileIcon: [URL: NSImage?] = [:]
    private let dispatchGroup = DispatchGroup()
    private let sortedApps: [AppInfo]
    private let streamingMode: Bool
    private var shouldStop = false

    init(appState: AppState? = nil, locations: Locations, fsm: FolderSettingsManager, sortedApps: [AppInfo], streamingMode: Bool = true) {
        self.appState = appState
        self.locations = locations
        self.fsm = fsm
        self.sortedApps = sortedApps
        self.streamingMode = streamingMode
    }

    func stop() {
        shouldStop = true
    }

    func reversePathsSearch(completion: @escaping () -> Void = {}) {
        Task(priority: .high) {
            if streamingMode {
                await self.processLocationsStreaming()
            } else {
                self.processLocations()
                self.calculateFileDetails()
                self.updateAppState()
            }
            completion()
        }
    }

    private func processLocationsStreaming() async {
        var batch: [(url: URL, size: (real: Int64, logical: Int64), icon: NSImage?)] = []
        let batchSize = 10

        for location in locations.reverse.paths where fileManager.fileExists(atPath: location) {
            if shouldStop {
                break
            }
            await processLocationStreaming(location, batch: &batch, batchSize: batchSize)
        }

        // Flush any remaining items
        if !batch.isEmpty {
            await flushBatch(&batch)
        }

        // Mark scanning as complete
        await MainActor.run {
            self.appState?.showProgress = false
        }
    }

    private func processLocationStreaming(_ location: String, batch: inout [(url: URL, size: (real: Int64, logical: Int64), icon: NSImage?)], batchSize: Int) async {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: location)
            for itemName in contents {
                if shouldStop {
                    return
                }
                let itemURL = URL(fileURLWithPath: location).appendingPathComponent(itemName)
                await processItemStreaming(itemName, itemURL: itemURL, batch: &batch, batchSize: batchSize)
            }
        } catch {
            printOS("Error processing location: \(location), error: \(error)")
        }
    }

    private func processItemStreaming(_ itemName: String, itemURL: URL, batch: inout [(url: URL, size: (real: Int64, logical: Int64), icon: NSImage?)], batchSize: Int) async {
        let itemPath = itemURL.path.pearFormat()
        let exclusionList = fsm.fileFolderPathsZ.map { $0.pearFormat() }

        if exclusionList.contains(itemPath) || itemPath.contains("dsstore") || itemPath.contains("daemonnameoridentifierhere") || exclusionList.first(where: { itemPath.contains($0) }) != nil {
            return
        }
        guard !isUUIDFormatted(itemName.pearFormat()),
              !skipReverse.contains(where: { itemName.pearFormat().contains($0) }),
              isSupportedFileType(at: itemURL.path),
              !isRelatedToInstalledApp(itemURL: itemURL),
        !isExcludedByConditions(itemPath: itemPath) else {
            return
        }

        // Calculate file details immediately
        let size = totalSizeOnDisk(for: itemURL)
        let icon = getIconForFileOrFolderNS(atPath: itemURL)

        // Add to batch
        batch.append((url: itemURL, size: size, icon: icon))

        // Flush batch when it reaches the batch size
        if batch.count >= batchSize {
            await flushBatch(&batch)
        }
    }

    private func flushBatch(_ batch: inout [(url: URL, size: (real: Int64, logical: Int64), icon: NSImage?)]) async {
        let batchCopy = batch
        batch.removeAll()

        await MainActor.run {
            var updatedZombieFile = self.appState?.zombieFile ?? ZombieFile.empty
            for item in batchCopy {
                updatedZombieFile.fileSize[item.url] = item.size.real
                updatedZombieFile.fileSizeLogical[item.url] = item.size.logical
                updatedZombieFile.fileIcon[item.url] = item.icon
            }
            self.appState?.zombieFile = updatedZombieFile
        }
    }

    func reversePathsSearchCLI() -> [URL] {
            self.processLocationsCLI()
        return collection
    }

    private func processLocations() {
        for location in locations.reverse.paths where fileManager.fileExists(atPath: location) {
            dispatchGroup.enter()
            processLocation(location)
            dispatchGroup.leave()
        }
    }

    private func processLocationsCLI() {
        for location in locations.reverse.paths where fileManager.fileExists(atPath: location) {
            processLocation(location)
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

        if exclusionList.contains(itemPath) || itemPath.contains("dsstore") || itemPath.contains("daemonnameoridentifierhere") || exclusionList.first(where: { itemPath.contains($0) }) != nil {
            return
        }
        guard !isUUIDFormatted(itemName.pearFormat()),
              !skipReverse.contains(where: { itemName.pearFormat().contains($0) }),
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

            // Check entitlements-based matching
            if let entitlements = app.entitlements {
                for entitlement in entitlements {
                    let entitlementFormatted = entitlement.pearFormat()
                    if !entitlementFormatted.isEmpty && itemPath.contains(entitlementFormatted) {
                        return true
                    }
                }
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
            // Ensure the condition's bundle_id matches an installed app
            guard sortedApps.contains(where: { $0.bundleIdentifier.pearFormat() == condition.bundle_id.pearFormat() || $0.bundleIdentifier.pearFormat().contains(condition.bundle_id.pearFormat()) }) else {
                continue
            }

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

    private func isUUIDFormatted(_ fileName: String) -> Bool {
        let uuidRegex = "^[0-9a-fA-F]{32}$" // UUID without dashes
        let regex = try? NSRegularExpression(pattern: uuidRegex)
        let range = NSRange(location: 0, length: fileName.utf16.count)
        return regex?.firstMatch(in: fileName, options: [], range: range) != nil
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
            self.appState?.zombieFile = updatedZombieFile
            self.appState?.showProgress = false
        }
    }

}


