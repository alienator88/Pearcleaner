//
//  Logic.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI


// Get all apps from /Applications and ~/Applications
func getSortedApps(paths: [String], appState: AppState) -> [AppInfo] {
    let fileManager = FileManager.default
    var apps: [URL] = []

    func collectAppPaths(at directoryPath: String) {
        do {
            let appURLs = try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: directoryPath), includingPropertiesForKeys: nil, options: [])
            
            for appURL in appURLs {
                if appURL.pathExtension == "app" && !isRestricted(atPath: appURL) {
                    // Add the path to the array
                    apps.append(appURL)
                } else if appURL.hasDirectoryPath {
                    // If it's a directory, recursively explore it
                    collectAppPaths(at: appURL.path)
                }
            }
        } catch {
            // Handle any potential errors here
            printOS("Error: \(error)")
        }
    }

    // Collect system applications
    paths.forEach { collectAppPaths(at: $0) }

    // Get app info and sort
    let sortedApps = apps
        .compactMap { AppInfoFetcher.getAppInfo(atPath: $0) }
        .sorted { $0.appName.replacingOccurrences(of: ".", with: "").lowercased() < $1.appName.replacingOccurrences(of: ".", with: "").lowercased() }


    return sortedApps
}



// Get directory path for darwin cache and temp directories
func darwinCT() -> (String, String) {
    let command = "echo $(getconf DARWIN_USER_CACHE_DIR) $(getconf DARWIN_USER_TEMP_DIR)"
    let process = Process()
    process.launchPath = "/bin/bash"
    process.arguments = ["-c", command]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        printOS("Could not get DARWIN_USER_CACHE_DIR or DARWIN_USER_TEMP_DIR")
        return ("", "")
    }

    let paths = output.split(separator: " ").map(String.init)
    guard paths.count >= 2 else {
        printOS("Could not parse DARWIN_USER_CACHE_DIR or DARWIN_USER_TEMP_DIR")
        return ("", "")
    }
    return (paths[0].trimmingCharacters(in: .whitespaces), paths[1].trimmingCharacters(in: .whitespaces))
}



func listAppSupportDirectories() -> [String] {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser
    let appSupportLocation = home.appendingPathComponent("Library/Application Support").path
    let exclusions = Set(["MobileSync", ".DS_Store", "Xcode", "SyncServices", "networkserviceproxy", "DiskImages", "CallHistoryTransactions", "App Store", "CloudDocs", "icdd", "iCloud", "Instruments", "AddressBook", "FaceTime", "AskPermission", "CallHistoryDB"])
    let exclusionRegex = try! NSRegularExpression(pattern: "\\bcom\\.apple\\b", options: [])

    do {
        let directoryContents = try fileManager.contentsOfDirectory(atPath: appSupportLocation)

        return directoryContents.compactMap { directoryName in
            let fullPath = appSupportLocation.appending("/\(directoryName)")
            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return nil
            }

            // Check for exclusions using regex and provided list
            let excludeByRegex = exclusionRegex.firstMatch(in: directoryName, options: [], range: NSRange(location: 0, length: directoryName.utf16.count)) != nil
            if exclusions.contains(directoryName) || excludeByRegex {
                return nil
            }
            return directoryName
        }
    } catch {
        printOS("Error listing AppSupport directories: \(error.localizedDescription)")
        return []
    }
}




// Load app paths on launch
func reversePreloader(allApps: [AppInfo], appState: AppState, locations: Locations, fsm: FolderSettingsManager, reverseAddon: Bool = false, completion: @escaping () -> Void = {}) {
    let dispatchGroup = DispatchGroup()
    appState.appInfoStore.removeAll()

    for app in allApps {
        dispatchGroup.enter()
        DispatchQueue.global(qos: .background).async {
            AppPathFinder(appInfo: app, appState: appState, locations: locations, backgroundRun: true, reverseAddon: reverseAddon).findPaths()
            dispatchGroup.leave()
        }
    }

    dispatchGroup.notify(queue: DispatchQueue.global(qos: .background)) {

        func checkAllAppsProcessed(retryCount: Int = 0, maxRetry: Int = 120) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if appState.appInfoStore.count == allApps.count {
                    ReversePathsSearcher(appState: appState, locations: locations, fsm: fsm).reversePathsSearch() {
                        updateOnMain {
                            appState.showProgress = false
                        }
                    }
                    completion()
                } else if retryCount < maxRetry {
                    checkAllAppsProcessed(retryCount: retryCount + 1, maxRetry: maxRetry)
                } else {
                    // Reset progress values to 0
                    updateOnMain {
                        appState.showProgress = false
                    }
                    printOS("loadAllPaths - Retry limit reached. Not all paths were loaded.")
                    completion()
                }
            }
        }

        checkAllAppsProcessed()

    }
}




// Load item in Files view
func showAppInFiles(appInfo: AppInfo, appState: AppState, locations: Locations, showPopover: Binding<Bool>) {
    showPopover.wrappedValue = false

    updateOnMain {
        appState.appInfo = .empty
        appState.selectedItems = []

        // Check if the appInfo exists in the appState.appInfoStore
        if let storedAppInfo = appState.appInfoStore.first(where: { $0.path == appInfo.path }) {
            // Update appState with the stored app info and selected items.
            appState.appInfo = storedAppInfo
            appState.selectedItems = Set(storedAppInfo.files)

            // Trigger the animation for changing views and showing the popover.
            withAnimation(Animation.easeIn(duration: 0.4)) {
                appState.currentView = .files
                showPopover.wrappedValue.toggle()
            }
        } else {
            // When the appInfo is not found, show progress, and search for paths.
            appState.showProgress = true

            // Initialize the path finder and execute its search.
            AppPathFinder(appInfo: appInfo, appState: appState, locations: locations) {
                updateOnMain {
                    // Update the progress indicator on the main thread once the search completes.
                    appState.showProgress = false
                }
            }.findPaths()

            appState.appInfo = appInfo

            // Animate the view change and popover display.
            withAnimation(Animation.easeIn(duration: 0.4)) {
                appState.currentView = .files
                showPopover.wrappedValue.toggle()
            }
        }
    }
}



// Move files to trash using applescript/Finder so it asks for user password if needed
func moveFilesToTrash(appState: AppState, at fileURLs: [URL], completion: @escaping (Bool) -> Void = {_ in }) {
    @AppStorage("settings.sentinel.enable") var sentinel: Bool = false
    if sentinel {
        launchctl(load: false)
    }
    updateOnBackground {
        let posixFiles = fileURLs.map { "POSIX file \"\($0.path)\", " }.joined().dropLast(3)
        let scriptSource = """
        tell application \"Finder\" to delete { \(posixFiles)" }
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
            if let error = error {
                checkAllPermissions(appState: appState) { results in
                    appState.permissionResults = results
                    if !results.allPermissionsGranted {
                        updateOnMain {
                            appState.permissionsOkay = false
                        }
                    }
                }
                printOS("Trash Error: \(error)")
                DispatchQueue.main.async {
                    completion(false)  // Indicate failure
                }
                return
            }
            if let outputString = output.stringValue {
                printOS(outputString)
            }
        }
        DispatchQueue.main.async {
            completion(true)  // Indicate success
        }
    }

}




// Undo trash action
func undoTrash(appState: AppState, completion: @escaping () -> Void = {}) {
    let scriptSource = """
    tell application "Finder"
        activate
    end tell
    
    tell application "System Events"
        keystroke "z" using command down
    end tell
    
    tell application "Pearcleaner"
        activate
    end tell
    """
    var error: NSDictionary?
    
    updateOnBackground {
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
            if let error = error {
                checkAllPermissions(appState: appState) { results in
                    appState.permissionResults = results
                    if !results.allPermissionsGranted {
                        updateOnMain {
                            appState.permissionsOkay = false
                        }
                    }
                }
                printOS("Undo Trash Error: \(error)")
            } else if let outputString = output.stringValue {
                printOS(outputString)
            }
        }
        DispatchQueue.main.async {
            completion()
        }
    }
}


