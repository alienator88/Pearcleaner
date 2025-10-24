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
        updater = SPUUpdater(
            hostBundle: appBundle,
            applicationBundle: appBundle,
            userDriver: self,
            delegate: self
        )

        do {
            try updater?.start()
            updater?.checkForUpdatesInBackground()
        } catch {
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
        // Auto-approve installation (no UI)
        progressCallback(0.0, .downloading)
        reply(.install)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        totalBytes = Int64(expectedContentLength)
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        downloadedBytes += Int64(length)
        let progress = totalBytes > 0 ? Double(downloadedBytes) / Double(totalBytes) : 0.0
        // Download = 0-75% of total progress
        progressCallback(progress * 0.75, .downloading)
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        // Extraction = 75-95% of total progress
        progressCallback(0.75 + (progress * 0.20), .extracting)
    }

    func showInstallingUpdate(withApplicationTerminated: Bool,
                            retryTerminatingApplication: @escaping () -> Void) {
        // Installing = 95-100%
        progressCallback(0.95, .installing)
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool,
                                         acknowledgement: @escaping () -> Void) {
        progressCallback(1.0, .completed)
        completionCallback(true, nil)
        acknowledgement()
    }

    func showUpdaterError(_ error: Error,
                         acknowledgement: @escaping () -> Void) {
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
