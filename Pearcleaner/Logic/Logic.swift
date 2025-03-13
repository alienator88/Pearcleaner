//
//  Logic.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI
import AlinFoundation
import UniformTypeIdentifiers
import ServiceManagement

// Get all apps from /Applications and ~/Applications
func getSortedApps(paths: [String]) -> [AppInfo] {
    let fileManager = FileManager.default
    var apps: [URL] = []

    func collectAppPaths(at directoryPath: String) {
        do {
            let appURLs = try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: directoryPath), includingPropertiesForKeys: nil, options: [])

            for appURL in appURLs {
                if appURL.pathExtension == "app" && !isRestricted(atPath: appURL) &&
                    !appURL.isSymlink() {
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

    // Convert collected paths to string format for metadata query
    let combinedPaths = apps.map { $0.path }

    // Get metadata for all collected app paths
    var metadataDictionary: [String: [String: Any]] = [:]
    if let metadata = getMDLSMetadataAsPlist(for: combinedPaths) {
        metadataDictionary = metadata
    }

    // Process each app path and construct AppInfo using metadata first, then fallback if necessary
    let appInfos: [AppInfo] = apps.compactMap { appURL in
        let appPath = appURL.path

        if let appMetadata = metadataDictionary[appPath] {
            // Use `MetadataAppInfoFetcher` first
            return MetadataAppInfoFetcher.getAppInfo(fromMetadata: appMetadata, atPath: appURL)
        } else {
            // Fallback to `AppInfoFetcher` if no metadata found
            return AppInfoFetcher.getAppInfo(atPath: appURL)
        }
    }

    // Sort apps by display name
    let sortedApps = appInfos.sorted { $0.appName.lowercased() < $1.appName.lowercased() }

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

    updateOnMain {
        appState.leftoverProgress.0 = String(localized: "Finding orphaned files, please wait...")
    }
    ReversePathsSearcher(appState: appState, locations: locations, fsm: fsm, sortedApps: allApps).reversePathsSearch {
        updateOnMain {
            //            printOS("Reverse search processed successfully")
            appState.showProgress = false
            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                appState.leftoverProgress.1 = 0.0
            }
            appState.leftoverProgress.0 = String(localized: "Reverse search completed successfully")
        }
        completion()
    }
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
        AppPathFinder(appInfo: appInfo, locations: locations, appState: appState) {
            updateOnMain {
                // Update the progress indicator on the main thread once the search completes.
                appState.showProgress = false
            }
        }.findPaths()

        appState.appInfo = appInfo

        // Animate the view change and popover display.
        withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
            appState.currentView = .files
            showPopover.wrappedValue = true
        }
    }
}



// Move files to trash using Authorization Services so it asks for user password if needed
func moveFilesToTrash(appState: AppState, at fileURLs: [URL]) -> Bool {


    let validFileURLs = filterValidFiles(fileURLs: fileURLs) // Filter invalid files

    // Check if there are any valid files to delete
    guard !validFileURLs.isEmpty else {
        printOS("No valid files to move to Trash.")
        return false
    }


    let result = FileManagerUndo.shared.deleteFiles(at: validFileURLs)


    if result {
        playTrashSound()
    }

    return result
}

func moveFilesToTrashCLI(at fileURLs: [URL]) -> Bool {

    let validFileURLs = filterValidFiles(fileURLs: fileURLs) // Filter invalid files

    // Check if there are any valid files to delete
    guard !validFileURLs.isEmpty else {
        printOS("No valid files to move to Trash.")
        return false
    }

    let result = FileManagerUndo.shared.deleteFiles(at: validFileURLs, isCLI: true)

    return result
}


// Helper function to check file existence
//func filesStillExist(at fileURLs: [URL]) -> Bool {
//    let maxRetries = 3
//    let delay: TimeInterval = 1 // 200 ms delay
//
//    for attempt in 0..<maxRetries {
//        var anyFileExists = false
//        print(attempt)
//        for url in fileURLs {
//            if FileManager.default.fileExists(atPath: url.path) {
//                print("File still exists at: \(url.path)")
//                anyFileExists = true
//                break
//            }
//        }
//
//        // If no files exist, return false
//        if !anyFileExists {
//            return false
//        }
//
//        // If this was the last attempt, return true
//        if attempt == maxRetries - 1 {
//            return true
//        }
//
//        // Otherwise, wait and try again
//        Thread.sleep(forTimeInterval: delay)
//    }
//
//    return false // All files were deleted
//}


func filterValidFiles(fileURLs: [URL]) -> [URL] {
    let fileManager = FileManager.default
    return fileURLs.filter { url in

        // Check if file or folder exists
        guard fileManager.fileExists(atPath: url.path) else {
            printOS("Skipping \(url.path): File or folder does not exist.")
            return false
        }

        // Unlock the file or folder if it is locked
        if url.isFileLocked {
            do {
                try removeImmutableAttribute(from: url)
                printOS("Unlocked \(url.path).")
            } catch {
                printOS("Skipping \(url.path): Failed to unlock file or folder (\(error)).")
                return false
            }
        }

        // Check if file or folder is writable //MARK: Disabled this as it ignores files that need sudo to remove
        //        guard fileManager.isWritableFile(atPath: url.path) else {
        //            printOS("Skipping \(url.path): File or folder is not writable.")
        //            return false
        //        }

        return true
    }
}

extension URL {
    var isFileLocked: Bool {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: self.path)
            if let isLocked = fileAttributes[.immutable] as? Bool {
                return isLocked
            }
        } catch {
            printOS("Error checking lock status for \(self.path): \(error)")
        }
        return false
    }
}

func removeImmutableAttribute(from url: URL) throws {
    let attributes = [FileAttributeKey.immutable: false]
    try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
}


// Undo trash action
func undoTrash() -> Bool {
    // Check if an undo action is available
    if FileManagerUndo.shared.undoManager.canUndo {
        FileManagerUndo.shared.undoManager.undo()
        playTrashSound(undo: true)
        return true
    } else {
        printOS("Undo Trash Error: No undo action available.")
        return false
    }
}


// Reload apps list
func reloadAppsList(appState: AppState, fsm: FolderSettingsManager, delay: Double = 0.0, completion: @escaping () -> Void = {}) {
    appState.reload = true
    updateOnBackground(after: delay) {
        let sortedApps = getSortedApps(paths: fsm.folderPaths)
        // Update UI on the main thread
        updateOnMain {
            appState.sortedApps = sortedApps
            appState.reload = false
            completion()
        }
    }
}


// Process CLI // ========================================================================================================
func processCLI(arguments: [String], appState: AppState, locations: Locations, fsm: FolderSettingsManager) {
    let options = Array(arguments.dropFirst()) // Remove the first argument (binary path)

    // Launch app in terminal for debugging purposes
    func debugLaunch() {
        printOS("Pearcleaner CLI | Launching App For Debugging:\n")
    }

    // Private function to list files for uninstall, using the provided path
    func listFiles(at path: String) {
        // Convert the provided string path to a URL
        let url = URL(fileURLWithPath: path)

        printOS("Pearcleaner CLI | List Application Files:\n")

        // Fetch the app info and safely unwrap
        guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
            printOS("Error: Invalid path or unable to fetch app info at path: \(path)\n")
            exit(1)  // Exit with non-zero code to indicate failure
        }

        // Use the AppPathFinderCLI to find paths synchronously
        let appPathFinder = AppPathFinder(appInfo: appInfo, locations: locations)

        // Call findPaths to get the Set of URLs
        let foundPaths = appPathFinder.findPathsCLI()

        // Print each path in the Set to the console
        for path in foundPaths {
            printOS(path.path)
        }

        printOS("\nFound \(foundPaths.count) application files.\n")

    }

    // Private function to list orphaned files for uninstall, using the provided path
    func listOrphanedFiles() {
        printOS("Pearcleaner CLI | List Orphaned Files:\n")

        // Get installed apps for filtering
        let sortedApps = getSortedApps(paths: fsm.folderPaths)

        // Find orphaned files
        let foundPaths = ReversePathsSearcher(locations: locations, fsm: fsm, sortedApps: sortedApps)
            .reversePathsSearchCLI()

        // Print each path in the array to the console
        for path in foundPaths {
            printOS(path.path)
        }
        printOS("\nFound \(foundPaths.count) orphaned files.\n")
    }

    // Private function to uninstall the application bundle at a given path
    func uninstallApp(at path: String) {
        // Convert the provided string path to a URL
        let url = URL(fileURLWithPath: path)
        printOS("Pearcleaner CLI | Uninstall Application:\n")

        // Fetch the app info and safely unwrap
        guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
            printOS("Error: Invalid path or unable to fetch app info at path: \(path)\n")
            exit(1)  // Exit with non-zero code to indicate failure
        }

        killApp(appId: appInfo.bundleIdentifier) {
            let success =  moveFilesToTrashCLI(at: [appInfo.path])
            if success {
                printOS("Application deleted successfully.\n")
                exit(0)
            } else {
                printOS("Failed to delete application.\n")
                exit(1)
            }
        }
    }

    // Private function to uninstall the application and all related files at a given path
    func uninstallAll(at path: String) {
        // Convert the provided string path to a URL
        let url = URL(fileURLWithPath: path)
        printOS("Pearcleaner CLI | Uninstall Application & Related Files:\n")

        // Fetch the app info and safely unwrap
        guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
            printOS("Error: Invalid path or unable to fetch app info at path: \(path)")
            exit(1)  // Exit with non-zero code to indicate failure
        }

        // Use the AppPathFinderCLI to find paths synchronously
        let appPathFinder = AppPathFinder(appInfo: appInfo, locations: locations)

        // Call findPaths to get the Set of URLs
        let foundPaths = appPathFinder.findPathsCLI()

        // Check if any file is protected (non-writable)
        let protectedFiles = foundPaths.filter {
            !FileManager.default.isWritableFile(atPath: $0.path)
        }

        // If protected files are found, echo message and exit
        if !protectedFiles.isEmpty {
            printOS("Protected files detected. Please run this command with sudo:\n")
            printOS("sudo pearcleaner --uninstall-all \(path)")
            printOS("\nProtected files:\n")
            for file in protectedFiles {
                printOS(file.path)
            }
            exit(1)
        }

        killApp(appId: appInfo.bundleIdentifier) {
            let success =  moveFilesToTrashCLI(at: Array(foundPaths))
            if success {
                printOS("The application and related files have been deleted successfully.\n")
                exit(0)
            } else {
                printOS("Failed to delete some files, they might be protected or in use.\n")
                exit(1)
            }
        }
    }

    // Private function to remove the orphaned files
    func removeOrphanedFiles() {
        printOS("Pearcleaner CLI | Remove Orphaned Files:\n")

        // Get installed apps for filtering
        let sortedApps = getSortedApps(paths: fsm.folderPaths)

        // Find orphaned files
        let foundPaths = ReversePathsSearcher(locations: locations, fsm: fsm, sortedApps: sortedApps)
            .reversePathsSearchCLI()

        // Check if any file is protected (non-writable)
        let protectedFiles = foundPaths.filter {
            !FileManager.default.isWritableFile(atPath: $0.path)
        }

        // If protected files are found, echo message and exit
        if !protectedFiles.isEmpty {
            printOS("Protected files detected. Please run this command with sudo:\n")
            printOS("sudo pearcleaner --remove-orphaned")
            printOS("\nProtected files:\n")
            for file in protectedFiles {
                printOS(file.path)
            }
            exit(1)
        }

        let success =  moveFilesToTrashCLI(at: foundPaths)
        if success {
            printOS("Orphaned files have been deleted successfully.\n")
            exit(0)
        } else {
            printOS("Failed to delete some orphaned files.\n")
            exit(1)
        }
    }

    // Handle run option (-r or --run)
    if options.contains("-r") || options.contains("--run") {
        debugLaunch()
        return
    }

    // Handle help option (-h or --help)
    if options.contains("-h") || options.contains("--help") {
        displayHelp()
        exit(0)
    }

    // Handle --list or -l option with a path argument for listing app bundle files
    if let listIndex = options.firstIndex(where: { $0 == "--list" || $0 == "-l" }), listIndex + 1 < options.count {
        let path = options[listIndex + 1] // Path provided after --list or -l
        listFiles(at: path)
        exit(0)
    }

    // Handle --listlf or -lf option with a path argument for listing orphaned files
    if options.contains("--list-orphaned") || options.contains("-lo") {
        listOrphanedFiles()
        exit(0)
    }

    // Handle --uninstall or -u option with a path argument to uninstall app bundle only
    if let uninstallIndex = options.firstIndex(where: { $0 == "--uninstall" || $0 == "-u" }), uninstallIndex + 1 < options.count {
        let path = options[uninstallIndex + 1] // Path provided after --uninstall or -u
        uninstallApp(at: path)
        exit(0)
    }

    // Handle --uninstall-all or -ua option with a path argument to uninstall app bundle and related files
    if let uninstallAllIndex = options.firstIndex(where: { $0 == "--uninstall-all" || $0 == "-ua" }), uninstallAllIndex + 1 < options.count {
        let path = options[uninstallAllIndex + 1] // Path provided after --uninstall-all or -ua
        uninstallAll(at: path)
        exit(0)
    }

    // Handle --uninstall-lf or -ulf option with a path argument for listing orphaned files
    if options.contains("--remove-orphaned") || options.contains("-ro") {
        removeOrphanedFiles()
        exit(0)
    }

    // If no valid option was provided, show the help menu by default
    displayHelp()
    exit(0)
}


// Private function to display help message
func displayHelp() {
    printOS("""
            
            Pearcleaner CLI | Usage:
            
            --run, -r                            Launch Pearcleaner in Debug mode to see console logs
            --list <path>, -l <path>             List application files available for uninstall at the specified path
            --list-orphaned, -lo                 List orphaned files available for removal
            --uninstall <path>, -u <path>        Uninstall only the application bundle at the specified path
            --uninstall-all <path>, -ua <path>   Uninstall application bundle and ALL related files at the specified path
            --remove-orphaned, -ro               Remove ALL orphaned files (To ignore files, add them to the exception list within Pearcleaner settings)
            --help, -h                           Show this help message
            
            SUDO WARNING:                        When running pearcleaner CLI with sudo, files are not moved to Trash bin as they are owned by                                   root. This does not affect Pearcleaner GUI.
            
            """)
}



// FinderExtension Sequoia Fix
func manageFinderPlugin(install: Bool) {
    let task = Process()
    task.launchPath = "/usr/bin/pluginkit"

    task.arguments = ["-e", "\(install ? "use" : "ignore")", "-i", "com.alienator88.Pearcleaner"]

    task.launch()
    task.waitUntilExit()
}



// Brew cleanup

func getBrewCleanupCommand(for caskName: String) -> String {
#if arch(x86_64)
    let brewPath = "/usr/local/bin/brew"
#elseif arch(arm64)
    let brewPath = "/opt/homebrew/bin/brew"
#else
    let brewPath = "/usr/local/bin/brew"
#endif

    return "\(brewPath) uninstall --cask \(caskName) --zap --force && \(brewPath) cleanup && clear; echo '\nHomebrew cleanup was successful, you may close this window..\n'"

}


func getCaskIdentifier(for appName: String) -> String? {

#if arch(x86_64)
    let caskroomPath = "/usr/local/Caskroom/"
#elseif arch(arm64)
    let caskroomPath = "/opt/homebrew/Caskroom/"
#endif

    let fileManager = FileManager.default
    let lowercasedAppName = appName.lowercased()

    do {
        // Get all cask directories from Caskroom, ignoring hidden files
        let casks = try fileManager.contentsOfDirectory(atPath: caskroomPath).filter { !$0.hasPrefix(".") }

        for cask in casks {
            // Construct the path to the cask directory
            let caskSubPath = caskroomPath + cask

            // Get all version directories for this cask, ignoring hidden files
            let versions = try fileManager.contentsOfDirectory(atPath: caskSubPath).filter { !$0.hasPrefix(".") }

            // Only check the first valid version directory to improve efficiency
            if let latestVersion = versions.first {
                let appDirectory = "\(caskSubPath)/\(latestVersion)/"

                // List all files in the version directory and check for .app file
                //                let appsInDir = try fileManager.contentsOfDirectory(atPath: appDirectory).filter { !$0.hasPrefix(".") }
                let appsInDir = try fileManager.contentsOfDirectory(atPath: appDirectory).filter {
                    !$0.hasPrefix(".") && $0.hasSuffix(".app") && !$0.lowercased().contains("uninstall")
                }
                if let appFile = appsInDir.first(where: { $0.hasSuffix(".app") }) {
                    let realAppName = appFile.replacingOccurrences(of: ".app", with: "").lowercased()
                    // Compare the lowercased app names for case-insensitive match
                    if realAppName == lowercasedAppName {
                        return realAppName.replacingOccurrences(of: " ", with: "-").lowercased()
                    }
                }
            }
        }
    } catch {
        printOS("Error reading cask metadata: \(error)")
    }

    // If no match is found, return nil
    return nil
}



// Print list of files locally
func saveURLsToFile(appState: AppState, copy: Bool = false) {
    let urls = Set(appState.selectedItems)

    if copy {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        var fileContent = ""
        let sortedUrls = urls.sorted { $0.path < $1.path }

        for url in sortedUrls {
            let pathWithTilde = url.path.replacingOccurrences(of: homeDirectory, with: "~")
            fileContent += "\(pathWithTilde)\n"
        }
        copyToClipboard(fileContent)
    } else {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK, let selectedFolder = panel.url {
            let filePath = selectedFolder.appendingPathComponent("Export-\(appState.appInfo.appName)(v\(appState.appInfo.appVersion)).txt")
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            var fileContent = ""
            let sortedUrls = urls.sorted { $0.path < $1.path }

            for url in sortedUrls {
                let pathWithTilde = url.path.replacingOccurrences(of: homeDirectory, with: "~")
                fileContent += "\(pathWithTilde)\n"
            }

            do {
                try fileContent.write(to: filePath, atomically: true, encoding: .utf8)
                printOS("File saved successfully at \(filePath.path)")
                // Open Finder and select the file
                NSWorkspace.shared.selectFile(filePath.path, inFileViewerRootedAtPath: filePath.deletingLastPathComponent().path)
            } catch {
                printOS("Error saving file: \(error)")
            }

        } else {
            printOS("Folder selection was canceled.")
        }
    }


}


// Remove app from cache
func removeApp(appState: AppState, withPath path: URL) {
    @AppStorage("settings.general.brew") var brew: Bool = false
    DispatchQueue.main.async {

        // Remove from sortedApps if found
        if let index = appState.sortedApps.firstIndex(where: { $0.path == path }) {
            appState.sortedApps.remove(at: index)
        }

        // Brew cleanup if enabled
        //        if brew {
        //            if appState.appInfo.cask != nil {
        //                appState.showTerminal = true
        //            }
        ////            caskCleanup(app: appState.appInfo.appName)
        //        }

        //        appState.appInfo = AppInfo.empty

    }
}



// --- Pearcleaner Uninstall --
func uninstallPearcleaner(appState: AppState, locations: Locations) {

    // Unload Sentinel Monitor if running
    launchctl(load: false)

    // Get app info for Pearcleaner
    let appInfo = AppInfoFetcher.getAppInfo(atPath: Bundle.main.bundleURL)

    // Find application files for Pearcleaner
    AppPathFinder(appInfo: appInfo!, locations: locations, appState: appState, completion: {
        // Kill Pearcleaner and tell Finder to trash the files
        let selectedItemsArray = Array(appState.selectedItems).filter { !$0.path.contains(".Trash") }
        let result = FileManagerUndo.shared.deleteFiles(at: selectedItemsArray)

        if result {
            playTrashSound()
        }
        exit(0)
    }).findPaths()
}


// --- Load Plist file with SMAppService ---
func launchctl(load: Bool, completion: @escaping () -> Void = {}) {
    let service = SMAppService.agent(plistName: "com.alienator88.PearcleanerSentinel.plist")

    if load {
        do {
            try service.register()
        } catch let error as NSError {
            printOS("Error registering PearcleanerSentinel: \(error)")
        }
    } else {
        do {
            try service.unregister()
        } catch let error as NSError {
            printOS("Error unregistering PearcleanerSentinel: \(error)")
        }
    }

    completion()
}



func createTarArchive(appState: AppState) {
    // Filter the array to include only paths under /Users/, /Applications/, or /Library/
    let allowedPaths = Array(appState.selectedItems).filter {
        $0.path.starts(with: "/Users/") ||
        $0.path.starts(with: "/Applications/")
    }

    guard !allowedPaths.isEmpty else {
        printOS("No valid paths provided.")
        return
    }

    // Create save panel
    let savePanel = NSSavePanel()
    //    savePanel.allowedContentTypes = [.zip]
    savePanel.canCreateDirectories = true
    savePanel.showsTagField = false

    // Set default filename
    savePanel.nameFieldStringValue = "Bundle-\(appState.appInfo.appName).tar"
    savePanel.allowedContentTypes = [UTType(filenameExtension: "tar")!]


    // Show save panel
    let response = savePanel.runModal()
    guard response == .OK, let finalDestination = savePanel.url else {
        printOS("Archive export cancelled.")
        return
    }

    do {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Bundle-" + appState.appInfo.appName)

        // Create a temporary directory to organize the paths
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)

        for path in allowedPaths {
            // Compute the relative path for each file
            let relativePath: String
            if path.path.starts(with: "/Users/") {
                relativePath = String(path.path.dropFirst("/Users/".count))
            } else if path.path.starts(with: "/Applications/") {
                relativePath = "Applications/" + String(path.path.dropFirst("/Applications/".count))
            } else {
                continue
            }

            // Create subdirectories as needed in the temporary directory
            let destinationPath = tempDir.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: destinationPath.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

            // Copy the file to the corresponding relative path in the temporary directory
            try FileManager.default.copyItem(at: path, to: destinationPath)
        }

        // Use `ditto` to create the tar archive
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", tempDir.path, finalDestination.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        // Check for process errors
        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "com.alienator88.Pearcleaner.archiveExport", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Clean up the temporary directory
        try FileManager.default.removeItem(at: tempDir)

        printOS("Archive created successfully at \(finalDestination.path)")

    } catch {
        printOS("Error creating tar archive: \(error)")
    }
}
