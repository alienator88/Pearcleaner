//
//  HomebrewAdoption.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/18/25.
//

import Foundation

// MARK: - Adoptable Cask Model

struct AdoptableCask: Identifiable {
    let id: String  // token
    let token: String
    let displayName: String
    let description: String?
    let version: String
    let autoUpdates: Bool
    let homepage: String?
    let isVersionCompatible: Bool
    let matchScore: Int

    init(from searchResult: HomebrewSearchResult, appInfo: AppInfo, matchScore: Int) {
        self.token = searchResult.name
        self.id = searchResult.name
        self.displayName = searchResult.displayName ?? searchResult.name
        self.description = searchResult.description
        self.version = searchResult.version ?? "unknown"
        self.autoUpdates = searchResult.autoUpdates ?? false
        self.homepage = searchResult.homepage
        self.matchScore = matchScore

        // Version compatibility check
        if self.autoUpdates {
            // Auto-updating apps don't need strict version matching
            self.isVersionCompatible = true
        } else {
            // Non auto-updating apps need version match
            self.isVersionCompatible = appInfo.appVersion.pearFormat() == self.version.pearFormat()
        }
    }
}

// MARK: - Cask Matching Logic

/// Finds matching Homebrew casks for a given app
/// Returns array of AdoptableCask sorted by match score (highest first)
func findMatchingCasks(for appInfo: AppInfo, from casks: [HomebrewSearchResult]) -> [AdoptableCask] {
    var matches: [(cask: HomebrewSearchResult, score: Int)] = []

    let appNameNormalized = appInfo.appName.pearFormat()
    let bundleIdNormalized = appInfo.bundleIdentifier.pearFormat()

    for cask in casks {
        var score = 0

        // Skip deprecated/disabled casks
        if cask.isDeprecated || cask.isDisabled {
            continue
        }

        // Priority 1: Check artifacts array (e.g., ["1Password.app"])
        if let artifacts = cask.artifacts {
            for artifact in artifacts {
                let artifactNormalized = artifact.pearFormat()

                // Exact match with .app extension
                if artifactNormalized == appNameNormalized + "app" {
                    score += 100
                    break
                }

                // Match without extension
                if artifactNormalized == appNameNormalized {
                    score += 90
                    break
                }

                // Partial match
                if artifactNormalized.contains(appNameNormalized) || appNameNormalized.contains(artifactNormalized) {
                    score += 50
                }
            }
        }

        // Priority 2: Check caskName array (e.g., ["1Password", "One Password"])
        if let caskNames = cask.caskName {
            for name in caskNames {
                let nameNormalized = name.pearFormat()

                // Exact match
                if nameNormalized == appNameNormalized {
                    score += 80
                    break
                }

                // Partial match (exact match only for very short names ≤2 chars)
                if nameNormalized.count <= 2 || appNameNormalized.count <= 2 {
                    // Exact match only for very short names to avoid false positives (e.g., "R" matching "Apparency")
                    // Skip partial matching
                } else {
                    // Partial match for longer names (3+ characters)
                    if nameNormalized.contains(appNameNormalized) || appNameNormalized.contains(nameNormalized) {
                        score += 40
                    }
                }
            }
        }

        // Priority 3: Check displayName (human-readable name)
        if let displayName = cask.displayName {
            let displayNameNormalized = displayName.pearFormat()

            // Exact match
            if displayNameNormalized == appNameNormalized {
                score += 70
            }

            // Partial match (exact match only for very short names ≤2 chars)
            if displayNameNormalized.count <= 2 || appNameNormalized.count <= 2 {
                // Exact match only for very short names to avoid false positives (e.g., "R" matching "Apparency")
                // Skip partial matching
            } else {
                // Partial match for longer names (3+ characters)
                if displayNameNormalized.contains(appNameNormalized) || appNameNormalized.contains(displayNameNormalized) {
                    score += 35
                }
            }
        }

        // Priority 4: Check token (cask identifier, e.g., "1password")
        let tokenNormalized = cask.name.pearFormat()

        // Exact match
        if tokenNormalized == appNameNormalized {
            score += 60
        }

        // Partial match (exact match only for very short names ≤2 chars)
        if tokenNormalized.count <= 2 || appNameNormalized.count <= 2 {
            // Exact match only for very short names to avoid false positives (e.g., "R" matching "Apparency")
            // Skip partial matching
        } else {
            // Partial match for longer names (3+ characters)
            if tokenNormalized.contains(appNameNormalized) || appNameNormalized.contains(tokenNormalized) {
                score += 30
            }
        }

        // Priority 5: Check bundle ID if available in description or homepage
        // Some casks include bundle ID in description or we can infer from paths
        if !bundleIdNormalized.isEmpty {
            if let description = cask.description {
                let descNormalized = description.pearFormat()
                if descNormalized.contains(bundleIdNormalized) {
                    score += 25
                }
            }
        }

        // Only include casks with meaningful matches (score > 0)
        if score > 0 {
            matches.append((cask: cask, score: score))
        }
    }

    // Sort by score descending, then by name ascending
    matches.sort { lhs, rhs in
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        return lhs.cask.name < rhs.cask.name
    }

    // Convert to AdoptableCask and return
    return matches.map { AdoptableCask(from: $0.cask, appInfo: appInfo, matchScore: $0.score) }
}

/// Validates if a manually entered cask token exists in the cask database
/// Returns AdoptableCask if found, nil otherwise
func validateManualCaskEntry(_ token: String, for appInfo: AppInfo, from casks: [HomebrewSearchResult]) -> AdoptableCask? {
    let tokenNormalized = token.pearFormat()

    // Find exact token match
    guard let cask = casks.first(where: { $0.name.pearFormat() == tokenNormalized }) else {
        return nil
    }

    // Skip deprecated/disabled casks
    if cask.isDeprecated || cask.isDisabled {
        return nil
    }

    // Return as AdoptableCask with manual entry score
    return AdoptableCask(from: cask, appInfo: appInfo, matchScore: 999)  // High score for manual entry
}
