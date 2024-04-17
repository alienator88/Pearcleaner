//
//  AppInfoFetch.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/20/24.
//

import Foundation
import SwiftUI

class AppInfoFetcher {
    static let fileManager = FileManager.default

    static func getAppInfo(atPath path: URL, wrapped: Bool = false) -> AppInfo? {
        if isDirectoryWrapped(path: path) {
            return handleWrappedDirectory(atPath: path)
        } else {
            return createAppInfoFromBundle(atPath: path, wrapped: wrapped)
        }
    }

    private static func isDirectoryWrapped(path: URL) -> Bool {
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
            printOS("Bundle not found or missing bundle identifier at path: \(path)")
            return nil
        }

//        let appName = bundle.localizedInfoDictionary?[kCFBundleNameKey as String] as? String
//        ?? bundle.infoDictionary?["CFBundleName"] as? String
//        ?? path.deletingPathExtension().lastPathComponent

        let appName = path.deletingPathExtension().lastPathComponent.capitalizingFirstLetter()

        let appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        ?? bundle.infoDictionary?["CFBundleVersion"] as? String
        ?? ""

        let appIcon = fetchAppIcon(for: path, wrapped: wrapped)

        let webApp = bundle.infoDictionary?["LSTemplateApplication"] as? Bool ?? false
        let system = !path.path.contains(NSHomeDirectory())

        return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName, appVersion: appVersion, appIcon: appIcon,
                       webApp: webApp, wrapped: wrapped, system: system, files: [], fileSize: [:], fileSizeLogical: [:], fileIcon: [:])
    }

    private static func fetchAppIcon(for path: URL, wrapped: Bool) -> NSImage? {
        let iconPath = wrapped ? path.deletingLastPathComponent().deletingLastPathComponent() : path
        if let appIcon = getIconForFileOrFolderNS(atPath: iconPath) {
            return convertICNSToPNG(icon: appIcon, size: NSSize(width: 100, height: 100))
        } else {
            printOS("App Icon not found for app at path: \(path)")
            return nil
        }
    }

}



// OLD FUNCTION ============================================================

//func getAppInfo(atPath path: URL, wrapped: Bool = false) -> AppInfo? {
//    let filemanager = FileManager.default
//    let wrapperURL = path.appendingPathComponent("Wrapper")
//    if filemanager.fileExists(atPath: wrapperURL.path) {
//        do {
//            let contents = try filemanager.contentsOfDirectory(at: wrapperURL, includingPropertiesForKeys: nil, options: [])
//            let appFiles = contents.filter { $0.pathExtension == "app" }
//
//            if let firstAppFile = appFiles.first {
//                let fullPath = wrapperURL.appendingPathComponent(firstAppFile.lastPathComponent)
//                if let wrappedAppInfo = getAppInfo(atPath: fullPath, wrapped: true) {
//                    return wrappedAppInfo
//                }
//            } else {
//                printOS("No .app files found in the 'Wrapper' directory: \(wrapperURL)")
//            }
//        } catch {
//            printOS("Error reading contents of 'Wrapper' directory: \(error.localizedDescription)\n\(wrapperURL)")
//        }
//    } else {
//        if let bundle = Bundle(url: path) {
//            if let bundleIdentifier = bundle.bundleIdentifier {
//                var appVersion: String?
//                var appIcon: NSImage?
//                var appName: String?
//                var webApp: Bool?
//                var wrappedApp: Bool?
//                var system: Bool?
//
//                if let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String, !shortVersion.isEmpty {
//                    appVersion = shortVersion
//                } else {
//                    if let bundleVersion = bundle.infoDictionary?["CFBundleVersion"] as? String, !bundleVersion.isEmpty {
//                        appVersion = bundleVersion
//                    } else {
//                        printOS("Failed to retrieve bundle version")
//                    }
//                }
//
//                if let localizedName = bundle.localizedInfoDictionary?[kCFBundleNameKey as String] as? String {
//                    appName = localizedName
//                } else if let bundleName = bundle.infoDictionary?["CFBundleName"] as? String {
//                    appName = bundleName
//                } else {
//                    appName = path.deletingPathExtension().lastPathComponent
//                }
//
//                // Get icon from app
//                if path.absoluteString.contains("Wrapper") {
//                    appIcon = getIconForFileOrFolderNS(atPath: path.deletingLastPathComponent().deletingLastPathComponent())
//                } else {
//                    appIcon = getIconForFileOrFolderNS(atPath: path)
//                }
//
//                // Convert the icon to a 100x100 PNG image
//                if let pngIcon = appIcon.flatMap({ convertICNSToPNG(icon: $0, size: NSSize(width: 100, height: 100)) }) {
//                    appIcon = pngIcon
//                }
//
//                if appIcon == nil {
//                    printOS("App Icon not found for app at path: \(path)")
//                }
//
//                if bundle.infoDictionary?["LSTemplateApplication"] is Bool {
//                    webApp = true
//                } else {
//                    webApp = false
//                }
//
//                if wrapped {
//                    wrappedApp = true
//                } else {
//                    wrappedApp = false
//                }
//
//                if !path.path.contains(home) {
//                    system = true
//                } else {
//                    system = false
//                }
//
//
//                return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName ?? "", appVersion: appVersion ?? "", appIcon: appIcon, webApp: webApp ?? false, wrapped: wrappedApp ?? false, system: system ?? false, files: [], fileSize: [:], fileIcon: [:])
//
//            } else {
//                printOS("Bundle identifier not found at path: \(path)")
//            }
//        } else {
//            printOS("Bundle not found at path: \(path)")
//        }
//    }
//    return nil
//}
