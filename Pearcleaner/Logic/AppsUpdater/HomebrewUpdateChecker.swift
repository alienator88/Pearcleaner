//
//  HomebrewUpdateChecker.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation

class HomebrewUpdateChecker {
    static func checkForUpdates(apps: [AppInfo], includeFormulae: Bool) async -> [UpdateableApp] {
        // Filter apps that have a cask identifier
        let brewApps = apps.filter { $0.cask != nil && !$0.cask!.isEmpty }

        // Get outdated packages with versions in ONE command (no additional API calls needed)
        guard let outdatedPackages = try? await HomebrewController.shared.getOutdatedPackagesWithVersions(),
              !outdatedPackages.isEmpty else { return [] }

        var updateableApps: [UpdateableApp] = []

        // Process outdated casks (GUI apps) - no API calls needed, versions already included
        for outdatedPkg in outdatedPackages where outdatedPkg.isCask {
            // Find matching app by cask name
            guard let appInfo = brewApps.first(where: { $0.cask == outdatedPkg.name }) else { continue }

            // Clean versions (remove commit hash) for accurate comparison
            let installedClean = outdatedPkg.installedVersion.cleanBrewVersionForDisplay()
            let availableClean = outdatedPkg.availableVersion.cleanBrewVersionForDisplay()

            // Compare versions using Version struct (supports 4+ components)
            let installed = Version(versionNumber: installedClean, buildNumber: nil)
            let available = Version(versionNumber: availableClean, buildNumber: nil)

            // Only add if truly outdated (available > installed)
            // This filters out false positives from --greedy flag on auto-updating apps
            guard !installed.isEmpty && !available.isEmpty && available > installed else {
                continue  // Skip if versions are equal, invalid, or installed is newer
            }

            let updateableApp = UpdateableApp(
                appInfo: appInfo,
                availableVersion: outdatedPkg.availableVersion,  // Available version from brew outdated
                source: .homebrew,
                adamID: nil,
                appStoreURL: nil,
                status: .idle,
                progress: 0.0,
                releaseTitle: nil,
                releaseDescription: nil,
                releaseNotesLink: nil,
                releaseDate: nil,
                isPreRelease: false,  // Homebrew updates are not pre-releases
                isIOSApp: false,  // Homebrew apps are never iOS apps
                extractedFromBinary: false,
                alternateSparkleURLs: nil,
                currentFeedURL: nil
            )
            updateableApps.append(updateableApp)
        }

        // Process outdated formulae (CLI tools) if enabled - no API calls needed
        if includeFormulae {
            // Get the set of cask names we've already processed
            let processedCasks = Set(brewApps.compactMap { $0.cask })

            for outdatedPkg in outdatedPackages where !outdatedPkg.isCask {
                // Skip if this formula name matches a cask we already processed
                guard !processedCasks.contains(outdatedPkg.name) else { continue }

                // Clean versions for comparison (same logic as casks)
                let installedClean = outdatedPkg.installedVersion.cleanBrewVersionForDisplay()
                let availableClean = outdatedPkg.availableVersion.cleanBrewVersionForDisplay()

                // Compare versions using Version struct
                let installed = Version(versionNumber: installedClean, buildNumber: nil)
                let available = Version(versionNumber: availableClean, buildNumber: nil)

                // Only add if truly outdated (available > installed)
                // This filters out revision bumps where user-facing version is identical
                guard !installed.isEmpty && !available.isEmpty && available > installed else {
                    continue  // Skip if versions are equal, invalid, or installed is newer
                }

                // Create a minimal AppInfo for the formula (CLI tool)
                let formulaAppInfo = AppInfo(
                    id: UUID(),
                    path: URL(fileURLWithPath: "/usr/local/bin/\(outdatedPkg.name)"), // Placeholder path
                    bundleIdentifier: "com.homebrew.formula.\(outdatedPkg.name)",
                    appName: outdatedPkg.name,
                    appVersion: outdatedPkg.installedVersion,
                    appIcon: nil,
                    webApp: false,
                    wrapped: false,
                    system: false,
                    arch: .universal,
                    cask: outdatedPkg.name, // Store formula name in cask field for update/uninstall operations
                    steam: false,
                    bundleSize: 0,
                    lipoSavings: nil,
                    fileSize: [:],
                    fileIcon: [:],
                    creationDate: nil,
                    contentChangeDate: nil,
                    lastUsedDate: nil,
                    entitlements: nil,
                    teamIdentifier: nil
                )

                let updateableApp = UpdateableApp(
                    appInfo: formulaAppInfo,
                    availableVersion: outdatedPkg.availableVersion,
                    source: .homebrew,
                    adamID: nil,
                    appStoreURL: nil,
                    status: .idle,
                    progress: 0.0,
                    releaseTitle: nil,
                    releaseDescription: nil,
                    releaseNotesLink: nil,
                    releaseDate: nil,
                    isPreRelease: false,
                    isIOSApp: false,
                    extractedFromBinary: false,
                    alternateSparkleURLs: nil,
                    currentFeedURL: nil
                )
                updateableApps.append(updateableApp)
            }
        }

        return updateableApps
    }
}
