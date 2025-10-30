//
//  HomebrewUpdateChecker.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation

class HomebrewUpdateChecker {
    static func checkForUpdates(apps: [AppInfo], includeFormulae: Bool, showAutoUpdatesInHomebrew: Bool = true) async -> [UpdateableApp] {
        // Filter apps that have a cask identifier
        // When showAutoUpdatesInHomebrew=false: exclude casks with auto_updates=true (they'll only appear in Sparkle)
        let brewApps = apps.filter { app in
            guard let cask = app.cask, !cask.isEmpty else { return false }

            // If user disabled auto-updating apps in Homebrew section, filter them out
            if !showAutoUpdatesInHomebrew, let autoUpdates = app.autoUpdates, autoUpdates {
                return false  // Skip apps with auto_updates=true
            }

            return true
        }

        // Step 1: Build list of installed packages by scanning Cellar/Caskroom (~70ms)
        // This enables the fast hybrid API approach instead of slow `brew outdated` command
        var installedCasks: [InstalledPackage] = []
        var installedFormulae: [InstalledPackage] = []

        // Scan casks (always needed)
        try? await HomebrewController.shared.streamInstalledPackages(cask: true) { name, displayName, desc, version, isPinned, tap, tapRbPath, installedOnRequest in
            // Check for cancellation during streaming
            if Task.isCancelled {
                return
            }
            installedCasks.append(InstalledPackage(
                name: name,
                displayName: displayName,
                description: desc,
                version: version,
                isCask: true,
                isPinned: isPinned,
                tap: tap,
                tapRbPath: tapRbPath,
                installedOnRequest: installedOnRequest  // Always true for casks
            ))
        }

        // Check for cancellation before scanning formulae
        if Task.isCancelled {
            return []
        }

        // Scan formulae only if enabled
        if includeFormulae {
            try? await HomebrewController.shared.streamInstalledPackages(cask: false) { name, displayName, desc, version, isPinned, tap, tapRbPath, installedOnRequest in
                // Check for cancellation during streaming
                if Task.isCancelled {
                    return
                }
                installedFormulae.append(InstalledPackage(
                    name: name,
                    displayName: displayName,
                    description: desc,
                    version: version,
                    isCask: false,
                    isPinned: isPinned,
                    tap: tap,
                    tapRbPath: tapRbPath,
                    installedOnRequest: installedOnRequest
                ))
            }
        }

        // Step 2: Check outdated using FAST hybrid API approach (~650ms)
        // Much faster than `brew outdated` command (~2.3s) - uses parallel API calls + .rb fallback for taps
        let outdatedPackages = await HomebrewController.shared.getOutdatedPackagesHybrid(
            formulae: installedFormulae,
            casks: installedCasks
        )

        guard !outdatedPackages.isEmpty else { return [] }

        var updateableApps: [UpdateableApp] = []

        // Process outdated casks (GUI apps) - no API calls needed, versions already included
        for outdatedPkg in outdatedPackages where outdatedPkg.isCask {
            // Find matching app by cask name
            guard let appInfo = brewApps.first(where: { $0.cask == outdatedPkg.name }) else { continue }

            // Use app's ACTUAL version from Info.plist (ground truth) instead of Homebrew's stale record
            // This eliminates false positives for auto-updating apps (Sparkle, direct downloads)
            let installedClean = appInfo.appVersion.cleanBrewVersionForDisplay()
            let availableClean = outdatedPkg.availableVersion.cleanBrewVersionForDisplay()

            // Compare ACTUAL app version vs latest Homebrew version
            let installed = Version(versionNumber: installedClean, buildNumber: nil)
            let available = Version(versionNumber: availableClean, buildNumber: nil)

            // Only add if truly outdated (available > installed)
            // Homebrew's .metadata/ record is ignored for comparison (can be stale if app auto-updated)
            guard !installed.isEmpty && !available.isEmpty && available > installed else {
                continue  // Skip if versions are equal, invalid, or installed is newer
            }

            // Keep actual version from Info.plist for accurate UI display
            // (Comparison above already used this version, so UI should match)
            let correctedAppInfo = AppInfo(
                id: appInfo.id,
                path: appInfo.path,
                bundleIdentifier: appInfo.bundleIdentifier,
                appName: appInfo.appName,
                appVersion: appInfo.appVersion,  // Use ACTUAL version from Info.plist (ground truth)
                appBuildNumber: appInfo.appBuildNumber,
                appIcon: appInfo.appIcon,
                webApp: appInfo.webApp,
                wrapped: appInfo.wrapped,
                system: appInfo.system,
                arch: appInfo.arch,
                cask: appInfo.cask,
                steam: appInfo.steam,
                hasSparkle: appInfo.hasSparkle,
                isAppStore: appInfo.isAppStore,
                autoUpdates: appInfo.autoUpdates,
                bundleSize: appInfo.bundleSize,
                lipoSavings: appInfo.lipoSavings,
                fileSize: appInfo.fileSize,
                fileIcon: appInfo.fileIcon,
                creationDate: appInfo.creationDate,
                contentChangeDate: appInfo.contentChangeDate,
                lastUsedDate: appInfo.lastUsedDate,
                entitlements: appInfo.entitlements,
                teamIdentifier: appInfo.teamIdentifier
            )

            let updateableApp = UpdateableApp(
                appInfo: correctedAppInfo,  // Use version from Homebrew metadata
                availableVersion: outdatedPkg.availableVersion,  // Available version from brew outdated
                availableBuildNumber: nil,  // Homebrew doesn't provide separate build numbers
                source: .homebrew,
                adamID: nil,
                appStoreURL: nil,
                status: .idle,
                progress: 0.0,
                isSelectedForUpdate: true,
                releaseTitle: nil,
                releaseDescription: nil,
                releaseNotesLink: nil,
                releaseDate: nil,
                isPreRelease: false,  // Homebrew updates are not pre-releases
                isIOSApp: false  // Homebrew apps are never iOS apps
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
                    path: URL(fileURLWithPath: "\(HomebrewController.shared.brewPrefix)/bin/\(outdatedPkg.name)"), // Placeholder path
                    bundleIdentifier: "com.homebrew.formula.\(outdatedPkg.name)",
                    appName: outdatedPkg.name,
                    appVersion: outdatedPkg.installedVersion,
                    appBuildNumber: nil,  // Formulae don't have build numbers
                    appIcon: nil,
                    webApp: false,
                    wrapped: false,
                    system: false,
                    arch: .universal,
                    cask: outdatedPkg.name, // Store formula name in cask field for update/uninstall operations
                    steam: false,
                    hasSparkle: false,  // Formulae (CLI tools) don't have Sparkle
                    isAppStore: false,  // Formulae are not from App Store
                    autoUpdates: nil,  // Formulae don't have auto_updates (cask-only property)
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
                    availableBuildNumber: nil,  // Homebrew doesn't provide separate build numbers
                    source: .homebrew,
                    adamID: nil,
                    appStoreURL: nil,
                    status: .idle,
                    progress: 0.0,
                    isSelectedForUpdate: true,
                    releaseTitle: nil,
                    releaseDescription: nil,
                    releaseNotesLink: nil,
                    releaseDate: nil,
                    isPreRelease: false,
                    isIOSApp: false
                )
                updateableApps.append(updateableApp)
            }
        }

        return updateableApps
    }
}
