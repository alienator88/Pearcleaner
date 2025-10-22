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

        // Get outdated packages from Homebrew (includes both casks and formulae)
        let outdatedNames = try? await HomebrewController.shared.getOutdatedPackages()

        guard let outdatedNames = outdatedNames, !outdatedNames.isEmpty else { return [] }

        var updateableApps: [UpdateableApp] = []

        // Process casks (GUI apps)
        for appInfo in brewApps {
            guard let cask = appInfo.cask else { continue }

            // Check if this cask is in the outdated list
            if outdatedNames.contains(cask) {
                let updateableApp = UpdateableApp(
                    appInfo: appInfo,
                    availableVersion: nil, // We don't have the new version easily available
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
                    isIOSApp: false  // Homebrew apps are never iOS apps
                )
                updateableApps.append(updateableApp)
            }
        }

        // Process formulae (CLI tools) if enabled
        if includeFormulae {
            // Get the set of cask names we've already processed
            let processedCasks = Set(brewApps.compactMap { $0.cask })

            // Filter outdated packages to only include formulae (not casks we already processed)
            let outdatedFormulae = outdatedNames.filter { !processedCasks.contains($0) }

            // Fetch versions concurrently for all outdated formulae
            await withTaskGroup(of: (String, String?, String?).self) { group in
                for formulaName in outdatedFormulae {
                    group.addTask {
                        // Get installed version from Cellar
                        let installedVersion = await HomebrewController.shared.getFormulaNameDescVersionPin(name: formulaName)?.2

                        // Get available version from API/cache
                        let availableVersion = try? await HomebrewController.shared.getFormulaVersion(name: formulaName)

                        return (formulaName, installedVersion, availableVersion)
                    }
                }

                // Collect results and create UpdateableApp entries
                for await (formulaName, installedVersion, availableVersion) in group {
                    // Create a minimal AppInfo for the formula (CLI tool)
                    let formulaAppInfo = AppInfo(
                        id: UUID(),
                        path: URL(fileURLWithPath: "/usr/local/bin/\(formulaName)"), // Placeholder path
                        bundleIdentifier: "com.homebrew.formula.\(formulaName)",
                        appName: formulaName,
                        appVersion: installedVersion ?? "unknown",
                        appIcon: nil,
                        webApp: false,
                        wrapped: false,
                        system: false,
                        arch: .universal,
                        cask: formulaName, // Store formula name in cask field for update/uninstall operations
                        steam: false,
                        bundleSize: 0,
                        lipoSavings: nil,
                        fileSize: [:],
                        fileIcon: [:],
                        creationDate: nil,
                        contentChangeDate: nil,
                        lastUsedDate: nil,
                        entitlements: nil
                    )

                    let updateableApp = UpdateableApp(
                        appInfo: formulaAppInfo,
                        availableVersion: availableVersion,
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
                        isIOSApp: false
                    )
                    updateableApps.append(updateableApp)
                }
            }
        }

        return updateableApps
    }
}
