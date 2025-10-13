//
//  AppStoreUpdateChecker.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation
import CommerceKit
import StoreFoundation
import AlinFoundation

class AppStoreUpdateChecker {
    static func checkForUpdates(apps: [AppInfo], adamIDs: [URL: UInt64]) async -> [UpdateableApp] {
        var updateableApps: [UpdateableApp] = []

        for (url, adamID) in adamIDs {
            guard let appInfo = apps.first(where: { $0.path == url }) else { continue }

            // First check if app still exists in App Store to avoid popup
            let appStoreInfo = await getAppStoreInfo(adamID: adamID)
            guard let appStoreURL = appStoreInfo else {
                continue
            }

            do {
                // Check for update using mas CLI approach: start download, check metadata, cancel immediately
                let version = try await checkVersion(for: adamID, currentVersion: appInfo.appVersion)

                // Only add if there's actually an update available
                if let availableVersion = version {
                    if availableVersion != appInfo.appVersion {
                        let updateableApp = UpdateableApp(
                            appInfo: appInfo,
                            availableVersion: availableVersion,
                            source: .appStore,
                            adamID: adamID,
                            appStoreURL: appStoreURL,  // Include the URL we fetched
                            status: .idle,
                            progress: 0.0
                        )
                        updateableApps.append(updateableApp)
                    }
                }
            } catch {
                // Catch errors like "no downloads" or network errors
                continue
            }
        }

        return updateableApps
    }

    private static func getAppStoreInfo(adamID: UInt64) async -> String? {
        // Query iTunes Search API to check if app is still available and get its URL
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(adamID)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resultCount = json["resultCount"] as? Int,
               resultCount > 0,
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let trackViewUrl = firstResult["trackViewUrl"] as? String {
                return trackViewUrl
            }
        } catch {
            // Error checking availability - silently fail
        }

        return nil
    }

    private static func checkVersion(for adamID: UInt64, currentVersion: String) async throws -> String? {
        // Exact mas CLI approach: perform purchase, then observe queue inside the callback
        let purchase = await SSPurchase(adamID: adamID, purchasing: false)

        return try await withCheckedThrowingContinuation { continuation in
            var capturedVersion: String?
            var hasResumed = false

            CKPurchaseController.shared().perform(purchase, withOptions: 0) { _, _, error, response in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard response?.downloads?.isEmpty == false else {
                    continuation.resume(returning: nil)
                    return
                }

                // Now set up observer after we know there are downloads
                Task {
                    let queue = CKDownloadQueue.shared()

                    let observer = UpdateCheckObserver(adamID: adamID) { download, shouldOutput in
                        // Capture version from metadata on first call
                        if shouldOutput {
                            capturedVersion = download.metadata?.bundleVersion
                        }

                        // Always return true to cancel immediately
                        return true
                    }

                    let observerID = queue.add(observer)

                    observer.completionHandler = {
                        guard !hasResumed else { return }
                        hasResumed = true
                        queue.removeObserver(observerID)
                        continuation.resume(returning: capturedVersion)
                    }

                    observer.errorHandler = { error in
                        guard !hasResumed else { return }
                        hasResumed = true
                        queue.removeObserver(observerID)
                        continuation.resume(throwing: error)
                    }

                    // Add timeout to force-cancel if observer doesn't respond (e.g., for removed apps)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        guard !hasResumed else { return }
                        hasResumed = true

                        // Force cancel any downloads for this adamID
                        if let downloads = queue.downloads as? [SSDownload] {
                            for download in downloads {
                                if download.metadata?.itemIdentifier == adamID {
                                    queue.cancelDownload(download, promptToConfirm: false, askToDelete: false)
                                }
                            }
                        }

                        queue.removeObserver(observerID)
                        continuation.resume(returning: capturedVersion)
                    }
                }
            }
        }
    }
}

// Observer class for update checking (exact copy of mas's DownloadQueueObserver logic)
private class UpdateCheckObserver: NSObject, CKDownloadQueueObserver {
    let adamID: UInt64
    let shouldCancel: (SSDownload, Bool) -> Bool  // Takes download and shouldOutput flag
    var completionHandler: (() -> Void)?
    var errorHandler: ((Error) -> Void)?

    init(adamID: UInt64, shouldCancel: @escaping (SSDownload, Bool) -> Bool) {
        self.adamID = adamID
        self.shouldCancel = shouldCancel
    }

    func downloadQueue(_ queue: CKDownloadQueue, statusChangedFor download: SSDownload) {
        guard let metadata = download.metadata,
              metadata.itemIdentifier == adamID,
              let status = download.status else {
            return
        }

        // Exactly like mas: check if cancelled OR if shouldCancel returns false (don't cancel)
        guard status.isCancelled || !shouldCancel(download, true) else {
            queue.cancelDownload(download, promptToConfirm: false, askToDelete: false)
            return
        }

        if status.isFailed || status.isCancelled {
            queue.removeDownload(withItemIdentifier: adamID)
        }
    }

    func downloadQueue(_ queue: CKDownloadQueue, changedWithRemoval download: SSDownload) {
        guard let metadata = download.metadata,
              metadata.itemIdentifier == adamID,
              let status = download.status else {
            return
        }

        if status.isFailed {
            errorHandler?(status.error ?? NSError(domain: "AppStoreUpdateChecker", code: -1))
        } else if status.isCancelled {
            // Check shouldCancel with false (removal phase)
            guard shouldCancel(download, false) else {
                errorHandler?(NSError(domain: "AppStoreUpdateChecker", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cancelled"]))
                return
            }
            completionHandler?()
        } else {
            // Download completed
            completionHandler?()
        }
    }

    func downloadQueue(_ queue: CKDownloadQueue, changedWithAddition download: SSDownload) {
        // Not needed for update checking
    }
}
