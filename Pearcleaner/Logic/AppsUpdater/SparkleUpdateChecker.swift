//
//  SparkleUpdateChecker.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/28/25.
//
//  Simplified Sparkle update checker using SPUUpdater directly
//

import Foundation
import Sparkle

/// Result of Sparkle update check - makes Sparkle's decision explicit
private enum SparkleUpdateResult {
    /// Sparkle found a valid update (always trust this)
    case updateFound(
        appcastItem: SUAppcastItem,
        state: SPUUserUpdateState
    )

    /// Sparkle says no update needed
    case noUpdate(
        reason: SPUNoUpdateFoundReason,
        latestItem: SUAppcastItem?  // May be nil if feed is empty
    )

    /// Sparkle encountered an error
    case error(Error)
}

class SparkleUpdateChecker {
    fileprivate static let logger = UpdaterDebugLogger.shared

    /// Cached current macOS version (computed once per session)
    private static let currentMacOSVersion: Version = {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        return Version(versionNumber: versionString, buildNumber: nil)
    }()

    /// Check for Sparkle updates using SPUUpdater directly
    /// Only checks apps with SUFeedURL in Info.plist (no binary scanning)
    static func checkForUpdates(apps: [AppInfo], includePreReleases: Bool) async -> [UpdateableApp] {
        logger.log(.sparkle, "Starting Sparkle update check for \(apps.count) apps (includePreReleases: \(includePreReleases))")

        // Filter apps that have Sparkle feed URLs
        var sparkleApps: [(appInfo: AppInfo, bundle: Bundle, feedURL: URL)] = []

        for appInfo in apps {
            guard let bundle = Bundle(url: appInfo.path) else { continue }

            guard let feedURL = Self.feedURL(from: bundle) else { continue }

            logger.log(.sparkle, "Checking: \(appInfo.appName) - \(feedURL.absoluteString)")
            sparkleApps.append((appInfo, bundle, feedURL))
        }

        guard !sparkleApps.isEmpty else {
            logger.log(.sparkle, "No Sparkle apps with valid feed URLs found")
            return []
        }

        // Check apps in batches to prevent system resource exhaustion
        // Batch size adapts to CPU core count (min: 5, max: 50)
        // Lower minimum helps Intel Macs complete scans faster while still being safe
        var updates: [UpdateableApp] = []
        let batches = createOptimalChunks(from: sparkleApps, minChunkSize: 5, maxChunkSize: 50)

        // Process each batch concurrently
        for batch in batches {
            // Check for cancellation between batches
            if Task.isCancelled {
                break
            }

            let batchResults = await withTaskGroup(of: UpdateableApp?.self) { group in
                for (appInfo, bundle, feedURL) in batch {
                    group.addTask {
                        await Self.checkSingleApp(appInfo: appInfo, bundle: bundle, feedURL: feedURL, includePreReleases: includePreReleases)
                    }
                }

                // Collect non-nil results from this batch
                var batchUpdates: [UpdateableApp] = []
                for await update in group {
                    if let update = update {
                        batchUpdates.append(update)
                    }
                }
                return batchUpdates
            }

            updates.append(contentsOf: batchResults)
        }

        logger.log(.sparkle, "Found \(updates.count) Sparkle updates available")
        return updates
    }

    /// Check a single app for updates using SPUUpdater
    private static func checkSingleApp(appInfo: AppInfo, bundle: Bundle, feedURL: URL, includePreReleases: Bool) async -> UpdateableApp? {
        // Directly proceed with Sparkle check (no pre-flight URL check)
        // Users can hide slow/problematic apps using the eye button to prevent future checks
        let result = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let operation = SparkleCheckerOperation(
                    appInfo: appInfo,
                    bundle: bundle,
                    feedURL: feedURL,
                    includePreReleases: includePreReleases,
                    currentMacOSVersion: Self.currentMacOSVersion
                ) { result in
                    continuation.resume(returning: result)
                }
                operation.start()
            }
        }

        return result
    }

    /// Get Sparkle feed URL from app bundle
    /// Checks SUFeedURL in Info.plist, falls back to DevMate if framework is present
    static func feedURL(from bundle: Bundle) -> URL? {
        guard let information = bundle.infoDictionary else { return nil }

        // 1. Check SUFeedURL in Info.plist (standard Sparkle configuration)
        if let urlString = information["SUFeedURL"] as? String,
           let feedURL = URL(string: urlString.unquoted) {
            return feedURL
        }

        // 2. DevMate framework fallback (older apps)
        guard let bundleIdentifier = bundle.bundleIdentifier else { return nil }

        let frameworksURL = bundle.bundleURL.appendingPathComponent("Contents/Frameworks")
        let frameworks = try? FileManager.default.contentsOfDirectory(atPath: frameworksURL.path)

        if frameworks?.contains(where: { $0.contains("DevMateKit") }) ?? false {
            // DevMate apps use https://updates.devmate.com/{bundleIdentifier}.xml
            return URL(string: "https://updates.devmate.com")?
                .appendingPathComponent(bundleIdentifier)
                .appendingPathExtension("xml")
        }

        return nil
    }
}

// MARK: - SPUUpdater Operation

/// Manages a single SPUUpdater instance to check for updates
private class SparkleCheckerOperation: NSObject, SPUUserDriver, SPUUpdaterDelegate {
    private let appInfo: AppInfo
    private let bundle: Bundle
    private let feedURL: URL
    private let includePreReleases: Bool
    private let currentMacOSVersion: Version
    private let completion: (UpdateableApp?) -> Void
    private var updater: SPUUpdater?

    init(appInfo: AppInfo, bundle: Bundle, feedURL: URL, includePreReleases: Bool, currentMacOSVersion: Version, completion: @escaping (UpdateableApp?) -> Void) {
        self.appInfo = appInfo
        self.bundle = bundle
        self.feedURL = feedURL
        self.includePreReleases = includePreReleases
        self.currentMacOSVersion = currentMacOSVersion
        self.completion = completion
        super.init()
    }

    func start() {
        // Log what we're passing to Sparkle for diagnostics
        SparkleUpdateChecker.logger.log(.sparkle, "  🔍 Creating SPUUpdater:")
        SparkleUpdateChecker.logger.log(.sparkle, "     Bundle path: \(bundle.bundlePath)")
        SparkleUpdateChecker.logger.log(.sparkle, "     CFBundleVersion: \(bundle.infoDictionary?["CFBundleVersion"] as? String ?? "nil")")
        SparkleUpdateChecker.logger.log(.sparkle, "     CFBundleShortVersionString: \(bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "nil")")
        SparkleUpdateChecker.logger.log(.sparkle, "     Feed URL: \(feedURL.absoluteString)")
        SparkleUpdateChecker.logger.log(.sparkle, "     Include pre-releases: \(includePreReleases)")

        // Create SPUUpdater with this operation as both user driver and delegate
        let updater = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: self, delegate: self)

        do {
            try updater.start()
            updater.checkForUpdates()
            self.updater = updater
        } catch {
            SparkleUpdateChecker.logger.log(.sparkle, "  ❌ Failed to start updater: \(error.localizedDescription)")
            finish(with: nil)
        }
    }

    private func finish(with update: UpdateableApp?) {
        completion(update)
        updater = nil
    }

    private func createUpdate(from appcastItem: SUAppcastItem, includePreReleases: Bool) -> UpdateableApp? {
        // Get versions from appcast item for display
        let availableVersionString = appcastItem.displayVersionString
        let buildVersionString = appcastItem.versionString

        // Note: Item was already validated by bestValidUpdate delegate method
        // Only need to filter pre-releases and extract metadata here
        SparkleUpdateChecker.logger.log(.sparkle, "     Processing validated update: \(availableVersionString) (build: \(buildVersionString))")

        // Check if this is a pre-release
        var isPreRelease = false

        // Method 1: Sparkle 2.0+ channels (modern apps)
        if let channel = appcastItem.channel, channel.lowercased() != "release" {
            if !includePreReleases {
                SparkleUpdateChecker.logger.log(.sparkle, "     Filtering: Pre-release channel '\(channel)' (toggle off)")
                return nil
            }
            isPreRelease = true
            SparkleUpdateChecker.logger.log(.sparkle, "     Detected pre-release channel: \(channel)")
        }

        // Method 2: Version string analysis (legacy apps like Transmission)
        if isPreReleaseVersion(availableVersionString) {
            if !includePreReleases {
                SparkleUpdateChecker.logger.log(.sparkle, "     Filtering: Pre-release version name '\(availableVersionString)' (toggle off)")
                return nil
            }
            isPreRelease = true
            SparkleUpdateChecker.logger.log(.sparkle, "     Detected pre-release version name: \(availableVersionString)")
        }

        // Extract release notes
        var releaseTitle: String?
        var releaseDescription: String?
        var releaseNotesLink: String?

        if let title = appcastItem.title {
            releaseTitle = title
        }
        if let description = appcastItem.itemDescription {
            releaseDescription = description
        }
        if let notesURL = appcastItem.releaseNotesURL ?? appcastItem.fullReleaseNotesURL {
            releaseNotesLink = notesURL.absoluteString
        }

        return UpdateableApp(
            appInfo: appInfo,
            availableVersion: availableVersionString,
            availableBuildNumber: buildVersionString,
            source: .sparkle,
            adamID: nil,
            appStoreURL: nil,
            status: .idle,
            progress: 0.0,
            isSelectedForUpdate: false,
            releaseTitle: releaseTitle,
            releaseDescription: releaseDescription,
            releaseNotesLink: releaseNotesLink,
            releaseDate: appcastItem.dateString,
            isPreRelease: isPreRelease,
            isIOSApp: false,
            foundInRegion: nil,
            appcastItem: appcastItem  // Cache the validated appcast item
        )
    }

    // MARK: - SPUUserDriver

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        // Disable automatic update checks and system profiling
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        let result = SparkleUpdateResult.updateFound(appcastItem: appcastItem, state: state)
        processResult(result, reply: reply, acknowledgement: nil)
    }

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let result = extractResultFromNoUpdateError(error)
        processResult(result, reply: nil, acknowledgement: acknowledgement)
    }

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let result = SparkleUpdateResult.error(error)
        processResult(result, reply: nil, acknowledgement: acknowledgement)
    }

    // MARK: - Helper Methods

    /// Extract structured result from Sparkle's "no update" error
    private func extractResultFromNoUpdateError(_ error: Error) -> SparkleUpdateResult {
        let nsError = error as NSError

        // Verify this is actually a "no update" error from Sparkle
        guard nsError.domain == SUSparkleErrorDomain,
              nsError.code == SUError.noUpdateError.rawValue else {
            // Some other error - treat as genuine error
            return .error(error)
        }

        // Extract latest appcast item (may be nil if feed is empty)
        let latestItem = nsError.userInfo[SPULatestAppcastItemFoundKey] as? SUAppcastItem

        // Extract Sparkle's reason for no update
        let reasonRawValue = (nsError.userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber)?.int32Value ?? 0
        let sparkleReason = SPUNoUpdateFoundReason(rawValue: reasonRawValue) ?? .unknown

        return .noUpdate(reason: sparkleReason, latestItem: latestItem)
    }

    /// Format SPUNoUpdateFoundReason as human-readable string
    private func formatNoUpdateReason(_ reason: SPUNoUpdateFoundReason) -> String {
        switch reason {
        case .onLatestVersion:
            return "Already on latest version"
        case .onNewerThanLatestVersion:
            return "Newer than latest (ahead of feed)"
        case .systemIsTooOld:
            return "System too old for update"
        case .systemIsTooNew:
            return "System too new for update"
        default:
            return "Unknown reason"
        }
    }

    /// Log comprehensive details about what Sparkle's callback told us
    private func logSparkleCallback(_ result: SparkleUpdateResult) {
        switch result {
        case .updateFound(let appcastItem, let state):
            SparkleUpdateChecker.logger.log(.sparkle, "  📥 CALLBACK: showUpdateFound")
            SparkleUpdateChecker.logger.log(.sparkle, "     App: \(appInfo.appName)")
            SparkleUpdateChecker.logger.log(.sparkle, "     Installed: \(appInfo.appVersion) (build: \(appInfo.appBuildNumber ?? "unknown"))")
            SparkleUpdateChecker.logger.log(.sparkle, "     Available: \(appcastItem.displayVersionString) (build: \(appcastItem.versionString))")

            if let minOS = appcastItem.minimumSystemVersion {
                SparkleUpdateChecker.logger.log(.sparkle, "     Min system version: \(minOS)")
            }

            if let channel = appcastItem.channel {
                SparkleUpdateChecker.logger.log(.sparkle, "     Channel: \(channel)")
            }

            if let date = appcastItem.dateString {
                SparkleUpdateChecker.logger.log(.sparkle, "     Release date: \(date)")
            }

            let stageDesc = state.stage == .notDownloaded ? "not downloaded" :
                           state.stage == .downloaded ? "downloaded" : "installing"
            let initiatedDesc = state.userInitiated ? "user-initiated" : "automatic"
            SparkleUpdateChecker.logger.log(.sparkle, "     State: \(stageDesc), \(initiatedDesc)")

        case .noUpdate(let reason, let latestItem):
            SparkleUpdateChecker.logger.log(.sparkle, "  📥 CALLBACK: showUpdateNotFoundWithError")
            SparkleUpdateChecker.logger.log(.sparkle, "     App: \(appInfo.appName)")
            SparkleUpdateChecker.logger.log(.sparkle, "     Installed: \(appInfo.appVersion)")

            if let item = latestItem {
                SparkleUpdateChecker.logger.log(.sparkle, "     Latest: \(item.displayVersionString) (build: \(item.versionString))")
                if let title = item.title {
                    SparkleUpdateChecker.logger.log(.sparkle, "     Title: \(title)")
                }
            } else {
                SparkleUpdateChecker.logger.log(.sparkle, "     Latest: (none in feed)")
            }

            let reasonDesc = formatNoUpdateReason(reason)
            SparkleUpdateChecker.logger.log(.sparkle, "     Reason: \(reasonDesc)")

        case .error(let error):
            SparkleUpdateChecker.logger.log(.sparkle, "  📥 CALLBACK: showUpdaterError")
            SparkleUpdateChecker.logger.log(.sparkle, "     App: \(appInfo.appName)")
            SparkleUpdateChecker.logger.log(.sparkle, "     Error: \(error.localizedDescription)")

            let nsError = error as NSError
            SparkleUpdateChecker.logger.log(.sparkle, "     Domain: \(nsError.domain), Code: \(nsError.code)")
        }
    }

    /// Process Sparkle's result with comprehensive logging and decision-making
    private func processResult(
        _ result: SparkleUpdateResult,
        reply: ((SPUUserUpdateChoice) -> Void)?,
        acknowledgement: (() -> Void)?
    ) {
        // Log what Sparkle told us (comprehensive callback details)
        logSparkleCallback(result)

        // Process based on result type
        switch result {
        case .updateFound(let appcastItem, _):
            // Trust Sparkle - it says update is available
            SparkleUpdateChecker.logger.log(.sparkle, "  → Processing update found callback")

            // Apply our pre-release filtering if toggle is OFF
            let update = createUpdate(from: appcastItem, includePreReleases: includePreReleases)

            if let update = update {
                SparkleUpdateChecker.logger.log(.sparkle, "  ✅ Showing update: \(update.appInfo.appName) \(appInfo.appVersion) → \(update.availableVersion ?? "unknown")")
                if update.isPreRelease {
                    SparkleUpdateChecker.logger.log(.sparkle, "     🔵 Marked as pre-release")
                }
            } else {
                // Our filtering rejected it (pre-release filtered or version not newer)
                SparkleUpdateChecker.logger.log(.sparkle, "  ⚠️ Update filtered out by Pearcleaner logic")
            }

            finish(with: update)

        case .noUpdate(let reason, let latestItem):
            // Sparkle says no update - trust it completely!
            let reasonDesc = formatNoUpdateReason(reason)
            SparkleUpdateChecker.logger.log(.sparkle, "  → No update needed: \(reasonDesc)")

            if let item = latestItem {
                let latestVersion = item.displayVersionString
                let latestBuild = item.versionString
                SparkleUpdateChecker.logger.log(.sparkle, "     Latest in feed: \(latestVersion) (build: \(latestBuild))")
            } else {
                SparkleUpdateChecker.logger.log(.sparkle, "     Latest in feed: (none)")
            }

            finish(with: nil)
            acknowledgement?()

        case .error(let error):
            SparkleUpdateChecker.logger.log(.sparkle, "  ❌ Sparkle error: \(error.localizedDescription)")
            finish(with: nil)
            acknowledgement?()
        }
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
        finish(with: nil)
    }

    // MARK: - Ignored SPUUserDriver Methods

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateInFocus() {}
    func showDownloadInitiated(cancellation: @escaping () -> Void) {}
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() {}
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {}
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {}
    func showCanCheck(forUpdates canCheckForUpdates: Bool) {}
    func dismissUserInitiatedUpdateCheck() {}
    func showSendingTerminationSignal() {}
    func dismissUpdateInstallation() {}

    // MARK: - SPUUpdaterDelegate

    func feedURLString(for updater: SPUUpdater) -> String? {
        // Provide the feed URL to Sparkle
        return feedURL.absoluteString
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        // If pre-releases are enabled, allow common pre-release channels
        // If disabled, return empty set (only default/stable channel)
        guard includePreReleases else {
            return []
        }

        // Common pre-release channel names used by Sparkle apps
        return ["beta", "alpha", "nightly", "rc", "dev"]
    }

    func bestValidUpdate(in appcast: SUAppcast, for updater: SPUUpdater) -> SUAppcastItem? {
        SparkleUpdateChecker.logger.log(.sparkle, "  🔍 bestValidUpdate called - finding newest valid version")
        SparkleUpdateChecker.logger.log(.sparkle, "     Total items in appcast: \(appcast.items.count)")

        // Get installed version info for comparison
        let installedDisplayVersion = appInfo.appVersion
        let installedBuild = appInfo.appBuildNumber

        SparkleUpdateChecker.logger.log(.sparkle, "     Installed: \(installedDisplayVersion) (build: \(installedBuild ?? "nil"))")

        // Sort items by display version (newest first) using Version struct
        let sortedItems = appcast.items.sorted { item1, item2 in
            let ver1 = Version(versionNumber: item1.displayVersionString, buildNumber: nil)
            let ver2 = Version(versionNumber: item2.displayVersionString, buildNumber: nil)
            return ver1 > ver2  // Descending order (newest first)
        }

        SparkleUpdateChecker.logger.log(.sparkle, "     Sorted items (newest → oldest):")
        for (index, item) in sortedItems.enumerated() {
            SparkleUpdateChecker.logger.log(.sparkle, "       \(index + 1). \(item.displayVersionString) (build: \(item.versionString))")
        }

        // Filter items for OS compatibility and pre-release requirements
        SparkleUpdateChecker.logger.log(.sparkle, "     ")
        SparkleUpdateChecker.logger.log(.sparkle, "     Filtering for OS compatibility and pre-release settings...")

        for (index, item) in sortedItems.enumerated() {
            // Filter 1: Check OS compatibility (using cached OS version)
            if let minOS = item.minimumSystemVersion {
                let minOSVersion = Version(versionNumber: minOS, buildNumber: nil)

                if currentMacOSVersion < minOSVersion {
                    SparkleUpdateChecker.logger.log(.sparkle, "       ❌ Filtered #\(index + 1): Requires macOS \(minOS), current: \(currentMacOSVersion.versionNumber ?? "unknown")")
                    continue
                }
            }

            // Filter 2: Check channel (pre-release toggle)
            if let channel = item.channel, channel.lowercased() != "release" {
                if !includePreReleases {
                    SparkleUpdateChecker.logger.log(.sparkle, "       ❌ Filtered #\(index + 1): Pre-release channel '\(channel)' (toggle off)")
                    continue
                } else {
                    SparkleUpdateChecker.logger.log(.sparkle, "       ℹ️ Item #\(index + 1): Pre-release channel '\(channel)' (allowed)")
                }
            }

            // Filter 3: Check if version string indicates pre-release (legacy apps)
            if isPreReleaseVersion(item.displayVersionString) {
                if !includePreReleases {
                    SparkleUpdateChecker.logger.log(.sparkle, "       ❌ Filtered #\(index + 1): Pre-release version name '\(item.displayVersionString)' (toggle off)")
                    continue
                } else {
                    SparkleUpdateChecker.logger.log(.sparkle, "       ℹ️ Item #\(index + 1): Pre-release version name '\(item.displayVersionString)' (allowed)")
                }
            }

            // Found the newest valid candidate - now check if it's newer than installed
            SparkleUpdateChecker.logger.log(.sparkle, "     ")
            SparkleUpdateChecker.logger.log(.sparkle, "     🎯 Newest valid candidate: \(item.displayVersionString) (build: \(item.versionString))")
            SparkleUpdateChecker.logger.log(.sparkle, "     Checking if newer than installed version...")

            // Dual-check strategy: Check BOTH display version AND build number
            let installedDisplayVer = Version(versionNumber: installedDisplayVersion, buildNumber: nil)
            let availableDisplayVer = Version(versionNumber: item.displayVersionString, buildNumber: nil)

            // Check #1: Display version semantic comparison
            let displayIsNewer = availableDisplayVer > installedDisplayVer
            SparkleUpdateChecker.logger.log(.sparkle, "       Check #1 (Display): \(installedDisplayVersion) → \(item.displayVersionString) = \(displayIsNewer ? "✅ NEWER" : "❌ not newer")")

            // Check #2: Build number lexicographical comparison
            var buildIsNewer = false
            if let installedBuild = installedBuild {
                let comparison = item.versionString.compare(installedBuild, options: .numeric)
                buildIsNewer = (comparison == .orderedDescending)
                SparkleUpdateChecker.logger.log(.sparkle, "       Check #2 (Build): \(installedBuild) → \(item.versionString) = \(buildIsNewer ? "✅ NEWER" : "❌ not newer")")
            } else {
                SparkleUpdateChecker.logger.log(.sparkle, "       Check #2 (Build): Skipped (no installed build number)")
            }

            // Accept if EITHER check shows update
            if displayIsNewer || buildIsNewer {
                SparkleUpdateChecker.logger.log(.sparkle, "       ")
                SparkleUpdateChecker.logger.log(.sparkle, "       ✅ SELECTED: \(item.displayVersionString) (build: \(item.versionString))")
                SparkleUpdateChecker.logger.log(.sparkle, "       Reason: \(displayIsNewer ? "Display version is newer" : "Build number is newer")")
                return item
            } else {
                SparkleUpdateChecker.logger.log(.sparkle, "       ⚠️ Candidate is not newer than installed version")
                SparkleUpdateChecker.logger.log(.sparkle, "       No update available")
                return nil
            }
        }

        // No valid candidate found after filtering
        SparkleUpdateChecker.logger.log(.sparkle, "     ")
        SparkleUpdateChecker.logger.log(.sparkle, "     ❌ No valid update found (all items filtered out)")
        return nil
    }
}

// MARK: - String Extension

private extension String {
    /// Removes surrounding quotes and apostrophes from the string
    /// Handles malformed Info.plist entries like: "https://example.com" or 'https://example.com'
    var unquoted: String {
        return trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
    }
}
