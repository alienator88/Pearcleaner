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
        let arch = checkArchViaFile(at: path.path)

        // Use similar helper functions as `AppInfoFetcher` for attributes not found in metadata
        let wrapped = AppInfoFetcher.isDirectoryWrapped(path: path)
        let appIcon = AppInfoUtils.fetchAppIcon(for: path, wrapped: wrapped, md: true)
        let webApp = AppInfoUtils.isWebApp(appPath: path)
        let system = !path.path.contains(NSHomeDirectory())
        let cask = getCaskIdentifier(for: appName)

        return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName,
                       appVersion: version, appIcon: appIcon, webApp: webApp, wrapped: wrapped, system: system,
                       arch: arch, cask: cask, bundleSize: logicalSize, fileSize: [:],
                       fileSizeLogical: [:], fileIcon: [:], creationDate: creationDate, contentChangeDate: contentChangeDate, lastUsedDate: lastUsedDate)
    }

    /// Determine the architecture type based on metadata
    //    private static func determineArchitecture(from metadata: [String: Any]) -> Arch {
    //        guard let architectures = metadata["kMDItemExecutableArchitectures"] as? [String] else {
    //            return .empty
    //        }
    //
    //        // Check for ARM and Intel presence
    //        let containsArm = architectures.contains("arm64")
    //        let containsIntel = architectures.contains("x86_64")
    //
    //        // Determine the Arch type based on available architectures
    //        if containsArm && containsIntel {
    //            return .universal
    //        } else if containsArm {
    //            return .arm
    //        } else if containsIntel {
    //            return .intel
    //        } else {
    //            return .empty
    //        }
    //    }
}






class AppInfoUtils {
    /// Determines if the app is a web application by directly reading its `Info.plist` using the app path.
    static func isWebApp(appPath: URL) -> Bool {
        guard let bundle = Bundle(url: appPath) else { return false }
        return isWebApp(bundle: bundle)
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
            return convertICNSToPNG(icon: appIcon, size: NSSize(width: 50, height: 50))
        } else {
            printOS("App Icon not found for app at path: \(path)")
            return nil
        }
    }
}




func getMDLSMetadata(for paths: [String]) -> [String: [String: Any]]? {
    var metadataDictionary = [String: [String: Any]]()
    let kMDItemLogicalSize: CFString = "kMDItemLogicalSize" as CFString // Not exposed in the CoreServices framework headers
    let kMDItemPhysicalSize: CFString = "kMDItemPhysicalSize" as CFString // Not exposed in the CoreServices framework headers

    // List of metadata attributes to fetch
    let attributes: [CFString] = [
        kMDItemFSCreationDate,
        kMDItemFSContentChangeDate,
        kMDItemLastUsedDate,
        kMDItemDisplayName,
        kMDItemCFBundleIdentifier,
        //        kMDItemExecutableArchitectures,
        kMDItemFSName,
        kMDItemVersion,
        kMDItemLogicalSize,
        kMDItemPhysicalSize
    ]

    // Iterate over each path to fetch metadata using CoreServices APIs
    for path in paths {
        // Create an MDItem for the file at the given path
        guard let mdItem = MDItemCreate(nil, path as CFString) else {
            printOS("Failed to create MDItem for path: \(path)")
            continue
        }

        var itemMetadata = [String: Any]()
        // Extract each attribute from the MDItem
        for attribute in attributes {
            if let value = MDItemCopyAttribute(mdItem, attribute) {
                itemMetadata[attribute as String] = value
            }
        }

        metadataDictionary[path] = itemMetadata
    }

    return metadataDictionary.isEmpty ? nil : metadataDictionary
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
        let arch = checkArchViaFile(at: path.path)

        return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName, appVersion: appVersion, appIcon: appIcon,
                       webApp: webApp, wrapped: wrapped, system: system, arch: arch, cask: cask, bundleSize: 0, fileSize: [:], fileSizeLogical: [:], fileIcon: [:], creationDate: nil, contentChangeDate: nil, lastUsedDate: nil)
    }

}


func checkArchViaFile(at path: String) -> Arch {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/file")
    // Target the app's main binary inside Contents/MacOS
    let binaryName = ((path as NSString).lastPathComponent as NSString).deletingPathExtension.replacingOccurrences(of: " ", with: "")
    let binaryPath = "\(path)/Contents/MacOS/\(binaryName)"
    task.arguments = [binaryPath]

    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    if output.contains("arm64") && output.contains("x86_64") {
        return .universal
    } else if output.contains("arm64") {
        return .arm
    } else if output.contains("x86_64") {
        return .intel
    } else {
        return .empty
    }
}



/// Executes `mdls` with `-plist -` and `-nullMarker ""` options and returns metadata in a structured dictionary.
//func getMDLSMetadataAsPlist2(for paths: [String]) -> [String: [String: Any]]? {
//    let task = Process()
//    task.executableURL = URL(fileURLWithPath: "/usr/bin/mdls")
//
//    // Define the required metadata attributes to include in the output
//    let attributes = [
//        "kMDItemFSCreationDate",
//        "kMDItemFSContentChangeDate",
//        "kMDItemLastUsedDate",
//        "kMDItemDisplayName",
//        "kMDItemAppStoreCategory",
//        "kMDItemCFBundleIdentifier",
//        "kMDItemExecutableArchitectures",
//        "kMDItemFSName",
//        "kMDItemVersion",
//        "kMDItemLogicalSize",
//        "kMDItemPhysicalSize"
//    ]
//
//    // Construct the `mdls` arguments: paths + -name for each attribute + -plist - + -nullMarker ""
//    var arguments = paths
//    for attribute in attributes {
//        arguments.append("-name")
//        arguments.append(attribute)
//    }
//    arguments.append("-plist")       // Use plist format
//    arguments.append("-")            // Output to stdout
//    arguments.append("-nullMarker")  // Replace null attributes
//    arguments.append("")             // Substitute null values with empty string
//
//    task.arguments = arguments
//
//    // Use Pipe to capture the output
//    let pipe = Pipe()
//    let errorPipe = Pipe()
//    task.standardOutput = pipe
//    task.standardError = errorPipe  // Capture stderr in case there are errors
//
//    do {
//        // Run the task
//        try task.run()
//
//        // Read the data from the pipe
//        let data = pipe.fileHandleForReading.readDataToEndOfFile()
//
//        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
//        if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
//            printOS("Error Output from mdls:\n\(errorOutput)\n")
//        }
//
//        // Check if there's any output captured
//        if data.isEmpty {
//            printOS("No output captured from mdls.")
//            return nil
//        }
//
//        // Attempt to parse the plist output into a Swift array of dictionaries
//        guard let plistArray = try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else {
//            printOS("Failed to parse plist output into expected format.")
//            return nil
//        }
//
////        printOS("Parsed plist array count: \(plistArray.count)")
//
//        // Ensure the number of plist items matches the number of paths
//        if plistArray.count != paths.count {
//            printOS("Warning: Number of plist items (\(plistArray.count)) does not match the number of paths (\(paths.count)).")
//        }
//
//        var metadataDictionary = [String: [String: Any]]()
//
//        // Map each metadata dictionary to its corresponding path using indices
//        for (index, appMetadata) in plistArray.enumerated() {
//            // Match metadata to path using the index
//            if index < paths.count {
//                let path = paths[index]
//                metadataDictionary[path] = appMetadata
////                printOS("Mapped metadata to path: \(path)")
//            } else {
//                printOS("Warning: More metadata entries than paths.")
//            }
//        }
//        return metadataDictionary
//
//    } catch {
//        printOS("Error running mdls: \(error)")
//        return nil
//    }
//}
