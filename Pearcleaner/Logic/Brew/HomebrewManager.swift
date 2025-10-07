//
//  HomebrewManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import Foundation
import AlinFoundation

@MainActor
class HomebrewManager: ObservableObject {
    // Lightweight models for Browse tab Installed section (fast streaming)
    @Published var installedFormulae: [InstalledPackage] = []
    @Published var installedCasks: [InstalledPackage] = []

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
    @Published var isLoadingAvailablePackages: Bool = false
    @Published var lastCacheRefresh: Date?  // For Browse tab timestamp display

    // Maintenance tab refresh trigger
    @Published var maintenanceRefreshTrigger: Bool = false

    var allPackages: [InstalledPackage] {
        return installedFormulae + installedCasks
    }

    // Calculate outdated packages by comparing installed version with JWS version
    var outdatedPackages: [InstalledPackage] {
        return allPackages.filter { package in
            guard let installedVersion = package.version else { return false }

            // Find the package in JWS data
            let availablePackages = package.isCask ? allAvailableCasks : allAvailableFormulae
            guard let jws = availablePackages.first(where: { $0.name == package.name }),
                  let latestVersion = jws.version else {
                return false
            }

            // Compare versions - simple string comparison for now
            return installedVersion != latestVersion
        }
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
        // Clear existing arrays
        installedFormulae.removeAll()
        installedCasks.removeAll()

        // Set loading flag only until first package arrives
        isLoadingPackages = true

        do {
            // Fast streaming scanner - reads local files directly
            // Stream formulae
            try await HomebrewController.shared.streamInstalledPackages(cask: false) { name, desc, version in
                let package = InstalledPackage(
                    name: name,
                    description: desc,
                    version: version,
                    isCask: false
                )
                self.installedFormulae.append(package)

                // Hide loading indicator once first package arrives
                if self.isLoadingPackages {
                    self.isLoadingPackages = false
                }
            }

            // Stream casks
            try await HomebrewController.shared.streamInstalledPackages(cask: true) { name, desc, version in
                let package = InstalledPackage(
                    name: name,
                    description: desc,
                    version: version,
                    isCask: true
                )
                self.installedCasks.append(package)
            }
        } catch {
            printOS("Error loading packages: \(error)")
        }

        // Ensure flag is cleared even if no packages found
        isLoadingPackages = false
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
        guard forceRefresh || (allAvailableFormulae.isEmpty && allAvailableCasks.isEmpty) else { return }

        isLoadingAvailablePackages = true
        defer { isLoadingAvailablePackages = false }

        // Set up SwiftData context for caching
        if #available(macOS 14.0, *), let container = appState.modelContainer {
            HomebrewController.shared.setModelContext(container: container)
        }

        // If force refresh, skip cache and reload from JSON
        if forceRefresh {
            await reloadFromJSON()
            return
        }

        // Try loading from cache first
        if #available(macOS 14.0, *) {
            let (cachedFormulae, cachedCasks, cacheDate) = await HomebrewController.shared.loadPackagesFromCache()

            if !cachedFormulae.isEmpty || !cachedCasks.isEmpty {
                // Sort cached results
                allAvailableFormulae = cachedFormulae.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                allAvailableCasks = cachedCasks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                lastCacheRefresh = cacheDate
                return
            }
        }

        // Cache miss - load from JSON files
        await reloadFromJSON()
    }

    private func reloadFromJSON() async {
        await HomebrewController.shared.preloadCache()

        do {
            // Load core packages from .jws.json files
            var formulae = try await HomebrewController.shared.searchPackages(query: "", cask: false)
            var casks = try await HomebrewController.shared.searchPackages(query: "", cask: true)

            // Append packages from tapped repositories
            let taps = try await HomebrewController.shared.loadTaps()
            for tap in taps where !tap.isOfficial {
                let (tapFormulae, tapCasks) = try await HomebrewController.shared.getPackagesFromTap(tap.name)
                formulae.append(contentsOf: tapFormulae)
                casks.append(contentsOf: tapCasks)
            }

            // Sort once here to avoid sorting on every search keystroke
            allAvailableFormulae = formulae.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            allAvailableCasks = casks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            // Save to cache (includes tap packages)
            if #available(macOS 14.0, *) {
                await HomebrewController.shared.savePackagesToCache(
                    formulae: allAvailableFormulae,
                    casks: allAvailableCasks
                )
                lastCacheRefresh = Date()
            }
        } catch {
            printOS("Error loading available packages: \(error)")
        }
    }

    // Add packages from a newly tapped repository to the Browse cache
    func addTapPackagesToCache(tapName: String) async {
        // Only add if Browse cache is already loaded
        guard !allAvailableFormulae.isEmpty || !allAvailableCasks.isEmpty else {
            return
        }

        do {
            // Load packages from the new tap
            let (tapFormulae, tapCasks) = try await HomebrewController.shared.getPackagesFromTap(tapName)

            // Append to existing lists
            allAvailableFormulae.append(contentsOf: tapFormulae)
            allAvailableCasks.append(contentsOf: tapCasks)

            // Update cache
            if #available(macOS 14.0, *) {
                await HomebrewController.shared.savePackagesToCache(
                    formulae: allAvailableFormulae,
                    casks: allAvailableCasks
                )
                lastCacheRefresh = Date()
            }

            printOS("Added \(tapFormulae.count) formulae and \(tapCasks.count) casks from \(tapName) to Browse cache")
        } catch {
            printOS("Error adding tap packages to cache: \(error)")
        }
    }

    // Remove packages from a removed tap from the Browse cache
    func removeTapPackagesFromCache(tapName: String) async {
        // Only remove if Browse cache is already loaded
        guard !allAvailableFormulae.isEmpty || !allAvailableCasks.isEmpty else {
            return
        }

        // Remove packages that start with the tap name
        let tapPrefix = "\(tapName)/"
        let beforeFormulaeCount = allAvailableFormulae.count
        let beforeCasksCount = allAvailableCasks.count

        allAvailableFormulae.removeAll { $0.name.hasPrefix(tapPrefix) }
        allAvailableCasks.removeAll { $0.name.hasPrefix(tapPrefix) }

        let removedFormulae = beforeFormulaeCount - allAvailableFormulae.count
        let removedCasks = beforeCasksCount - allAvailableCasks.count

        // Update cache
        if #available(macOS 14.0, *) {
            await HomebrewController.shared.savePackagesToCache(
                formulae: allAvailableFormulae,
                casks: allAvailableCasks
            )
            lastCacheRefresh = Date()
        }

        printOS("Removed \(removedFormulae) formulae and \(removedCasks) casks from \(tapName) from Browse cache")
    }
}
