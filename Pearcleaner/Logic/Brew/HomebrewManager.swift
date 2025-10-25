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
    @Published var downloadsCacheSize: Int64 = 0
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
        async let cache: Void = loadDownloadsCacheSize()
        async let analytics: Void = checkAnalyticsStatus()

        _ = await (packages, taps, version, cache, analytics)
    }

    func refreshMaintenance() async {
        // Toggle trigger immediately to notify MaintenanceSection to re-run checks
        maintenanceRefreshTrigger.toggle()

        async let version: Void = loadBrewVersion()
        async let cache: Void = loadDownloadsCacheSize()
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
            // Collect formulae
            try await HomebrewController.shared.streamInstalledPackages(cask: false) { name, desc, version, isPinned in
                let package = InstalledPackage(
                    name: name,
                    description: desc,
                    version: version,
                    isCask: false,
                    isPinned: isPinned
                )
                tempFormulae.append(package)
            }

            // Collect casks
            try await HomebrewController.shared.streamInstalledPackages(cask: true) { name, desc, version, isPinned in
                let package = InstalledPackage(
                    name: name,
                    description: desc,
                    version: version,
                    isCask: true,
                    isPinned: isPinned
                )
                tempCasks.append(package)
            }

            // Update @Published properties once with all packages
            installedFormulae = tempFormulae
            installedCasks = tempCasks

            // Mark as loaded for this session
            hasLoadedInstalledPackages = true

            // Populate installedByCategory immediately with initial data (empty outdated for now)
            updateInstalledCategories()

            // Load outdated packages from brew outdated in background (don't block UI)
            Task {
                await MainActor.run { isLoadingOutdated = true }

                if let packages = try? await HomebrewController.shared.getOutdatedPackagesWithVersions() {
                    await MainActor.run {
                        outdatedPackagesMap = Dictionary(uniqueKeysWithValues: packages.map {
                            ($0.name, OutdatedVersionInfo(installed: $0.installedVersion, available: $0.availableVersion))
                        })
                        isLoadingOutdated = false
                        // Update categories now that we have outdated info
                        updateInstalledCategories()
                    }
                } else {
                    await MainActor.run { isLoadingOutdated = false }
                }
            }
        } catch {
            printOS("Error loading packages: \(error)")
        }
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

        // Sort and update dictionary
        installedByCategory[.outdated] = outdated.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        installedByCategory[.formulae] = formulae.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        installedByCategory[.casks] = casks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

        let tap = matchingPackage?.tap

        return HomebrewSearchResult(
            name: package.name,
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

    func loadDownloadsCacheSize() async {
        do {
            downloadsCacheSize = try await HomebrewController.shared.getDownloadsCacheSize()
        } catch {
            printOS("Error loading downloads cache size: \(error)")
        }
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
            // Update Homebrew first to ensure name files are up to date
            if forceRefresh {
                try await HomebrewController.shared.updateBrew()
            }

            // Load package names from tiny text files (172KB total vs 44MB JWS)
            let formulaeNames = try await HomebrewController.shared.loadPackageNames(cask: false)
            let caskNames = try await HomebrewController.shared.loadPackageNames(cask: true)

            // Convert names to minimal SearchResult objects (name only, no description)
            // Sort once here to avoid sorting on every search keystroke
            allAvailableFormulae = formulaeNames.map { name in
                HomebrewSearchResult(
                    name: name,
                    description: nil,  // No description - will fetch on demand when Info clicked
                    homepage: nil,
                    license: nil,
                    version: nil,
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
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            allAvailableCasks = caskNames.map { name in
                HomebrewSearchResult(
                    name: name,
                    description: nil,  // No description - will fetch on demand when Info clicked
                    homepage: nil,
                    license: nil,
                    version: nil,
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
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            // Populate availableByCategory dictionary
            availableByCategory[.formulae] = allAvailableFormulae
            availableByCategory[.casks] = allAvailableCasks

            hasLoadedAvailablePackages = true
        } catch {
            printOS("Error loading package names: \(error)")
        }
    }
}
