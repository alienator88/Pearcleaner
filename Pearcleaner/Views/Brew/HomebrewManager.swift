//
//  HomebrewManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import Foundation

@MainActor
class HomebrewManager: ObservableObject {
    @Published var installedFormulae: [HomebrewPackageInfo] = []
    @Published var installedCasks: [HomebrewPackageInfo] = []
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

    var allPackages: [HomebrewPackageInfo] {
        return installedFormulae + installedCasks
    }

    var outdatedPackages: [HomebrewPackageInfo] {
        return allPackages.filter { $0.isOutdated }
    }

    func refreshAll() async {
        async let packages: Void = loadInstalledPackages()
        async let taps: Void = loadTaps()
        async let version: Void = loadBrewVersion()
        async let cache: Void = loadDownloadsCacheSize()
        async let analytics: Void = checkAnalyticsStatus()

        _ = await (packages, taps, version, cache, analytics)
    }

    func loadInstalledPackages() async {
        isLoadingPackages = true
        defer { isLoadingPackages = false }

        do {
            let (formulae, casks) = try await HomebrewController.shared.loadInstalledPackages()
            installedFormulae = formulae
            installedCasks = casks
        } catch {
            print("Error loading packages: \(error)")
        }
    }

    func loadTaps() async {
        isLoadingTaps = true
        defer { isLoadingTaps = false }

        do {
            availableTaps = try await HomebrewController.shared.loadTaps()
        } catch {
            print("Error loading taps: \(error)")
        }
    }

    func loadBrewVersion() async {
        do {
            brewVersion = try await HomebrewController.shared.getBrewVersion()
        } catch {
            print("Error loading brew version: \(error)")
        }
    }

    func checkForUpdate() async {
        do {
            let result = try await HomebrewController.shared.checkForBrewUpdate()
            brewVersion = result.current
            latestBrewVersion = result.latest
            updateAvailable = result.updateAvailable
        } catch {
            print("Error checking for brew update: \(error)")
        }
    }

    func loadDownloadsCacheSize() async {
        do {
            downloadsCacheSize = try await HomebrewController.shared.getDownloadsCacheSize()
        } catch {
            print("Error loading downloads cache size: \(error)")
        }
    }

    func checkAnalyticsStatus() async {
        isCheckingAnalytics = true
        defer { isCheckingAnalytics = false }

        do {
            analyticsEnabled = try await HomebrewController.shared.getAnalyticsStatus()
        } catch {
            print("Error checking analytics status: \(error)")
        }
    }

    func loadAvailablePackages() async {
        guard allAvailableFormulae.isEmpty && allAvailableCasks.isEmpty else { return }

        isLoadingAvailablePackages = true
        defer { isLoadingAvailablePackages = false }

        // Preload cache first
        await HomebrewController.shared.preloadCache()

        do {
            // Load all formulae
            allAvailableFormulae = try await HomebrewController.shared.searchPackages(query: "", cask: false)
            // Load all casks
            allAvailableCasks = try await HomebrewController.shared.searchPackages(query: "", cask: true)
        } catch {
            print("Error loading available packages: \(error)")
        }
    }
}
