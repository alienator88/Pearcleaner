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
    private var fileIcon: [URL: NSImage?] = [:]
    private let dispatchGroup = DispatchGroup()
    private let sortedApps: [AppInfo]
    private let streamingMode: Bool
    private var shouldStop = false

    // Cached formatted data to avoid repeated .pearFormat() calls
    private lazy var formattedExclusionList: [String] = {
        fsm.fileFolderPathsZ.map { $0.pearFormat() }
    }()

    private struct CachedAppIdentifiers {
        let formattedBundleId: String
        let formattedAppName: String
        let formattedEntitlements: [String]
    }

    private lazy var cachedAppIdentifiers: [CachedAppIdentifiers] = {
        sortedApps.map { app in
            CachedAppIdentifiers(
                formattedBundleId: app.bundleIdentifier.pearFormat(),
                formattedAppName: app.appName.pearFormat(),
                formattedEntitlements: app.entitlements?.compactMap { entitlement in
                    let formatted = entitlement.pearFormat()
                    return formatted.isEmpty ? nil : formatted
                } ?? []
            )
        }
    }()

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
        var batch: [(url: URL, size: Int64, icon: NSImage?)] = []
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

    private func processLocationStreaming(_ location: String, batch: inout [(url: URL, size: Int64, icon: NSImage?)], batchSize: Int) async {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: location)
            for scannedItemName in contents {
                if shouldStop {
                    return
                }
                let scannedItemURL = URL(fileURLWithPath: location).appendingPathComponent(scannedItemName)
                await processItemStreaming(scannedItemName, scannedItemURL: scannedItemURL, batch: &batch, batchSize: batchSize)
            }
        } catch {
            printOS("Error processing location: \(location), error: \(error)")
        }
    }

    private func processItemStreaming(_ scannedItemName: String, scannedItemURL: URL, batch: inout [(url: URL, size: Int64, icon: NSImage?)], batchSize: Int) async {
        let normalizedItemPath = scannedItemURL.path.pearFormat()

        if formattedExclusionList.contains(normalizedItemPath) || normalizedItemPath.contains("dsstore") || normalizedItemPath.contains("daemonnameoridentifierhere") || formattedExclusionList.first(where: { normalizedItemPath.contains($0) }) != nil {
            return
        }

        let normalizedItemName = scannedItemName.pearFormat()
        guard !isUUIDFormatted(normalizedItemName),
              !skipReverse.contains(where: { normalizedItemName.contains($0) }),
              isSupportedFileType(at: scannedItemURL.path),
              !isRelatedToInstalledApp(scannedItemURL: scannedItemURL),
        !isExcludedByConditions(normalizedItemPath: normalizedItemPath) else {
            return
        }

        // Calculate file details immediately
        let size = totalSizeOnDisk(for: scannedItemURL)
        let icon = getIconForFileOrFolderNS(atPath: scannedItemURL)

        // Add to batch
        batch.append((url: scannedItemURL, size: size, icon: icon))

        // Flush batch when it reaches the batch size
        if batch.count >= batchSize {
            await flushBatch(&batch)
        }
    }

    private func flushBatch(_ batch: inout [(url: URL, size: Int64, icon: NSImage?)]) async {
        let batchCopy = batch
        batch.removeAll()

        await MainActor.run {
            var updatedZombieFile = self.appState?.zombieFile ?? ZombieFile.empty
            for item in batchCopy {
                updatedZombieFile.fileSize[item.url] = item.size
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
            contents.forEach { scannedItemName in
                let scannedItemURL = URL(fileURLWithPath: location).appendingPathComponent(scannedItemName)
                processItem(scannedItemName, scannedItemURL: scannedItemURL)
            }
        } catch {
            printOS("Error processing location: \(location), error: \(error)")
        }
    }

    private func processItem(_ scannedItemName: String, scannedItemURL: URL) {
        let normalizedItemPath = scannedItemURL.path.pearFormat()

        if formattedExclusionList.contains(normalizedItemPath) || normalizedItemPath.contains("dsstore") || normalizedItemPath.contains("daemonnameoridentifierhere") || formattedExclusionList.first(where: { normalizedItemPath.contains($0) }) != nil {
            return
        }

        let normalizedItemName = scannedItemName.pearFormat()
        guard !isUUIDFormatted(normalizedItemName),
              !skipReverse.contains(where: { normalizedItemName.contains($0) }),
              isSupportedFileType(at: scannedItemURL.path),
              !isRelatedToInstalledApp(scannedItemURL: scannedItemURL),
        !isExcludedByConditions(normalizedItemPath: normalizedItemPath) else {

            return
        }

        collection.append(scannedItemURL)
    }

    private func isRelatedToInstalledApp(scannedItemURL: URL) -> Bool {
        let normalizedItemPath = scannedItemURL.path.pearFormat()

        for (_, cached) in cachedAppIdentifiers.enumerated() {
            if normalizedItemPath.contains(cached.formattedBundleId) ||
                normalizedItemPath.contains(cached.formattedAppName) {
                return true
            }

            // Check entitlements-based matching (using pre-formatted entitlements)
            for entitlementFormatted in cached.formattedEntitlements {
                if normalizedItemPath.contains(entitlementFormatted) {
                    return true
                }
            }

            // Check if the path contains /Containers or /Group Containers
            if scannedItemURL.path.contains("/Containers/") {
                let containerName = scannedItemURL.containerNameByUUID().pearFormat()
                if containerName.contains(cached.formattedBundleId) {
                    return true
                }
            }
        }
        return false
    }

    private func isExcludedByConditions(normalizedItemPath: String) -> Bool {

        for condition in conditions {
            // Ensure the condition's bundle_id matches an installed app (condition.bundle_id is already formatted in Conditions.swift)
            guard cachedAppIdentifiers.contains(where: { $0.formattedBundleId == condition.bundle_id || $0.formattedBundleId.contains(condition.bundle_id) }) else {
                continue
            }

            // Include keywords (condition.include is already formatted in Conditions.swift)
            if condition.include.contains(where: { normalizedItemPath.contains($0) }) {
                return true
            }

            // Include force
            if let includeForce = condition.includeForce,
               includeForce.contains(where: { normalizedItemPath.contains($0.path.pearFormat()) }) {
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
            fileSize[path] = size
            fileIcon[path] = getIconForFileOrFolderNS(atPath: path)
        }
    }

    private func updateAppState() {
        dispatchGroup.notify(queue: .main) {
            var updatedZombieFile = ZombieFile.empty
            updatedZombieFile.fileSize = self.fileSize
            updatedZombieFile.fileIcon = self.fileIcon
            self.appState?.zombieFile = updatedZombieFile
            self.appState?.showProgress = false
        }
    }

}


