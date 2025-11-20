//
//  AppInfoFetch.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/20/24.
//

import Foundation
import SwiftUI
import AlinFoundation

// MARK: - Helper Functions

/// Read Info.plist directly from disk without using Bundle cache
/// This is useful when Bundle(url:) returns nil due to macOS not yet indexing a newly installed app
private func readInfoPlistDirect(at appPath: URL) -> [String: Any]? {
    let infoPlistURL = appPath.appendingPathComponent("Contents/Info.plist")
    return NSDictionary(contentsOf: infoPlistURL) as? [String: Any]
}

// Metadata-based AppInfo Fetcher Class
class MetadataAppInfoFetcher {
    static func getAppInfo(fromMetadata metadata: [String: Any], atPath path: URL) -> AppInfo? {
        // Extract metadata attributes for known fields
        var displayName = metadata["kMDItemDisplayName"] as? String ?? ""
        displayName = displayName.replacingOccurrences(of: ".app", with: "")
        let fsName = metadata["kMDItemFSName"] as? String ?? path.lastPathComponent
        let appName = displayName.isEmpty ? fsName : displayName

        let bundleIdentifier = metadata["kMDItemCFBundleIdentifier"] as? String ?? ""

        // Get version and build number directly from bundle Info.plist instead of metadata (always up-to-date)
        let (version, buildNumber): (String, String?) = {
            // Try Bundle(url:) first
            if let bundle = Bundle(url: path) {
                // Extract marketing version (CFBundleShortVersionString), fallback to CFBundleVersion if missing
                let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                let buildVer = bundle.infoDictionary?["CFBundleVersion"] as? String ?? ""

                // Use shortVersion if available, otherwise use buildVersion
                let marketingVersion = shortVersion.isEmpty ? buildVer : shortVersion

                // Build number is CFBundleVersion (only set if different from marketing version)
                let build = shortVersion.isEmpty ? nil : buildVer
                return (marketingVersion, build)
            }

            // Fallback: Read Info.plist directly from disk (useful for newly installed apps)
            if let infoDict = readInfoPlistDirect(at: path) {
                let shortVersion = infoDict["CFBundleShortVersionString"] as? String ?? ""
                let buildVer = infoDict["CFBundleVersion"] as? String ?? ""

                let marketingVersion = shortVersion.isEmpty ? buildVer : shortVersion
                let build = shortVersion.isEmpty ? nil : buildVer
                return (marketingVersion, build)
            }

            return ("", nil)
        }()

        // Size
        let logicalSize = metadata["kMDItemLogicalSize"] as? Int64 ?? 0

        // Extract optional date fields early so we can pass them to fallback if needed
        let creationDate = metadata["kMDItemFSCreationDate"] as? Date
        let contentChangeDate = metadata["kMDItemFSContentChangeDate"] as? Date
        let lastUsedDate = metadata["kMDItemLastUsedDate"] as? Date
        let dateAdded = metadata["kMDItemDateAdded"] as? Date

        // Check if any of the critical fields are missing or invalid
        // Note: Size can be 0 for some apps where Spotlight hasn't indexed size yet, so only require core identifiers
        if appName.isEmpty || bundleIdentifier.isEmpty || version.isEmpty {
            // Fallback to the regular AppInfoFetcher for this app, but preserve dates we extracted from metadata
            return AppInfoFetcher.getAppInfo(atPath: path, dates: (creationDate, contentChangeDate, lastUsedDate, dateAdded))
        }

        // Determine architecture type
        let arch = checkAppBundleArchitecture(at: path.path)

        // Use similar helper functions as `AppInfoFetcher` for attributes not found in metadata
        let wrapped = AppInfoFetcher.isDirectoryWrapped(path: path)
        let appIcon = AppInfoUtils.fetchAppIcon(for: path, wrapped: wrapped, md: true)
        let webApp = AppInfoUtils.isWebApp(appPath: path)
        let system = !path.path.contains(NSHomeDirectory())

        // Get cask metadata (includes cask name and auto_updates flag)
        // Pass both display name, path, and bundle ID to handle various matching scenarios
        let caskInfo = getCaskInfo(for: appName, appPath: path, bundleId: bundleIdentifier)
        let cask = caskInfo?.caskName
        let autoUpdates = caskInfo?.autoUpdates

        // Get entitlements for the app
        let entitlements = getEntitlements(for: path.path)
        let teamIdentifier = getTeamIdentifier(for: path.path)

        // Detect update sources (done at load time for performance)
        let bundle = Bundle(url: path)
        let hasSparkle = AppCategoryDetector.checkForSparkle(bundle: bundle, infoDict: bundle?.infoDictionary)
        let isAppStore = AppCategoryDetector.checkForAppStore(bundle: bundle, path: path, wrapped: wrapped)

        // Extract App Store adamID from metadata (if available)
        let adamID: UInt64? = {
            if let adamValue = metadata["kMDItemAppStoreAdamID"] {
                // Handle NSNumber conversion
                if let number = adamValue as? NSNumber {
                    return number.uint64Value
                }
                // Handle direct UInt64
                if let uint = adamValue as? UInt64 {
                    return uint
                }
            }
            return nil
        }()

        return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName,
                       appVersion: version, appBuildNumber: buildNumber, appIcon: appIcon, webApp: webApp, wrapped: wrapped, system: system,
                       arch: arch, cask: cask, steam: false, hasSparkle: hasSparkle, isAppStore: isAppStore, adamID: adamID, autoUpdates: autoUpdates, bundleSize: logicalSize, fileSize: [:],
                       fileIcon: [:], creationDate: creationDate, contentChangeDate: contentChangeDate, lastUsedDate: lastUsedDate, dateAdded: dateAdded, entitlements: entitlements, teamIdentifier: teamIdentifier)
    }

    // MARK: - Phase 1: Fast Loading with AppInfoMini

    /// Fast lightweight app info loading for initial display
    /// Skips expensive operations: arch detection, entitlements, cask lookup, team identifier
    /// Always calculates bundleSize (required for sorting)
    static func getAppInfoMini(fromMetadata metadata: [String: Any], atPath path: URL) -> AppInfoMini? {
        // Extract basic info from metadata
        var displayName = metadata["kMDItemDisplayName"] as? String ?? ""
        displayName = displayName.replacingOccurrences(of: ".app", with: "")
        let fsName = metadata["kMDItemFSName"] as? String ?? path.lastPathComponent
        let appName = displayName.isEmpty ? fsName : displayName

        let bundleIdentifier = metadata["kMDItemCFBundleIdentifier"] as? String ?? ""

        // Get version from bundle Info.plist
        let version: String = {
            if let bundle = Bundle(url: path) {
                let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                let buildVer = bundle.infoDictionary?["CFBundleVersion"] as? String ?? ""
                return shortVersion.isEmpty ? buildVer : shortVersion
            }

            if let infoDict = readInfoPlistDirect(at: path) {
                let shortVersion = infoDict["CFBundleShortVersionString"] as? String ?? ""
                let buildVer = infoDict["CFBundleVersion"] as? String ?? ""
                return shortVersion.isEmpty ? buildVer : shortVersion
            }

            return ""
        }()

        // Require critical fields
        if appName.isEmpty || bundleIdentifier.isEmpty || version.isEmpty {
            return nil
        }

        // Get app icon (required for display, fast enough ~5-10ms)
        let wrapped = AppInfoFetcher.isDirectoryWrapped(path: path)
        let appIcon = AppInfoUtils.fetchAppIcon(for: path, wrapped: wrapped, md: true)

        // Determine if system app
        let system = !path.path.contains(NSHomeDirectory())

        // Get bundleSize - ALWAYS calculate, never 0 (required for sorting)
        let bundleSize: Int64 = {
            // Try mdls metadata first (fast)
            if let mdlsSize = metadata["kMDItemLogicalSize"] as? Int64, mdlsSize > 0 {
                return mdlsSize
            }

            // Fallback: Calculate using totalSizeOnDisk (same as AppInfoFetcher)
            return totalSizeOnDisk(for: path)
        }()

        // Extract date fields from metadata
        let creationDate = metadata["kMDItemFSCreationDate"] as? Date
        let contentChangeDate = metadata["kMDItemFSContentChangeDate"] as? Date
        let lastUsedDate = metadata["kMDItemLastUsedDate"] as? Date
        let dateAdded = metadata["kMDItemDateAdded"] as? Date

        return AppInfoMini(
            id: UUID(),
            path: path,
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            appVersion: version,
            appIcon: appIcon,
            system: system,
            bundleSize: bundleSize,  // ✅ Always calculated
            creationDate: creationDate,
            contentChangeDate: contentChangeDate,
            lastUsedDate: lastUsedDate,
            dateAdded: dateAdded
        )
    }

    // MARK: - Phase 2: Upgrade to Full AppInfo

    /// Upgrade AppInfoMini to full AppInfo with all expensive properties
    /// Runs expensive operations: arch, entitlements, cask lookup, team identifier
    static func upgradeToFullAppInfo(mini: AppInfoMini) -> AppInfo {
        let path = mini.path

        // Get bundle for further inspection
        let bundle = Bundle(url: path)
        let infoDict = bundle?.infoDictionary ?? readInfoPlistDirect(at: path)

        // NOW do the expensive operations that were skipped in Phase 1

        // Architecture detection (expensive: reads Mach-O binary headers)
        let arch = checkAppBundleArchitecture(at: path.path)

        // Entitlements scanning (expensive: code signing + recursive bundle scan)
        let entitlements = getEntitlements(for: path.path)

        // Team identifier (expensive: code signing read)
        let teamIdentifier = getTeamIdentifier(for: path.path)

        // Cask lookup (expensive: first-time builds entire lookup table)
        let caskInfo = getCaskInfo(for: mini.appName, appPath: path, bundleId: mini.bundleIdentifier)
        let cask = caskInfo?.caskName
        let autoUpdates = caskInfo?.autoUpdates

        // Detect app properties
        let wrapped = AppInfoFetcher.isDirectoryWrapped(path: path)
        let webApp = AppInfoUtils.isWebApp(appPath: path)

        // Detect update sources
        let hasSparkle = AppCategoryDetector.checkForSparkle(bundle: bundle, infoDict: infoDict)
        let isAppStore = AppCategoryDetector.checkForAppStore(bundle: bundle, path: path, wrapped: wrapped)

        // Get build number
        let appBuildNumber: String? = {
            if let dict = infoDict {
                let shortVersion = dict["CFBundleShortVersionString"] as? String ?? ""
                let buildVer = dict["CFBundleVersion"] as? String ?? ""
                return shortVersion.isEmpty ? nil : buildVer
            }
            return nil
        }()

        // Steam detection (not implemented in fast path, defaults to false)
        let steam = false

        // Adam ID (App Store ID) - would need to query mdls again, skip for now
        let adamID: UInt64? = nil

        return AppInfo(
            id: mini.id,
            path: mini.path,
            bundleIdentifier: mini.bundleIdentifier,
            appName: mini.appName,
            appVersion: mini.appVersion,
            appBuildNumber: appBuildNumber,
            appIcon: mini.appIcon,
            webApp: webApp,
            wrapped: wrapped,
            system: mini.system,
            arch: arch,                      // ✅ Phase 2 populated
            cask: cask,                      // ✅ Phase 2 populated
            steam: steam,
            hasSparkle: hasSparkle,          // ✅ Phase 2 populated
            isAppStore: isAppStore,          // ✅ Phase 2 populated
            adamID: adamID,
            autoUpdates: autoUpdates,
            bundleSize: mini.bundleSize,     // Keep from Phase 1
            lipoSavings: nil,
            fileSize: [:],                   // Populated when user selects app
            fileIcon: [:],                   // Populated when user selects app
            creationDate: mini.creationDate,
            contentChangeDate: mini.contentChangeDate,
            lastUsedDate: mini.lastUsedDate,
            dateAdded: mini.dateAdded,
            entitlements: entitlements,      // ✅ Phase 2 populated
            teamIdentifier: teamIdentifier   // ✅ Phase 2 populated
        )
    }
}


// MARK: - Update Source Detection Helpers

class AppCategoryDetector {
    /// Check if app has Sparkle update framework
    /// Detects Sparkle by checking for common Info.plist keys
    /// Excludes SetApp apps (they use Sparkle but are managed by SetApp)
    static func checkForSparkle(bundle: Bundle?, infoDict: [String: Any]?) -> Bool {
        guard let dict = infoDict ?? bundle?.infoDictionary else { return false }

        // Check for common Sparkle keys
        let hasSparkleKeys = dict["SUFeedURL"] != nil ||
               dict["SUFeedUrl"] != nil ||
               dict["SUPublicEDKey"] != nil ||
               dict["SUPublicDSAKeyFile"] != nil ||
               dict["SUEnableAutomaticChecks"] != nil

        // Exclude SetApp apps (they use Sparkle but are managed by SetApp)
        if hasSparkleKeys && isSetAppApp(bundle: bundle, infoDict: dict) {
            return false
        }

        return hasSparkleKeys
    }

    /// Check if app is a SetApp-managed app
    /// SetApp requires all apps to use the "-setapp" bundle ID suffix
    static func isSetAppApp(bundle: Bundle?, infoDict: [String: Any]?) -> Bool {
        // Try to get bundle ID from bundle first, then from infoDict
        if let bundleID = bundle?.bundleIdentifier ?? infoDict?["CFBundleIdentifier"] as? String {
            return bundleID.hasSuffix("-setapp")
        }
        return false
    }

    /// Check if app is from App Store
    /// Detects by checking for receipt or iTunes metadata
    static func checkForAppStore(bundle: Bundle?, path: URL, wrapped: Bool) -> Bool {
        // Check for wrapped iPad/iOS app first
        if wrapped {
            // Determine if path is wrapped or not
            // No wrapper: /Applications/App.app
            // With wrapper: /Applications/App.app/Wrapper/App.app
            let wrapperDir = path.appendingPathComponent("Wrapper")
            let isOuterWrapper = FileManager.default.fileExists(atPath: wrapperDir.path)

            // Use path directly if it's the outer wrapper, otherwise go up two levels to find it
            let outerWrapperPath = isOuterWrapper ? path : path.deletingLastPathComponent().deletingLastPathComponent()
            let iTunesMetadataPath = outerWrapperPath.appendingPathComponent("Wrapper/iTunesMetadata.plist").path

            if FileManager.default.fileExists(atPath: iTunesMetadataPath) {
                return true
            }
        }

        // Check for traditional Mac app receipt
        guard let receiptPath = bundle?.appStoreReceiptURL?.path else { return false }
        return FileManager.default.fileExists(atPath: receiptPath)
    }
}


class AppInfoUtils {
    /// Determines if the app is a web application by directly reading its `Info.plist` using the app path.
    static func isWebApp(appPath: URL) -> Bool {
        let infoPlistURL = appPath.appendingPathComponent("Contents/Info.plist")
        guard let infoDict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else {
            return false
        }
        return (infoDict["LSTemplateApplication"] as? Bool ?? false) ||
        (infoDict["CFBundleExecutable"] as? String == "app_mode_loader")
    }

    /// Determines if the app is a web application based on its bundle.
    static func isWebApp(bundle: Bundle?) -> Bool {
        guard let infoDict = bundle?.infoDictionary else { return false }
        return (infoDict["LSTemplateApplication"] as? Bool ?? false) ||
        (infoDict["CFBundleExecutable"] as? String == "app_mode_loader")
    }

    /// Fetch app icon.
    static func fetchAppIcon(for path: URL, wrapped: Bool, md: Bool = false) -> NSImage? {
        let iconPath = wrapped ? (md ? path : path.deletingLastPathComponent().deletingLastPathComponent()) : path
        guard let appIcon = getIconForFileOrFolderNS(atPath: iconPath) else {
            printOS("App Icon not found for app at path: \(path)")
            return nil
        }

        let targetSize = NSSize(width: 50, height: 50)

        // OPTIMIZATION: Pre-render icon with cached representation using modern API
        // This must run on main thread to avoid deadlock with AppKit initialization
        func createRenderedIcon() -> NSImage {
            return NSImage(size: targetSize, flipped: false) { rect in
                appIcon.draw(in: rect)
                return true
            }
        }

        if Thread.isMainThread {
            return createRenderedIcon()
        } else {
            return DispatchQueue.main.sync {
                createRenderedIcon()
            }
        }
    }
}



func getMDLSMetadata(for paths: [String]) -> [String: [String: Any]]? {
    let kMDItemLogicalSize: CFString = "kMDItemLogicalSize" as CFString
    let kMDItemPhysicalSize: CFString = "kMDItemPhysicalSize" as CFString
    let kMDItemAppStoreAdamID: CFString = "kMDItemAppStoreAdamID" as CFString

    // List of metadata attributes to fetch
    let attributes: [CFString] = [
        kMDItemFSCreationDate,
        kMDItemFSContentChangeDate,
        kMDItemLastUsedDate,
        kMDItemDateAdded,
        kMDItemDisplayName,
        kMDItemCFBundleIdentifier,
        kMDItemFSName,
        kMDItemLogicalSize,
        kMDItemPhysicalSize,
        kMDItemAppStoreAdamID
    ]

    // OPTIMIZATION: Process in parallel chunks
    let chunks = createOptimalChunks(from: paths, minChunkSize: 15, maxChunkSize: 50)
    let queue = DispatchQueue(label: "com.pearcleaner.metadata", qos: .userInitiated, attributes: .concurrent)
    let group = DispatchGroup()

    var allResults: [String: [String: Any]] = [:]
    let resultsQueue = DispatchQueue(label: "com.pearcleaner.metadata.results")

    for chunk in chunks {
        group.enter()
        queue.async {
            autoreleasepool {
                var chunkResults: [String: [String: Any]] = [:]

                // Process each path in this chunk
                for path in chunk {
                    autoreleasepool {
                        guard let mdItem = MDItemCreate(nil, path as CFString) else {
                            return
                        }

                        var itemMetadata = [String: Any]()
                        for attribute in attributes {
                            if let value = MDItemCopyAttribute(mdItem, attribute) {
                                itemMetadata[attribute as String] = value
                            }
                        }
                        chunkResults[path] = itemMetadata
                    }
                }

                // Safely merge results
                resultsQueue.sync {
                    allResults.merge(chunkResults) { _, new in new }
                }
            }
            group.leave()
        }
    }

    group.wait()
    return allResults.isEmpty ? nil : allResults
}

// Add this helper extension if you don't have it yet:
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}




//MARK: Fallback legacy function in case metadata doesn't contain the needed information
class AppInfoFetcher {
    static let fileManager = FileManager.default

    public static func getAppInfo(atPath path: URL, wrapped: Bool = false, dates: (creation: Date?, contentChange: Date?, lastUsed: Date?, dateAdded: Date?)? = nil) -> AppInfo? {
        if isDirectoryWrapped(path: path) {
            return handleWrappedDirectory(atPath: path, dates: dates)
        } else {
            return createAppInfoFromBundle(atPath: path, wrapped: wrapped, dates: dates)
        }
    }

    public static func isDirectoryWrapped(path: URL) -> Bool {
        let wrapperURL = path.appendingPathComponent("Wrapper")
        return fileManager.fileExists(atPath: wrapperURL.path)
    }

    private static func handleWrappedDirectory(atPath path: URL, dates: (creation: Date?, contentChange: Date?, lastUsed: Date?, dateAdded: Date?)? = nil) -> AppInfo? {
        let wrapperURL = path.appendingPathComponent("Wrapper")
        do {
            let contents = try fileManager.contentsOfDirectory(at: wrapperURL, includingPropertiesForKeys: nil)
            guard let firstAppFile = contents.first(where: { $0.pathExtension == "app" }) else {
                printOS("No .app files found in the 'Wrapper' directory: \(wrapperURL)")
                return nil
            }
            let fullPath = wrapperURL.appendingPathComponent(firstAppFile.lastPathComponent)
            return getAppInfo(atPath: fullPath, wrapped: true, dates: dates)
        } catch {
            printOS("Error reading contents of 'Wrapper' directory: \(error.localizedDescription)\n\(wrapperURL)")
            return nil
        }
    }

    private static func createAppInfoFromBundle(atPath path: URL, wrapped: Bool, dates: (creation: Date?, contentChange: Date?, lastUsed: Date?, dateAdded: Date?)? = nil) -> AppInfo? {
        // Try Bundle(url:) first
        if let bundle = Bundle(url: path), let bundleIdentifier = bundle.bundleIdentifier {
            let appName = wrapped ? path.deletingLastPathComponent().deletingLastPathComponent().deletingPathExtension().lastPathComponent : path.localizedName()

            // Extract marketing version (CFBundleShortVersionString) - no fallback to build number
            let appVersion = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String)?.isEmpty ?? true
                ? ""
                : bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

            // Extract build number (CFBundleVersion) separately
            let appBuildNumber = bundle.infoDictionary?["CFBundleVersion"] as? String

            let appIcon = AppInfoUtils.fetchAppIcon(for: path, wrapped: wrapped)
            let webApp = AppInfoUtils.isWebApp(bundle: bundle)

            let system = !path.path.contains(NSHomeDirectory())

            // Get cask metadata (includes cask name and auto_updates flag)
            // Pass both display name, path, and bundle ID to handle various matching scenarios
            let caskInfo = getCaskInfo(for: appName, appPath: path, bundleId: bundleIdentifier)
            let cask = caskInfo?.caskName
            let autoUpdates = caskInfo?.autoUpdates

            let arch = checkAppBundleArchitecture(at: path.path)

            // Get entitlements for the app
            let entitlements = getEntitlements(for: path.path)
            let teamIdentifier = getTeamIdentifier(for: path.path)

            // Detect update sources (done at load time for performance)
            let hasSparkle = AppCategoryDetector.checkForSparkle(bundle: bundle, infoDict: bundle.infoDictionary)
            let isAppStore = AppCategoryDetector.checkForAppStore(bundle: bundle, path: path, wrapped: wrapped)

            // adamID not available in fallback path (no mdls metadata)
            let adamID: UInt64? = nil

            return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName, appVersion: appVersion, appBuildNumber: appBuildNumber, appIcon: appIcon,
                           webApp: webApp, wrapped: wrapped, system: system, arch: arch, cask: cask, steam: false, hasSparkle: hasSparkle, isAppStore: isAppStore, adamID: adamID, autoUpdates: autoUpdates, bundleSize: 0, fileSize: [:], fileIcon: [:], creationDate: dates?.creation, contentChangeDate: dates?.contentChange, lastUsedDate: dates?.lastUsed, dateAdded: dates?.dateAdded, entitlements: entitlements, teamIdentifier: teamIdentifier)
        }

        // Fallback: Read Info.plist directly from disk (useful for newly installed apps where Bundle cache isn't ready)
        if let infoDict = readInfoPlistDirect(at: path), let bundleIdentifier = infoDict["CFBundleIdentifier"] as? String {
            let appName = wrapped ? path.deletingLastPathComponent().deletingLastPathComponent().deletingPathExtension().lastPathComponent : path.localizedName()

            // Extract marketing version (CFBundleShortVersionString) - no fallback to build number
            let appVersion = (infoDict["CFBundleShortVersionString"] as? String)?.isEmpty ?? true
                ? ""
                : infoDict["CFBundleShortVersionString"] as? String ?? ""

            // Extract build number (CFBundleVersion) separately
            let appBuildNumber = infoDict["CFBundleVersion"] as? String

            let appIcon = AppInfoUtils.fetchAppIcon(for: path, wrapped: wrapped)
            let webApp = AppInfoUtils.isWebApp(appPath: path)  // Use path-based version since we don't have bundle

            let system = !path.path.contains(NSHomeDirectory())

            // Get cask metadata (includes cask name and auto_updates flag)
            // Pass both display name, path, and bundle ID to handle various matching scenarios
            let caskInfo = getCaskInfo(for: appName, appPath: path, bundleId: bundleIdentifier)
            let cask = caskInfo?.caskName
            let autoUpdates = caskInfo?.autoUpdates

            let arch = checkAppBundleArchitecture(at: path.path)

            // Get entitlements for the app
            let entitlements = getEntitlements(for: path.path)
            let teamIdentifier = getTeamIdentifier(for: path.path)

            // Detect update sources (done at load time for performance)
            let hasSparkle = AppCategoryDetector.checkForSparkle(bundle: nil, infoDict: infoDict)
            let isAppStore = AppCategoryDetector.checkForAppStore(bundle: nil, path: path, wrapped: wrapped)

            // adamID not available in fallback path (no mdls metadata)
            let adamID: UInt64? = nil

            return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName, appVersion: appVersion, appBuildNumber: appBuildNumber, appIcon: appIcon,
                           webApp: webApp, wrapped: wrapped, system: system, arch: arch, cask: cask, steam: false, hasSparkle: hasSparkle, isAppStore: isAppStore, adamID: adamID, autoUpdates: autoUpdates, bundleSize: 0, fileSize: [:], fileIcon: [:], creationDate: dates?.creation, contentChangeDate: dates?.contentChange, lastUsedDate: dates?.lastUsed, dateAdded: dates?.dateAdded, entitlements: entitlements, teamIdentifier: teamIdentifier)
        }

        // If both Bundle and direct reading failed, check if this might be a Steam game
        if let steamAppInfo = SteamAppInfoFetcher.checkForSteamGame(launcherPath: path) {
            return steamAppInfo
        }

        printOS("Bundle not found or missing bundle identifier at path: \(path)")
        return nil
    }

}

//MARK: Steam Games Support
class SteamAppInfoFetcher {
    static let fileManager = FileManager.default
    
    /// Check if a failed app bundle is actually a Steam game launcher and find the real bundle
    static func checkForSteamGame(launcherPath: URL) -> AppInfo? {
        // Extract the app name from the launcher path (e.g., "Helltaker" from "Helltaker.app")
        let appName = launcherPath.deletingPathExtension().lastPathComponent
        
        // Check if this app exists in the Steam common directory
        let steamCommonPath = "\(NSHomeDirectory())/Library/Application Support/Steam/steamapps/common"
        let steamGamePath = steamCommonPath + "/" + appName
        
        guard fileManager.fileExists(atPath: steamGamePath) else {
            return nil
        }
        
        // Look for the actual .app bundle within the Steam game directory
        guard let actualAppBundle = findAppBundle(in: steamGamePath) else {
            return nil
        }
        
        // Create AppInfo using the actual Steam game bundle but keep the launcher path
        return createSteamAppInfo(launcherPath: launcherPath, actualBundlePath: actualAppBundle, gameFolderName: appName)
    }
    
    /// Find the .app bundle within a Steam game directory
    private static func findAppBundle(in directory: String) -> URL? {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directory)
            
            // Look for .app files
            for item in contents {
                if item.hasSuffix(".app") {
                    let appPath = directory + "/" + item
                    let appURL = URL(fileURLWithPath: appPath)
                    
                    // Verify it has an Info.plist
                    let infoPlistPath = appPath + "/Contents/Info.plist"
                    if fileManager.fileExists(atPath: infoPlistPath) {
                        return appURL
                    }
                }
            }
        } catch {
            printOS("Error searching for app bundle in \(directory): \(error)")
        }
        
        return nil
    }
    
    /// Create AppInfo for Steam games using the launcher path but actual bundle info
    private static func createSteamAppInfo(launcherPath: URL, actualBundlePath: URL, gameFolderName: String) -> AppInfo? {
        guard let bundle = Bundle(url: actualBundlePath) else {
            printOS("Steam game bundle not found at path: \(actualBundlePath)")
            return nil
        }
        
        // Handle missing bundle identifier by providing a fallback
        let bundleIdentifier = bundle.bundleIdentifier?.isEmpty == false ? bundle.bundleIdentifier! : "com.no.bundleid"
        
        // Use the game folder name as the app name
        let appName = gameFolderName.capitalizingFirstLetter()

        // Extract marketing version (CFBundleShortVersionString) - no fallback to build number
        let appVersion = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String)?.isEmpty ?? true
            ? ""
            : bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        // Extract build number (CFBundleVersion) separately
        let appBuildNumber = bundle.infoDictionary?["CFBundleVersion"] as? String

        // Use the actual bundle path for the icon (proper game icon) instead of launcher
        let appIcon = AppInfoUtils.fetchAppIcon(for: actualBundlePath, wrapped: false)
        let webApp = false
        let system = false // Steam games are never system apps
        let arch = checkAppBundleArchitecture(at: actualBundlePath.path)
        
        // Use the launcher path as the main path (so users see the ~/Applications version)
        // but store the actual bundle path info
        // Get entitlements for the Steam app
        let entitlements = getEntitlements(for: actualBundlePath.path)
        let teamIdentifier = getTeamIdentifier(for: actualBundlePath.path)

        // Steam games: typically no Sparkle or App Store (distributed via Steam)
        let hasSparkle = AppCategoryDetector.checkForSparkle(bundle: bundle, infoDict: bundle.infoDictionary)
        let isAppStore = false  // Steam games are never from App Store
        let adamID: UInt64? = nil  // Steam games don't have App Store adamID
        let autoUpdates: Bool? = nil  // Steam games don't use Homebrew

        return AppInfo(id: UUID(), path: launcherPath, bundleIdentifier: bundleIdentifier, appName: appName,
                       appVersion: appVersion, appBuildNumber: appBuildNumber, appIcon: appIcon, webApp: webApp, wrapped: false,
                       system: system, arch: arch, cask: nil, steam: true, hasSparkle: hasSparkle, isAppStore: isAppStore, adamID: adamID, autoUpdates: autoUpdates, bundleSize: 0, fileSize: [:],
                       fileIcon: [:], creationDate: nil, contentChangeDate: nil, lastUsedDate: nil, dateAdded: nil, entitlements: entitlements, teamIdentifier: teamIdentifier)
    }
}



private func getEntitlements(for appPath: String) -> [String]? {
    return autoreleasepool { () -> [String]? in
        let appURL = URL(fileURLWithPath: appPath) as CFURL
        var staticCode: SecStaticCode?

        // Create a static code object for the app
        guard SecStaticCodeCreateWithPath(appURL, [], &staticCode) == errSecSuccess,
              let code = staticCode else {
            return nil
        }

        // 1 << 2 is the bitmask for entitlements (kSecCSEntitlements)
        var info: CFDictionary?
        if SecCodeCopySigningInformation(code,
                                         SecCSFlags(rawValue: 1 << 2),
                                         &info) == errSecSuccess,
           let dict = info as? [String: Any],
           let entitlements = dict[kSecCodeInfoEntitlementsDict as String] as? [String: Any] {

            var results: [String] = []

            // com.apple.security.application-groups
            if let appGroups = entitlements["com.apple.security.application-groups"] as? [String] {
                results.append(contentsOf: appGroups)
            }

            // com.apple.developer.icloud-container-identifiers
            if let icloudContainers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] {
                results.append(contentsOf: icloudContainers)
            }

            // Note: Path-based entitlements (like temporary-exception.files paths) are not extracted
            // as they cause false positives by matching generic folder names like "Desktop", "Documents"

            // Scan Contents/MacOS folder for binary names
            // App binaries often leave behind files/folders matching their names
            let macosPath = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/MacOS")
            if FileManager.default.fileExists(atPath: macosPath.path) {
                do {
                    let files = try FileManager.default.contentsOfDirectory(atPath: macosPath.path)
                    for file in files where !file.hasPrefix(".") {
                        // Add binary name if not already present and length >= 5 to avoid false matches
                        if !results.contains(file) && file.count >= 5 {
                            results.append(file)
                        }
                    }
                } catch {
                    // Silently ignore errors (e.g., permission denied, folder doesn't exist)
                }
            }

            // Scan nested bundles one level deep in Contents/*/ for helper apps
            // Example: Contents/SharedSupport/wpscloudsvr.app
            let contentsPath = URL(fileURLWithPath: appPath).appendingPathComponent("Contents")
            if FileManager.default.fileExists(atPath: contentsPath.path) {
                do {
                    let subdirs = try FileManager.default.contentsOfDirectory(at: contentsPath, includingPropertiesForKeys: nil)
                    for subdir in subdirs where subdir.hasDirectoryPath {
                        // Check for .app bundles in this subdirectory
                        if let bundles = try? FileManager.default.contentsOfDirectory(at: subdir, includingPropertiesForKeys: nil) {
                            for bundle in bundles where bundle.pathExtension == "app" {
                                // Add bundle name (without .app extension)
                                let bundleName = bundle.deletingPathExtension().lastPathComponent
                                // Skip generic names that could cause false positives
                                let excludedNames = ["crashhandler", "crash handler"]
                                let bundleNameLower = bundleName.lowercased()
                                if !results.contains(bundleName) && bundleName.count >= 5 && !excludedNames.contains(bundleNameLower) {
                                    results.append(bundleName)
                                }

                                // Scan nested bundle's MacOS folder for binary names
                                let nestedMacOS = bundle.appendingPathComponent("Contents/MacOS")
                                if let binaries = try? FileManager.default.contentsOfDirectory(atPath: nestedMacOS.path) {
                                    for binary in binaries where !binary.hasPrefix(".") && binary.count >= 5 {
                                        let binaryNameLower = binary.lowercased()
                                        if !results.contains(binary) && !excludedNames.contains(binaryNameLower) {
                                            results.append(binary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    // Silently ignore errors (e.g., permission denied, folder doesn't exist)
                }
            }

            return results.isEmpty ? nil : results
        }

        return nil
    }
}

private func getTeamIdentifier(for appPath: String) -> String? {
    return autoreleasepool {
        let appURL = URL(fileURLWithPath: appPath) as CFURL
        var staticCode: SecStaticCode?

        // Create a static code object for the app
        guard SecStaticCodeCreateWithPath(appURL, [], &staticCode) == errSecSuccess,
              let code = staticCode else {
            return nil
        }

        // Get signing information with team identifier
        var info: CFDictionary?
        if SecCodeCopySigningInformation(code,
                                         SecCSFlags(rawValue: kSecCSSigningInformation),
                                         &info) == errSecSuccess,
           let dict = info as? [String: Any],
           let teamIdentifier = dict[kSecCodeInfoTeamIdentifier as String] as? String {
            return teamIdentifier
        }

        return nil
    }
}


