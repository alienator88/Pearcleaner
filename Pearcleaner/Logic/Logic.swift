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
           var appIconFileName = bundle.infoDictionary?["CFBundleIconFile"] as? String {
            var appVersion = "0.0.0"
            var appIcon: NSImage?
            var appName: String?
            var webApp: Bool?


            if let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String {
                appVersion = shortVersion
            } else {
                if let bundleVersion = bundle.infoDictionary?["CFBundleVersion"] as? String {
                    appVersion = bundleVersion
                } else {
                    print("Failed to retrieve bundle version")
                }
            }

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


            return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName ?? "", appVersion: appVersion, appIcon: appIcon, webApp: webApp ?? false, wrapped: false)

        } else {
            let wrapperURL = path.appendingPathComponent("Wrapper")

            // Check that file path exists, exit if not
            if FileManager.default.fileExists(atPath: wrapperURL.path) {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: wrapperURL, includingPropertiesForKeys: nil, options: [])
                    let appFiles = contents.filter { $0.pathExtension == "app" }

                    if let firstAppFile = appFiles.first {
                        let fullPath = wrapperURL.appendingPathComponent(firstAppFile.lastPathComponent)
                        if let wrappedAppInfo = getWrappedAppInfo(atPath: fullPath) {
                            return wrappedAppInfo
                        }
                    } else {
                        print("No .app files found in the 'Wrapper' directory.")
                    }
                } catch {
                    print("Error reading contents of 'Wrapper' directory: \(error.localizedDescription)")
                }
            } else {
                print("Error: 'Wrapper' directory not found at path: \(wrapperURL.path)")
            }

        }
    } else {
        print("Bundle not found at path: \(path)")
    }
    return nil
}


func getWrappedAppInfo(atPath path: URL) -> AppInfo? {
    if let bundle = Bundle(url: path) {
        if let bundleIdentifier = bundle.bundleIdentifier,
           let appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            var appIconFileName = bundle.infoDictionary?["CFBundleIconFile"] as? String
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

            if appIconFileName == nil {
                if let iconsDict = bundle.infoDictionary?["CFBundleIcons"] as? [String: Any] {
                    if let primaryIconDict = iconsDict["CFBundlePrimaryIcon"] as? [String: Any],
                       let iconFiles = primaryIconDict["CFBundleIconFiles"] as? [String],
                       let primaryIconFile = iconFiles.first {
                        // Now, you can use the primaryIconFile to construct the path to the icon file
                        let iconPath = path.appendingPathComponent(primaryIconFile)
                        appIconFileName = iconPath.path

                        if let contents = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil) {
                            // Find the first file that matches the specified prefix
                            if let foundURL = contents.first(where: { $0.lastPathComponent.hasPrefix(primaryIconFile) }),
                               let image = NSImage(contentsOfFile: foundURL.path) {
                                appIcon = image


                            } else {
                                print("No matching image found for \(primaryIconFile).")
                            }
                        } else {
                            print("Unable to access the directory at \(primaryIconFile).")
                        }

                    }
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


            return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName ?? "", appVersion: appVersion, appIcon: appIcon, webApp: webApp ?? false, wrapped: true)

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


// Add subfolders of ~/Library/Application Support/ to locations for deeper search
func appSupSubfolders() throws -> [String] {
    let fileManager = FileManager.default
    let appSup = "\(home)/Library/Application Support/"
    let subfolders = try fileManager.contentsOfDirectory(atPath: appSup)
    let exclusionRegex = try NSRegularExpression(pattern: "\\bcom\\.apple\\b", options: [])
    let exclusions = ["MobileSync", ".DS_Store", "Xcode", "SyncServices", "networkserviceproxy", "DiskImages", "CallHistoryTransactions", "App Store", "CloudDocs", "icdd", "iCloud", "Instruments", "AddressBook", "FaceTime", "AskPermission", "CallHistoryDB"]

    let allowedFolders = subfolders.filter { folder in
        let range = NSRange(location: 0, length: folder.utf16.count)
        return exclusionRegex.firstMatch(in: folder, options: [], range: range) == nil && !exclusions.contains(folder)
    }

    return allowedFolders
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
func findPathsForApp(appState: AppState, locations: Locations) {
    Task(priority: .high) {
        updateOnMain {
            appState.paths = []
        }
        let appInfo = appState.appInfo
        var collection: [URL] = []
        if let url = URL(string: appInfo.path.absoluteString) {
            collection.insert(url, at: 0)
        }
        
        let fileManager = FileManager.default
//        let progressManager = appState.progressManager
        let dispatchGroup = DispatchGroup()
        var bundleComponents = appInfo.bundleIdentifier.components(separatedBy: ".")
        if let lastComponent = bundleComponents.last, let rangeOfDash = lastComponent.range(of: "-") {
            // Remove the dash and everything after it
            let updatedLastComponent = String(lastComponent[..<rangeOfDash.lowerBound])
            bundleComponents[bundleComponents.count - 1] = updatedLastComponent
        }
        var bundle: String = ""
        if bundleComponents.count >= 3 { // get last 2 or middle 2 components
            bundle = bundleComponents[1...2].joined(separator: "").lowercased()
        }

        let nameL = appInfo.appName.pearFormat()
        let nameP = appInfo.path.lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let bundleIdentifierL = appInfo.bundleIdentifier.pearFormat()

        for location in locations.apps.paths {
            if !fileManager.fileExists(atPath: location) {
                continue
            }


//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                withAnimation {
//                    progressManager.updateStatus(status: location)
//                    progressManager.updateProgress()
//                    progressManager.objectWillChange.send()
//                }
//            }


            dispatchGroup.enter() // Enter the dispatch group



            do {
                
                let contents = try fileManager.contentsOfDirectory(atPath: location)
                
                for item in contents {
                    let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
                    let itemL = ("\(item)").replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "").lowercased()


                    if collection.contains(itemURL) {
                        break
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
                        } else {
                            if itemL.contains(bundleIdentifierL) || itemL.contains(bundle) || (nameL.count > 3 && itemL.contains(nameL) || (nameP.count > 3 && itemL.contains(nameP))) {
                                collection.append(itemURL)
                            }
                        }
                    }
                    
                }
            } catch {
                print("Error processing location:", location, error)
                continue
            }

//            try await Task.sleep(nanoseconds: 50_000_000)

            dispatchGroup.leave() // Leave the dispatch group

        }

        // Append group containers
        let groupContainers = getGroupContainers(bundleURL: appState.appInfo.path)
        collection.append(contentsOf: groupContainers)
        let sortedCollection = collection.sorted(by: { $0.absoluteString < $1.absoluteString })

        // Save to appState
        dispatchGroup.notify(queue: .main) {
            updateOnMain {
                appState.paths = sortedCollection
                appState.selectedItems = Set(sortedCollection)
            }
        }

    }
}


func getGroupContainers(bundleURL: URL) -> [URL] {
    let fileManager = FileManager.default

    var staticCode: SecStaticCode?

    guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess else {
        return []
    }

    var signingInformation: CFDictionary?

    let status = SecCodeCopySigningInformation(staticCode!, SecCSFlags(), &signingInformation)

    if status != errSecSuccess {
        print("Failed to copy signing information. Status: \(status)")
        return []
    }

    guard let topDict = signingInformation as? [String: Any],
          let entitlementsDict = topDict["entitlements-dict"] as? [String: Any],
          let appGroups = entitlementsDict["com.apple.security.application-groups"] as? [String] else {
//        print("No application groups to extract from entitlements for this app.")
        return []
    }

    let groupContainersPath = appGroups.map { URL(fileURLWithPath: "\(home)/Library/Group Containers/" + $0) }
    let existingGroupContainers = groupContainersPath.filter { fileManager.fileExists(atPath: $0.path) }

    return existingGroupContainers
}


// Move files to trash using applescript/Finder so it asks for user password if needed
func moveFilesToTrash(at fileURLs: [URL], completion: @escaping () -> Void = {}) {
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
