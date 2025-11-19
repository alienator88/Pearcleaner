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

    /// Hide an app (add to hidden filter, remove from visible lists, trigger rescan)
    func hideApp(_ app: UpdateableApp) {
        // Add to persistent hidden storage
        var hidden = hiddenApps
        hidden[app.uniqueIdentifier] = app.source
        hiddenApps = hidden

        // Immediately remove from visible lists for instant UI feedback
        updatesBySource[app.source]?.removeAll { $0.uniqueIdentifier == app.uniqueIdentifier }

        // Add to hidden list for sidebar display
        if !hiddenUpdates.contains(where: { $0.uniqueIdentifier == app.uniqueIdentifier }) {
            hiddenUpdates.append(app)
        }

        // Rescan to ensure filtering is applied
        Task { await scanForUpdates() }
    }

    /// Unhide an app (remove from hidden filter, trigger rescan to check for updates)
    func unhideApp(_ app: UpdateableApp) {
        // Remove from persistent hidden storage
        var hidden = hiddenApps
        hidden.removeValue(forKey: app.uniqueIdentifier)
        hiddenApps = hidden

        // Immediately remove from hidden list for instant UI feedback
        hiddenUpdates.removeAll { $0.uniqueIdentifier == app.uniqueIdentifier }

        // Rescan to check for updates now that app is unhidden
        Task { await scanForUpdates() }
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
        if forceReload || debugLogging || AppState.shared.sortedApps.isEmpty {
            // Flush bundle caches (useful for testing with fake versions in debug mode)
            Pearcleaner.flushBundleCaches(for: AppState.shared.sortedApps)

            // Reload apps from disk to detect newly installed/uninstalled apps
            let folderPaths = await MainActor.run {
                FolderSettingsManager.shared.folderPaths
            }
            await loadAppsAsync(folderPaths: folderPaths, useStreaming: false)
        }

        // Check for cancellation after loading apps
        if Task.isCancelled {
            return
        }

        // Use apps from AppState (either freshly loaded or existing)
        let apps = AppState.shared.sortedApps

        // Filter out hidden apps BEFORE checking for updates
        // This prevents wasting time on HEAD requests and SPUUpdater calls for hidden apps
        let hiddenAppIds = Set(hiddenApps.keys)
        let visibleApps = apps.filter { !hiddenAppIds.contains($0.bundleIdentifier) }

        // Launch concurrent scans with progressive updates
        await withTaskGroup(of: (UpdateSource, [UpdateableApp]).self) { group in
            if checkHomebrew {
                group.addTask {
                    let results = await HomebrewUpdateChecker.checkForUpdates(apps: visibleApps, includeFormulae: false, showAutoUpdatesInHomebrew: self.showAutoUpdatesInHomebrew)
                    return (.homebrew, results)
                }
            }

            if checkAppStore {
                group.addTask {
                    // Use pre-categorized flag (instant check vs expensive receipt verification)
                    let appStoreApps = visibleApps.filter { $0.isAppStore }
                    let results = await AppStoreUpdateChecker.checkForUpdates(apps: appStoreApps)
                    return (.appStore, results)
                }
            }

            if checkSparkle {
                group.addTask {
                    // Show all apps with Sparkle, regardless of other update sources
                    // This allows users to see version differences across App Store/Homebrew/Sparkle
                    // and choose which source to update from
                    let sparkleApps = visibleApps.filter { $0.hasSparkle }

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

        // Deduplicate: Remove Homebrew apps that also exist in Sparkle (when auto_updates=true and toggle is ON)
        // Rationale: If an app has both Homebrew cask and Sparkle framework with auto_updates=true,
        // prefer the developer's choice (built-in Sparkle updater) and avoid showing in both categories
        if showAutoUpdatesInHomebrew, let homebrewApps = updatesBySource[.homebrew], let sparkleApps = updatesBySource[.sparkle] {
            // Build set of Sparkle app paths for quick lookup
            let sparkleAppPaths = Set(sparkleApps.map { $0.appInfo.path })

            // Filter out Homebrew apps that have both:
            // 1. auto_updates=true (developer chose built-in updater)
            // 2. Sparkle framework (exists in Sparkle category)
            let deduplicatedHomebrew = homebrewApps.filter { brewApp in
                guard let autoUpdates = brewApp.appInfo.autoUpdates, autoUpdates else {
                    return true  // Keep: no auto_updates flag
                }

                // Exclude if app also exists in Sparkle (prefer Sparkle)
                return !sparkleAppPaths.contains(brewApp.appInfo.path)
            }

            // Update with deduplicated list
            updatesBySource[.homebrew] = deduplicatedHomebrew
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
                isIOSApp: false,
                foundInRegion: nil,
                appcastItem: nil
            )
        }

        await processSourceResults(source: .unsupported, apps: unsupportedApps)

        // Rebuild hidden apps list for display
        // This ensures ALL hidden apps appear in the sidebar, even those without updates
        await rebuildHiddenAppsList(allApps: apps)

        lastScanDate = Date()

        // Print formatted debug report to console after scan completes
        if debugLogging {
            printOS("\n" + UpdaterDebugLogger.shared.generateDebugReport())
        }

        // Clear task reference on completion
        currentScanTask = nil
    }

    /// Rebuild hidden apps list from storage for display in sidebar
    /// This populates hiddenUpdates with ALL hidden apps (even those without updates)
    private func rebuildHiddenAppsList(allApps: [AppInfo]) async {
        let hidden = hiddenApps

        // For each hidden app in storage, create an UpdateableApp for display
        for (bundleID, source) in hidden {
            // Skip if already in hiddenUpdates (was found during update check)
            if hiddenUpdates.contains(where: { $0.uniqueIdentifier == bundleID }) {
                continue
            }

            // Find the app in sortedApps
            guard let appInfo = allApps.first(where: { $0.bundleIdentifier == bundleID }) else {
                // App no longer exists, remove from hidden storage
                var mutableHidden = hidden
                mutableHidden.removeValue(forKey: bundleID)
                hiddenApps = mutableHidden
                continue
            }

            // Create UpdateableApp without update info (just for display)
            let updateableApp = UpdateableApp(
                appInfo: appInfo,
                availableVersion: nil,
                availableBuildNumber: nil,
                source: source,
                adamID: nil,
                appStoreURL: nil,
                status: .idle,
                progress: 0.0,
                isSelectedForUpdate: false,
                releaseTitle: nil,
                releaseDescription: nil,
                releaseNotesLink: nil,
                releaseDate: nil,
                isPreRelease: false,
                isIOSApp: false,
                foundInRegion: nil,
                appcastItem: nil
            )

            hiddenUpdates.append(updateableApp)
        }
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
        isScanning = false  // Immediately update UI state
        currentScanTask?.cancel()
        currentScanTask = nil
        scanningSources.removeAll()  // Clear scanning state for all sources
    }

    func updateApp(_ app: UpdateableApp) async {
        switch app.source {
        case .homebrew:
            if let cask = app.appInfo.cask {
                GlobalConsoleManager.shared.appendOutput("Starting Homebrew update for \(app.appInfo.appName) (\(cask))...\n", source: CurrentPage.updater.title)

                // Update the app status
                if var apps = updatesBySource[.homebrew],
                   let index = apps.firstIndex(where: { $0.id == app.id }) {
                    apps[index].status = .downloading
                    updatesBySource[.homebrew] = apps
                }

                // Perform upgrade
                do {
                    try await HomebrewController.shared.upgradePackage(name: cask)

                    GlobalConsoleManager.shared.appendOutput("✓ Successfully updated \(app.appInfo.appName) to version \(app.availableVersion ?? "unknown")\n", source: CurrentPage.updater.title)

                    // Only remove from list if upgrade succeeded
                    updatesBySource[.homebrew]?.removeAll { $0.id == app.id }

                    // Refresh apps (only flush updated app's bundle for performance)
                    await refreshApps(updatedApp: app.appInfo)
                } catch {
                    GlobalConsoleManager.shared.appendOutput("✗ Failed to update \(app.appInfo.appName): \(error.localizedDescription)\n", source: CurrentPage.updater.title)

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
                GlobalConsoleManager.shared.appendOutput("Starting App Store update for \(app.appInfo.appName) (adamID: \(adamID))...\n", source: CurrentPage.updater.title)

                // Update the app status
                if var apps = updatesBySource[.appStore],
                   let index = apps.firstIndex(where: { $0.id == app.id }) {
                    apps[index].status = .downloading
                    updatesBySource[.appStore] = apps
                }

                // Perform update (new API throws errors)
                do {
                    try await AppStoreUpdater.shared.updateApp(adamID: adamID, appPath: app.appInfo.path, isIOSApp: app.isIOSApp) { [weak self] progress, status in
                        Task { @MainActor in
                            guard let self = self else { return }
                            if var apps = self.updatesBySource[.appStore],
                               let index = apps.firstIndex(where: { $0.id == app.id }) {
                                apps[index].progress = progress

                                // Update status based on App Store phase
                                if status.contains("Downloading") || status.contains("Preparing") {
                                    // Phase 0 or 4: Downloading or preparing
                                    apps[index].status = .downloading
                                    self.updatesBySource[.appStore] = apps
                                } else if status.contains("Installing") {
                                    // Phase 1: Installing
                                    apps[index].status = .installing
                                    self.updatesBySource[.appStore] = apps
                                } else if status.contains("Completed") || status.contains("Already up to date") {
                                    // Phase 5 or no download needed: Complete - remove from list and refresh
                                    Task {
                                        await self.removeFromUpdatesList(appID: app.id, source: .appStore)
                                        await self.refreshApps(updatedApp: app.appInfo)
                                    }
                                } else {
                                    // Other phases: Keep updating progress but maintain current status
                                    self.updatesBySource[.appStore] = apps
                                }
                            }
                        }
                    }

                    // Update succeeded - refresh happens via completion callback above
                    UpdaterDebugLogger.shared.log(.appStore, "✅ App Store update completed for adamID \(adamID)")
                    GlobalConsoleManager.shared.appendOutput("✓ Successfully updated \(app.appInfo.appName) from App Store\n", source: CurrentPage.updater.title)

                } catch {
                    // Handle errors from the new throwing API
                    let message = error.localizedDescription
                    printOS("❌ App Store update failed for adamID \(adamID): \(message)")
                    GlobalConsoleManager.shared.appendOutput("✗ Failed to update \(app.appInfo.appName) from App Store: \(message)\n", source: CurrentPage.updater.title)

                    // Update UI to show error (matching Sparkle's error display pattern)
                    if var apps = updatesBySource[.appStore],
                       let index = apps.firstIndex(where: { $0.id == app.id }) {
                        apps[index].status = .failed(message)
                        apps[index].progress = 0.0
                        updatesBySource[.appStore] = apps
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
                GlobalConsoleManager.shared.appendOutput("⚠ Update already queued for \(app.appInfo.appName)\n", source: CurrentPage.updater.title)
                return
            }

            GlobalConsoleManager.shared.appendOutput("Starting Sparkle update for \(app.appInfo.appName) (target version: \(app.availableVersion ?? "unknown"))...\n", source: CurrentPage.updater.title)

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
                            GlobalConsoleManager.shared.appendOutput("✓ Successfully updated \(app.appInfo.appName) via Sparkle\n", source: CurrentPage.updater.title)
                            // Update completed - remove from list and refresh (only flush updated app's bundle)
                            await self.removeFromUpdatesList(appID: app.id, source: .sparkle)
                            await self.refreshApps(updatedApp: app.appInfo)
                        } else {
                            // Update failed - show error
                            let message = error?.localizedDescription ?? "Unknown error"
                            UpdaterDebugLogger.shared.log(.sparkle, "═══ Update failed for \(app.appInfo.appName): \(message)")
                            GlobalConsoleManager.shared.appendOutput("✗ Failed to update \(app.appInfo.appName) via Sparkle: \(message)\n", source: CurrentPage.updater.title)
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

    /// Update an iOS app from the App Store
    func updateIOSApp(_ app: UpdateableApp) async {
        guard app.isIOSApp, let adamID = app.adamID else {
            printOS("❌ Not an iOS app or missing adamID")
            GlobalConsoleManager.shared.appendOutput("✗ Not an iOS app or missing adamID for \(app.appInfo.appName)\n", source: CurrentPage.updater.title)
            return
        }

        GlobalConsoleManager.shared.appendOutput("Starting iOS app update for \(app.appInfo.appName) (adamID: \(adamID))...\n", source: CurrentPage.updater.title)

        // Update status
        if var apps = updatesBySource[.appStore],
           let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].status = .downloading
            apps[index].progress = 0.0
            updatesBySource[.appStore] = apps
        }

        // Call AppStoreUpdater to download (which will trigger our observer)
        do {
            try await AppStoreUpdater.shared.updateApp(
                adamID: adamID,
                appPath: app.appInfo.path,
                isIOSApp: true,
                progress: { [weak self] progress, status in
                    Task { @MainActor in
                        guard let self = self else { return }
                        if var apps = self.updatesBySource[.appStore],
                           let index = apps.firstIndex(where: { $0.id == app.id }) {
                            apps[index].progress = progress

                            // Update status based on App Store phase (match real updateApp logic)
                            if status.contains("Downloading") || status.contains("Preparing") {
                                // Phase 0 or 4: Downloading or preparing
                                apps[index].status = .downloading
                                self.updatesBySource[.appStore] = apps
                            } else if status.contains("Installing") {
                                // Phase 1: Installing
                                apps[index].status = .installing
                                self.updatesBySource[.appStore] = apps
                            } else if status.contains("Completed") || status.contains("Already up to date") {
                                // Phase 5 or no download needed: Complete - remove from list and refresh
                                Task {
                                    await self.removeFromUpdatesList(appID: app.id, source: .appStore)
                                    await self.refreshApps(updatedApp: app.appInfo)
                                }
                            } else {
                                // Other phases: Keep updating progress but maintain current status
                                self.updatesBySource[.appStore] = apps
                            }
                        }
                    }
                }
            )
            GlobalConsoleManager.shared.appendOutput("✓ Successfully updated iOS app \(app.appInfo.appName)\n", source: CurrentPage.updater.title)
        } catch {
            printOS("❌ iOS app update failed: \(error)")
            GlobalConsoleManager.shared.appendOutput("✗ Failed to update iOS app \(app.appInfo.appName): \(error.localizedDescription)\n", source: CurrentPage.updater.title)
            if var apps = updatesBySource[.appStore],
               let index = apps.firstIndex(where: { $0.id == app.id }) {
                apps[index].status = .failed("Open in App Store to update using the App Store button to the left.")
                updatesBySource[.appStore] = apps
            }
        }
    }

    func updateAll(source: UpdateSource) async {
        guard let apps = updatesBySource[source] else { return }

        // Only update apps that are selected for update
        let selectedApps = apps.filter { $0.isSelectedForUpdate }

        GlobalConsoleManager.shared.appendOutput("Starting batch update for \(selectedApps.count) app(s) from \(source.rawValue)...\n", source: CurrentPage.updater.title)

        for app in selectedApps {
            await updateApp(app)
        }

        GlobalConsoleManager.shared.appendOutput("Batch update completed for \(source.rawValue)\n", source: CurrentPage.updater.title)
    }

    /// Update all selected apps across all sources (concurrent per-source)
    func updateSelectedApps() async {
        // Count total selected apps across all sources
        let totalSelected = updatesBySource.values.flatMap { $0 }.filter { $0.isSelectedForUpdate }.count
        GlobalConsoleManager.shared.appendOutput("Starting updates for \(totalSelected) selected app(s) across all sources...\n", source: CurrentPage.updater.title)

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

        GlobalConsoleManager.shared.appendOutput("All selected updates completed\n", source: CurrentPage.updater.title)
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

        await loadAppsAsync(folderPaths: folderPaths, useStreaming: false)
    }
}
