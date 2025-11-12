//
//  AppStoreUpdater.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation
import CommerceKit
import StoreFoundation
import AlinFoundation

// MARK: - Error Types

enum AppStoreUpdateError: Error {
    case noDownloads
    case downloadFailed(String)
    case downloadCancelled
    case networkError(Error)
}

// MARK: - AppStoreUpdater

class AppStoreUpdater {
    static let shared = AppStoreUpdater()

    private init() {}

    /// Check if running macOS version affected by installd bug
    /// Affected: 14.8.2 (Darwin 24.6.2), 15.7.2 (Darwin 25.7.2), and 26.1+ (Darwin 26.1+)
    private func needsInstalldWorkaround() -> Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion

        // macOS 26.1+ (all versions)
        if version.majorVersion >= 26 && version.minorVersion >= 1 {
            return true
        }

        // macOS 15.7.2 (Darwin 25.7.2)
        if version.majorVersion == 25 && version.minorVersion == 7 && version.patchVersion >= 2 {
            return true
        }

        // macOS 14.8.2 (Darwin 24.6.2)
        if version.majorVersion == 24 && version.minorVersion == 6 && version.patchVersion >= 2 {
            return true
        }

        return false
    }

    /// Update an app from the App Store with progress tracking
    /// - Parameters:
    ///   - adamID: The App Store ID of the app
    ///   - appPath: Path to the installed app (for receipt injection)
    ///   - progress: Progress callback (percent: 0.0-1.0, status message)
    ///   - attemptCount: Number of retry attempts for network errors (default: 3)
    func updateApp(
        adamID: UInt64,
        appPath: URL,
        isIOSApp: Bool = false,
        progress: @escaping @Sendable (Double, String) -> Void,
        attemptCount: UInt32 = 3
    ) async throws {
        do {
            // Create SSPurchase for downloading (purchasing: false = update existing app)
            let purchase = await SSPurchase(adamID: adamID, purchasing: false)

            // iOS apps need special handling on ALL macOS versions (flag passed from caller)
            // Check if workaround is needed for macOS apps on affected OS versions
            let needsWorkaround = needsInstalldWorkaround()

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                CKPurchaseController.shared().perform(purchase, withOptions: 0) { _, _, error, response in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if response?.downloads?.isEmpty == false {
                        // Download started - create observer to track it
                        Task {
                            do {
                                if isIOSApp {
                                    // iOS apps: Use dedicated iOS observer (all macOS versions)
                                    let observer = IOSDownloadObserver(adamID: adamID, appPath: appPath, progress: progress)
                                    try await observer.observeDownloadQueue()
                                } else if needsWorkaround {
                                    // macOS apps on affected OS versions: Use workaround observer
                                    printOS("⚠️ Detected macOS version with installd bug - using workaround")
                                    let observer = MacOSDownloadObserverWithWorkaround(adamID: adamID, appPath: appPath, progress: progress)
                                    try await observer.observeDownloadQueue()
                                } else {
                                    // macOS apps on unaffected OS versions: Use standard observer
                                    let observer = AppStoreDownloadObserver(adamID: adamID, progress: progress)
                                    try await observer.observeDownloadQueue()
                                }
                                continuation.resume()
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        // No downloads means already up to date
                        progress(1.0, "Already up to date")
                        continuation.resume()
                    }
                }
            }
        } catch {
            // Retry logic for network errors (like mas does)
            guard attemptCount > 1 else {
                throw error
            }

            // Only retry network errors
            guard (error as NSError).domain == NSURLErrorDomain else {
                throw error
            }

            let remainingAttempts = attemptCount - 1
            try await updateApp(adamID: adamID, appPath: appPath, isIOSApp: isIOSApp, progress: progress, attemptCount: remainingAttempts)
        }
    }
}

// MARK: - AppStoreDownloadObserver

/// Per-download observer that tracks a single App Store download/update
/// This matches the architecture used by mas CLI tool
private final class AppStoreDownloadObserver: NSObject, CKDownloadQueueObserver {
    private let adamID: UInt64
    private let progressCallback: @Sendable (Double, String) -> Void
    private var completionHandler: (() -> Void)?
    private var errorHandler: ((Error) -> Void)?

    init(adamID: UInt64, progress: @escaping @Sendable (Double, String) -> Void) {
        self.adamID = adamID
        self.progressCallback = progress
        super.init()
    }

    /// Observe the download queue until this download completes
    /// Uses defer to ensure observer is always removed when done
    func observeDownloadQueue(_ queue: CKDownloadQueue = .shared()) async throws {
        let observerID = queue.add(self)
        defer {
            queue.removeObserver(observerID)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            completionHandler = { [weak self] in
                self?.completionHandler = nil
                self?.errorHandler = nil
                continuation.resume()
            }
            errorHandler = { [weak self] error in
                self?.completionHandler = nil
                self?.errorHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - CKDownloadQueueObserver Delegate Methods

    func downloadQueue(_ queue: CKDownloadQueue, changedWithAddition download: SSDownload) {
        // Download was added to queue - no action needed
    }

    func downloadQueue(_ queue: CKDownloadQueue, changedWithRemoval download: SSDownload) {
        guard let metadata = download.metadata,
              metadata.itemIdentifier == adamID,
              let status = download.status else {
            return
        }

        // This is the official completion signal from CommerceKit
        if status.isFailed {
            let error = status.error ?? AppStoreUpdateError.downloadFailed("Download failed")
            errorHandler?(error)
        } else if status.isCancelled {
            errorHandler?(AppStoreUpdateError.downloadCancelled)
        } else {
            // Success!
            progressCallback(1.0, "Completed")
            completionHandler?()
        }
    }

    func downloadQueue(_ queue: CKDownloadQueue, statusChangedFor download: SSDownload) {
        guard let metadata = download.metadata,
              metadata.itemIdentifier == adamID,
              let status = download.status,
              let activePhase = status.activePhase else {
            return
        }

        let phaseType = activePhase.phaseType
        let percentComplete = status.percentComplete  // Float: 0.0 to 1.0
        let progress = max(0.0, min(1.0, Double(percentComplete)))

        // Report progress based on phase
        // Special case: at 100%, always show "Installing..." (CommerceKit sometimes resets to phase 0 at completion)
        if progress >= 1.0 {
            progressCallback(progress, "Installing...")
        } else {
            switch phaseType {
            case 0: // Downloading
                progressCallback(progress, "Downloading...")

            case 1: // Installing
                progressCallback(progress, "Installing...")

            case 4: // Initial/Preparing
                progressCallback(progress, "Preparing...")

            case 5: // Downloaded (not complete yet - wait for changedWithRemoval)
                progressCallback(progress, "Installing...")

            default:
                progressCallback(progress, "Processing...")
            }
        }
    }
}

// MARK: - IOSDownloadObserver

/// Observer for iOS/iPad app downloads (IPA files)
/// Preserves IPA to /tmp for installation
/// Used for all iOS apps regardless of macOS version
private final class IOSDownloadObserver: NSObject, CKDownloadQueueObserver {
    private let adamID: UInt64
    private let appPath: URL
    private let progressCallback: @Sendable (Double, String) -> Void
    private var completionHandler: (() -> Void)?
    private var errorHandler: ((Error) -> Void)?
    private var iosFilesPreserved = false  // Track if IPA was already preserved
    private var hardLinkedIPAPath: String?  // Path to hard-linked IPA in /tmp
    private var isManuallyInstalling = false

    init(adamID: UInt64, appPath: URL, progress: @escaping @Sendable (Double, String) -> Void) {
        self.adamID = adamID
        self.appPath = appPath
        self.progressCallback = progress
        super.init()
    }

    func observeDownloadQueue(_ queue: CKDownloadQueue = .shared()) async throws {
        let observerID = queue.add(self)
        defer {
            queue.removeObserver(observerID)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            completionHandler = { [weak self] in
                self?.completionHandler = nil
                self?.errorHandler = nil
                continuation.resume()
            }
            errorHandler = { [weak self] error in
                self?.completionHandler = nil
                self?.errorHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - CKDownloadQueueObserver Delegate Methods

    func downloadQueue(_ queue: CKDownloadQueue, changedWithAddition download: SSDownload) {
        // Download was added to queue - no action needed
    }

    func downloadQueue(_ queue: CKDownloadQueue, changedWithRemoval download: SSDownload) {
        guard let metadata = download.metadata,
              metadata.itemIdentifier == adamID,
              let status = download.status else {
            return
        }

        // iOS app download completed - always perform manual installation if IPA was preserved
        // (CommerceKit cannot install iOS apps, so we handle it ourselves regardless of reported status)
        if let ipaPath = hardLinkedIPAPath {
            Task {
                await performManualInstallation(ipaPath: ipaPath)
            }
        } else {
            // No IPA preserved - this shouldn't happen, but handle gracefully
            if status.isFailed || status.isCancelled {
                errorHandler?(AppStoreUpdateError.downloadFailed("Failed to preserve IPA file"))
            } else {
                // Unexpected: CommerceKit claims success but we don't have an IPA
                printOS("⚠️ Download completed but no IPA was preserved")
                progressCallback(1.0, "Completed")
                completionHandler?()
            }
        }
    }

    func downloadQueue(_ queue: CKDownloadQueue, statusChangedFor download: SSDownload) {
        guard let metadata = download.metadata,
              metadata.itemIdentifier == adamID,
              let status = download.status,
              let activePhase = status.activePhase else {
            return
        }

        let phaseType = activePhase.phaseType
        let percentComplete = status.percentComplete
        let progress = max(0.0, min(1.0, Double(percentComplete)))

        // At 80% progress, preserve IPA file before CommerceKit potentially cleans it up
        if progress >= 0.80 && progress < 1.0 && !iosFilesPreserved {
            preserveIPAFile()
        }

        // Report progress
        if isManuallyInstalling {
            progressCallback(progress, "Installing...")
        } else if progress >= 1.0 {
            progressCallback(progress, "Downloading...")
        } else {
            switch phaseType {
            case 0: // Downloading
                progressCallback(progress, "Downloading...")
            case 4: // Initial/Preparing
                progressCallback(progress, "Preparing...")
            default:
                progressCallback(progress, "Downloading...")
            }
        }
    }

    // MARK: - Helper Methods

    private func performManualInstallation(ipaPath: String) async {
        isManuallyInstalling = true

        // 80%: Preparing installation
        progressCallback(0.80, "Preparing installation...")
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec

        do {
            // 80-100%: IOSAppInstaller handles the rest (extraction, metadata, installation, cleanup)
            try await IOSAppInstaller.installIOSApp(
                ipaPath: ipaPath,
                adamID: adamID,
                existingAppPath: appPath,
                progress: progressCallback
            )

            completionHandler?()
        } catch {
            errorHandler?(error)
        }
    }

    private func preserveIPAFile() {
        guard !iosFilesPreserved else { return }

        let downloadDir = "\(CKDownloadDirectory(nil))/\(adamID)"
        let tempDir = "/tmp/pearcleaner-ios-\(adamID)"

        do {
            // Create temp directory
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

            let contents = try FileManager.default.contentsOfDirectory(atPath: downloadDir)

            if let ipaFile = contents.first(where: { $0.hasSuffix(".ipa") }) {
                // Hard link IPA to /tmp (same pattern as PKG files)
                let ipaSource = "\(downloadDir)/\(ipaFile)"
                let ipaDest = "\(tempDir)/app.ipa"

                try FileManager.default.linkItem(atPath: ipaSource, toPath: ipaDest)
                hardLinkedIPAPath = ipaDest

                printOS("✅ Hard linked IPA: \(ipaFile)")

                iosFilesPreserved = true
            } else {
                printOS("⚠️ No IPA file found in \(downloadDir)")
            }
        } catch {
            printOS("❌ Failed to preserve IPA: \(error.localizedDescription)")
        }
    }
}

// MARK: - MacOSDownloadObserverWithWorkaround

/// Special observer for macOS versions affected by installd bug
/// Downloads PKG, hard links it, then manually installs via HelperToolManager
/// Used only for macOS apps on affected OS versions
private final class MacOSDownloadObserverWithWorkaround: NSObject, CKDownloadQueueObserver {
    private let adamID: UInt64
    private let appPath: URL
    private let progressCallback: @Sendable (Double, String) -> Void
    private var completionHandler: (() -> Void)?
    private var errorHandler: ((Error) -> Void)?
    private var hardLinkedPkgPath: String?
    private var hardLinkedReceiptPath: String?
    private var isManuallyInstalling = false

    init(adamID: UInt64, appPath: URL, progress: @escaping @Sendable (Double, String) -> Void) {
        self.adamID = adamID
        self.appPath = appPath
        self.progressCallback = progress
        super.init()
    }

    func observeDownloadQueue(_ queue: CKDownloadQueue = .shared()) async throws {
        let observerID = queue.add(self)
        defer {
            queue.removeObserver(observerID)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            completionHandler = { [weak self] in
                self?.completionHandler = nil
                self?.errorHandler = nil
                continuation.resume()
            }
            errorHandler = { [weak self] error in
                self?.completionHandler = nil
                self?.errorHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - CKDownloadQueueObserver Delegate Methods

    func downloadQueue(_ queue: CKDownloadQueue, changedWithAddition download: SSDownload) {
        // Download was added to queue - no action needed
    }

    func downloadQueue(_ queue: CKDownloadQueue, changedWithRemoval download: SSDownload) {
        guard let metadata = download.metadata,
              metadata.itemIdentifier == adamID,
              let status = download.status else {
            return
        }

        // Download completed (installd will fail, but we have the PKG hard linked)
        if status.isFailed || status.isCancelled {
            // Expected failure on affected macOS versions - proceed with manual installation
            if let pkgPath = hardLinkedPkgPath {
                Task {
                    await performManualInstallation(pkgPath: pkgPath)
                }
            } else {
                errorHandler?(AppStoreUpdateError.downloadFailed("Failed to preserve PKG file"))
            }
        } else {
            // Unexpected success (installd worked somehow)
            if let pkgPath = hardLinkedPkgPath {
                // Clean up temp directory since installd succeeded
                let tempDir = (pkgPath as NSString).deletingLastPathComponent
                try? FileManager.default.removeItem(atPath: tempDir)
                hardLinkedPkgPath = nil
                hardLinkedReceiptPath = nil
            }
            progressCallback(1.0, "Completed")
            completionHandler?()
        }
    }

    func downloadQueue(_ queue: CKDownloadQueue, statusChangedFor download: SSDownload) {
        guard let metadata = download.metadata,
              metadata.itemIdentifier == adamID,
              let status = download.status,
              let activePhase = status.activePhase else {
            return
        }

        let phaseType = activePhase.phaseType
        let percentComplete = status.percentComplete
        let progress = max(0.0, min(1.0, Double(percentComplete)))

        // At 80% progress, create hard link to preserve PKG before installd fails
        if progress >= 0.80 && progress < 1.0 && hardLinkedPkgPath == nil && !isManuallyInstalling {
            createHardLinkToPKG()
        }

        // Report progress
        if isManuallyInstalling {
            progressCallback(progress, "Installing...")
        } else if progress >= 1.0 {
            progressCallback(progress, "Downloading...")
        } else {
            switch phaseType {
            case 0: // Downloading
                progressCallback(progress, "Downloading...")
            case 4: // Initial/Preparing
                progressCallback(progress, "Preparing...")
            default:
                progressCallback(progress, "Downloading...")
            }
        }
    }

    // MARK: - Helper Methods

    private func createHardLinkToPKG() {
        let downloadDir = "\(CKDownloadDirectory(nil))/\(adamID)"
        let tempDir = "/tmp/pearcleaner-appstore-\(adamID)"

        do {
            // Create temp directory
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

            let contents = try FileManager.default.contentsOfDirectory(atPath: downloadDir)

            // Find PKG file (macOS apps only)
            if let pkgFile = contents.first(where: { $0.hasSuffix(".pkg") }) {
                // Hard link PKG file
                let pkgSource = "\(downloadDir)/\(pkgFile)"
                let pkgDest = "\(tempDir)/\(pkgFile)"

                try FileManager.default.linkItem(atPath: pkgSource, toPath: pkgDest)
                hardLinkedPkgPath = pkgDest
                printOS("✅ Hard linked PKG: \(pkgFile)")

                // Hard link receipt file
                let receiptSource = "\(downloadDir)/receipt"
                let receiptDest = "\(tempDir)/receipt"
                if FileManager.default.fileExists(atPath: receiptSource) {
                    try FileManager.default.linkItem(atPath: receiptSource, toPath: receiptDest)
                    hardLinkedReceiptPath = receiptDest
                } else {
                    printOS("⚠️ No receipt file found in \(downloadDir)")
                }
            } else {
                printOS("⚠️ No PKG file found in \(downloadDir)")
            }
        } catch {
            printOS("❌ Failed to create hard links: \(error.localizedDescription)")
        }
    }

    private func performManualInstallation(pkgPath: String) async {
        isManuallyInstalling = true

        // 80-85%: Preparing installation
        progressCallback(0.80, "Preparing installation...")
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
        progressCallback(0.85, "Installing...")

        // 85-90%: Running installer
        let result = await HelperToolManager.shared.runCommand("installer -pkg \(pkgPath) -target /")

        progressCallback(0.90, "Configuring App Store receipt...")

        // 90-95%: Inject receipt and refresh metadata
        if result.0, let receiptPath = hardLinkedReceiptPath, FileManager.default.fileExists(atPath: receiptPath) {
            let appPathString = appPath.path
            let receiptDir = "\(appPathString)/Contents/_MASReceipt"
            let receiptDestPath = "\(receiptDir)/receipt"

            // Create _MASReceipt directory using privileged helper
            let mkdirResult = await HelperToolManager.shared.runCommand("mkdir -p \"\(receiptDir)\"")
            if !mkdirResult.0 {
                printOS("⚠️ Failed to create _MASReceipt directory: \(mkdirResult.1)")
            } else {
                // Copy receipt file using privileged helper
                let cpResult = await HelperToolManager.shared.runCommand("cp \"\(receiptPath)\" \"\(receiptDestPath)\"")
                if !cpResult.0 {
                    printOS("⚠️ Failed to copy receipt: \(cpResult.1)")
                } else {
                    // Set proper permissions using privileged helper
                    let chmodResult = await HelperToolManager.shared.runCommand("chmod 644 \"\(receiptDestPath)\"")
                    if !chmodResult.0 {
                        printOS("⚠️ Failed to set receipt permissions: \(chmodResult.1)")
                    }

                    // Force immediate Spotlight re-indexing
                    let mdimportProcess = Process()
                    mdimportProcess.executableURL = URL(fileURLWithPath: "/usr/bin/mdimport")
                    mdimportProcess.arguments = ["-i", appPathString]
                    try? mdimportProcess.run()
                    mdimportProcess.waitUntilExit()
                }
            }
        }

        progressCallback(0.95, "Cleaning up...")

        // 95-100%: Clean up temp directory
        if let pkgPath = hardLinkedPkgPath {
            let tempDir = (pkgPath as NSString).deletingLastPathComponent
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        if result.0 {
            progressCallback(1.0, "Completed")
            completionHandler?()
        } else {
            printOS("❌ Manual PKG installation failed: \(result.1)")
            errorHandler?(AppStoreUpdateError.downloadFailed("Installation failed: \(result.1)"))
        }
    }
}
