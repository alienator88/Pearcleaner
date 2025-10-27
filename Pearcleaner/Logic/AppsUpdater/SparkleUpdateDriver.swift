//
//  SparkleUpdateDriver.swift
//  Pearcleaner
//
//  Custom SPUUserDriver for programmatically controlling Sparkle updates.
//  Allows Pearcleaner to download and install updates for third-party Sparkle apps directly.
//

import Foundation
import Sparkle

class SparkleUpdateDriver: NSObject, SPUUserDriver, SPUUpdaterDelegate, @unchecked Sendable {

    // MARK: - Properties

    private let appBundle: Bundle
    private let feedURL: String
    private var updater: SPUUpdater?
    private let progressCallback: (Double, UpdateStatus) -> Void
    private let completionCallback: (Bool, Error?) -> Void

    private var downloadedBytes: Int64 = 0
    private var totalBytes: Int64 = 0

    private let logger = UpdaterDebugLogger.shared

    // MARK: - Initialization

    init(appInfo: AppInfo,
         feedURL: String,
         progressCallback: @escaping (Double, UpdateStatus) -> Void,
         completionCallback: @escaping (Bool, Error?) -> Void) {
        guard let bundle = Bundle(url: appInfo.path) else {
            fatalError("Could not create bundle for app at \(appInfo.path)")
        }
        self.appBundle = bundle
        self.feedURL = feedURL
        self.progressCallback = progressCallback
        self.completionCallback = completionCallback
        super.init()
    }

    // MARK: - Public Methods

    func startUpdate() {
        logger.log(.sparkle, "━━━ Starting Sparkle update for \(appBundle.bundleIdentifier ?? "unknown")")
        logger.log(.sparkle, "  App path: \(appBundle.bundlePath)")
        logger.log(.sparkle, "  Feed URL: \(feedURL)")

        // Check for public key
        if let publicKey = appBundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String {
            logger.log(.sparkle, "  ✓ Found SUPublicEDKey: \(publicKey.prefix(20))...")
        } else {
            logger.log(.sparkle, "  ⚠️ No SUPublicEDKey found")
        }

        updater = SPUUpdater(
            hostBundle: appBundle,
            applicationBundle: appBundle,
            userDriver: self,
            delegate: self
        )

        do {
            try updater?.start()
            logger.log(.sparkle, "  ✓ Sparkle updater started successfully")
            updater?.checkForUpdates()
            logger.log(.sparkle, "  ✓ Triggered user-initiated update check (forces SPUUserDriver callbacks)")
        } catch {
            logger.log(.sparkle, "  ❌ Failed to start updater: \(error.localizedDescription)")
            completionCallback(false, error)
        }
    }

    // MARK: - SPUUserDriver Protocol (Auto-approve installation, track progress)

    func show(_ request: SPUUpdatePermissionRequest,
             reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        // Auto-approve without showing permission dialog
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true,
                                        sendSystemProfile: false))
    }

    func showUpdateFound(with appcastItem: SUAppcastItem,
                        state: SPUUserUpdateState,
                        reply: @escaping (SPUUserUpdateChoice) -> Void) {
        logger.log(.sparkle, "  ✓ Update found: \(appcastItem.displayVersionString) (build \(appcastItem.versionString))")
        if let fileURL = appcastItem.fileURL {
            logger.log(.sparkle, "  Download URL: \(fileURL.absoluteString)")
        }
        logger.log(.sparkle, "  Auto-approving installation...")
        // Auto-approve installation (no UI)
        progressCallback(0.0, .downloading)
        reply(.install)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        totalBytes = Int64(expectedContentLength)
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(expectedContentLength), countStyle: .file)
        logger.log(.sparkle, "  Starting download (\(sizeStr))...")
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        downloadedBytes += Int64(length)
        let progress = totalBytes > 0 ? Double(downloadedBytes) / Double(totalBytes) : 0.0

        // Log at 25%, 50%, 75% milestones
        let percentage = Int(progress * 100)
        if percentage > 0 && percentage % 25 == 0 {
            let downloaded = ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            logger.log(.sparkle, "  Download progress: \(percentage)% (\(downloaded) / \(total))")
        }

        // Download = 0-75% of total progress
        progressCallback(progress * 0.75, .downloading)
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        let percentage = Int(progress * 100)
        if percentage > 0 && percentage % 25 == 0 {
            logger.log(.sparkle, "  Extraction progress: \(percentage)%")
        }
        // Extraction = 75-95% of total progress
        progressCallback(0.75 + (progress * 0.20), .extracting)
    }

    func showInstallingUpdate(withApplicationTerminated: Bool,
                            retryTerminatingApplication: @escaping () -> Void) {
        if withApplicationTerminated {
            logger.log(.sparkle, "  ✓ Target app terminated, installing update...")
        } else {
            logger.log(.sparkle, "  Installing update (app will be terminated)...")
        }
        // Installing = 95-100%
        progressCallback(0.95, .installing)
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool,
                                         acknowledgement: @escaping () -> Void) {
        logger.log(.sparkle, "  ✓✓✓ Update installed successfully!")
        if relaunched {
            logger.log(.sparkle, "  App relaunched")
        }
        progressCallback(1.0, .completed)
        completionCallback(true, nil)
        acknowledgement()
    }

    func showUpdaterError(_ error: Error,
                         acknowledgement: @escaping () -> Void) {
        logger.log(.sparkle, "  ❌❌❌ Sparkle updater error:")
        logger.log(.sparkle, "    \(error.localizedDescription)")
        if let nsError = error as NSError? {
            logger.log(.sparkle, "    Domain: \(nsError.domain), Code: \(nsError.code)")
            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                logger.log(.sparkle, "    Underlying: \(underlyingError.localizedDescription)")
            }
        }
        completionCallback(false, error)
        acknowledgement()
    }

    // MARK: - SPUUserDriver Protocol (Stubbed UI methods)

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        // No UI - stub
    }

    func dismissUserInitiatedUpdateCheck() {
        // No UI - stub
    }

    func showUpdateNotFoundWithError(_ error: Error,
                                    acknowledgement: @escaping () -> Void) {
        logger.log(.sparkle, "  ℹ️ No update found: \(error.localizedDescription)")
        acknowledgement()
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        // No UI - stub
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {
        // No UI - stub
    }

    func showUpdateInFocus() {
        // No UI - stub
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        // No UI - stub
    }

    func showDownloadDidStartExtractingUpdate() {
        // No UI - stub
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // Auto-approve installation
        reply(.install)
    }

    func showSendingTerminationSignal() {
        // No UI - stub
    }

    func dismissUpdateInstallation() {
        // No UI - stub
    }

    func showCanCheck(forUpdates canCheckForUpdates: Bool) {
        // No UI - stub
    }

    // MARK: - SPUUpdaterDelegate Protocol

    func feedURLString(for updater: SPUUpdater) -> String? {
        // Provide the feed URL (handles apps without SUFeedURL in Info.plist)
        return feedURL
    }
}
