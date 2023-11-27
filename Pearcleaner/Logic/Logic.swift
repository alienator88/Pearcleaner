//
//  Logic.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI


// Get list of apps and sort it
func getSortedApps() -> (systemApps: [AppInfo], userApps: [AppInfo]) {
    let apps = getApplications()
    let sortedSystemApps = apps.systemApps
        .compactMap { getAppInfo(atPath: $0) }
        .sorted { $0.appName.replacingOccurrences(of: ".", with: "").lowercased() < $1.appName.replacingOccurrences(of: ".", with: "").lowercased() }
    let sortedUserApps = apps.userApps
        .compactMap { getAppInfo(atPath: $0) }
        .sorted { $0.appName.replacingOccurrences(of: ".", with: "").lowercased() < $1.appName.replacingOccurrences(of: ".", with: "").lowercased() }
    
    return (systemApps: sortedSystemApps, userApps: sortedUserApps)
}


// Get all applications from /Applications and ~/Applications
func getApplications() -> (systemApps: [URL], userApps: [URL]) {
    let fileManager = FileManager.default
    
    // Define the paths for system and user applications
    let systemAppsPath = "/Applications"
    let userAppsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
    
    var systemApps: [URL] = []
    var userApps: [URL] = []
    
    func collectAppPaths(at directoryPath: String, isSystem: Bool) {
        do {
            let appURLs = try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: directoryPath), includingPropertiesForKeys: nil, options: [])
            
            for appURL in appURLs {
                if appURL.pathExtension == "app" {
                    // Add the path to the appropriate list
                    if isSystem && !isRestricted(atPath: appURL) {
                        systemApps.append(appURL)
                    } else if !isSystem && !isRestricted(atPath: appURL) {
                        userApps.append(appURL)
                    }
                } else if appURL.hasDirectoryPath {
                    // If it's a directory, recursively explore it
                    collectAppPaths(at: appURL.path, isSystem: isSystem)
                }
            }
        } catch {
            // Handle any potential errors here
            print("Error: \(error)")
        }
    }
    
    // Collect system applications
    collectAppPaths(at: systemAppsPath, isSystem: true)
    
    // Collect user applications
    collectAppPaths(at: userAppsPath, isSystem: false)
    
    // Filter out unwanted system folders like /Applications/Utilities
    systemApps = systemApps.filter { !$0.absoluteString.contains("/Applications/Utilities/") }
    return (systemApps, userApps)
}


// Get app bundle information from provided path
func getAppInfo(atPath path: URL) -> AppInfo? {
    if let bundle = Bundle(url: path) {
        if let bundleIdentifier = bundle.bundleIdentifier,
           let appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
           var appIconFileName = bundle.infoDictionary?["CFBundleIconFile"] as? String {
            var appIcon: NSImage?
            var appName: String?
            var webApp: Bool?
            if let localizedName = bundle.localizedInfoDictionary?[kCFBundleNameKey as String] as? String {
                appName = localizedName
            } else if let bundleName = bundle.infoDictionary?["CFBundleName"] as? String {
                appName = bundleName
            } else {
                appName = path.deletingPathExtension().lastPathComponent
            }
            // Check if the icon file name has an .icns extension, if not, add it
            if !appIconFileName.hasSuffix(".icns") {
                appIconFileName += ".icns"
            }
            
            // Try to find the icon in the main bundle
            if let iconPath = bundle.path(forResource: appIconFileName, ofType: nil),
               let icon = NSImage(contentsOfFile: iconPath) {
                appIcon = icon
            }
            
            // If not found, try to find it in the resources directory
            if appIcon == nil,
               let resourcesPath = bundle.resourcePath {
                let iconURL = URL(fileURLWithPath: resourcesPath).appendingPathComponent(appIconFileName)
                if let icon = NSImage(contentsOfFile: iconURL.path) {
                    appIcon = icon
                }
            }
            
            // Convert the icon to a 100x100 PNG image
            if let pngIcon = appIcon.flatMap({ convertICNSToPNG(icon: $0, size: NSSize(width: 100, height: 100)) }) {
                appIcon = pngIcon
            }
            
            if appIcon == nil {
                print("App Icon not found for app at path: \(path)")
            }

            if bundle.infoDictionary?["LSTemplateApplication"] is Bool {
                webApp = true
            } else {
                webApp = false
            }
            
            return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName ?? "", appVersion: appVersion, appIcon: appIcon, webApp: webApp ?? false)
            
        } else {
            print("One or more variables missing for app at path: \(path)")
        }
    } else {
        print("Bundle not found at path: \(path)")
    }
    return nil
}



// Get directory path for darwin cache and temp directories
func darwinCT() -> (String, String) {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", "getconf DARWIN_USER_CACHE_DIR; getconf DARWIN_USER_TEMP_DIR"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        let components = output.components(separatedBy: "\n")
        if components.count >= 2 {
            var cacheDir = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            var tempDir = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if cacheDir.hasSuffix("/") {
                cacheDir.removeLast()
            }
            if tempDir.hasSuffix("/") {
                tempDir.removeLast()
            }
            return (cacheDir, tempDir)
        }
    }
    print("Could not get DARWIN_USER_CACHE_DIR or DARWIN_USER_TEMP_DIR")
    return ("", "")
}



// Check if app is running before deleting app files
func killApp(appId: String, completion: @escaping () -> Void = {}) {
    let runningApps = NSWorkspace.shared.runningApplications
    for app in runningApps {
        if app.bundleIdentifier == appId {
            app.terminate()
        }
    }
    completion()
}




// Find all possible paths for an app based on name/bundle id
func findPathsForApp(appState: AppState, appInfo: AppInfo) {
    Task(priority: .high) {
        updateOnMain {
            appState.paths = []
        }
        var collection: [URL] = []
        if let url = URL(string: appInfo.path.absoluteString) {
            //        appState.paths.insert(url, at: 0)
            collection.insert(url, at: 0)
        }
        
        let fileManager = FileManager.default
        let dispatchGroup = DispatchGroup()
        let bundleComponents = appInfo.bundleIdentifier.components(separatedBy: ".")
        var bundle: String = ""
        if bundleComponents.count >= 3 { // get last 2 or middle 2 components
            bundle = bundleComponents[1...2].joined(separator: "").lowercased()
        }
        let nameL = appInfo.appName.pearFormat()
        let bundleIdentifierL = appInfo.bundleIdentifier.pearFormat()
        let locations = Locations()
        
        for location in locations.apps.paths {
            if !fileManager.fileExists(atPath: location) {
//                print("Directory does not exist: \(location)")
                continue
            }
            
            dispatchGroup.enter() // Enter the dispatch group
            
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: location)
                
                for item in contents {
                    
                    let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
                    let itemL = ("\(item)").replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "").lowercased()
                    
                    if collection.contains(itemURL) {
                        return
                    }
                    // Catch web app plist files
                    if appInfo.webApp {
                        if itemL.contains(bundleIdentifierL) {
                            if collection.contains(itemURL) {
                                continue
                            }
                            collection.append(itemURL)
                        }
                    } else {
                        // Catch all the com.apple folders in the OS since there's a ton and probably unrelated
                        if itemL.contains("comapple")  {
                            if itemL.contains(bundle) || itemL.contains(bundleIdentifierL) || (nameL.count > 4 && itemL.contains(nameL)) {
                                collection.append(itemURL)
                            }
                        }
                        // Catch Xcode files
                        else if itemL.contains("xcode") {
                            if itemL.contains(bundle) || itemL.contains(bundleIdentifierL) || (nameL.count > 4 && itemL.contains(nameL)) {
                                collection.append(itemURL)
                            }
                            // Catch Logitech files since Logi is part of word login and can return random files
                        } else if itemL.contains("logi") && !itemL.contains("login") {
                            if itemL.contains(bundleComponents[1]) || itemL.contains(bundle) || itemL.contains(bundleIdentifierL) || (nameL.count > 3 && itemL.contains(nameL)) {
                                collection.append(itemURL)
                            }
                            // Catch MS Office files since they have many random folder names and very short names
                        } else if itemL.contains("office") || itemL.contains("oneauth") || itemL.suffix(2).contains("ms") || itemL.contains("onenote") {
                            if itemL.contains(bundle) || itemL.contains(bundleIdentifierL) || (nameL.count > 4 && itemL.contains(nameL)) {
                                collection.append(itemURL)
                            }
                        } else {
                            if itemL.contains(bundleIdentifierL) || itemL.contains(bundle) || (nameL.count > 3 && itemL.contains(nameL)) {
                                collection.append(itemURL)
                            }
                        }
                    }
                    
                }
            } catch {
                continue
            }
            
            dispatchGroup.leave() // Leave the dispatch group
            
            dispatchGroup.notify(queue: .main) {
                updateOnMain {
                    appState.paths = collection
                    appState.selectedItems = Set(collection)
                }
            }
            
        }
    }
}





// Move files to trash using applescript/Finder so it asks for user password if needed
func moveFilesToTrash(at fileURLs: [URL], completion: @escaping () -> Void = {}) {
    updateOnBackground {
        let posixFiles = fileURLs.map { "POSIX file \"\($0.path)\", " }.joined().dropLast(3)
        let scriptSource = """
        tell application \"Finder\" to delete { \(posixFiles)" }
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("Error: \(error)")
            } else if let outputString = output.stringValue {
                print(outputString)
            }
        }
        DispatchQueue.main.async {
            completion()
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
                if let value = error["NSAppleScriptErrorNumber"] {
                    if value as! Int == 1002 {
                        _ = checkAndRequestAccessibilityAccess(appState: appState)
                    }
                }
                print("Error: \(error)")
            } else if let outputString = output.stringValue {
                print(outputString)
            }
        }
        DispatchQueue.main.async {
            completion()
        }
    }
}












//func isAppRunning(appName: String) -> Bool {
//    let task = Process()
//    task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
//    task.arguments = ["-af", appName]
//    
//    let outputPipe = Pipe()
//    task.standardOutput = outputPipe
//    
//    do {
//        try task.run()
//    } catch {
//        print("Failed to run task: \(error)")
//        return false
//    }
//    
//    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
//    let output = String(decoding: outputData, as: UTF8.self)
//    
//    if output.isEmpty {
//        return false
//    } else {
//        return true
//    }
//}
//
//// Kill app if running
//func killApp2(appName: String, completion: @escaping () -> Void = {}) {
//    if isAppRunning(appName: appName) {
//        let task = Process()
//        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
//        task.arguments = ["-af", appName]
//        
//        do {
//            try task.run()
//        } catch {
//            print("Failed to run task: \(error)")
//            return
//        }
//        
//    }
//    completion()
//}
