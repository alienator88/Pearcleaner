//
//  SparkleUpdateOperation.swift
//  Pearcleaner
//
//  Operation subclass that blocks until Sparkle update completes using DispatchSemaphore.
//  Prevents concurrent Sparkle updates from conflicting with each other.
//

import Foundation

class SparkleUpdateOperation: Operation, @unchecked Sendable {
    let app: UpdateableApp
    let includePreReleases: Bool
    let progressCallback: (Double, UpdateStatus) -> Void
    let completionCallback: (Bool, Error?) -> Void

    private let semaphore = DispatchSemaphore(value: 0)

    var bundleIdentifier: String {
        app.appInfo.bundleIdentifier
    }

    init(
        app: UpdateableApp,
        includePreReleases: Bool,
        progressCallback: @escaping (Double, UpdateStatus) -> Void,
        completionCallback: @escaping (Bool, Error?) -> Void
    ) {
        self.app = app
        self.includePreReleases = includePreReleases
        self.progressCallback = progressCallback
        self.completionCallback = completionCallback
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        // Debug: Log cached appcast item status
        if let cachedItem = app.appcastItem {
            UpdaterDebugLogger.shared.log(.sparkle, "🔍 DEBUG: Cached appcast item found: \(cachedItem.displayVersionString) (build: \(cachedItem.versionString))")
        } else {
            UpdaterDebugLogger.shared.log(.sparkle, "⚠️ DEBUG: No cached appcast item - app.appcastItem is nil!")
        }

        // Sparkle must be initialized and started on the main thread
        DispatchQueue.main.sync {
            let driver = SparkleUpdateDriver(
                appInfo: app.appInfo,
                includePreReleases: includePreReleases,
                cachedAppcastItem: app.appcastItem,  // Pass cached item from check phase
                progressCallback: progressCallback,
                completionCallback: { [weak self] success, error in
                    guard let self = self else { return }

                    // Call the original completion callback
                    self.completionCallback(success, error)

                    // Signal the semaphore to unblock the operation
                    self.semaphore.signal()
                }
            )

            driver.startUpdate()
        }

        // Block here until the update completes (semaphore.signal() is called in completion callback)
        semaphore.wait()
    }
}
