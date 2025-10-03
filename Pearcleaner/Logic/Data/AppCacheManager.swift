//
//  AppCacheManager.swift
//  Pearcleaner
//
//  Manages SwiftData cache for app metadata
//

import Foundation
import SwiftData
import AlinFoundation

@available(macOS 14.0, *)
@MainActor
class AppCacheManager {
    static let shared = AppCacheManager()

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    private init() {}

    // MARK: - Setup

    func setContainer(_ container: ModelContainer) {
        self.modelContainer = container
        self.modelContext = ModelContext(container)
    }

    /// Creates and returns a ModelContainer for app caching
    /// - Returns: ModelContainer instance or nil if creation fails or macOS < 14
    static func createModelContainer() -> Any? {
        do {
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Pearcleaner")
            let storeURL = appSupportURL.appendingPathComponent("AppCache.sqlite")

            let config = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(
                for: CachedAppInfo.self, CachedHomebrewPackage.self,
                configurations: config
            )
            return container
        } catch {
            printOS("❌ Failed to create ModelContainer: \(error)")
            return nil
        }
    }

    // MARK: - Reusable App Loading Function

    /// Loads and updates apps using cache (macOS 14+) or fallback scan (macOS 13)
    /// - Parameters:
    ///   - modelContainer: The SwiftData ModelContainer (Any? type for compatibility)
    ///   - folderPaths: Array of folder paths to scan for apps
    ///   - completion: Optional completion handler called after loading
    static func loadAndUpdateApps(modelContainer: Any?, folderPaths: [String], completion: @escaping () -> Void = {}) {
        DispatchQueue.global(qos: .userInitiated).async {
            let sortedApps: Task<[AppInfo], Never>

            // Use caching if model container provided, otherwise fall back to direct scan
            if let modelContainer = modelContainer as? ModelContainer {
                Task { @MainActor in
                    AppCacheManager.shared.setContainer(modelContainer)
                }
                sortedApps = Task { @MainActor in
                    AppCacheManager.shared.loadAppsWithCache(folderPaths: folderPaths)
                }
            } else {
                // No model container - fall back to direct scan
                sortedApps = Task {
                    getSortedApps(paths: folderPaths)
                }
            }

            Task { @MainActor in
                AppState.shared.sortedApps = await sortedApps.value
                // Restore zombie file associations after apps are loaded
                AppState.shared.restoreZombieAssociations()

                // Disabled: Background lipo pre-calculation causes 1GB+ memory spikes
                // Lipo savings are calculated on-demand when user opens LipoView instead
                // The LazyVStack ensures only visible apps are calculated, preventing memory issues

                //MARK: Enable here if needed in the future
                 AppCacheManager.precalculateLipoSavings()

                // Call completion handler
                completion()
            }
        }
    }

    // MARK: - Lipo Savings Pre-calculation

    /// Pre-calculates lipo savings for universal apps in background (low priority)
    static func precalculateLipoSavings() {
        Task.detached(priority: .utility) {
            // Get universal apps that need calculation
            let appsToCalculate = await MainActor.run {
                AppState.shared.sortedApps.filter {
                    $0.arch == .universal && $0.lipoSavings == nil
                }
            }

            guard !appsToCalculate.isEmpty else {
                return
            }

            for app in appsToCalculate {
                // Calculate savings using dry-run
                let savings = await calculateLipoSavings(at: app.path, arch: app.arch)

                // Update AppState
                await MainActor.run {
                    if let index = AppState.shared.sortedApps.firstIndex(where: { $0.path == app.path }) {
                        AppState.shared.sortedApps[index].lipoSavings = savings
                    }
                }

                // Update SwiftData cache if available (macOS 14+)
                await updateLipoSavingsInCache(appPath: app.path.path, savings: savings)

                // Force memory pressure relief to reclaim memory
                malloc_zone_pressure_relief(nil, 0)

                // Throttle: Longer delay to allow memory to be fully reclaimed
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            }

        }
    }

    /// Calculate lipo savings for a single app using dry-run
    /// Uses serial queue to prevent memory spikes from concurrent calculations
    private static func calculateLipoSavings(at bundlePath: URL, arch: Arch) async -> Int64 {
        return await withCheckedContinuation { continuation in
            // Use .userInitiated instead of .utility for more controlled execution
            // Serial execution is enforced by the await in the for loop
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    let (success, sizes) = thinAppBundleArchitecture(
                        at: bundlePath, of: arch, multi: true, dryRun: true
                    )

                    if success, let sizes = sizes {
                        let preSize = sizes["pre"] ?? 0
                        let postSize = sizes["post"] ?? 0
                        let savings = preSize > postSize ? Int64(preSize - postSize) : 0
                        continuation.resume(returning: savings)
                    } else {
                        continuation.resume(returning: 0)
                    }
                }
            }
        }
    }

    /// Update lipo savings in SwiftData cache
    @MainActor
    static func updateLipoSavingsInCache(appPath: String, savings: Int64) async {
        guard let context = shared.modelContext else { return }

        do {
            let predicate = #Predicate<CachedAppInfo> { app in
                app.path == appPath
            }
            let descriptor = FetchDescriptor<CachedAppInfo>(predicate: predicate)

            if let cachedApps = try? context.fetch(descriptor), let cachedApp = cachedApps.first {
                cachedApp.lipoSavings = savings
                try context.save()
            }
        } catch {
            printOS("⚠️ Failed to update lipo savings in cache for \(appPath): \(error)")
        }
    }

    // MARK: - Main Orchestration Function

    /// Loads apps using cache for fast startup. Only processes new/changed apps.
    /// - Parameter folderPaths: Array of folder paths to scan for apps
    /// - Returns: Array of AppInfo sorted by name
    func loadAppsWithCache(folderPaths: [String]) -> [AppInfo] {
        // Fallback if SwiftData not available
        guard modelContext != nil else {
            printOS("⚠️ SwiftData not available, falling back to full scan")
            return getSortedApps(paths: folderPaths)
        }

        do {
            // 1. Quick path-only scan (~0.5s)
            let currentPaths = AppPathScanner.getInstalledAppPaths(from: folderPaths)

            // 2. Load cached paths from SwiftData
            let cachedPaths = try getCachedPaths()

            // 3. Calculate diff
            let newPaths = currentPaths.subtracting(cachedPaths)
            let removedPaths = cachedPaths.subtracting(currentPaths)

            // 4. Cleanup removed apps from cache
            if !removedPaths.isEmpty {
                try removeFromCache(paths: Array(removedPaths))
            }

            // 5. Process ONLY new apps (heavy operation with MDLS + getAppInfo)
            if !newPaths.isEmpty {
                let newApps = processNewApps(appPaths: Array(newPaths))
                try saveToCache(newApps)
            }

            // 6. Load all from cache for UI
            let allApps = try loadFromCache()
            return allApps

        } catch {
            printOS("❌ Cache error: \(error). Falling back to full scan")
            // On any error, fallback to full scan and attempt to rebuild cache
            let apps = getSortedApps(paths: folderPaths)
            try? saveToCache(apps)
            return apps
        }
    }

    // MARK: - App Processing

    /// Process specific app paths and get their metadata
    /// - Parameter appPaths: Array of app bundle paths (e.g., ["/Applications/Safari.app"])
    /// - Returns: Array of AppInfo with metadata
    private func processNewApps(appPaths: [String]) -> [AppInfo] {
        let appURLs = appPaths.map { URL(fileURLWithPath: $0) }

        // Get metadata for all app paths
        var metadataDictionary: [String: [String: Any]] = [:]
        if let metadata = getMDLSMetadata(for: appPaths) {
            metadataDictionary = metadata
        }

        // Process each app path
        let appInfos: [AppInfo] = appURLs.compactMap { appURL in
            let appPath = appURL.path

            var appInfo: AppInfo?
            if let appMetadata = metadataDictionary[appPath] {
                appInfo = MetadataAppInfoFetcher.getAppInfo(fromMetadata: appMetadata, atPath: appURL)
            } else {
                appInfo = AppInfoFetcher.getAppInfo(atPath: appURL)
            }

            // Enrich with missing quick-to-compute fields
            if var enrichedInfo = appInfo {
                enrichedInfo = enrichAppInfo(enrichedInfo)
                return enrichedInfo
            }

            return appInfo
        }

        return appInfos
    }

    /// Enrich AppInfo with missing bundleSize (if it's 0) and initialize lipoSavings
    /// Uses the same logic as AppListItems onAppear
    private func enrichAppInfo(_ appInfo: AppInfo) -> AppInfo {
        var enriched = appInfo

        // Fill in bundleSize if it's 0 (from AppInfoFetcher fallback path)
        // Uses totalSizeOnDisk like the UI does on scroll
        if enriched.bundleSize == 0 {
            let calculatedSize = totalSizeOnDisk(for: appInfo.path).logical
            enriched.bundleSize = calculatedSize
        }

        // Initialize lipoSavings based on architecture
        // Universal apps: nil (to be calculated in background)
        // Non-universal apps: 0 (no savings possible)
        enriched.lipoSavings = (enriched.arch == .universal) ? nil : 0

        return enriched
    }

    // MARK: - Cache Operations

    /// Load all apps from cache and convert to AppInfo
    func loadFromCache() throws -> [AppInfo] {
        guard let context = modelContext else {
            throw CacheError.noContext
        }

        let descriptor = FetchDescriptor<CachedAppInfo>(
            sortBy: [SortDescriptor(\.appName)]
        )

        let cachedApps = try context.fetch(descriptor)
        let appInfos = cachedApps.compactMap { $0.toAppInfo() }

        return appInfos
    }

    /// Save apps to cache
    func saveToCache(_ apps: [AppInfo]) throws {
        guard let context = modelContext else {
            throw CacheError.noContext
        }

        for app in apps {
            let cached = CachedAppInfo.from(app)
            context.insert(cached)
        }

        try context.save()
    }

    /// Remove apps from cache by path
    func removeFromCache(paths: [String]) throws {
        guard let context = modelContext else {
            throw CacheError.noContext
        }

        for path in paths {
            let predicate = #Predicate<CachedAppInfo> { app in
                app.path == path
            }
            let descriptor = FetchDescriptor<CachedAppInfo>(predicate: predicate)

            if let apps = try? context.fetch(descriptor) {
                for app in apps {
                    context.delete(app)
                }
            }
        }

        try context.save()
    }

    /// Get all cached app paths (fast query)
    func getCachedPaths() throws -> Set<String> {
        guard let context = modelContext else {
            throw CacheError.noContext
        }

        let descriptor = FetchDescriptor<CachedAppInfo>()
        let cachedApps = try context.fetch(descriptor)
        return Set(cachedApps.map { $0.path })
    }

    /// Clear entire cache by deleting all database files
    @MainActor
    func clearCache() async throws {
        // Release the model context to close database connections
        self.modelContext = nil
        self.modelContainer = nil

        // Delete all AppCache* files (sqlite, sqlite-wal, sqlite-shm)
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Pearcleaner")

        let deleteCommand = "rm -f '\(appSupportURL.path)'/AppCache.sqlite*"

        var success = false
        var output = ""

        if HelperToolManager.shared.isHelperToolInstalled {
            let result = await HelperToolManager.shared.runCommand(deleteCommand)
            success = result.0
            output = result.1
        } else {
            let result = await Task.detached {
                return performPrivilegedCommands(commands: deleteCommand)
            }.value
            success = result.0
            output = result.1
        }

        if !success {
            printOS("⚠️ Cache file deletion failed: \(output)")
            throw CacheError.deletionFailed
        }
    }

    // MARK: - Error Types

    enum CacheError: Error {
        case noContext
        case serializationFailed
        case deletionFailed
    }
}
