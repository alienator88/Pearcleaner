//
//  SparkleUpdateChecker.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/28/25.
//
//  Simplified Sparkle update checker using SPUUpdater directly
//  Based on Latest's approach: https://github.com/mangerlahn/Latest
//

import Foundation
import Sparkle

class SparkleUpdateChecker {
    fileprivate static let logger = UpdaterDebugLogger.shared

    /// Check for Sparkle updates using SPUUpdater directly
    /// Only checks apps with SUFeedURL in Info.plist (no binary scanning)
    static func checkForUpdates(apps: [AppInfo], includePreReleases: Bool) async -> [UpdateableApp] {
        logger.log(.sparkle, "Starting Sparkle update check for \(apps.count) apps (includePreReleases: \(includePreReleases))")

        // Filter apps that have Sparkle feed URLs
        var sparkleApps: [(appInfo: AppInfo, bundle: Bundle, feedURL: URL)] = []

        for appInfo in apps {
            guard let bundle = Bundle(url: appInfo.path) else { continue }

            // Get feed URL using Latest's simple approach (SUFeedURL + DevMate fallback)
            guard let feedURL = Self.feedURL(from: bundle) else { continue }

            logger.log(.sparkle, "Checking: \(appInfo.appName) - \(feedURL.absoluteString)")
            sparkleApps.append((appInfo, bundle, feedURL))
        }

        guard !sparkleApps.isEmpty else {
            logger.log(.sparkle, "No Sparkle apps with valid feed URLs found")
            return []
        }

        // Check apps concurrently using SPUUpdater
        return await withTaskGroup(of: UpdateableApp?.self) { group in
            for (appInfo, bundle, feedURL) in sparkleApps {
                group.addTask {
                    await Self.checkSingleApp(appInfo: appInfo, bundle: bundle, feedURL: feedURL, includePreReleases: includePreReleases)
                }
            }

            // Collect non-nil results
            var updates: [UpdateableApp] = []
            for await update in group {
                if let update = update {
                    updates.append(update)
                }
            }

            logger.log(.sparkle, "Found \(updates.count) Sparkle updates available")
            return updates
        }
    }

    /// Check a single app for updates using SPUUpdater
    private static func checkSingleApp(appInfo: AppInfo, bundle: Bundle, feedURL: URL, includePreReleases: Bool) async -> UpdateableApp? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let operation = SparkleCheckerOperation(
                    appInfo: appInfo,
                    bundle: bundle,
                    feedURL: feedURL,
                    includePreReleases: includePreReleases
                ) { result in
                    continuation.resume(returning: result)
                }
                operation.start()
            }
        }
    }

    /// Get Sparkle feed URL from app bundle (Latest's approach)
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
    private let completion: (UpdateableApp?) -> Void
    private var updater: SPUUpdater?

    init(appInfo: AppInfo, bundle: Bundle, feedURL: URL, includePreReleases: Bool, completion: @escaping (UpdateableApp?) -> Void) {
        self.appInfo = appInfo
        self.bundle = bundle
        self.feedURL = feedURL
        self.includePreReleases = includePreReleases
        self.completion = completion
        super.init()
    }

    func start() {
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
        // Get versions from appcast item
        let availableVersionString = appcastItem.displayVersionString
        let buildVersionString = appcastItem.versionString

        // Create Version objects for comparison
        let installedVer = Version(versionNumber: appInfo.appVersion, buildNumber: nil)
        let availableVer = Version(versionNumber: availableVersionString, buildNumber: buildVersionString)

        // Sanitize available version (handle edge cases like 1.2 vs 1.2.0)
        let sanitizedAvailableVer = availableVer.sanitize(with: installedVer)

        // Only show update if available > installed
        guard !installedVer.isEmpty && !sanitizedAvailableVer.isEmpty && sanitizedAvailableVer > installedVer else {
            SparkleUpdateChecker.logger.log(.sparkle, "  ✓ Up to date")
            return nil
        }

        SparkleUpdateChecker.logger.log(.sparkle, "  📦 UPDATE AVAILABLE: \(appInfo.appVersion) → \(availableVersionString)")

        // Check if this is a pre-release (only if toggle is ON)
        let isPreRelease: Bool
        if includePreReleases {
            // Method 1: Sparkle 2.0+ channels (modern apps)
            // Method 2: Version string analysis (legacy apps like Transmission)
            isPreRelease = appcastItem.channel != nil ||
                           isPreReleaseVersion(availableVersionString)
        } else {
            // Toggle OFF - filter out ALL pre-releases
            // Check both channel and version string to reject them
            let hasChannel = appcastItem.channel != nil
            let hasPreReleaseVersion = isPreReleaseVersion(availableVersionString)

            if hasChannel || hasPreReleaseVersion {
                SparkleUpdateChecker.logger.log(.sparkle, "  ⚠️ Skipped pre-release: \(availableVersionString)")
                return nil
            }
            isPreRelease = false
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
            isIOSApp: false
        )
    }

    // MARK: - SPUUserDriver

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        // Disable automatic update checks and system profiling
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // Sparkle has already filtered channel-based pre-releases
        // createUpdate will handle version-based pre-release filtering
        let update = createUpdate(from: appcastItem, includePreReleases: includePreReleases)
        finish(with: update)
    }

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        // Check if Sparkle found the latest item but determined no update is needed
        let nsError = error as NSError
        if nsError.domain == SUSparkleErrorDomain &&
           nsError.code == SUError.noUpdateError.rawValue,
           let appcastItem = nsError.userInfo[SPULatestAppcastItemFoundKey] as? SUAppcastItem {
            // We have the latest appcast item, check if it's actually newer
            let update = createUpdate(from: appcastItem, includePreReleases: includePreReleases)
            finish(with: update)
        } else {
            // Genuine error or no update available
            SparkleUpdateChecker.logger.log(.sparkle, "  ✓ No update available")
            finish(with: nil)
        }
        acknowledgement()
    }

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        SparkleUpdateChecker.logger.log(.sparkle, "  ❌ Updater error: \(error.localizedDescription)")
        finish(with: nil)
        acknowledgement()
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
}

// MARK: - String Extension

private extension String {
    /// Removes surrounding quotes and apostrophes from the string
    /// Handles malformed Info.plist entries like: "https://example.com" or 'https://example.com'
    var unquoted: String {
        return trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
    }
}
