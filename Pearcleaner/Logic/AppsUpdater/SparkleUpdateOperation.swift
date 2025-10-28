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

        // Sparkle must be initialized and started on the main thread
        DispatchQueue.main.sync {
            let driver = SparkleUpdateDriver(
                appInfo: app.appInfo,
                includePreReleases: includePreReleases,
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
