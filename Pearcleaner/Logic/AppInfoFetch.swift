//
//  AppInfoFetch.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/20/24.
//

import Foundation
import SwiftUI
import AlinFoundation

// Metadata-based AppInfo Fetcher Class
class MetadataAppInfoFetcher {
    static func getAppInfo(fromMetadata metadata: [String: Any], atPath path: URL) -> AppInfo? {
        // Extract metadata attributes for known fields
        var displayName = metadata["kMDItemDisplayName"] as? String ?? ""
        displayName = displayName.replacingOccurrences(of: ".app", with: "").capitalizingFirstLetter()
        let fsName = metadata["kMDItemFSName"] as? String ?? path.lastPathComponent
        let appName = displayName.isEmpty ? fsName : displayName

        let bundleIdentifier = metadata["kMDItemCFBundleIdentifier"] as? String ?? ""
        let version = metadata["kMDItemVersion"] as? String ?? ""

        // Sizes
        let logicalSize = metadata["kMDItemLogicalSize"] as? Int64 ?? 0
        let physicalSize = metadata["kMDItemPhysicalSize"] as? Int64 ?? 0

        // Check if any of the critical fields are missing or invalid
        if appName.isEmpty || bundleIdentifier.isEmpty || version.isEmpty || logicalSize == 0 || physicalSize == 0 {
            // Fallback to the regular AppInfoFetcher for this app
            return AppInfoFetcher.getAppInfo(atPath: path)
        }

        // Extract optional date fields
        let creationDate = metadata["kMDItemFSCreationDate"] as? Date
        let contentChangeDate = metadata["kMDItemFSContentChangeDate"] as? Date
        let lastUsedDate = metadata["kMDItemLastUsedDate"] as? Date

        // Determine architecture type
        let arch = checkAppBundleArchitecture(at: path.path)

        // Use similar helper functions as `AppInfoFetcher` for attributes not found in metadata
        let wrapped = AppInfoFetcher.isDirectoryWrapped(path: path)
        let appIcon = AppInfoUtils.fetchAppIcon(for: path, wrapped: wrapped, md: true)
        let webApp = AppInfoUtils.isWebApp(appPath: path)
        let system = !path.path.contains(NSHomeDirectory())
        let cask = getCaskIdentifier(for: appName)

        return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName,
                       appVersion: version, appIcon: appIcon, webApp: webApp, wrapped: wrapped, system: system,
                       arch: arch, cask: cask, steam: false, bundleSize: logicalSize, fileSize: [:],
                       fileSizeLogical: [:], fileIcon: [:], creationDate: creationDate, contentChangeDate: contentChangeDate, lastUsedDate: lastUsedDate)
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
        if let appIcon = getIconForFileOrFolderNS(atPath: iconPath) {
            appIcon.size = NSSize(width: 50, height: 50)

            // OPTIMIZATION: Force NSImage to prepare its representations
            appIcon.lockFocus()
            appIcon.unlockFocus()

            return appIcon
        } else {
            printOS("App Icon not found for app at path: \(path)")
            return nil
        }
    }
}



func getMDLSMetadata(for paths: [String]) -> [String: [String: Any]]? {
    let kMDItemLogicalSize: CFString = "kMDItemLogicalSize" as CFString
    let kMDItemPhysicalSize: CFString = "kMDItemPhysicalSize" as CFString

    // List of metadata attributes to fetch
    let attributes: [CFString] = [
        kMDItemFSCreationDate,
        kMDItemFSContentChangeDate,
        kMDItemLastUsedDate,
        kMDItemDisplayName,
        kMDItemCFBundleIdentifier,
        kMDItemFSName,
        kMDItemVersion,
        kMDItemLogicalSize,
        kMDItemPhysicalSize
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
            var chunkResults: [String: [String: Any]] = [:]

            // Process each path in this chunk
            for path in chunk {
                guard let mdItem = MDItemCreate(nil, path as CFString) else {
                    continue
                }

                var itemMetadata = [String: Any]()
                for attribute in attributes {
                    if let value = MDItemCopyAttribute(mdItem, attribute) {
                        itemMetadata[attribute as String] = value
                    }
                }
                chunkResults[path] = itemMetadata
            }

            // Safely merge results
            resultsQueue.sync {
                allResults.merge(chunkResults) { _, new in new }
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

    public static func getAppInfo(atPath path: URL, wrapped: Bool = false) -> AppInfo? {
        if isDirectoryWrapped(path: path) {
            return handleWrappedDirectory(atPath: path)
        } else {
            return createAppInfoFromBundle(atPath: path, wrapped: wrapped)
        }
    }

    public static func isDirectoryWrapped(path: URL) -> Bool {
        let wrapperURL = path.appendingPathComponent("Wrapper")
        return fileManager.fileExists(atPath: wrapperURL.path)
    }

    private static func handleWrappedDirectory(atPath path: URL) -> AppInfo? {
        let wrapperURL = path.appendingPathComponent("Wrapper")
        do {
            let contents = try fileManager.contentsOfDirectory(at: wrapperURL, includingPropertiesForKeys: nil)
            guard let firstAppFile = contents.first(where: { $0.pathExtension == "app" }) else {
                printOS("No .app files found in the 'Wrapper' directory: \(wrapperURL)")
                return nil
            }
            let fullPath = wrapperURL.appendingPathComponent(firstAppFile.lastPathComponent)
            return getAppInfo(atPath: fullPath, wrapped: true)
        } catch {
            printOS("Error reading contents of 'Wrapper' directory: \(error.localizedDescription)\n\(wrapperURL)")
            return nil
        }
    }

    private static func createAppInfoFromBundle(atPath path: URL, wrapped: Bool) -> AppInfo? {
        guard let bundle = Bundle(url: path), let bundleIdentifier = bundle.bundleIdentifier else {
            // Check if this might be a Steam game and try to find the actual bundle
            if let steamAppInfo = SteamAppInfoFetcher.checkForSteamGame(launcherPath: path) {
                return steamAppInfo
            }
            
            printOS("Bundle not found or missing bundle identifier at path: \(path)")
            return nil
        }

        let appName = wrapped ? path.deletingLastPathComponent().deletingLastPathComponent().deletingPathExtension().lastPathComponent.capitalizingFirstLetter() : path.localizedName().capitalizingFirstLetter()

        let appVersion = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String)?.isEmpty ?? true
        ? bundle.infoDictionary?["CFBundleVersion"] as? String ?? ""
        : bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        let appIcon = AppInfoUtils.fetchAppIcon(for: path, wrapped: wrapped)
        let webApp = AppInfoUtils.isWebApp(bundle: bundle)


        let system = !path.path.contains(NSHomeDirectory())
        let cask = getCaskIdentifier(for: appName)
        let arch = checkAppBundleArchitecture(at: path.path)

        return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName, appVersion: appVersion, appIcon: appIcon,
                       webApp: webApp, wrapped: wrapped, system: system, arch: arch, cask: cask, steam: false, bundleSize: 0, fileSize: [:], fileSizeLogical: [:], fileIcon: [:], creationDate: nil, contentChangeDate: nil, lastUsedDate: nil)
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
        
        let appVersion = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String)?.isEmpty ?? true
        ? bundle.infoDictionary?["CFBundleVersion"] as? String ?? ""
        : bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        
        // Use the actual bundle path for the icon (proper game icon) instead of launcher
        let appIcon = AppInfoUtils.fetchAppIcon(for: actualBundlePath, wrapped: false)
        let webApp = false
        let system = false // Steam games are never system apps
        let arch = checkAppBundleArchitecture(at: actualBundlePath.path)
        
        // Use the launcher path as the main path (so users see the ~/Applications version)
        // but store the actual bundle path info
        return AppInfo(id: UUID(), path: launcherPath, bundleIdentifier: bundleIdentifier, appName: appName, 
                       appVersion: appVersion, appIcon: appIcon, webApp: webApp, wrapped: false, 
                       system: system, arch: arch, cask: nil, steam: true, bundleSize: 0, fileSize: [:], 
                       fileSizeLogical: [:], fileIcon: [:], creationDate: nil, contentChangeDate: nil, lastUsedDate: nil)
    }
}
