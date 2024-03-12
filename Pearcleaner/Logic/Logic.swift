//
//  Logic.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI

// Get all apps from /Applications and ~/Applications
func getSortedApps() -> [AppInfo] {
    let fileManager = FileManager.default
    
    // Define the paths for system and user applications
    let systemAppsPath = "/Applications"
    let userAppsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
    
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
    collectAppPaths(at: systemAppsPath)
    
    // Collect user applications
    collectAppPaths(at: userAppsPath)

    // Get app info and sort
    let sortedApps = apps
        .compactMap { getAppInfo(atPath: $0) }
        .sorted { $0.appName.replacingOccurrences(of: ".", with: "").lowercased() < $1.appName.replacingOccurrences(of: ".", with: "").lowercased() }

    return sortedApps
}


// Get app bundle information from provided path
func getAppInfo(atPath path: URL, wrapped: Bool = false) -> AppInfo? {
    let filemanager = FileManager.default
    let wrapperURL = path.appendingPathComponent("Wrapper")
    if filemanager.fileExists(atPath: wrapperURL.path) {
        do {
            let contents = try filemanager.contentsOfDirectory(at: wrapperURL, includingPropertiesForKeys: nil, options: [])
            let appFiles = contents.filter { $0.pathExtension == "app" }

            if let firstAppFile = appFiles.first {
                let fullPath = wrapperURL.appendingPathComponent(firstAppFile.lastPathComponent)
                if let wrappedAppInfo = getAppInfo(atPath: fullPath, wrapped: true) {
                    return wrappedAppInfo
                }
            } else {
                printOS("No .app files found in the 'Wrapper' directory: \(wrapperURL)")
            }
        } catch {
            printOS("Error reading contents of 'Wrapper' directory: \(error.localizedDescription)\n\(wrapperURL)")
        }
    } else {
        if let bundle = Bundle(url: path) {
            if let bundleIdentifier = bundle.bundleIdentifier {
                var appIconFileName = bundle.infoDictionary?["CFBundleIconFile"] as? String ?? ""
                var appVersion: String?
                var appIcon: NSImage?
                var appName: String?
                var webApp: Bool?
                var wrappedApp: Bool?
                var system: Bool?

                if let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String, !shortVersion.isEmpty {
                    appVersion = shortVersion
                } else {
                    if let bundleVersion = bundle.infoDictionary?["CFBundleVersion"] as? String, !bundleVersion.isEmpty {
                        appVersion = bundleVersion
                    } else {
                        printOS("Failed to retrieve bundle version")
                    }
                }

                if let localizedName = bundle.localizedInfoDictionary?[kCFBundleNameKey as String] as? String {
                    appName = localizedName
                } else if let bundleName = bundle.infoDictionary?["CFBundleName"] as? String {
                    appName = bundleName
                } else {
                    appName = path.deletingPathExtension().lastPathComponent
                }

                if appIconFileName.isEmpty {
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
                                    printOS("No matching image found for \(primaryIconFile) in wrapped app.")
                                }
                            } else {
                                printOS("Unable to access the directory at \(primaryIconFile) for wrapped app.")
                            }

                        }
                    }
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
                    printOS("App Icon not found for app at path: \(path)")
                }

                if bundle.infoDictionary?["LSTemplateApplication"] is Bool {
                    webApp = true
                } else {
                    webApp = false
                }

                if wrapped {
                    wrappedApp = true
                } else {
                    wrappedApp = false
                }

                if !path.path.contains(home) {
                    system = true
                } else {
                    system = false
                }


                return AppInfo(id: UUID(), path: path, bundleIdentifier: bundleIdentifier, appName: appName ?? "", appVersion: appVersion ?? "", appIcon: appIcon, webApp: webApp ?? false, wrapped: wrappedApp ?? false, system: system ?? false, files: [], fileSize: [:], fileIcon: [:])

            } else {
                printOS("Bundle identifier not found at path: \(path)")
            }
        } else {
            printOS("Bundle not found at path: \(path)")
        }
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
    printOS("Could not get DARWIN_USER_CACHE_DIR or DARWIN_USER_TEMP_DIR")
    return ("", "")
}


func listAppSupportDirectories() -> [String] {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let appSupportLocation = home.appendingPathComponent("Library/Application Support/")
    let exclusions = ["MobileSync", ".DS_Store", "Xcode", "SyncServices", "networkserviceproxy", "DiskImages", "CallHistoryTransactions", "App Store", "CloudDocs", "icdd", "iCloud", "Instruments", "AddressBook", "FaceTime", "AskPermission", "CallHistoryDB"]
    let exclusionRegex = try! NSRegularExpression(pattern: "\\bcom\\.apple\\b", options: [])

    do {
        let fileManager = FileManager.default
        let directoryContents = try fileManager.contentsOfDirectory(at: appSupportLocation, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)

        let filteredDirectories: [String] = directoryContents.compactMap { url in
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                return nil
            }

            let directoryName = url.lastPathComponent

            // Check for exclusions using regex and provided list
            let excludeByRegex = exclusionRegex.firstMatch(in: directoryName, options: [], range: NSRange(location: 0, length: directoryName.utf16.count)) != nil
            let excludeByList = exclusions.contains(directoryName)

            return isDirectory.boolValue && !excludeByRegex && !excludeByList ? directoryName : nil
        }

        return filteredDirectories
    } catch {
        printOS("Error listing AppSupport directories: \(error.localizedDescription)")
        return []
    }
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
func findPathsForApp(appInfo: AppInfo = .empty, appState: AppState, locations: Locations, backgroundRun: Bool = false, completion: @escaping () -> Void = {}) {
    Task(priority: .high) {
        
        var collection: [URL] = []
        if let url = URL(string: appInfo.path.absoluteString) {
            if !url.path.contains(".Trash") {
                if url.path.contains("Wrapper") {
                    let modifiedUrl = url.deletingLastPathComponent().deletingLastPathComponent()
                    collection.insert(modifiedUrl, at: 0)
                } else {
                    collection.insert(url, at: 0)
                }
            }
        }


        let fileManager = FileManager.default
        let dispatchGroup = DispatchGroup()
        var bundleComponents = appInfo.bundleIdentifier.components(separatedBy: ".")
        if let lastComponent = bundleComponents.last, let rangeOfDash = lastComponent.range(of: "-") {
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

            dispatchGroup.enter() // Enter the dispatch group



            do {
                
                let contents = try fileManager.contentsOfDirectory(atPath: location)

                for item in contents {

                    let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
                    let itemL = ("\(item)").replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "").lowercased()
                    let filterItem = "\(location)/\(itemL)"

                    // Skip directories that start with com.apple. except for a few
                    if itemL.hasPrefix("comapple") && !itemL.hasPrefix("comappleconfigurator") && !itemL.hasPrefix("comappledt") && !itemL.hasPrefix("comappleiwork") {
                        continue
                    }

                    // Skip adding item if the collection already has it to prevent duplicates
                    if collection.contains(itemURL) {
                        continue
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
                        // Catch Xcode files for Xcodes app
                        if itemL.contains("xcode") && bundleIdentifierL.contains("comappledt") {
                            if filterItem.contains("comrobotsandpencilsxcodesapp") || filterItem.contains("comoneminutegamesxcodecleaner") || filterItem.contains("iohyperappxcodecleaner") || filterItem.contains("xcodesjson") {
                                continue
                            }
                            if itemL.contains(bundle) || itemL.contains(bundleIdentifierL) || (nameL.count < 6 && itemL.contains(nameL)) {
                                collection.append(itemURL)
                            }
                        } else if itemL.contains("xcodes") && bundleIdentifierL.contains("comrobotsandpencilsxcodesapp") {
                            if filterItem.contains("comappledt") {
                                continue
                            }
                            if itemL.contains(bundle) || itemL.contains(bundleIdentifierL) || (nameL.count > 4 && itemL.contains(nameL)) {
                                collection.append(itemURL)
                            }
                        }
                        else {
                            if itemL.contains(bundleIdentifierL) || itemL.contains(bundle) || (nameL.count > 3 && itemL.contains(nameL) || (nameP.count > 3 && itemL.contains(nameP))) {
                                collection.append(itemURL)
                            }
                        }
                    }
                    
                }
            } catch {
                printOS("Error processing location:", location, error)
                continue
            }

            dispatchGroup.leave() // Leave the dispatch group

        }

        // Append group containers
        let groupContainers = getGroupContainers(bundleURL: appState.appInfo.path)
        collection.append(contentsOf: groupContainers)
        var sortedCollection = collection.sorted(by: { $0.absoluteString < $1.absoluteString })

        // Calculate file details (sizes and icons)
        var fileSize: [URL: Int64] = [:]
        var fileIcon: [URL: NSImage?] = [:]
        var updatedAppInfo = appInfo

        for path in collection {
            var size: Int64
            var icon: NSImage? = nil
            size = totalSizeOnDisk(for: path)
            icon = getIconForFileOrFolderNS(atPath: path)

            fileSize[path] = size
            fileIcon[path] = icon
        }

        if sortedCollection.count == 1 {
            if let firstURL = sortedCollection.first, firstURL.path.contains(".Trash") {
                sortedCollection = []
            }
        }

        // Save to appState
        dispatchGroup.notify(queue: .main) {

            updateOnMain {
                updatedAppInfo.files = sortedCollection
                updatedAppInfo.fileSize = fileSize
                updatedAppInfo.fileIcon = fileIcon
                if !backgroundRun {
                    appState.appInfo = updatedAppInfo
                    appState.selectedItems = Set(sortedCollection)
                }
                appState.appInfoStore.append(updatedAppInfo)
            }
        }

        completion()

    }
}


// Load app paths on launch
func loadAllPaths(allApps: [AppInfo], appState: AppState, locations: Locations, reverseAddon: Bool = false, completion: @escaping () -> Void = {}) {

    let dispatchGroup = DispatchGroup()
    let retryLimit = 120
    var currentRetryCount = 0

    func checkCompletion() {
        if appState.appInfoStore.count == allApps.count {
            if reverseAddon {
                reversePathsSearch(appState: appState, locations: locations)
            }
            completion()
        } else {
            if currentRetryCount < retryLimit {
                currentRetryCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    checkCompletion()
                }
            } else {
                printOS("loadAllPaths - Retry limit timed out. Unable to load all paths within 1 minute.")
                completion()
            }
        }
    }

    dispatchGroup.enter()

    updateOnMain {
        appState.appInfoStore.removeAll()
    }

    dispatchGroup.notify(queue: .main) {
        checkCompletion()
    }

    DispatchQueue.global(qos: .background).async {
        for app in allApps {
            findPathsForApp(appInfo: app, appState: appState, locations: locations, backgroundRun: true)
        }
        dispatchGroup.leave()

    }

}


// Load item in Files view
func showAppInFiles(appInfo: AppInfo, mini: Bool, appState: AppState, locations: Locations, showPopover: Binding<Bool>) {
    showPopover.wrappedValue = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        updateOnMain {
            appState.appInfo = .empty
            appState.selectedItems = []
            if let storedAppInfo = appState.appInfoStore.first(where: { $0.path == appInfo.path }) {
                appState.appInfo = storedAppInfo
                appState.selectedItems = Set(storedAppInfo.files)
                withAnimation(Animation.easeIn(duration: 0.4)) {
                    if mini {
                        appState.currentView = .files
                        showPopover.wrappedValue.toggle()
                    } else {
                        appState.currentView = .files
                    }
                }
            } else {
                // Handle the case where the appInfo is not found in the store
                withAnimation(Animation.easeIn(duration: 0.4)) {
                    appState.showProgress = true
                    if mini {
                        appState.currentView = .files
                        showPopover.wrappedValue.toggle()
                    } else {
                        appState.currentView = .files
                    }
                }
                appState.appInfo = appInfo
                findPathsForApp(appInfo: appInfo, appState: appState, locations: locations) {
                    withAnimation(Animation.easeIn(duration: 0.4)) {
                        updateOnMain {
                            appState.showProgress = false
                        }
                    }
                }
            }
        }

    }
}


// Get group containers
func getGroupContainers(bundleURL: URL) -> [URL] {
    let fileManager = FileManager.default

    var staticCode: SecStaticCode?

    guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess else {
        return []
    }

    var signingInformation: CFDictionary?

    let status = SecCodeCopySigningInformation(staticCode!, SecCSFlags(), &signingInformation)

    if status != errSecSuccess {
        printOS("Failed to copy signing information. Status: \(status)")
        return []
    }

    guard let topDict = signingInformation as? [String: Any],
          let entitlementsDict = topDict["entitlements-dict"] as? [String: Any],
          let appGroups = entitlementsDict["com.apple.security.application-groups"] as? [String] else {
//        printOS("No application groups to extract from entitlements for this app.")
        return []
    }

    let groupContainersPath = appGroups.map { URL(fileURLWithPath: "\(home)/Library/Group Containers/" + $0) }
    let existingGroupContainers = groupContainersPath.filter { fileManager.fileExists(atPath: $0.path) }

    return existingGroupContainers
}




// Reverse search for leftover zombie files
func reversePathsSearch(appState: AppState, locations: Locations, completion: @escaping () -> Void = {}) {
    Task(priority: .high) {

            var collection: [URL] = []
            let fileManager = FileManager.default
            let dispatchGroup = DispatchGroup()
            let allPaths = appState.appInfoStore.flatMap { $0.files.map { $0.path.pearFormat() } }
            let allNames = appState.appInfoStore.map { $0.appName.pearFormat() }
            let skipped = ["apple", "temporary", "btserver", "proapps", "scripteditor", "ilife", "livefsd", "siritoday", "addressbook", "animoji", "appstore", "askpermission", "callhistory", "clouddocs", "diskimages", "dock", "facetime", "fileprovider", "instruments", "knowledge", "mobilesync", "syncservices", "homeenergyd", "icloud", "icdd", "networkserviceproxy", "familycircle", "geoservices", "installation", "passkit", "sharedimagecache", "desktop", "mbuseragent", "swiftpm", "baseband", "coresimulator", "photoslegacyupgrade", "photosupgrade", "siritts", "ipod", "globalpreferences", "apmanalytics", "apmexperiment", "avatarcache", "byhost", "contextstoreagent", "mobilemeaccounts", "intentbuilderc", "loginwindow", "momc", "replayd", "sharedfilelistd", "clang", "audiocomponent", "csexattrcryptoservice", "livetranscriptionagent", "sandboxhelper", "statuskitagent", "betaenrollmentd", "contentlinkingd", "diagnosticextensionsd", "gamed", "heard", "homed", "itunescloudd", "lldb", "mds", "mediaanalysisd", "metrickitd", "mobiletimerd", "proactived", "ptpcamerad", "studentd", "talagent", "watchlistd", "apptranslocation", "xcrun", "ds_store", "caches", "crashreporter", "trash", "pearcleaner", "amsdatamigratortool", "arfilecache", "assistant", "chromium", "cloudkit", "webkit", "databases", "diagnostic", "cache", "gamekit", "homebrew", "logi", "microsoft", "mozilla", "sync", "google"] // Skip system folders


            // Skip locations that might not exist
            for location in locations.reverse.paths {
                if !fileManager.fileExists(atPath: location) {
                    continue
                }

                dispatchGroup.enter()

                do {

                    let contents = try fileManager.contentsOfDirectory(atPath: location)

                    for item in contents {

                        let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
                        let itemName = ("\(item)").pearFormat()
                        let itemPath = "\(location)/\(itemName)".pearFormat()

                        if skipped.contains(where: { itemName.contains($0) }) {
                            continue
                        }

                        if allPaths.contains(where: { $0 == itemPath }) || allNames.contains(where: { $0 == itemName }) {
                            continue
                        }

                        collection.append(itemURL)

                    }
                } catch {
                    printOS("Error processing location:", location, error)
                    continue
                }

                dispatchGroup.leave() // Leave the dispatch group

            }

            // Calculate file details (sizes and icons)
            var fileSize: [URL: Int64] = [:]
            var fileIcon: [URL: NSImage?] = [:]
            var updatedZombieFile = ZombieFile.empty

            for path in collection {
                var size: Int64
                var icon: NSImage? = nil
                size = totalSizeOnDisk(for: path)
                icon = getIconForFileOrFolderNS(atPath: path)
                fileSize[path] = size
                fileIcon[path] = icon
            }

            // Save to appState
            dispatchGroup.notify(queue: .main) {

                updateOnMain {
                    updatedZombieFile.fileSize = fileSize
                    updatedZombieFile.fileIcon = fileIcon
                    appState.zombieFile = updatedZombieFile
                    appState.showProgress = false
                }

            }

            completion()

    }
}




// Move files to trash using applescript/Finder so it asks for user password if needed
func moveFilesToTrash(at fileURLs: [URL], completion: @escaping () -> Void = {}) {
    @AppStorage("settings.sentinel.enable") var sentinel: Bool = false
    var filesFinder = fileURLs
    var filesSudo: [URL] = []

    for file in fileURLs {
        if isSocketFile(at: file) {
            if let index = filesFinder.firstIndex(of: file) {
                filesFinder.remove(at: index)
                filesSudo.insert(file, at: 0)
            }
        }
    }

    if !filesSudo.isEmpty {
        // Remove socket files with rm
        let filesSudoPaths = filesSudo.map { $0.path }
        do {
            let fileHandler = try Authorization.executeWithPrivileges("/bin/rm -f \(filesSudoPaths.joined(separator: " "))").get()
            printOS(String(bytes: fileHandler.readDataToEndOfFile(), encoding: .utf8)!)
        } catch {
            printOS("Failed to remove socket file/s with privileges: \(error)")
        }
    }



    updateOnBackground {
        let posixFiles = filesFinder.map { "POSIX file \"\($0.path)\", " }.joined().dropLast(3)
        let scriptSource = """
        tell application \"Finder\" to delete { \(posixFiles)" }
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
            if let error = error {
                printOS("Error: \(error)")
            } else if let outputString = output.stringValue {
                printOS(outputString)
            }
        }
        DispatchQueue.main.async {
            completion()
        }
    }
}


func isSocketFile(at url: URL) -> Bool {
    do {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileType = attributes[FileAttributeKey.type] as? FileAttributeType {
            return fileType == .typeSocket
        }
    } catch {
        print("Error: \(error)")
    }
    return false
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
                printOS("Error: \(error)")
            } else if let outputString = output.stringValue {
                printOS(outputString)
            }
        }
        DispatchQueue.main.async {
            completion()
        }
    }
}


