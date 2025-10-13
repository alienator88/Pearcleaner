//
//  AppStoreDetector.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation
import AlinFoundation

@MainActor
class AppStoreDetector {
    static func findAppStoreApps(from apps: [AppInfo]) async -> [URL: UInt64] {
        return await withCheckedContinuation { continuation in
            let query = NSMetadataQuery()
            query.predicate = NSPredicate(format: "kMDItemAppStoreAdamID LIKE '*'")
            query.searchScopes = [
                "/Applications",
                NSHomeDirectory() + "/Applications"
            ]

            var adamIDs: [URL: UInt64] = [:]
            let appPaths = Set(apps.map { $0.path })
            var hasResumed = false

            // Add timeout in case the query never completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if !hasResumed {
                    hasResumed = true
                    query.stop()
                    continuation.resume(returning: adamIDs)
                }
            }

            NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { notification in
                guard !hasResumed else { return }
                hasResumed = true
                query.stop()

                for item in query.results as! [NSMetadataItem] {
                    let path = item.value(forAttribute: NSMetadataItemPathKey) as? String

                    // Get adamID - it's returned as NSNumber, not String
                    guard let path = path,
                          let adamIDNumber = item.value(forAttribute: "kMDItemAppStoreAdamID") as? NSNumber else {
                        continue
                    }

                    let adamID = adamIDNumber.uint64Value
                    let url = URL(fileURLWithPath: path)

                    // Normalize URLs for comparison (resolve symlinks, standardize)
                    let standardizedURL = url.standardizedFileURL

                    // Check if this URL matches any in our apps list
                    for appPath in appPaths {
                        let standardizedAppPath = appPath.standardizedFileURL
                        if standardizedURL == standardizedAppPath {
                            adamIDs[appPath] = adamID
                            break
                        }
                    }
                }

                continuation.resume(returning: adamIDs)
            }

            query.start()
        }
    }
}
