//
//  Logic.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI
import AlinFoundation


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
func reversePreloader(allApps: [AppInfo], appState: AppState, locations: Locations, fsm: FolderSettingsManager, completion: @escaping () -> Void = {}) {
    @AppStorage("settings.interface.animationEnabled") var animationEnabled: Bool = true
//    appState.operationQueueLeftover.maxConcurrentOperationCount = 10 // Adjust this value as needed
//    appState.shouldCancelOperations = false
//    appState.appInfoStore.removeAll()
//    let sortedAllApps = allApps.sorted { $0.appName.localizedCompare($1.appName) == .orderedAscending }

    updateOnMain {
        appState.leftoverProgress.0 = "Finding leftover files, please wait..."
    }
    ReversePathsSearcher(appState: appState, locations: locations, fsm: fsm, sortedApps: allApps).reversePathsSearch {
        updateOnMain {
            printOS("Reverse search processed successfully")
            appState.showProgress = false
            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                appState.leftoverProgress.1 = 0.0
            }
            appState.leftoverProgress.0 = "Reverse search completed successfully"
        }
        completion()
    }

//    let totalApps = sortedAllApps.count
//    var processedApps = 0
//
//    DispatchQueue.global(qos: .userInitiated).async {
//        for (index, app) in sortedAllApps.enumerated() {
//            autoreleasepool {
//                if appState.shouldCancelOperations {
//                    printOS("Operations cancelled.") // Debug print
//                    return
//                }
//                printOS("Processing app \(index + 1) of \(totalApps): \(app.appName)")
//
//                let semaphore = DispatchSemaphore(value: 0)
//                appState.operationQueueLeftover.addOperation {
//                    if appState.shouldCancelOperations {
//                        printOS("Operations cancelled.") // Debug print
//                        return
//                    }
//                    let pathFinder = AppPathFinder(
//                        appInfo: app,
//                        appState: appState,
//                        locations: locations,
//                        backgroundRun: true,
//                        reverseAddon: reverseAddon,
//                        completion: {
//                            semaphore.signal()
//                        }
//                    )
//                    pathFinder.findPaths()
//                }
//
//                semaphore.wait()
//
//                DispatchQueue.main.async {
//                    processedApps += 1
//                    let progress = Double(processedApps) / Double(totalApps)
//                    withAnimation {
//                        appState.leftoverProgress.1 = progress
//                    }
//                    appState.leftoverProgress.0 = "Excluding application files for \(app.appName)"
//                    printOS("Progress: \(Int(progress * 100))%") // Debug print
//                }
//            }
//
//        }
//
//        appState.operationQueueLeftover.waitUntilAllOperationsAreFinished()
//
//        DispatchQueue.main.async {
//            if appState.shouldCancelOperations {
//                completion()
//                return
//            }
//
//            if appState.appInfoStore.count == sortedAllApps.count {
//                printOS("All apps processed successfully")
//                appState.leftoverProgress.0 = "Finding leftover files, please wait..."
//                ReversePathsSearcher(appState: appState, locations: locations, fsm: fsm, sortedApps: sortedAllApps).reversePathsSearch {
//                    updateOnMain {
//                        printOS("Reverse search processed successfully")
//                        appState.showProgress = false
//                        withAnimation {
//                            appState.leftoverProgress.1 = 0.0
//                        }
//                        appState.leftoverProgress.0 = "Reverse search completed successfully"
//                    }
//                    completion()
//                }
//            } else {
//                printOS("reversePreloader - Not all paths were loaded. Expected: \(sortedAllApps.count), Actual: \(appState.appInfoStore.count)")
//                updateOnMain {
//                    appState.showProgress = false
//                    withAnimation {
//                        appState.leftoverProgress.1 = 0.0
//                    }
//                    appState.leftoverProgress.0 = "Reverse search failed to process existing application files (\(sortedAllApps.count)/\(appState.appInfoStore.count))"
//                }
//                completion()
//            }
//        }
//    }
}




// Load item in Files view
func showAppInFiles(appInfo: AppInfo, appState: AppState, locations: Locations, showPopover: Binding<Bool>) {
    @AppStorage("settings.interface.animationEnabled") var animationEnabled: Bool = true

    showPopover.wrappedValue = false

    updateOnMain {
        appState.appInfo = .empty
        appState.selectedItems = []

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
        withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
            appState.currentView = .files
            showPopover.wrappedValue.toggle()
        }
        
        // Check if the appInfo exists in the appState.appInfoStore
//        if let storedAppInfo = appState.appInfoStore.first(where: { $0.path == appInfo.path }) {
//            // Update appState with the stored app info and selected items.
//            appState.appInfo = storedAppInfo
//            appState.selectedItems = Set(storedAppInfo.files)
//
//            // Trigger the animation for changing views and showing the popover.
//            withAnimation(Animation.easeIn(duration: 0.4)) {
//                appState.currentView = .files
//                showPopover.wrappedValue.toggle()
//            }
//        } else {
//            // When the appInfo is not found, show progress, and search for paths.
//            appState.showProgress = true
//
//            // Initialize the path finder and execute its search.
//            AppPathFinder(appInfo: appInfo, appState: appState, locations: locations) {
//                updateOnMain {
//                    // Update the progress indicator on the main thread once the search completes.
//                    appState.showProgress = false
//                }
//            }.findPaths()
//
//            appState.appInfo = appInfo
//
//            // Animate the view change and popover display.
//            withAnimation(Animation.easeIn(duration: 0.4)) {
//                appState.currentView = .files
//                showPopover.wrappedValue.toggle()
//            }
//        }
    }
}



// Move files to trash using applescript/Finder so it asks for user password if needed
func moveFilesToTrash(appState: AppState, at fileURLs: [URL], completion: @escaping (Bool) -> Void = {_ in }) {
    // Stop Sentinel FileWatcher momentarily to ignore .app bundle being sent to Trash
    sendStopNotificationFW()

    updateOnBackground {
        let posixFiles = fileURLs.map { item in
            return "POSIX file \"\(item.path)\"" + (item == fileURLs.last ? "" : ", ")}.joined()
        let scriptSource = """
        tell application \"Finder\" to delete { \(posixFiles) }
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
            if let error = error {
//                checkAllPermissions(appState: appState) { results in
//                    appState.permissionResults = results
//                    if !results.allPermissionsGranted {
//                        updateOnMain {
//                            appState.permissionsOkay = false
//                        }
//                    }
//                }
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
//                checkAllPermissions(appState: appState) { results in
//                    appState.permissionResults = results
//                    if !results.allPermissionsGranted {
//                        updateOnMain {
//                            appState.permissionsOkay = false
//                        }
//                    }
//                }
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


