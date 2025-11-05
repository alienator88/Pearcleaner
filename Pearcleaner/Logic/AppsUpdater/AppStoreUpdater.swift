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

    /// Update an app from the App Store with progress tracking
    /// - Parameters:
    ///   - adamID: The App Store ID of the app
    ///   - progress: Progress callback (percent: 0.0-1.0, status message)
    ///   - attemptCount: Number of retry attempts for network errors (default: 3)
    func updateApp(
        adamID: UInt64,
        progress: @escaping @Sendable (Double, String) -> Void,
        attemptCount: UInt32 = 3
    ) async throws {
        do {
            // Create SSPurchase for downloading (purchasing: false = update existing app)
            let purchase = await SSPurchase(adamID: adamID, purchasing: false)

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                CKPurchaseController.shared().perform(purchase, withOptions: 0) { _, _, error, response in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if response?.downloads?.isEmpty == false {
                        // Download started - create observer to track it
                        Task {
                            do {
                                let observer = AppStoreDownloadObserver(adamID: adamID, progress: progress)
                                try await observer.observeDownloadQueue()
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
            try await updateApp(adamID: adamID, progress: progress, attemptCount: remainingAttempts)
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
