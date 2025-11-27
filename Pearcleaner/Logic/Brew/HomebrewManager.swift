//
//  HomebrewManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import Foundation
import AlinFoundation

enum InstalledCategory: String, CaseIterable {
    case outdated = "Outdated"
    case formulae = "Formulae"
    case casks = "Casks"

    var icon: String {
        switch self {
        case .outdated: return "arrow.triangle.2.circlepath"
        case .formulae: return "terminal"
        case .casks: return "shippingbox"
        }
    }
}

enum AvailableCategory: String, CaseIterable {
    case formulae = "Formulae"
    case casks = "Casks"

    var icon: String {
        switch self {
        case .formulae: return "terminal"
        case .casks: return "shippingbox"
        }
    }
}

@MainActor
class HomebrewManager: ObservableObject {
    // Lightweight models for Browse tab Installed section (fast streaming)
    @Published var installedFormulae: [InstalledPackage] = []
    @Published var installedCasks: [InstalledPackage] = []
    @Published var outdatedPackagesMap: [String: OutdatedVersionInfo] = [:]
    @Published var isLoadingOutdated: Bool = false

    // Organized categories for Browse tab (matches UpdateManager pattern)
    @Published var installedByCategory: [InstalledCategory: [HomebrewSearchResult]] = [:]
    @Published var availableByCategory: [AvailableCategory: [HomebrewSearchResult]] = [:]

    @Published var availableTaps: [HomebrewTapInfo] = []
    @Published var isLoadingPackages: Bool = false
    @Published var isLoadingTaps: Bool = false
    @Published var brewVersion: String = ""
    @Published var latestBrewVersion: String = ""
    @Published var updateAvailable: Bool = false
    @Published var cacheSize: Int64 = 0 // Swift-calculated cache size (instant)
    @Published var analyticsEnabled: Bool = false
    @Published var isCheckingAnalytics: Bool = false

    // Browse tab cached packages
    @Published var allAvailableFormulae: [HomebrewSearchResult] = []
    @Published var allAvailableCasks: [HomebrewSearchResult] = []

    // Track if initial data has been loaded for session
    var hasLoadedInstalledPackages: Bool = false
    var hasLoadedAvailablePackages: Bool = false
    @Published var isLoadingAvailablePackages: Bool = false

    // Maintenance tab refresh trigger
    @Published var maintenanceRefreshTrigger: Bool = false

    var allPackages: [InstalledPackage] {
        return installedFormulae + installedCasks
    }

    // Calculate outdated packages by comparing installed version with JWS version
    var outdatedPackages: [InstalledPackage] {
        return allPackages.filter { package in
            // Use brew outdated as source of truth
            return outdatedPackagesMap.keys.contains(package.name)
        }
    }

    /// Get version information for an outdated package
    /// Returns version info or nil if not outdated
    func getOutdatedVersions(for packageName: String) -> OutdatedVersionInfo? {
        // Try exact name first
        if let versions = outdatedPackagesMap[packageName] {
            return versions
        }

        // Try short name fallback (e.g., "homebrew/cask/name" -> "name")
        let shortName = packageName.components(separatedBy: "/").last ?? packageName
        return outdatedPackagesMap[shortName]
    }

    func refreshAll() async {
        async let packages: Void = loadInstalledPackages()
        async let taps: Void = loadTaps()
        async let version: Void = loadBrewVersion()
        async let cache: Void = loadCacheSize()
        async let analytics: Void = checkAnalyticsStatus()

        _ = await (packages, taps, version, cache, analytics)
    }

    func refreshMaintenance() async {
        // Toggle trigger immediately to notify MaintenanceSection to re-run checks
        maintenanceRefreshTrigger.toggle()

        async let version: Void = loadBrewVersion()
        async let cache: Void = loadCacheSize()
        async let analytics: Void = checkAnalyticsStatus()
        async let update: Void = checkForUpdate()

        _ = await (version, cache, analytics, update)
    }

    func loadInstalledPackages() async {
        isLoadingPackages = true
        defer { isLoadingPackages = false }

        // Clear existing arrays
        installedFormulae.removeAll()
        installedCasks.removeAll()

        // Temporary arrays to collect all packages before updating @Published properties
        var tempFormulae: [InstalledPackage] = []
        var tempCasks: [InstalledPackage] = []

        do {
            // Fast scanner - reads local files directly (~70ms total)
            // Collect formulae with installedOnRequest from INSTALL_RECEIPT.json
            try await HomebrewController.shared.streamInstalledPackages(cask: false) { name, displayName, desc, version, isPinned, tap, tapRbPath, installedOnRequest in
                let package = InstalledPackage(
                    name: name,
                    displayName: displayName,
                    description: desc,
                    version: version,
                    isCask: false,
                    isPinned: isPinned,
                    tap: tap,
                    tapRbPath: tapRbPath,
                    installedOnRequest: installedOnRequest
                )
                tempFormulae.append(package)
            }

            // Collect casks (casks are always installed on request)
            try await HomebrewController.shared.streamInstalledPackages(cask: true) { name, displayName, desc, version, isPinned, tap, tapRbPath, installedOnRequest in
                let package = InstalledPackage(
                    name: name,
                    displayName: displayName,
                    description: desc,
                    version: version,
                    isCask: true,
                    isPinned: isPinned,
                    tap: tap,
                    tapRbPath: tapRbPath,
                    installedOnRequest: installedOnRequest  // Always true for casks
                )
                tempCasks.append(package)
            }

            // Update @Published properties once with all packages (sorted alphabetically by display name)
            installedFormulae = tempFormulae.sorted { ($0.displayName ?? $0.name).sortKey < ($1.displayName ?? $1.name).sortKey }
            installedCasks = tempCasks.sorted { ($0.displayName ?? $0.name).sortKey < ($1.displayName ?? $1.name).sortKey }

            // Mark as loaded for this session
            hasLoadedInstalledPackages = true

            // Populate installedByCategory immediately with initial data (empty outdated for now)
            updateInstalledCategories()

            // Load outdated packages using hybrid approach (don't block UI)
            // ~3.5x faster than `brew outdated` for core packages, accurate for tap packages
            Task {
                await MainActor.run { isLoadingOutdated = true }

                let packages = await HomebrewController.shared.getOutdatedPackagesHybrid(
                    formulae: tempFormulae,
                    casks: tempCasks
                )

                await MainActor.run {
                    outdatedPackagesMap = Dictionary(uniqueKeysWithValues: packages.map {
                        // Strip revision suffix for casks (Sparkle updates), keep for formulae (revision tracking)
                        let installedDisplay = $0.isCask ? $0.installedVersion.stripBrewRevisionSuffix() : $0.installedVersion
                        let availableDisplay = $0.isCask ? $0.availableVersion.stripBrewRevisionSuffix() : $0.availableVersion
                        return ($0.name, OutdatedVersionInfo(installed: installedDisplay, available: availableDisplay))
                    })
                    isLoadingOutdated = false
                    // Update categories now that we have outdated info
                    updateInstalledCategories()

                    // Print debug log report if debug logging is enabled
                    if UserDefaults.standard.object(forKey: "settings.updater.debugLogging") as? Bool ?? true {
                        printOS("\n" + UpdaterDebugLogger.shared.generateDebugReport())
                    }
                }
            }
        } catch {
            printOS("Error loading packages: \(error)")
        }
    }

    /// Refresh only specific packages after install/update/uninstall operations
    /// Much faster than full loadInstalledPackages() scan - only checks specified packages
    func refreshSpecificPackages(_ packageNames: [String]) async {
        guard !packageNames.isEmpty else { return }

        UpdaterDebugLogger.shared.log(.homebrew, "🔄 Refreshing \(packageNames.count) specific package(s): \(packageNames.joined(separator: ", "))")

        isLoadingPackages = true
        defer { isLoadingPackages = false }

        for name in packageNames {
            // Check both Cellar (formulae) and Caskroom (casks)
            let cellarPath = "\(HomebrewController.shared.brewPrefix)/Cellar/\(name)"
            let caskroomPath = "\(HomebrewController.shared.brewPrefix)/Caskroom/\(name)"

            if FileManager.default.fileExists(atPath: cellarPath) {
                // Formula still installed - update its info
                UpdaterDebugLogger.shared.log(.homebrew, "  Updating formula: \(name)")
                await refreshSinglePackage(name: name, isCask: false)
            } else if FileManager.default.fileExists(atPath: caskroomPath) {
                // Cask still installed - update its info
                UpdaterDebugLogger.shared.log(.homebrew, "  Updating cask: \(name)")
                await refreshSinglePackage(name: name, isCask: true)
            } else {
                // Package uninstalled - remove from lists
                UpdaterDebugLogger.shared.log(.homebrew, "  Package removed: \(name)")
                installedFormulae.removeAll { $0.name == name }
                installedCasks.removeAll { $0.name == name }
            }
        }

        // Update categories with refreshed data
        updateInstalledCategories()

        // Check outdated status for these specific packages only
        await refreshOutdatedStatus(for: packageNames)

        UpdaterDebugLogger.shared.log(.homebrew, "✓ Refresh complete for \(packageNames.count) package(s)")
    }

    /// Refresh a single package's information from Cellar/Caskroom
    private func refreshSinglePackage(name: String, isCask: Bool) async {
        do {
            var updatedPackage: InstalledPackage?

            // Stream only this specific package
            try await HomebrewController.shared.streamInstalledPackages(cask: isCask) { pkgName, displayName, desc, version, isPinned, tap, tapRbPath, installedOnRequest in
                if pkgName == name {
                    updatedPackage = InstalledPackage(
                        name: pkgName,
                        displayName: displayName,
                        description: desc,
                        version: version,
                        isCask: isCask,
                        isPinned: isPinned,
                        tap: tap,
                        tapRbPath: tapRbPath,
                        installedOnRequest: installedOnRequest
                    )
                }
            }

            // Update the appropriate array
            if let updated = updatedPackage {
                if isCask {
                    if let index = installedCasks.firstIndex(where: { $0.name == name }) {
                        installedCasks[index] = updated
                    } else {
                        installedCasks.append(updated)
                    }
                    // Re-sort after adding/updating to maintain alphabetical order
                    installedCasks.sort { ($0.displayName ?? $0.name).sortKey < ($1.displayName ?? $1.name).sortKey }
                } else {
                    if let index = installedFormulae.firstIndex(where: { $0.name == name }) {
                        installedFormulae[index] = updated
                    } else {
                        installedFormulae.append(updated)
                    }
                    // Re-sort after adding/updating to maintain alphabetical order
                    installedFormulae.sort { ($0.displayName ?? $0.name).sortKey < ($1.displayName ?? $1.name).sortKey }
                }
            }
        } catch {
            printOS("Error refreshing package \(name): \(error)")
        }
    }

    /// Check outdated status for specific packages only (much faster than checking all)
    private func refreshOutdatedStatus(for packageNames: [String]) async {
        isLoadingOutdated = true
        defer { isLoadingOutdated = false }

        // Get packages to check
        let packagesToCheck = allPackages.filter { packageNames.contains($0.name) }

        // Check outdated status using hybrid approach (only for these specific packages)
        let updatedOutdated = await HomebrewController.shared.getOutdatedPackagesHybrid(
            formulae: packagesToCheck.filter { !$0.isCask },
            casks: packagesToCheck.filter { $0.isCask }
        )

        // Update outdatedPackagesMap - remove old entries for these packages, add new ones if outdated
        for name in packageNames {
            outdatedPackagesMap.removeValue(forKey: name)
        }

        for package in updatedOutdated {
            // Strip revision suffix for casks (Sparkle updates), keep for formulae (revision tracking)
            let installedDisplay = package.isCask ? package.installedVersion.stripBrewRevisionSuffix() : package.installedVersion
            let availableDisplay = package.isCask ? package.availableVersion.stripBrewRevisionSuffix() : package.availableVersion
            outdatedPackagesMap[package.name] = OutdatedVersionInfo(
                installed: installedDisplay,
                available: availableDisplay
            )
        }

        // Update categories with new outdated status
        updateInstalledCategories()
    }

    // Update the installedByCategory dictionary (matches UpdateManager pattern)
    func updateInstalledCategories() {
        let allPackages = installedFormulae + installedCasks
        let allConverted = allPackages.map { convertToSearchResult($0) }

        // Separate into categories
        var outdated: [HomebrewSearchResult] = []
        var formulae: [HomebrewSearchResult] = []
        var casks: [HomebrewSearchResult] = []

        for result in allConverted {
            let isCask = installedCasks.contains(where: { $0.name == result.name })

            // Add to type-based category
            if isCask {
                casks.append(result)
            } else {
                formulae.append(result)
            }

            // Also add to Outdated if outdated
            if isPackageOutdated(result) {
                outdated.append(result)
            }
        }

        // Sort and update dictionary (by displayName for consistent alphabetical ordering)
        installedByCategory[.outdated] = outdated.sorted { ($0.displayName ?? $0.name).sortKey < ($1.displayName ?? $1.name).sortKey }
        installedByCategory[.formulae] = formulae.sorted { ($0.displayName ?? $0.name).sortKey < ($1.displayName ?? $1.name).sortKey }
        installedByCategory[.casks] = casks.sorted { ($0.displayName ?? $0.name).sortKey < ($1.displayName ?? $1.name).sortKey }
    }

    private func isPackageOutdated(_ result: HomebrewSearchResult) -> Bool {
        let shortName = result.name.components(separatedBy: "/").last ?? result.name
        return outdatedPackagesMap.keys.contains(result.name) ||
               outdatedPackagesMap.keys.contains(shortName)
    }

    private func convertToSearchResult(_ package: InstalledPackage) -> HomebrewSearchResult {
        // Look up tap info from available packages
        let availablePackages = package.isCask ? allAvailableCasks : allAvailableFormulae
        let shortName = package.name.components(separatedBy: "/").last ?? package.name

        // Try multiple matching strategies
        let matchingPackage = availablePackages.first(where: {
            if $0.name == package.name { return true }
            if $0.name == shortName { return true }
            let availableShortName = $0.name.components(separatedBy: "/").last ?? $0.name
            return availableShortName == shortName
        })

        let tap = package.tap

        // For installed casks, prefer AppInfo name over Homebrew displayName for consistent sorting
        let finalDisplayName: String? = {
            if package.isCask {
                // Look up app in sortedApps to get actual app name
                if let appInfo = AppState.shared.sortedApps.first(where: { $0.cask == package.name || $0.cask == shortName }) {
                    return appInfo.appName  // Use AppInfo name (e.g., "AppCleaner")
                }
            }
            // Fallback: Ruby file → JWS lookup
            return package.displayName ?? matchingPackage?.displayName
        }()

        return HomebrewSearchResult(
            name: package.name,
            displayName: finalDisplayName,
            description: package.description,
            homepage: nil,
            license: nil,
            version: package.version,
            dependencies: nil,
            caveats: nil,
            tap: tap,
            fullName: nil,
            isDeprecated: false,
            deprecationReason: nil,
            deprecationDate: nil,
            isDisabled: false,
            disableDate: nil,
            disableReason: nil,
            conflictsWith: nil,
            conflictsWithReasons: nil,
            isBottled: nil,
            isKegOnly: nil,
            kegOnlyReason: nil,
            buildDependencies: nil,
            optionalDependencies: nil,
            recommendedDependencies: nil,
            usesFromMacos: nil,
            aliases: nil,
            versionedFormulae: nil,
            requirements: nil,
            caskName: nil,
            autoUpdates: nil,
            artifacts: nil,
            url: nil,
            appcast: nil
        )
    }

    func loadTaps() async {
        isLoadingTaps = true
        defer { isLoadingTaps = false }

        do {
            availableTaps = try await HomebrewController.shared.loadTaps()
        } catch {
            printOS("Error loading taps: \(error)")
        }
    }

    func removeTapFromList(name: String) {
        availableTaps.removeAll { $0.name == name }
    }

    func loadBrewVersion() async {
        do {
            brewVersion = try await HomebrewController.shared.getBrewVersion()
        } catch {
            printOS("Error loading brew version: \(error)")
        }
    }

    func checkForUpdate() async {
        do {
            let result = try await HomebrewController.shared.checkForBrewUpdate()
            brewVersion = result.current
            latestBrewVersion = result.latest
            updateAvailable = result.updateAvailable
        } catch {
            printOS("Error checking for brew update: \(error)")
        }
    }

    func loadCacheSize() async {
        let result = await HomebrewController.shared.calculateCacheSize()
        cacheSize = result.bytes
    }

    func checkAnalyticsStatus() async {
        isCheckingAnalytics = true
        defer { isCheckingAnalytics = false }

        do {
            analyticsEnabled = try await HomebrewController.shared.getAnalyticsStatus()
        } catch {
            printOS("Error checking analytics status: \(error)")
        }
    }

    func loadAvailablePackages(appState: AppState, forceRefresh: Bool = false) async {
        guard forceRefresh || (allAvailableFormulae.isEmpty && allAvailableCasks.isEmpty) else {
            hasLoadedAvailablePackages = true
            return
        }

        isLoadingAvailablePackages = true
        defer { isLoadingAvailablePackages = false }

        do {
            // Update Homebrew first to ensure JWS files are up to date
            if forceRefresh {
                try await HomebrewController.shared.updateBrew()
            }

            // Load both JWS files in parallel (~0.63s total from earlier test)
            async let formulaeMetadata = HomebrewController.shared.loadMinimalPackageMetadata(cask: false)
            async let casksMetadata = HomebrewController.shared.loadMinimalPackageMetadata(cask: true)

            let (formulae, casks) = try await (formulaeMetadata, casksMetadata)

            // Convert to SearchResult objects with displayName, description, and version
            // Sort once here to avoid sorting on every search keystroke
            allAvailableFormulae = formulae.map { (name, displayName, description, version, _) in
                HomebrewSearchResult(
                    name: name,
                    displayName: displayName,
                    description: description,
                    homepage: nil,
                    license: nil,
                    version: version,
                    dependencies: nil,
                    caveats: nil,
                    tap: nil,
                    fullName: nil,
                    isDeprecated: false,
                    deprecationReason: nil,
                    deprecationDate: nil,
                    isDisabled: false,
                    disableDate: nil,
                    disableReason: nil,
                    conflictsWith: nil,
                    conflictsWithReasons: nil,
                    isBottled: nil,
                    isKegOnly: nil,
                    kegOnlyReason: nil,
                    buildDependencies: nil,
                    optionalDependencies: nil,
                    recommendedDependencies: nil,
                    usesFromMacos: nil,
                    aliases: nil,
                    versionedFormulae: nil,
                    requirements: nil,
                    caskName: nil,
                    autoUpdates: nil,
                    artifacts: nil,
                    url: nil,
                    appcast: nil
                )
            }.sorted { ($0.displayName ?? $0.name).sortKey < ($1.displayName ?? $1.name).sortKey }

            allAvailableCasks = casks.map { (name, displayName, description, version, _) in
                HomebrewSearchResult(
                    name: name,
                    displayName: displayName,
                    description: description,
                    homepage: nil,
                    license: nil,
                    version: version,
                    dependencies: nil,
                    caveats: nil,
                    tap: nil,
                    fullName: nil,
                    isDeprecated: false,
                    deprecationReason: nil,
                    deprecationDate: nil,
                    isDisabled: false,
                    disableDate: nil,
                    disableReason: nil,
                    conflictsWith: nil,
                    conflictsWithReasons: nil,
                    isBottled: nil,
                    isKegOnly: nil,
                    kegOnlyReason: nil,
                    buildDependencies: nil,
                    optionalDependencies: nil,
                    recommendedDependencies: nil,
                    usesFromMacos: nil,
                    aliases: nil,
                    versionedFormulae: nil,
                    requirements: nil,
                    caskName: nil,
                    autoUpdates: nil,
                    artifacts: nil,
                    url: nil,
                    appcast: nil
                )
            }.sorted { ($0.displayName ?? $0.name).sortKey < ($1.displayName ?? $1.name).sortKey }

            // Populate availableByCategory dictionary
            availableByCategory[.formulae] = allAvailableFormulae
            availableByCategory[.casks] = allAvailableCasks

            hasLoadedAvailablePackages = true
        } catch {
            printOS("Error loading package metadata: \(error)")
        }
    }
}
