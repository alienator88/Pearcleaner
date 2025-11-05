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

class AppStoreUpdater: NSObject, @unchecked Sendable {
    static let shared = AppStoreUpdater()

    private let callbackQueue = DispatchQueue(label: "com.pearcleaner.appstoreupdater")
    private var progressCallbacks: [UInt64: (Double, String) -> Void] = [:]

    nonisolated func updateApp(adamID: UInt64, progress: @escaping (Double, String) -> Void) async {
        callbackQueue.sync {
            progressCallbacks[adamID] = progress
        }

        // Create SSPurchase for downloading
        let purchase = await SSPurchase(adamID: adamID, purchasing: false)

        // Start observing download queue
        _ = CKDownloadQueue.shared().add(self)

        // Perform purchase/update - bridge to async context
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            CKPurchaseController.shared().perform(purchase, withOptions: 0) { [weak self] _, _, error, response in
                if let error = error {
                    progress(0.0, "Error: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }

                if response?.downloads?.isEmpty == false {
                    progress(0.0, "Starting download...")
                } else {
                    progress(1.0, "Already up to date")
                    _ = self?.callbackQueue.sync {
                        self?.progressCallbacks.removeValue(forKey: adamID)
                    }
                }
                continuation.resume()
            }
        }
    }
}

// CKDownloadQueueObserver implementation
extension AppStoreUpdater: CKDownloadQueueObserver {
    nonisolated func downloadQueue(_ queue: CKDownloadQueue, changedWithAddition download: SSDownload) {
        // Download was added to queue
    }

    nonisolated func downloadQueue(_ queue: CKDownloadQueue, changedWithRemoval download: SSDownload) {
        // Download was removed from queue - cleanup
        if let adamID = download.metadata?.itemIdentifier {
            _ = callbackQueue.sync {
                progressCallbacks.removeValue(forKey: adamID)
            }
        }
    }

    nonisolated func downloadQueue(_ queue: CKDownloadQueue, statusChangedFor download: SSDownload) {
        guard let adamID = download.metadata?.itemIdentifier else {
            return
        }

        let callback = callbackQueue.sync { progressCallbacks[adamID] }
        guard let callback = callback else { return }

        guard let status = download.status,
              let activePhase = status.activePhase else { return }

        let phaseType = activePhase.phaseType

        // Read progress from status (statusChangedFor fires frequently during download)
        let percentComplete = status.percentComplete  // Float: 0.0 to 1.0
        let progress = max(0.0, min(1.0, Double(percentComplete)))

        printOS("🔄 App Store status changed for adamID \(adamID) - phaseType: \(phaseType), progress: \(String(format: "%.1f", progress * 100))%")

        switch phaseType {
        case 0: // Downloading
            printOS("  📥 Downloading...")
            callback(progress, "Downloading...")

        case 1: // Installing
            printOS("  📦 Installing...")
            callback(progress, "Installing...")

        case 5: // Complete
            printOS("  ✅ Complete")

            // Cleanup callback
            _ = callbackQueue.sync {
                progressCallbacks.removeValue(forKey: adamID)
            }

            callback(1.0, "Completed")

        default:
            printOS("  ❓ Unknown phase type: \(phaseType)")
            callback(progress, "Processing...")
        }
    }
}
