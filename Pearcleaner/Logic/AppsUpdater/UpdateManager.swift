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
    @AppStorage("settings.updater.ignoredAppsData") private var ignoredAppsData: Data = Data()

    private var hasAutoScannedOnce = false

    private init() {
        // Migrate old hiddenApps data to new ignoredApps format on first launch
        migrateHiddenAppsIfNeeded()

        // Subscribe to notification for automatic background scanning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAllAppsFullyLoaded),
            name: NSNotification.Name("AllAppsFullyLoaded"),
            object: nil
        )
    }

    @objc private func handleAllAppsFullyLoaded() {
        // Only run once per app session
        guard !hasAutoScannedOnce else { return }
        hasAutoScannedOnce = true

        Task { @MainActor in
            await scanIfNeeded()
        }
    }

    /// Public entry point for triggering scans. Prevents duplicate scans through centralized logic.
    /// - Parameter forceReload: If true, bypasses cache and forces a fresh scan
    func scanIfNeeded(forceReload: Bool = false) async {
        // Prevent duplicate scans
        guard !isScanning else { return }

        // If forcing reload, always scan
        if forceReload {
            await scanForUpdates(forceReload: true)
            return
        }

        // Otherwise, only scan if no data exists yet
        guard lastScanDate == nil else { return }
        await scanForUpdates()
    }

    var hasUpdates: Bool {
        updatesBySource.values.contains { !$0.isEmpty } || !hiddenUpdates.isEmpty
    }

    var totalUpdateCount: Int {
        updatesBySource
            .filter { $0.key != .unsupported && $0.key != .current }
            .values
            .reduce(0) { $0 + $1.count }
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

    /// Unified ignored apps storage: bundleID -> [source -> version?]
    /// nil version = permanently ignored, string version = skip until newer version
    private var ignoredApps: [String: [String: String?]] {
        get {
            guard let decoded = try? JSONDecoder().decode([String: [String: String?]].self, from: ignoredAppsData) else {
                return [:]
            }
            return decoded
        }
        set {
            ignoredAppsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// Migrate old hiddenApps data to new ignoredApps format (one-time migration)
    private func migrateHiddenAppsIfNeeded() {
        // Only migrate if old data exists and new data is empty
        guard !hiddenAppsData.isEmpty, ignoredAppsData.isEmpty else { return }

        var migrated: [String: [String: String?]] = [:]
        for (bundleID, source) in hiddenApps {
            // Convert to new format with nil version (permanent ignore)
            migrated[bundleID] = [source.rawValue: nil]
        }

        ignoredApps = migrated
        // Keep old data for now in case user downgrades
    }

    /// Get the ignored version for a specific app and source
    /// - Parameter app: The app to check
    /// - Returns: nil if permanently ignored, version string if skipped, or nil if not ignored for this source
    func getIgnoredVersion(for app: UpdateableApp) -> String? {
        return ignoredApps[app.uniqueIdentifier]?[app.source.rawValue] ?? nil
    }

    /// Update the fetched release notes for a specific app
    /// - Parameters:
    ///   - appId: The UUID of the app to update
    ///   - content: The fetched release notes content
    func updateFetchedReleaseNotes(for appId: UUID, content: String) {
        // Find and update the app in updatesBySource
        for (source, apps) in updatesBySource {
            if let index = apps.firstIndex(where: { $0.id == appId }) {
                var updatedApp = apps[index]
                updatedApp.fetchedReleaseNotes = content
                updatesBySource[source]?[index] = updatedApp
                return
            }
        }
    }

    /// Hide an app permanently or skip a specific version
    /// - Parameters:
    ///   - app: The app to ignore
    ///   - skipVersion: Optional version to skip. If nil, app is permanently ignored. If provided, only that version is skipped.
    func hideApp(_ app: UpdateableApp, skipVersion: String? = nil) {
        // Add to new unified ignored apps storage
        var ignored = ignoredApps
        if ignored[app.uniqueIdentifier] == nil {
            ignored[app.uniqueIdentifier] = [:]
        }
        ignored[app.uniqueIdentifier]?[app.source.rawValue] = skipVersion

        ignoredApps = ignored

        // Also update old storage for backward compatibility
        if skipVersion == nil {
            var hidden = hiddenApps
            hidden[app.uniqueIdentifier] = app.source
            hiddenApps = hidden
        }

        // Immediately remove from visible lists for instant UI feedback
        updatesBySource[app.source]?.removeAll { $0.uniqueIdentifier == app.uniqueIdentifier }

        // Add to hidden list for sidebar display
        if !hiddenUpdates.contains(where: { $0.uniqueIdentifier == app.uniqueIdentifier }) {
            hiddenUpdates.append(app)
        }
    }

    /// Rescan a single app to get fresh update data
    func recheckUpdate(for app: UpdateableApp) async -> UpdateableApp? {
        // Get fresh AppInfo from sortedApps (handles case where app was updated externally)
        guard let freshAppInfo = AppState.shared.sortedApps.first(where: {
            $0.bundleIdentifier == app.uniqueIdentifier
        }) else {
            return nil // App no longer exists
        }

        // Call appropriate source-specific checker based on app.source
        switch app.source {
        case .homebrew:
            let results = await HomebrewUpdateChecker.checkForUpdates(
                apps: [freshAppInfo],
                includeFormulae: false,
                showAutoUpdatesInHomebrew: showAutoUpdatesInHomebrew
            )
            return results.first

        case .appStore:
            let results = await AppStoreUpdateChecker.checkForUpdates(apps: [freshAppInfo])
            return results.first

        case .sparkle:
            let results = await SparkleUpdateChecker.checkForUpdates(
                apps: [freshAppInfo],
                includePreReleases: includeSparklePreReleases
            )
            return results.first

        case .unsupported:
            return nil // Can't check unsupported apps

        case .current:
            return nil // Already current, no update available
        }
    }

    /// Unhide an app (remove from hidden filter and restore to visible list if it has an update)
    func unhideApp(_ app: UpdateableApp) async {
        // Remove from new unified ignored apps storage
        var ignored = ignoredApps
        ignored[app.uniqueIdentifier]?.removeValue(forKey: app.source.rawValue)
        if ignored[app.uniqueIdentifier]?.isEmpty == true {
            ignored.removeValue(forKey: app.uniqueIdentifier)
        }
        ignoredApps = ignored

        // Also remove from old storage for backward compatibility
        var hidden = hiddenApps
        hidden.removeValue(forKey: app.uniqueIdentifier)
        hiddenApps = hidden

        // Immediately remove from hidden list for instant UI feedback
        hiddenUpdates.removeAll { $0.uniqueIdentifier == app.uniqueIdentifier }

        // Rescan the app to get fresh update data
        if let refreshedApp = await recheckUpdate(for: app) {
            // Add refreshed app to visible list
            if var apps = updatesBySource[app.source] {
                apps.append(refreshedApp)
                updatesBySource[app.source] = apps
            } else {
                updatesBySource[app.source] = [refreshedApp]
            }
        }
        // If nil returned, no update available anymore - don't add to visible list
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

        // Filter out ignored apps BEFORE checking for updates
        // This prevents wasting time on HEAD requests and SPUUpdater calls for ignored apps
        let ignoredAppIds = Set(ignoredApps.keys)
        let visibleApps = apps.filter { !ignoredAppIds.contains($0.bundleIdentifier) }

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

        // Calculate current apps (supported but up-to-date - no updates available)
        let currentApps = apps.filter { app in
            // Not a web app
            !app.webApp &&
            // Must be supported (App Store, Homebrew, or Sparkle)
            (app.isAppStore || app.cask != nil || app.hasSparkle) &&
            // But doesn't have an update available in any of the update sources
            !updatesBySource.values.flatMap { $0 }.contains(where: { $0.appInfo.path == app.path })
        }.map { app in
            // Create UpdateableApp with current source
            UpdateableApp(
                appInfo: app,
                availableVersion: app.appVersion,  // Already up-to-date
                availableBuildNumber: nil,
                source: .current,
                adamID: nil,
                appStoreURL: nil,
                status: .idle,
                progress: 0.0,
                isSelectedForUpdate: false,  // Already current, no update needed
                releaseTitle: nil,
                releaseDescription: nil,
                releaseNotesLink: nil,
                releaseDate: nil,
                isPreRelease: false,
                isIOSApp: false,
                foundInRegion: nil,
                fetchedReleaseNotes: nil,
                appcastItem: nil
            )
        }

        await processSourceResults(source: .current, apps: currentApps)

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

        // Filter ignored and version-skipped apps
        let ignored = ignoredApps
        let visible = sortedApps.filter { app in
            // Check if app is in ignored list
            guard let ignoredVersions = ignored[app.uniqueIdentifier],
                  let ignoredVersion = ignoredVersions[source.rawValue] else {
                return true // Not ignored, show it
            }

            // If ignoredVersion is nil, permanently ignored
            if ignoredVersion == nil {
                return false
            }

            // If ignoredVersion matches availableVersion, skip this version
            if let availableVersion = app.availableVersion,
               availableVersion == ignoredVersion {
                return false
            }

            // Newer version available, show it
            return true
        }
        let hiddenAppsFromSource = sortedApps.filter { app in
            guard let ignoredVersions = ignored[app.uniqueIdentifier],
                  let ignoredVersion = ignoredVersions[source.rawValue] else {
                return false
            }
            return ignoredVersion == nil || app.availableVersion == ignoredVersion
        }

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

        case .current:
            // Current apps are already up-to-date - do nothing
            UpdaterDebugLogger.shared.log(.sparkle, "ℹ️ App is already current: \(app.appInfo.appName)")
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
