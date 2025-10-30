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
    @Published var hiddenUpdates: [UpdateableApp] = []
    @Published var isScanning: Bool = false
    @Published var lastScanDate: Date?
    @Published var scanningSources: Set<UpdateSource> = []
    @Published var currentScanTask: Task<Void, Never>?

    // Track apps currently being verified to prevent duplicate verification tasks
    private var verifyingApps: Set<UUID> = []

    @AppStorage("settings.updater.checkAppStore") private var checkAppStore: Bool = true
    @AppStorage("settings.updater.checkHomebrew") private var checkHomebrew: Bool = true
    @AppStorage("settings.updater.checkSparkle") private var checkSparkle: Bool = true
    @AppStorage("settings.updater.includeSparklePreReleases") private var includeSparklePreReleases: Bool = false
    @AppStorage("settings.updater.showAutoUpdatesInHomebrew") private var showAutoUpdatesInHomebrew: Bool = false
    @AppStorage("settings.updater.showUnsupported") private var showUnsupported: Bool = true
    @AppStorage("settings.updater.debugLogging") private var debugLogging: Bool = true
    @AppStorage("settings.updater.hiddenAppsData") private var hiddenAppsData: Data = Data()

    private init() {}

    var hasUpdates: Bool {
        updatesBySource.values.contains { !$0.isEmpty } || !hiddenUpdates.isEmpty
    }

    /// Computed property for easy access to hidden apps mapping (bundleID -> source)
    private var hiddenApps: [String: UpdateSource] {
        get {
            guard let decoded = try? JSONDecoder().decode([String: String].self, from: hiddenAppsData) else {
                return [:]
            }
            // Convert String to UpdateSource
            return decoded.compactMapValues { UpdateSource(rawValue: $0) }
        }
        set {
            // Convert UpdateSource to String for storage
            let stringDict = newValue.mapValues { $0.rawValue }
            hiddenAppsData = (try? JSONEncoder().encode(stringDict)) ?? Data()
        }
    }

    /// Hide an app (move to hidden category)
    func hideApp(_ app: UpdateableApp) {
        var hidden = hiddenApps
        hidden[app.uniqueIdentifier] = app.source
        hiddenApps = hidden

        // Move app from its source category to hidden
        moveAppToHidden(app)
    }

    /// Unhide an app (restore to original category)
    func unhideApp(_ app: UpdateableApp) {
        var hidden = hiddenApps
        hidden.removeValue(forKey: app.uniqueIdentifier)
        hiddenApps = hidden

        // Move app from hidden back to its original source category
        moveAppFromHidden(app)
    }

    /// Move an app from its source category to hidden
    private func moveAppToHidden(_ app: UpdateableApp) {
        // Remove from source category
        updatesBySource[app.source]?.removeAll { $0.id == app.id }

        // Add to hidden (check by bundle ID to prevent duplicates)
        if !hiddenUpdates.contains(where: { $0.uniqueIdentifier == app.uniqueIdentifier }) {
            hiddenUpdates.append(app)
        }
    }

    /// Move an app from hidden back to its original source category
    private func moveAppFromHidden(_ app: UpdateableApp) {
        // Remove from hidden
        hiddenUpdates.removeAll { $0.id == app.id }

        // Add back to source category
        if updatesBySource[app.source] == nil {
            updatesBySource[app.source] = []
        }
        if !updatesBySource[app.source]!.contains(where: { $0.id == app.id }) {
            updatesBySource[app.source]!.append(app)
        }
    }

    /// Toggle selection state for an app in the update queue
    func toggleAppSelection(_ app: UpdateableApp) {
        guard var apps = updatesBySource[app.source],
              let index = apps.firstIndex(where: { $0.id == app.id }) else { return }

        apps[index].isSelectedForUpdate.toggle()
        updatesBySource[app.source] = apps
    }

    func scanForUpdates(forceReload: Bool = false) async {
        isScanning = true
        defer { isScanning = false }

        // Clear previous results and mark all enabled sources as scanning
        updatesBySource = [:]
        hiddenUpdates = []  // Clear to prevent stale entries (will be rebuilt from persistent storage)
        scanningSources = []
        if checkAppStore { scanningSources.insert(.appStore) }
        if checkHomebrew { scanningSources.insert(.homebrew) }
        if checkSparkle { scanningSources.insert(.sparkle) }

        // Only flush caches and reload apps if explicitly requested or debug mode enabled
        // This significantly improves performance for regular update checks
        if forceReload || debugLogging {
            // Flush bundle caches (useful for testing with fake versions in debug mode)
            Pearcleaner.flushBundleCaches(for: AppState.shared.sortedApps)

            // Reload apps from disk to detect newly installed/uninstalled apps
            let folderPaths = await MainActor.run {
                FolderSettingsManager.shared.folderPaths
            }
            await loadAppsAsync(folderPaths: folderPaths)
        }

        // Check for cancellation after loading apps
        if Task.isCancelled {
            return
        }

        // Use apps from AppState (either freshly loaded or existing)
        let apps = AppState.shared.sortedApps

        // Launch concurrent scans with progressive updates
        await withTaskGroup(of: (UpdateSource, [UpdateableApp]).self) { group in
            if checkHomebrew {
                group.addTask {
                    let results = await HomebrewUpdateChecker.checkForUpdates(apps: apps, includeFormulae: false, showAutoUpdatesInHomebrew: self.showAutoUpdatesInHomebrew)
                    return (.homebrew, results)
                }
            }

            if checkAppStore {
                group.addTask {
                    // Use pre-categorized flag (instant check vs expensive receipt verification)
                    let appStoreApps = apps.filter { $0.isAppStore }
                    let results = await AppStoreUpdateChecker.checkForUpdates(apps: appStoreApps)
                    return (.appStore, results)
                }
            }

            if checkSparkle {
                group.addTask {
                    // Show all apps with Sparkle, regardless of other update sources
                    // This allows users to see version differences across App Store/Homebrew/Sparkle
                    // and choose which source to update from
                    let sparkleApps = apps.filter { $0.hasSparkle }

                    let results = await SparkleUpdateChecker.checkForUpdates(apps: sparkleApps, includePreReleases: self.includeSparklePreReleases)
                    return (.sparkle, results)
                }
            }

            // Process results as they complete
            for await (source, apps) in group {
                // Check for cancellation between source results
                if Task.isCancelled {
                    break
                }
                await processSourceResults(source: source, apps: apps)
            }
        }

        // Check for cancellation before final processing
        if Task.isCancelled {
            return
        }

        // Calculate unsupported apps (always calculate - it's instant, toggle only controls UI visibility)
        let unsupportedApps = apps.filter { app in
            // Not a web app (web apps update with browser)
            !app.webApp &&
            // Not an App Store app
            !app.isAppStore &&
            // Not a Homebrew cask/formula
            app.cask == nil &&
            // Doesn't have Sparkle
            !app.hasSparkle
        }.map { app in
            // Create UpdateableApp with unsupported source
            UpdateableApp(
                appInfo: app,
                availableVersion: nil,  // Can't check updates
                availableBuildNumber: nil,
                source: .unsupported,
                adamID: nil,
                appStoreURL: nil,
                status: .idle,
                progress: 0.0,
                isSelectedForUpdate: false,  // Can't update unsupported apps
                releaseTitle: nil,
                releaseDescription: nil,
                releaseNotesLink: nil,
                releaseDate: nil,
                isPreRelease: false,
                isIOSApp: false
            )
        }

        await processSourceResults(source: .unsupported, apps: unsupportedApps)

        lastScanDate = Date()

        // Print formatted debug report to console after scan completes
        if debugLogging {
            printOS("\n" + UpdaterDebugLogger.shared.generateDebugReport())
        }

        // Clear task reference on completion
        currentScanTask = nil
    }

    private func processSourceResults(source: UpdateSource, apps: [UpdateableApp]) async {
        // Sort alphabetically
        let sortedApps = apps.sorted { $0.appInfo.appName.localizedCaseInsensitiveCompare($1.appInfo.appName) == .orderedAscending }

        // Filter hidden apps
        let hidden = hiddenApps
        let visible = sortedApps.filter { !hidden.keys.contains($0.uniqueIdentifier) }
        let hiddenAppsFromSource = sortedApps.filter { hidden.keys.contains($0.uniqueIdentifier) }

        // Update results (set to empty array even if no visible results to indicate "completed")
        updatesBySource[source] = visible

        // Add hidden apps to hidden list
        for app in hiddenAppsFromSource {
            if !hiddenUpdates.contains(where: { $0.uniqueIdentifier == app.uniqueIdentifier }) {
                hiddenUpdates.append(app)
            }
        }

        // Mark source as no longer scanning
        scanningSources.remove(source)
    }

    /// Cancel the current scan operation
    func cancelScan() {
        currentScanTask?.cancel()
        currentScanTask = nil
        scanningSources.removeAll()  // Clear scanning state for all sources
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
                do {
                    try await HomebrewController.shared.upgradePackage(name: cask)

                    // Only remove from list if upgrade succeeded
                    updatesBySource[.homebrew]?.removeAll { $0.id == app.id }

                    // Refresh apps (only flush updated app's bundle for performance)
                    await refreshApps(updatedApp: app.appInfo)
                } catch {
                    // Update status to failed on error
                    if var apps = updatesBySource[.homebrew],
                       let index = apps.firstIndex(where: { $0.id == app.id }) {
                        apps[index].status = .failed(error.localizedDescription)
                        apps[index].progress = 0.0  // Reset progress indicator
                        updatesBySource[.homebrew] = apps
                    }
                    printOS("Error updating Homebrew package \(cask): \(error)")
                }
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
            // Use Sparkle's updater via UpdateQueue to prevent concurrent update conflicts
            // SPUUpdater will automatically get feed URL from Info.plist via delegate

            // Check if update already queued/running for this app
            if UpdateQueue.shared.containsOperation(for: app.appInfo.bundleIdentifier) {
                UpdaterDebugLogger.shared.log(.sparkle, "⚠️ Update already queued for \(app.appInfo.appName)")
                printOS("Update already queued for \(app.appInfo.appName)")
                return
            }

            UpdaterDebugLogger.shared.log(.sparkle, "═══ Initiating update for \(app.appInfo.appName)")
            UpdaterDebugLogger.shared.log(.sparkle, "  Bundle ID: \(app.appInfo.bundleIdentifier)")
            UpdaterDebugLogger.shared.log(.sparkle, "  Current version: \(app.appInfo.appVersion)")
            UpdaterDebugLogger.shared.log(.sparkle, "  Target version: \(app.availableVersion ?? "unknown")")

            // Set initial downloading status
            updateStatus(for: app, status: .downloading, progress: 0.0)

            // Create Sparkle update operation (blocks until completion)
            let operation = SparkleUpdateOperation(
                app: app,
                includePreReleases: self.includeSparklePreReleases,
                progressCallback: { [weak self] progress, status in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.updateStatus(for: app, status: status, progress: progress)
                    }
                },
                completionCallback: { [weak self] success, error in
                    guard let self = self else { return }
                    Task { @MainActor in
                        if success {
                            UpdaterDebugLogger.shared.log(.sparkle, "═══ Update completed successfully for \(app.appInfo.appName)")
                            // Update completed - remove from list and refresh (only flush updated app's bundle)
                            await self.removeFromUpdatesList(appID: app.id, source: .sparkle)
                            await self.refreshApps(updatedApp: app.appInfo)
                        } else {
                            // Update failed - show error
                            let message = error?.localizedDescription ?? "Unknown error"
                            UpdaterDebugLogger.shared.log(.sparkle, "═══ Update failed for \(app.appInfo.appName): \(message)")
                            self.updateStatus(for: app, status: .failed(message), progress: 0.0)
                        }
                    }
                }
            )

            // Add to queue (limits concurrent operations to prevent Sparkle conflicts)
            UpdateQueue.shared.addOperation(operation)

        case .unsupported:
            // Unsupported apps cannot be updated - do nothing
            UpdaterDebugLogger.shared.log(.sparkle, "⚠️ Cannot update unsupported app: \(app.appInfo.appName)")
            break
        }
    }

    func updateAll(source: UpdateSource) async {
        guard let apps = updatesBySource[source] else { return }

        // Only update apps that are selected for update
        let selectedApps = apps.filter { $0.isSelectedForUpdate }

        for app in selectedApps {
            await updateApp(app)
        }
    }

    /// Update all selected apps across all sources (concurrent per-source)
    func updateSelectedApps() async {
        await withTaskGroup(of: Void.self) { group in
            // Process each source's updates concurrently in separate Tasks
            for source in UpdateSource.allCases {
                if let apps = updatesBySource[source] {
                    let selectedApps = apps.filter { $0.isSelectedForUpdate }
                    if !selectedApps.isEmpty {
                        group.addTask {
                            // Within each source, process apps sequentially
                            for app in selectedApps {
                                await self.updateApp(app)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Update the status and progress of an app in the updates list
    private func updateStatus(for app: UpdateableApp, status: UpdateStatus, progress: Double) {
        if var apps = updatesBySource[app.source],
           let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].status = status
            apps[index].progress = progress
            updatesBySource[app.source] = apps
        }
    }

    // REMOVED: refreshSparkleAppWithURL - no longer needed with simplified Sparkle approach
    // Alternate feed URLs are not supported when using SPUUpdater directly

    /// Wait for the App Store to finish replacing the bundle on disk
    /// This monitors the app bundle and removes it from the update list once the version changes
    private func waitForBundleUpdate(app: UpdateableApp) async {
        let appPath = app.appInfo.path
        let currentVersion = app.appInfo.appVersion
        let maxAttempts = 40 // 40 attempts = ~20 seconds max wait
        let pollInterval: UInt64 = 1_000_000_000 // 1 second

        var bundleWasRemoved = false

        for _ in 0..<maxAttempts {
            try? await Task.sleep(nanoseconds: pollInterval)

            // Read version directly from Info.plist to avoid Bundle caching issues
            if let diskVersion = readBundleVersionDirectly(at: appPath, wrapped: app.appInfo.wrapped) {
                // Strategy: Detect when bundle was removed and then reappeared with any version
                // This is more reliable than matching exact version strings since CommerceKit
                // metadata may not always match what actually gets installed
                if bundleWasRemoved {
                    // Bundle was removed and now exists again - App Store finished!
                    await removeFromUpdatesList(appID: app.id, source: .appStore)
                    await refreshApps(updatedApp: app.appInfo)
                    return
                } else if diskVersion != currentVersion {
                    // Version changed without bundle removal - also a success
                    await removeFromUpdatesList(appID: app.id, source: .appStore)
                    await refreshApps(updatedApp: app.appInfo)
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
        if let diskVersion = readBundleVersionDirectly(at: appPath, wrapped: app.appInfo.wrapped) {
            printOS("⚠️ App Store update verification timed out for \(app.appInfo.appName): final version on disk is \(diskVersion)")
        } else {
            printOS("⚠️ App Store update verification timed out for \(app.appInfo.appName): bundle still missing")
        }
        await removeFromUpdatesList(appID: app.id, source: .appStore)
        await refreshApps()
    }

    /// Read bundle version directly from Info.plist without Bundle caching
    /// This ensures we always get fresh data from disk during verification
    private func readBundleVersionDirectly(at path: URL, wrapped: Bool) -> String? {
        if wrapped {
            // iPad/iOS app: read version from iTunesMetadata.plist
            // For wrapped apps, path points to the inner bundle (e.g., /Applications/X.app/Wrapper/Twitter.app/)
            // We need to go up 2 levels to get to the outer wrapper (e.g., /Applications/X.app/)
            let outerWrapperPath = path.deletingLastPathComponent().deletingLastPathComponent()
            let iTunesMetadataPath = outerWrapperPath.appendingPathComponent("Wrapper/iTunesMetadata.plist")

            guard let plistData = try? Data(contentsOf: iTunesMetadataPath),
                  let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
                return nil
            }

            // Read from iTunesMetadata.plist (uses different keys than Info.plist)
            if let version = plist["bundleShortVersionString"] as? String, !version.isEmpty {
                return version
            } else if let version = plist["bundleVersion"] as? String, !version.isEmpty {
                return version
            }

            return nil
        } else {
            // Standard Mac app: Contents/Info.plist
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
    }

    /// Remove an app from the updates list
    private func removeFromUpdatesList(appID: UUID, source: UpdateSource) async {
        updatesBySource[source]?.removeAll { $0.id == appID }
    }

    /// Refresh all apps after an update
    /// - Parameter updatedApp: Optional specific app that was updated (only flushes that bundle for performance)
    private func refreshApps(updatedApp: AppInfo? = nil) async {
        let folderPaths = await MainActor.run {
            FolderSettingsManager.shared.folderPaths
        }

        // Only flush cache for the app that was just updated (or all if none specified)
        if let app = updatedApp {
            Pearcleaner.flushBundleCaches(for: [app])
        } else {
            Pearcleaner.flushBundleCaches(for: AppState.shared.sortedApps)
        }

        await loadAppsAsync(folderPaths: folderPaths)
    }
}
