//
//  UpdateManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation
import SwiftUI
import AlinFoundation

@MainActor
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var updatesBySource: [UpdateSource: [UpdateableApp]] = [:]
    @Published var isScanning: Bool = false
    @Published var lastScanDate: Date?

    // Track apps currently being verified to prevent duplicate verification tasks
    private var verifyingApps: Set<UUID> = []

    private init() {}

    var hasUpdates: Bool {
        updatesBySource.values.contains { !$0.isEmpty }
    }

    func scanForUpdates() async {
        isScanning = true
        defer { isScanning = false }

        // Get apps from AppState
        let apps = AppState.shared.sortedApps

        // Scan for updates using coordinator
        updatesBySource = await UpdateCoordinator.scanForUpdates(apps: apps)
        lastScanDate = Date()
    }

    func updateApp(_ app: UpdateableApp) async {
        switch app.source {
        case .homebrew:
            if let cask = app.appInfo.cask {
                // Update the app status
                if var apps = updatesBySource[.homebrew],
                   let index = apps.firstIndex(where: { $0.id == app.id }) {
                    apps[index].status = .downloading
                    updatesBySource[.homebrew] = apps
                }

                // Perform upgrade
                try? await HomebrewController.shared.upgradePackage(name: cask)

                // Remove from list after upgrade
                updatesBySource[.homebrew]?.removeAll { $0.id == app.id }

                // Refresh apps
                await refreshApps()
            }

        case .appStore:
            if let adamID = app.adamID {
                // Update the app status
                if var apps = updatesBySource[.appStore],
                   let index = apps.firstIndex(where: { $0.id == app.id }) {
                    apps[index].status = .downloading
                    updatesBySource[.appStore] = apps
                }

                // Perform update
                await AppStoreUpdater.shared.updateApp(adamID: adamID) { [weak self] progress, status in
                    Task { @MainActor in
                        guard let self = self else { return }
                        if var apps = self.updatesBySource[.appStore],
                           let index = apps.firstIndex(where: { $0.id == app.id }) {
                            apps[index].progress = progress

                            // Update status based on App Store phase
                            if status.contains("Installing") {
                                // Phase 1: App Store is removing old bundle and installing new one
                                apps[index].status = .installing
                                self.updatesBySource[.appStore] = apps
                            } else if status.contains("Completed") {
                                // Phase 5: CommerceKit finished, transition to verifying
                                // Only start verification once to prevent duplicate tasks
                                if !self.verifyingApps.contains(app.id) {
                                    self.verifyingApps.insert(app.id)
                                    apps[index].status = .verifying
                                    self.updatesBySource[.appStore] = apps

                                    // Start monitoring the app bundle for version change
                                    Task {
                                        await self.waitForBundleUpdate(app: app)
                                        self.verifyingApps.remove(app.id)
                                    }
                                }
                            } else {
                                // Phase 0 or other: Keep current status or set to downloading
                                self.updatesBySource[.appStore] = apps
                            }
                        }
                    }
                }
            }

        case .sparkle:
            // Open the app so it can self-update
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            do {
                try await NSWorkspace.shared.open(app.appInfo.path, configuration: configuration)
            } catch {
                printOS("Failed to open Sparkle app: \(error.localizedDescription)")
            }
        }
    }

    func updateAll(source: UpdateSource) async {
        guard let apps = updatesBySource[source] else { return }

        for app in apps {
            await updateApp(app)
        }
    }

    /// Wait for the App Store to finish replacing the bundle on disk
    /// This monitors the app bundle and removes it from the update list once the version changes
    private func waitForBundleUpdate(app: UpdateableApp) async {
        let appPath = app.appInfo.path
        let currentVersion = app.appInfo.appVersion
        let maxAttempts = 40 // 40 attempts = ~20 seconds max wait
        let pollInterval: UInt64 = 500_000_000 // 0.5 seconds

        var bundleWasRemoved = false

        for _ in 0..<maxAttempts {
            try? await Task.sleep(nanoseconds: pollInterval)

            // Read version directly from Info.plist to avoid Bundle caching issues
            if let diskVersion = readBundleVersionDirectly(at: appPath) {
                // Strategy: Detect when bundle was removed and then reappeared with any version
                // This is more reliable than matching exact version strings since CommerceKit
                // metadata may not always match what actually gets installed
                if bundleWasRemoved {
                    // Bundle was removed and now exists again - App Store finished!
                    await removeFromUpdatesList(appID: app.id, source: .appStore)
                    await refreshApps()
                    return
                } else if diskVersion != currentVersion {
                    // Version changed without bundle removal - also a success
                    await removeFromUpdatesList(appID: app.id, source: .appStore)
                    await refreshApps()
                    return
                }
            } else {
                // Bundle doesn't exist - it's being replaced
                if !bundleWasRemoved {
                    bundleWasRemoved = true
                }
            }
        }

        // Timeout: remove from list anyway after max wait time
        if let diskVersion = readBundleVersionDirectly(at: appPath) {
            printOS("⚠️ App Store update verification timed out for \(app.appInfo.appName): final version on disk is \(diskVersion)")
        } else {
            printOS("⚠️ App Store update verification timed out for \(app.appInfo.appName): bundle still missing")
        }
        await removeFromUpdatesList(appID: app.id, source: .appStore)
        await refreshApps()
    }

    /// Read bundle version directly from Info.plist without Bundle caching
    /// This ensures we always get fresh data from disk during verification
    private func readBundleVersionDirectly(at path: URL) -> String? {
        let plistPath = path.appendingPathComponent("Contents/Info.plist")

        guard FileManager.default.fileExists(atPath: plistPath.path),
              let plistData = try? Data(contentsOf: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        // Prefer CFBundleShortVersionString, fallback to CFBundleVersion
        if let shortVersion = plist["CFBundleShortVersionString"] as? String, !shortVersion.isEmpty {
            return shortVersion
        } else if let version = plist["CFBundleVersion"] as? String, !version.isEmpty {
            return version
        }

        return nil
    }

    /// Remove an app from the updates list
    private func removeFromUpdatesList(appID: UUID, source: UpdateSource) async {
        updatesBySource[source]?.removeAll { $0.id == appID }
    }

    /// Refresh all apps after an update
    private func refreshApps() async {
        let folderPaths = await MainActor.run {
            FolderSettingsManager.shared.folderPaths
        }

        loadApps(folderPaths: folderPaths)

        // Wait for apps to load
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}
