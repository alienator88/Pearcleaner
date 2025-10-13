//
//  SparkleDetector.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation

class SparkleDetector {
    static func findSparkleApps(from apps: [AppInfo]) async -> [UpdateableApp] {
        // NOTE: Without importing the Sparkle framework, we cannot actually check
        // if updates are available. We can only detect that an app uses Sparkle.
        // To avoid showing false positives (all Sparkle apps as "having updates"),
        // we return an empty list. Users can check for updates within each app.
        //
        // If you want to show Sparkle-enabled apps anyway, uncomment the code below:

        return []

        /*
        var sparkleApps: [UpdateableApp] = []

        for appInfo in apps {
            // Read the app's Info.plist
            let infoPlistURL = appInfo.path.appendingPathComponent("Contents/Info.plist")

            guard let infoDict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else {
                continue
            }

            // Check for Sparkle feed URL
            if infoDict["SUFeedURL"] != nil || infoDict["SUFeedUrl"] != nil {
                let updateableApp = UpdateableApp(
                    appInfo: appInfo,
                    availableVersion: nil, // Can't check version without Sparkle framework
                    source: .sparkle,
                    adamID: nil,
                    appStoreURL: nil,
                    status: .idle,
                    progress: 0.0
                )
                sparkleApps.append(updateableApp)
            }
        }

        return sparkleApps
        */
    }
}
