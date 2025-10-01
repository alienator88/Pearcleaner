//
//  AppPathScanner.swift
//  Pearcleaner
//
//  Fast path-only scanner for installed apps (no metadata, no heavy operations)
//

import Foundation

struct AppPathScanner {

    /// Quickly scans for installed app paths without loading metadata
    /// Matches the logic of getSortedApps() but only collects paths
    /// - Parameter folderPaths: Array of folder paths to scan
    /// - Returns: Set of app bundle paths as strings
    static func getInstalledAppPaths(from folderPaths: [String]) -> Set<String> {
        let fileManager = FileManager.default
        var appPaths = Set<String>()
        let queue = DispatchQueue(label: "com.pearcleaner.pathscanner", qos: .userInitiated, attributes: .concurrent)
        let group = DispatchGroup()
        let resultsQueue = DispatchQueue(label: "com.pearcleaner.pathscanner.results")

        func collectAppPathsRecursively(at directoryPath: String) {
            do {
                let appURLs = try fileManager.contentsOfDirectory(
                    at: URL(fileURLWithPath: directoryPath),
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                    options: [])

                var foundApps: [String] = []
                var subdirectories: [URL] = []

                // Separate apps from subdirectories in one pass
                for appURL in appURLs {
                    let resourceValues = try? appURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    let isDirectory = resourceValues?.isDirectory ?? false
                    let isSymlink = resourceValues?.isSymbolicLink ?? false

                    // Match getSortedApps logic: check extension, not restricted, not symlink
                    if appURL.pathExtension == "app" && !isRestricted(atPath: appURL) && !isSymlink {
                        foundApps.append(appURL.path)
                        // Don't recurse into .app bundles - they may contain nested .app bundles
                    } else if isDirectory && !isSymlink {
                        subdirectories.append(appURL)
                    }
                }

                // Add found apps to the main collection
                if !foundApps.isEmpty {
                    resultsQueue.sync {
                        appPaths.formUnion(foundApps)
                    }
                }

                // Process subdirectories recursively in parallel
                for subdirectory in subdirectories {
                    group.enter()
                    queue.async {
                        collectAppPathsRecursively(at: subdirectory.path)
                        group.leave()
                    }
                }

            } catch {
                // Silently continue on errors
            }
        }

        // Process each root folder path
        for folderPath in folderPaths {
            if fileManager.fileExists(atPath: folderPath) {
                group.enter()
                queue.async {
                    collectAppPathsRecursively(at: folderPath)
                    group.leave()
                }
            }
        }

        group.wait()
        return appPaths
    }

    /// Check if path is restricted (matches isRestricted from Utilities.swift)
    private static func isRestricted(atPath path: URL) -> Bool {
        let pathString = path.path
        return pathString.contains("/Applications/Safari") ||
               pathString.contains(Bundle.main.name) ||
               pathString.contains("/Applications/Utilities")
    }
}
