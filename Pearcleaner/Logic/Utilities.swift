//
//  Utilities.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/3/23.
//

import Foundation
import SwiftUI
import AlinFoundation
import AppKit

// Reload apps list
func reloadAppsList(appState: AppState, fsm: FolderSettingsManager) {
    appState.reload = true
    updateOnBackground {
        let sortedApps = getSortedApps(paths: fsm.folderPaths)
        // Update UI on the main thread
        updateOnMain {
            appState.sortedApps = sortedApps
            appState.reload = false
        }
    }
}



func resizeWindowAuto(windowSettings: WindowSettings, title: String) {
    if let window = NSApplication.shared.windows.first(where: { $0.title == title }) {
        print(windowSettings.loadWindowSettings())
        let newSize = NSSize(width: windowSettings.loadWindowSettings().width, height: windowSettings.loadWindowSettings().height)
        window.setContentSize(newSize)
    }
}



// Check if Pearcleaner has any windows open
func hasWindowOpen() -> Bool {
    for window in NSApp.windows where window.title == "Pearcleaner" {
        return true
    }
    return false
}



func findAndSetWindowFrame(named titles: [String], windowSettings: WindowSettings) {
    windowSettings.registerDefaultWindowSettings() {
        for title in titles {
            if let window = NSApp.windows.first(where: { $0.title == title }) {
                window.isRestorable = false
                window.isReleasedWhenClosed = false
                let frame = windowSettings.loadWindowSettings()
                window.setFrame(frame, display: true, animate: true)
            }
        }
    }
}


// Process CLI // ========================================================================================================
func processCLI(arguments: [String], appState: AppState, locations: Locations, fsm: FolderSettingsManager) {
    let options = Array(arguments.dropFirst()) // Remove the first argument (binary path)

    // Private function to list files for uninstall, using the provided path
    func listFiles(at path: String) {
        // Convert the provided string path to a URL
        let url = URL(fileURLWithPath: path)

        print("[BETA] Pearcleaner CLI | List Application Files:\n")

        // Fetch the app info and safely unwrap
        guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
            print("Error: Invalid path or unable to fetch app info at path: \(path)\n")
            exit(1)  // Exit with non-zero code to indicate failure
        }

        // Use the AppPathFinderCLI to find paths synchronously
        let appPathFinder = AppPathFinder(appInfo: appInfo, locations: locations)

        // Call findPaths to get the Set of URLs
        let foundPaths = appPathFinder.findPathsCLI()

        // Print each path in the Set to the console
        for path in foundPaths {
            print(path.path)
        }

        print("\nFound \(foundPaths.count) application files.\n")

    }

    // Private function to list orphaned files for uninstall, using the provided path
    func listLeftoverFiles() {
        print("[BETA] Pearcleaner CLI | List Orphaned Files:\n")

        // Get installed apps for filtering
        let sortedApps = getSortedApps(paths: fsm.folderPaths)

        // Find orphaned files
        let foundPaths = ReversePathsSearcher(locations: locations, fsm: fsm, sortedApps: sortedApps)
            .reversePathsSearchCLI()

        // Print each path in the array to the console
        for path in foundPaths {
            print(path.path)
        }
        print("\nFound \(foundPaths.count) orphaned files.\n")
    }

    // Private function to uninstall the application bundle at a given path
    func uninstallApp(at path: String) {
        // Convert the provided string path to a URL
        let url = URL(fileURLWithPath: path)
        print("[BETA] Pearcleaner CLI | Uninstall Application:\n")

        // Fetch the app info and safely unwrap
        guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
            print("Error: Invalid path or unable to fetch app info at path: \(path)\n")
            exit(1)  // Exit with non-zero code to indicate failure
        }

        killApp(appId: appInfo.bundleIdentifier) {
            let success =  moveFilesToTrashCLI(at: [appInfo.path])
            if success {
                print("Application moved to the trash successfully.\n")
                exit(0)
            } else {
                print("Failed to move application to trash.\n")
                exit(1)
            }
        }
    }

    // Private function to uninstall the application and all related files at a given path
    func uninstallAll(at path: String) {
        // Convert the provided string path to a URL
        let url = URL(fileURLWithPath: path)
        print("[BETA] Pearcleaner CLI | Uninstall Application & Related Files:\n")

        // Fetch the app info and safely unwrap
        guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
            print("Error: Invalid path or unable to fetch app info at path: \(path)")
            exit(1)  // Exit with non-zero code to indicate failure
        }

        // Use the AppPathFinderCLI to find paths synchronously
        let appPathFinder = AppPathFinder(appInfo: appInfo, locations: locations)

        // Call findPaths to get the Set of URLs
        let foundPaths = appPathFinder.findPathsCLI()

        killApp(appId: appInfo.bundleIdentifier) {
            let success =  moveFilesToTrashCLI(at: Array(foundPaths))
            if success {
                print("The application and related files have been moved to the trash successfully.\n")
                exit(0)
            } else {
                print("Failed to move application and related files to trash.\n")
                exit(1)
            }
        }
    }

    // Private function to remove the orphaned files
    func removeLeftoverFiles() {
        print("[BETA] Pearcleaner CLI | Remove Orphaned Files:\n")

        // Get installed apps for filtering
        let sortedApps = getSortedApps(paths: fsm.folderPaths)

        // Find orphaned files
        let foundPaths = ReversePathsSearcher(locations: locations, fsm: fsm, sortedApps: sortedApps)
            .reversePathsSearchCLI()

        let success =  moveFilesToTrashCLI(at: foundPaths)
        if success {
            print("Orphaned files have been moved to the trash successfully.\n")
            exit(0)
        } else {
            print("Failed to move orphaned files to trash.\n")
            exit(1)
        }
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
        listLeftoverFiles()
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
        removeLeftoverFiles()
        exit(0)
    }

    // If no valid option was provided, show the help menu by default
    displayHelp()
    exit(0)
}

// Private function to display help message
func displayHelp() {
    print("""
            
            [BETA] Pearcleaner CLI | Usage:
            
            --list <path>, -l <path>             List application files available for uninstall at the specified path
            --list-orphaned, -lo                 List orphaned files available for removal
            --uninstall <path>, -u <path>        Uninstall only the application bundle at the specified path
            --uninstall-all <path>, -ua <path>   Uninstall application bundle and ALL related files at the specified path
            --remove-orphaned, -ro               Remove ALL orphaned files (To ignore files, add them to the exception list within Pearcleaner settings)
            --help, -h                           Show this help message
            
            """)
}


// Check if pearcleaner symlink exists
func checkCLISymlink() -> Bool {
    let filePath = "/usr/local/bin/pearcleaner"
    let fileManager = FileManager.default

    // Check if the file exists and is a symlink
    guard fileManager.fileExists(atPath: filePath) else { return false }

    // Check if the symlink points to the correct path
    do {
        let destination = try fileManager.destinationOfSymbolicLink(atPath: filePath)
        return destination == Bundle.main.executablePath
    } catch {
        return false
    }
}

// Install/uninstall symlink for CLI
func manageSymlink(install: Bool) {
    // Get the current running application's bundle binary path
    guard let appPath = Bundle.main.executablePath else {
        printOS("Error: Unable to get the executable path.")
        return
    }

    // Path where the symlink should be created
    let symlinkPath = "/usr/local/bin/pearcleaner"

    // Check if the symlink already exists
    let symlinkExists = checkCLISymlink()

    // If we are installing the symlink and it already exists, skip creating it
    if install && symlinkExists {
        printOS("Symlink already exists at \(symlinkPath). No action needed.")
        return
    }

    // If we are uninstalling the symlink and it doesn't exist, skip removing it
    if !install && !symlinkExists {
        printOS("Symlink does not exist at \(symlinkPath). No action needed.")
        return
    }

    // Create AppleScript commands for installing or uninstalling the symlink
    let script: String

    if install {
        // AppleScript to create a symlink with admin privileges
        script = """
        do shell script "ln -s '\(appPath)' '\(symlinkPath)'" with administrator privileges
        """
    } else {
        // AppleScript to remove the symlink with admin privileges
        script = """
        do shell script "rm '\(symlinkPath)'" with administrator privileges
        """
    }

    updateOnMain {
        // Execute the AppleScript
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)

            if let error = error {
                printOS("AppleScript Error: \(error)")
            } else {
                if install {
                    printOS("Symlink created successfully at \(symlinkPath).")
                } else {
                    printOS("Symlink removed successfully from \(symlinkPath).")
                }
            }
        } else {
            printOS("Error: Unable to create the AppleScript object.")
        }
    }

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
func caskCleanup(app: String) {
    Task(priority: .high) {

#if arch(x86_64)
        let cmd = "/usr/local/bin/brew"
#elseif arch(arm64)
        let cmd = "/opt/homebrew/bin/brew"
#endif

        if let formattedApp = getCaskIdentifier(for: app) {
            // App found, proceed with cleanup
            let script = """
            tell application "Terminal"
                activate
                do script "/bin/bash --noprofile --norc -c '
                clear;
                echo \\"[Pearcleaner] Homebrew cleanup for \(app):\n\\";
                \(cmd) uninstall --cask \(formattedApp) --force;
                \(cmd) cleanup;
                killall Terminal;
                '" in front window
            end tell
            """

            updateOnMain {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&error)
                }

                if let error = error {
                    printOS("AppleScript Error: \(error)")
                }
            }

        } else {
            printOS("Brew cleanup: No cask found for \(app).")
        }
    }
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
                let appsInDir = try fileManager.contentsOfDirectory(atPath: appDirectory).filter { !$0.hasPrefix(".") }

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
        print("Error reading cask metadata: \(error)")
    }

    // If no match is found, return nil
    return nil
}


func caskCleanup2(app: String) {
    Task(priority: .high) {
        let formattedApp = app.lowercased().replacingOccurrences(of: " ", with: "-")

#if arch(x86_64)
        let cmd = "/usr/local/bin/brew"
#elseif arch(arm64)
        let cmd = "/opt/homebrew/bin/brew"
#endif

        let script = """
        tell application "Terminal"
            activate
            do script "/bin/bash --noprofile --norc -c '
            found_cask=$(\(cmd) list --cask | grep '\(formattedApp)');
            if [ -n \\"$found_cask\\" ]; then
                clear;
                echo \\"[Pearcleaner] Homebrew cleanup for \(formattedApp):\n\\";
                \(cmd) uninstall --cask \\"$found_cask\\" --force;
                \(cmd) cleanup;
                killall Terminal;
            else
                clear;
                echo \\"[Pearcleaner] \(formattedApp) cask not found for homebrew cleanup!\nClosing window in 5 seconds..\\";
                sleep 5;
                killall Terminal;
            fi'" in front window
        end tell
        """
        updateOnMain {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }

            if let error = error {
                print("AppleScript Error: \(error)")
            }
        }

    }
}


// Print list of files locally
func saveURLsToFile(urls: Set<URL>, appState: AppState, copy: Bool = false) {

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


// Open trash folder
func openTrash() {
    if let trashURL = try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
        NSWorkspace.shared.open(trashURL)
    }
}

// Check if restricted app
func isRestricted(atPath path: URL) -> Bool {
    if path.path.contains("Safari") || path.path.contains(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "") || path.path.contains("/Applications/Utilities") {
        return true
    } else {
        return false
    }
}


// Check app bundle architecture
func checkAppBundleArchitecture(at appBundlePath: String) -> Arch {
    let bundleURL = URL(fileURLWithPath: appBundlePath)
    let executableName: String

    // Extract the executable name from Info.plist
    let infoPlistPath = bundleURL.appendingPathComponent("Contents/Info.plist")
    if let infoPlist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any],
       let bundleExecutable = infoPlist["CFBundleExecutable"] as? String {
        executableName = bundleExecutable
    } else {
        printOS("Failed to read Info.plist or CFBundleExecutable not found when checking bundle architecture")
        return .empty
    }

    let executablePath = bundleURL.appendingPathComponent("Contents/MacOS/\(executableName)").path

    let task = Process()
    task.launchPath = "/usr/bin/file"
    task.arguments = [executablePath]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()

    if let output = String(data: data, encoding: .utf8) {

        if output.contains("Mach-O universal binary") {
            return .universal
        } else if output.contains("arm64") {
            return .arm
        } else if output.contains("x86_64") {
            return .intel
        }
    }

    return .empty
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

// Remove app from cache
func removeApp(appState: AppState, withPath path: URL) {
    @AppStorage("settings.general.brew") var brew: Bool = false
    DispatchQueue.main.async {

        // Remove from sortedApps if found
        if let index = appState.sortedApps.firstIndex(where: { $0.path == path }) {
            appState.sortedApps.remove(at: index)
//            return // Exit the function if the app was found and removed
        }

        // Brew cleanup if enabled
        if brew {
            caskCleanup(app: appState.appInfo.appName)
        }

        appState.appInfo = AppInfo.empty

    }
}


// Check if file/folder name has localized variant
func showLocalized(url: URL) -> String {
    guard FileManager.default.fileExists(atPath: url.path) else {
        return url.lastPathComponent
    }
    do {
        // Retrieve the localized name
        let resourceValues = try url.resourceValues(forKeys: [.localizedNameKey])
        if let localizedName = resourceValues.localizedName {
            return localizedName
        }
    } catch {
        printOS("Error retrieving localized name: \(error)")
    }
    // Return the last path component as a fallback
    return url.lastPathComponent
}

extension URL {
    func localizedName() -> String {
        do {
            let resourceValues = try self.resourceValues(forKeys: [.localizedNameKey])
            return resourceValues.localizedName?.replacingOccurrences(of: ".app", with: "") ?? self.lastPathComponent.replacingOccurrences(of: ".app", with: "")
        } catch {
            print("Error getting localized name: \(error)")
            return self.lastPathComponent.replacingOccurrences(of: ".app", with: "")
        }
    }
}

extension String {
    func localizedName() -> String {
        let url = URL(fileURLWithPath: self)
        do {
            let resourceValues = try url.resourceValues(forKeys: [.localizedNameKey])
            return resourceValues.localizedName?.replacingOccurrences(of: ".app", with: "") ?? self
        } catch {
            print("Error getting localized name: \(error)")
            return self
        }
    }
}

extension URL {
    /// Returns the bundle name of the container by its UUID if found.
    func containerNameByUUID() -> String {
        // Extract the last path component, which should be the UUID
        let uuid = self.lastPathComponent

        // Ensure the UUID matches the expected pattern.
        let uuidRegex = try! NSRegularExpression(
            pattern: "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$",
            options: .caseInsensitive
        )
        let range = NSRange(location: 0, length: uuid.utf16.count)
        guard uuidRegex.firstMatch(in: uuid, options: [], range: range) != nil else {
//            print("The URL does not point to a valid UUID container.")
            return ""
        }

        // Path to the Containers directory.
        let containersPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers")

        do {
            // List all directories in the Containers folder.
            let containerDirectories = try FileManager.default.contentsOfDirectory(
                at: containersPath,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            // Iterate over each directory to find a match with the UUID.
            for directory in containerDirectories {
                let directoryName = directory.lastPathComponent

                if directoryName == uuid {
                    // Attempt to read the metadata plist file.
                    let metadataPlistURL = directory.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")

                    if let metadataDict = NSDictionary(contentsOf: metadataPlistURL),
                       let applicationBundleID = metadataDict["MCMMetadataIdentifier"] as? String {
                        return applicationBundleID
                    }
                }
            }
        } catch {
            print("Error accessing the Containers directory: \(error)")
        }

        // Return nil if no matching UUID is found.
        return ""
    }
}

// Removes the sidebar toggle button from the toolbar, if running on macOS 14.0 or newer.
extension View {
    @ViewBuilder
    func removeSidebarToggle() -> some View {
        if #available(macOS 14.0, *) {
            self.toolbar(removing: .sidebarToggle)
        } else {
            self
        }
    }
}

// Drag window by background
extension View {
    // Helper function to apply the movable background window
    func movableByWindowBackground() -> some View {
        self.background(MovableWindowAccessor())
    }
}

// Custom NSWindow accessor to modify window properties
struct MovableWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()

        DispatchQueue.main.async {
            if let window = nsView.window {
                // Enable dragging by the window's background
                window.isMovableByWindowBackground = true
            }
        }

        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}


// Return image for different folders
func folderImages(for path: String) -> AnyView? {
    if path.contains("/Library/Containers/") || path.contains("/Library/Group Containers/") {
        return AnyView(
            Image(systemName: "shippingbox.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 13)
                .foregroundStyle(.primary.opacity(0.5))
                .help("Container")
        )
    } else if path.contains("/Library/Application Scripts/") {
        return AnyView(
            Image(systemName: "applescript.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 13)
                .foregroundStyle(.primary.opacity(0.5))
                .help("Application Script")
        )
    } else if path.contains(".plist") {
        return AnyView(
            Image(systemName: "doc.badge.gearshape.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 13)
                .foregroundStyle(.primary.opacity(0.5))
                .help("Plist File")
        )
    }

    // Return nil if no conditions are met
    return nil
}


// Check if app bundle is nested
func isNested(path: URL) -> Bool {
    let applicationsPath = "/Applications"
    let homeApplicationsPath = "\(home)/Applications"

    guard path.path.contains("Applications") else {
        return false
    }
    
    // Get the parent directory of the app
    let parentDirectory = path.deletingLastPathComponent().path

    // Check if the parent directory is not directly /Applications or ~/Applications
    return parentDirectory != applicationsPath && parentDirectory != homeApplicationsPath
}


// Date formatter for metadata
func formattedMDDate(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm zzz"
    formatter.timeZone = .current // Use the current timezone
    return formatter.string(from: date)
}



// --- Extend String to remove periods, spaces and lowercase the string
extension String {
    func pearFormat() -> String {
        // Remove all non-alphanumeric characters using regular expression and convert to lowercase
        return self.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
    }
}


// --- Returns comma separated string as array of strings
extension String {
    func toConditionFormat() -> [String] {
        if self.isEmpty {
            return []
        }
        return self.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
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
        let posixFiles = selectedItemsArray.map { item in
            return "POSIX file \"\(item.path)\"" + (item == selectedItemsArray.last ? "" : ", ")}.joined()
        let scriptSource = """
        tell application \"Finder\" to delete { \(posixFiles) }
        """
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 1; osascript -e '\(scriptSource)'"]
        task.launch()
        exit(0)
    }).findPaths()
}


// --- Load Plist file with launchctl ---
func launchctl(load: Bool, completion: @escaping () -> Void = {}) {
    let cmd = load ? "load" : "unload"

    if let plistPath = Bundle.main.path(forResource: "com.alienator88.PearcleanerSentinel", ofType: "plist") {
        var plistContent = try! String(contentsOfFile: plistPath)
        let executableURL = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/PearcleanerSentinel")

        // Replace the placeholder with the actual executable path
        plistContent = plistContent.replacingOccurrences(of: "__EXECUTABLE_PATH__", with: executableURL.path)

        // Create a temporary plist file with the updated content
        let temporaryPlistURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.alienator88.PearcleanerSentinel.plist")

        do {
            try plistContent.write(to: temporaryPlistURL, atomically: true, encoding: .utf8)
        } catch {
            printOS("Error writing the temporary plist file: \(error)")
            return
        }

        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = [cmd, "-w", temporaryPlistURL.path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.launch()

        completion()
    }
}


func sendStartNotificationFW() {
    DistributedNotificationCenter.default().postNotificationName(Notification.Name("Pearcleaner.StartFileWatcher"), object: nil, userInfo: nil, deliverImmediately: true)
}

func sendStopNotificationFW() {
    DistributedNotificationCenter.default().postNotificationName(Notification.Name("Pearcleaner.StopFileWatcher"), object: nil, userInfo: nil, deliverImmediately: true)
}
