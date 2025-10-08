//
//  AppCachePlist.swift
//  Pearcleaner
//
//  Binary Plist cache for app metadata (replaces SwiftData)
//

import Foundation
import AlinFoundation
import AppKit

// MARK: - Codable Model

struct CachedAppInfoPlist: Codable {
    var path: String
    var bundleIdentifier: String
    var appName: String
    var appVersion: String
    var appIconData: Data?
    var webApp: Bool
    var wrapped: Bool
    var system: Bool
    var arch: String
    var cask: String?
    var steam: Bool
    var bundleSize: Int64
    var lipoSavings: Int64?
    var creationDate: Date?
    var contentChangeDate: Date?
    var lastUsedDate: Date?
    var entitlements: [String]?

    // File size dictionaries stored as [String: Int64] for Codable support
    var fileSizePaths: [String]
    var fileSizeValues: [Int64]
    var fileSizeLogicalPaths: [String]
    var fileSizeLogicalValues: [Int64]

    // Metadata for cache management
    var lastScanned: Date

    // MARK: - Conversion to AppInfo

    func toAppInfo() -> AppInfo? {
        let pathURL = URL(fileURLWithPath: path)

        // Reconstruct file size dictionaries
        let fileSize = Dictionary(uniqueKeysWithValues: zip(
            fileSizePaths.map { URL(fileURLWithPath: $0) },
            fileSizeValues
        ))
        let fileSizeLogical = Dictionary(uniqueKeysWithValues: zip(
            fileSizeLogicalPaths.map { URL(fileURLWithPath: $0) },
            fileSizeLogicalValues
        ))

        // Convert icon data to NSImage
        let appIcon: NSImage? = if let iconData = appIconData {
            NSImage(data: iconData)
        } else {
            nil
        }

        // Convert arch string to Arch enum
        let archEnum: Arch = switch arch {
        case "arm": .arm
        case "intel": .intel
        case "universal": .universal
        default: .empty
        }

        return AppInfo(
            id: UUID(),
            path: pathURL,
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            appVersion: appVersion,
            appIcon: appIcon,
            webApp: webApp,
            wrapped: wrapped,
            system: system,
            arch: archEnum,
            cask: cask,
            steam: steam,
            bundleSize: bundleSize,
            lipoSavings: lipoSavings,
            fileSize: fileSize,
            fileSizeLogical: fileSizeLogical,
            fileIcon: [:],  // Icons not cached
            creationDate: creationDate,
            contentChangeDate: contentChangeDate,
            lastUsedDate: lastUsedDate,
            entitlements: entitlements
        )
    }

    // MARK: - Conversion from AppInfo

    static func from(_ appInfo: AppInfo) -> CachedAppInfoPlist {
        // Convert icon to data
        let iconData = appInfo.appIcon?.tiffRepresentation

        // Split file size dictionaries into parallel arrays for Codable
        let fileSizePairs = appInfo.fileSize.sorted { $0.key.path < $1.key.path }
        let fileSizeLogicalPairs = appInfo.fileSizeLogical.sorted { $0.key.path < $1.key.path }

        return CachedAppInfoPlist(
            path: appInfo.path.path,
            bundleIdentifier: appInfo.bundleIdentifier,
            appName: appInfo.appName,
            appVersion: appInfo.appVersion,
            appIconData: iconData,
            webApp: appInfo.webApp,
            wrapped: appInfo.wrapped,
            system: appInfo.system,
            arch: appInfo.arch.type,
            cask: appInfo.cask,
            steam: appInfo.steam,
            bundleSize: appInfo.bundleSize,
            lipoSavings: appInfo.lipoSavings,
            creationDate: appInfo.creationDate,
            contentChangeDate: appInfo.contentChangeDate,
            lastUsedDate: appInfo.lastUsedDate,
            entitlements: appInfo.entitlements,
            fileSizePaths: fileSizePairs.map { $0.key.path },
            fileSizeValues: fileSizePairs.map { $0.value },
            fileSizeLogicalPaths: fileSizeLogicalPairs.map { $0.key.path },
            fileSizeLogicalValues: fileSizeLogicalPairs.map { $0.value },
            lastScanned: Date()
        )
    }
}

// MARK: - Cache Container

struct AppCachePlistContainer: Codable {
    var apps: [CachedAppInfoPlist]
    var cacheVersion: Int = 1
}

// MARK: - Cache Manager

@MainActor
class AppCachePlist {
    static let shared = AppCachePlist()

    private init() {}

    private var cacheURL: URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Pearcleaner")
        return appSupportURL.appendingPathComponent("AppCache.plist")
    }

    // MARK: - Reusable App Loading Function

    /// Loads and updates apps using cache or fallback scan
    /// - Parameters:
    ///   - folderPaths: Array of folder paths to scan for apps
    ///   - completion: Optional completion handler called after loading
    static func loadAndUpdateApps(folderPaths: [String], completion: @escaping () -> Void = {}) {
        DispatchQueue.global(qos: .userInitiated).async {
            let sortedApps: Task<[AppInfo], Never>

            // Check if caching is enabled
            let cacheEnabled = UserDefaults.standard.bool(forKey: "settings.cache.enabled")

            if cacheEnabled {
                sortedApps = Task { @MainActor in
                    AppCachePlist.shared.loadAppsWithCache(folderPaths: folderPaths)
                }
            } else {
                // Caching disabled - fall back to direct scan
                sortedApps = Task {
                    getSortedApps(paths: folderPaths)
                }
            }

            Task { @MainActor in
                AppState.shared.sortedApps = await sortedApps.value
                // Restore zombie file associations after apps are loaded
                AppState.shared.restoreZombieAssociations()

                // Pre-calculate lipo savings in background
                AppCachePlist.precalculateLipoSavings()

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

                // Update cache if available
                await updateLipoSavingsInCache(appPath: app.path.path, savings: savings)

                // Force memory pressure relief to reclaim memory
                malloc_zone_pressure_relief(nil, 0)

                // Throttle: Longer delay to allow memory to be fully reclaimed
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            }
        }
    }

    /// Calculate lipo savings for a single app using dry-run
    private static func calculateLipoSavings(at bundlePath: URL, arch: Arch) async -> Int64 {
        return await withCheckedContinuation { continuation in
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

    /// Update lipo savings in plist cache
    @MainActor
    static func updateLipoSavingsInCache(appPath: String, savings: Int64) async {
        // Check if caching is enabled
        let cacheEnabled = UserDefaults.standard.bool(forKey: "settings.cache.enabled")
        guard cacheEnabled else { return }

        // Check if cache file exists
        guard FileManager.default.fileExists(atPath: shared.cacheURL.path) else { return }

        do {
            var container = try shared.loadContainer()
            if let index = container.apps.firstIndex(where: { $0.path == appPath }) {
                container.apps[index].lipoSavings = savings
                try shared.saveContainer(container)
            }
        } catch {
            // Silently fail - cache may have been cleared
        }
    }

    // MARK: - Main Orchestration Function

    /// Loads apps using cache for fast startup. Only processes new/changed apps.
    /// - Parameter folderPaths: Array of folder paths to scan for apps
    /// - Returns: Array of AppInfo sorted by name
    func loadAppsWithCache(folderPaths: [String]) -> [AppInfo] {
        // Check if cache file exists
        if !FileManager.default.fileExists(atPath: cacheURL.path) {
            printOS("⚠️ Cache file missing, falling back to full scan")
            let apps = getSortedApps(paths: folderPaths)
            try? saveToCache(apps)
            return apps
        }

        do {
            // 1. Quick path-only scan (~0.5s)
            let currentPaths = AppPathScanner.getInstalledAppPaths(from: folderPaths)

            // 2. Load cached paths from plist
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
                try addToCache(newApps)
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
    private func enrichAppInfo(_ appInfo: AppInfo) -> AppInfo {
        var enriched = appInfo

        // Fill in bundleSize if it's 0
        if enriched.bundleSize == 0 {
            let calculatedSize = totalSizeOnDisk(for: appInfo.path).logical
            enriched.bundleSize = calculatedSize
        }

        // Initialize lipoSavings based on architecture
        enriched.lipoSavings = (enriched.arch == .universal) ? nil : 0

        return enriched
    }

    // MARK: - Cache Operations

    /// Load container from plist
    private func loadContainer() throws -> AppCachePlistContainer {
        let data = try Data(contentsOf: cacheURL)
        let decoder = PropertyListDecoder()
        return try decoder.decode(AppCachePlistContainer.self, from: data)
    }

    /// Save container to plist
    private func saveContainer(_ container: AppCachePlistContainer) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(container)
        try data.write(to: cacheURL, options: .atomic)

        // Clean up old SwiftData files on first save
        cleanupOldSwiftDataCache()
    }

    /// Remove legacy SwiftData cache files (temporary cleanup function)
    private func cleanupOldSwiftDataCache() {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Pearcleaner")

        let oldCacheFiles = [
            appSupportURL.appendingPathComponent("AppCache.sqlite"),
            appSupportURL.appendingPathComponent("AppCache.sqlite-wal"),
            appSupportURL.appendingPathComponent("AppCache.sqlite-shm")
        ]

        for fileURL in oldCacheFiles {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                } catch {
                    printOS("⚠️ Failed to remove old cache file \(fileURL.lastPathComponent): \(error)")
                }
            }
        }
    }

    /// Load all apps from cache and convert to AppInfo
    func loadFromCache() throws -> [AppInfo] {
        let container = try loadContainer()
        let appInfos = container.apps.compactMap { $0.toAppInfo() }
        return appInfos.sorted { $0.appName < $1.appName }
    }

    /// Save apps to cache (replaces existing cache)
    func saveToCache(_ apps: [AppInfo]) throws {
        let cachedApps = apps.map { CachedAppInfoPlist.from($0) }
        let container = AppCachePlistContainer(apps: cachedApps)
        try saveContainer(container)
    }

    /// Add apps to existing cache (appends without replacing)
    func addToCache(_ apps: [AppInfo]) throws {
        var container = try loadContainer()
        let newCachedApps = apps.map { CachedAppInfoPlist.from($0) }
        container.apps.append(contentsOf: newCachedApps)
        try saveContainer(container)
    }

    /// Remove apps from cache by path
    func removeFromCache(paths: [String]) throws {
        var container = try loadContainer()
        container.apps.removeAll { paths.contains($0.path) }
        try saveContainer(container)
    }

    /// Get all cached app paths (fast query)
    func getCachedPaths() throws -> Set<String> {
        let container = try loadContainer()
        return Set(container.apps.map { $0.path })
    }

    /// Clear entire cache by deleting plist file
    @MainActor
    func clearCache() async throws {
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            try FileManager.default.removeItem(at: cacheURL)
        }
    }

    // MARK: - Error Types

    enum CacheError: Error {
        case fileNotFound
        case encodingFailed
        case decodingFailed
    }
}
