//
//  Utilities.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/3/23.
//

import Foundation
import SwiftUI
import OSLog
import CoreImage
import AppKit

// Make updates on main thread
func updateOnMain(after delay: Double? = nil, _ updates: @escaping () -> Void) {
    if let delay = delay {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            updates()
        }
    } else {
        DispatchQueue.main.async {
            updates()
        }
    }
}


// Execute functions on background thread
func updateOnBackground(_ updates: @escaping () -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        updates()
    }
}

// Reload apps list
func reloadAppsList(appState: AppState, fsm: FolderSettingsManager) {
    appState.reload = true
    updateOnBackground {
        let sortedApps = getSortedApps(paths: fsm.folderPaths, appState: appState)
        // Update UI on the main thread
        updateOnMain {
            appState.sortedApps = sortedApps
            appState.reload = false
        }
    }
}



func resizeWindowAuto(windowSettings: WindowSettings, title: String) {
    if let window = NSApplication.shared.windows.first(where: { $0.title == title }) {
        let newSize = NSSize(width: windowSettings.loadWindowSettings().width, height: windowSettings.loadWindowSettings().height)
        window.setContentSize(newSize)
    }
}



// Check app directory based on user permission
func checkAppDirectoryAndUserRole(completion: @escaping ((isInCorrectDirectory: Bool, isAdmin: Bool)) -> Void) {
    isCurrentUserAdmin { isAdmin in
        let bundlePath = Bundle.main.bundlePath as NSString
        let applicationsDir = "/Applications"
        let userApplicationsDir = "\(home)/Applications"

        var isInCorrectDirectory = false

        if isAdmin {
            // Admins can have the app in either /Applications or ~/Applications
            isInCorrectDirectory = bundlePath.deletingLastPathComponent == applicationsDir ||
            bundlePath.deletingLastPathComponent == userApplicationsDir
        } else {
            // Standard users should only have the app in ~/Applications
            isInCorrectDirectory = bundlePath.deletingLastPathComponent == userApplicationsDir
        }

        // Return both conditions: if the app is in the correct directory and if the user is an admin
        completion((isInCorrectDirectory, isAdmin))
    }
}


// Check if user is admin or standard user
func isCurrentUserAdmin(completion: @escaping (Bool) -> Void) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh") // Using zsh, macOS default shell
    process.arguments = ["-c", "groups $(whoami) | grep -q ' admin '"]

    process.terminationHandler = { process in
        // On macOS, a process's exit status of 0 indicates success (admin group found in this context)
        completion(process.terminationStatus == 0)
    }

    do {
        try process.run()
    } catch {
        print("Failed to execute command: \(error)")
        completion(false)
    }
}

// Check if appearance is dark mode
func isDarkMode() -> Bool {
    return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
}

// Set app color mode
func setAppearance(mode: NSAppearance.Name) {
    NSApp.appearance = NSAppearance(named: mode)
}

// Check if Pearcleaner has any windows open
func hasWindowOpen() -> Bool {
    for window in NSApp.windows where window.title == "Pearcleaner" {
        return true
    }
    return false
}

// Find and hide/show main app window when using menubar item
func findAndHideWindows(named titles: [String]) {
    for title in titles {
        if let window = NSApp.windows.first(where: { $0.title == title }) {
            window.close()
        }
    }
}

func findAndSetWindowFrame(named titles: [String], windowSettings: WindowSettings) {
    windowSettings.registerDefaultWindowSettings() {
        for title in titles {
            if let window = NSApp.windows.first(where: { $0.title == title }) {
                window.isRestorable = false
                let frame = windowSettings.loadWindowSettings()
                window.setFrame(frame, display: true)
            }
        }
    }
}


func findAndShowWindows(named titles: [String]) {
    for title in titles {
        if let window = NSApp.windows.first(where: { $0.title == title }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// Copy to clipboard
func copyToClipboard(text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}




// Brew cleanup
func caskCleanup(app: String) {
    Task(priority: .high) {
        let process = Process()
#if arch(x86_64)
        let cmd = "/usr/local/bin/brew"
#elseif arch(arm64)
        let cmd = "/opt/homebrew/bin/brew"
#endif
        let formattedApp = app.lowercased().replacingOccurrences(of: " ", with: "-")
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
//        process.arguments = ["-c", "\(cmd) uninstall --cask \"\(formattedApp)\" --force; \(cmd) cleanup"]
        process.arguments = ["-c", """
        found_cask=$(\(cmd) list --cask | grep "\(formattedApp)")
        if [ -n "$found_cask" ]; then
            \(cmd) uninstall --cask "$found_cask" --force;
            \(cmd) cleanup;
        else
            echo "Cask not found for \(formattedApp)";
        fi
        """]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit() // Ensure the process completes
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = (String(data: data, encoding: .utf8) ?? "") as String
        printOS(output)
    }
}


// Print list of files locally
func saveURLsToFile(urls: Set<URL>, appState: AppState) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Select Folder"

    if panel.runModal() == .OK, let selectedFolder = panel.url {
        let filePath = selectedFolder.appendingPathComponent("Export-\(appState.appInfo.appName)(v\(appState.appInfo.appVersion)).txt")
        var fileContent = ""
        var count = 1
        let sortedUrls = urls.sorted { $0.path < $1.path }

        for url in sortedUrls {
            fileContent += "[\(count)] - \(url.path)\n"
            count += 1
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


// Check if symlink
func isSymlink(atPath path: URL) -> Bool {
    do {
        let _ = try path.checkResourceIsReachable()
        let resourceValues = try path.resourceValues(forKeys: [.isSymbolicLinkKey])
        return resourceValues.isSymbolicLink == true
    } catch {
        return false
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



// Convert icon to png so colors render correctly
func convertICNSToPNG(icon: NSImage, size: NSSize) -> NSImage? {
    // Resize the icon to the specified size
    let resizedIcon = NSImage(size: size)
    resizedIcon.lockFocus()
    icon.draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
    resizedIcon.unlockFocus()
    
    // Convert the resized icon to PNG format
    if let resizedImageData = resizedIcon.tiffRepresentation,
       let resizedBitmap = NSBitmapImageRep(data: resizedImageData),
       let pngData = resizedBitmap.representation(using: .png, properties: [:]) {
        return NSImage(data: pngData)
    }
    
    return nil
}

// Get icon for files and folders
func getIconForFileOrFolder(atPath path: URL) -> Image? {
    return Image(nsImage: NSWorkspace.shared.icon(forFile: path.path))
}

func getIconForFileOrFolderNS(atPath path: URL) -> NSImage? {
    return NSWorkspace.shared.icon(forFile: path.path)
}


// Get average color from image
extension NSImage {
    var averageColor: NSColor? {
        guard let tiffData = self.tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffData), let inputImage = CIImage(bitmapImageRep: bitmapImage) else { return nil }

        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: CIFormat.RGBA8, colorSpace: nil)

        return NSColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
}

func startEnd(_ function: @escaping () -> Void) {
    let startTime = Date() // Capture start time
    function()
    let endTime = Date()
    let executionTime = endTime.timeIntervalSince(startTime)
    printOS("Function executed in: \n\(executionTime) seconds")
}


// Relaunch app
func relaunchApp(afterDelay seconds: TimeInterval = 0.5) -> Never {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", "sleep \(seconds); open \"\(Bundle.main.bundlePath)\""]
    task.launch()
    
    NSApp.terminate(nil)
    exit(0)
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
        // Remove from appInfoStore if found
        if let index = appState.appInfoStore.firstIndex(where: { $0.path == path }) {
            appState.appInfoStore.remove(at: index)
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

// Return image for different folders
func folderImages(for path: String) -> AnyView? {
    if path.contains("/Library/Containers/") || path.contains("/Library/Group Containers/") {
        return AnyView(
            Image(systemName: "shippingbox.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 13)
                .foregroundStyle(Color("mode").opacity(0.5))
                .help("Container")
        )
    } else if path.contains("/Library/Application Scripts/") {
        return AnyView(
            Image(systemName: "applescript.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 13)
                .foregroundStyle(Color("mode").opacity(0.5))
                .help("Application Script")
        )
    } else if path.contains(".plist") {
        return AnyView(
            Image(systemName: "doc.badge.gearshape.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 13)
                .foregroundStyle(Color("mode").opacity(0.5))
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



// --- Extend Int to convert hours to seconds ---
extension Int {
    var daysToSeconds: Double {
        return Double(self) * 24 * 60 * 60
    }
}


// --- Extend String to remove periods, spaces and lowercase the string
extension String {
    func pearFormat() -> String {
        // Remove all non-alphanumeric characters using regular expression and convert to lowercase
        return self.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
    }
}

// --- Extend string to replace - and | with custom characters
extension String {
    func featureFormat() -> String {
        return self.replacingOccurrences(of: "- ", with: "• ").replacingOccurrences(of: "|", with: "\n\n")
    }
}

// --- Capitalize first letter of string only
extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
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


// --- Overload the greater than operator ">" to do a semantic check on the string versions
extension String {
    func versionStringToTuple() -> (Int, Int, Int) {
        let components = self.split(separator: ".").compactMap { Int($0) }
        return (components[0], components[1], components[2])
    }

    static func > (lhs: String, rhs: String) -> Bool {
        let lhsVersion = lhs.versionStringToTuple()
        let rhsVersion = rhs.versionStringToTuple()
        return lhsVersion > rhsVersion
    }
}


// --- Trash Relationship ---
//extension FileManager {
//    public func isInTrash(_ file: URL) -> Bool {
//        var relationship: URLRelationship = .other
//        try? getRelationship(&relationship, of: .trashDirectory, in: .userDomainMask, toItemAt: file)
//        return relationship == .contains
//    }
//}

// --- Extend print command to also output to the Console ---
func printOS(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { "\($0)" }.joined(separator: separator)
    let log = OSLog(subsystem: "pearcleaner", category: "Application")
    os_log("%@", log: log, type: .default, message)

}


// Get size of files
func totalSizeOnDisk(for paths: [URL]) -> (real: Int64, logical: Int64) {
    let fileManager = FileManager.default
    var totalAllocatedSize: Int64 = 0
    var totalFileSize: Int64 = 0

    for url in paths {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileSizeKey]
            if isDirectory.boolValue {
                // It's a directory, recurse into it
                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, errorHandler: nil) {
                    for case let fileURL as URL in enumerator {
                        do {
                            let fileAttributes = try fileURL.resourceValues(forKeys: Set(keys))
                            if let allocatedSize = fileAttributes.totalFileAllocatedSize {
                                totalAllocatedSize += Int64(allocatedSize)
                            }
                            if let fileSize = fileAttributes.fileSize {
                                totalFileSize += Int64(fileSize)
                            }
                        } catch {
                            print("Error getting file attributes for \(fileURL): \(error)")
                        }
                    }
                }
            } else {
                // It's a file
                do {
                    let fileAttributes = try url.resourceValues(forKeys: Set(keys))
                    if let allocatedSize = fileAttributes.totalFileAllocatedSize {
                        totalAllocatedSize += Int64(allocatedSize)
                    }
                    if let fileSize = fileAttributes.fileSize {
                        totalFileSize += Int64(fileSize)
                    }
                } catch {
                    print("Error getting file attributes for \(url): \(error)")
                }
            }
        }
    }

    return (real: totalAllocatedSize, logical: totalFileSize)
}



func totalSizeOnDisk(for path: URL) -> (real: Int64, logical: Int64) {
    return totalSizeOnDisk(for: [path])
}

// ByteFormatter
func formatByte(size: Int64) -> (human: String, byte: String) {
    let byteCountFormatter = ByteCountFormatter()
    byteCountFormatter.countStyle = .file
    byteCountFormatter.allowedUnits = [.useAll]
    let human = byteCountFormatter.string(fromByteCount: size)

    let numberformatter = NumberFormatter()
    numberformatter.numberStyle = .decimal
    let formattedNumber = numberformatter.string(from: NSNumber(value: size)) ?? "\(size)"
    let byte = "\(formattedNumber)"

    return (human: human, byte: byte)

}


// Only process supported files
func isSupportedFileType(at path: String) -> Bool {
    let fileManager = FileManager.default
    do {
        let attributes = try fileManager.attributesOfItem(atPath: path)
        if let fileType = attributes[FileAttributeKey.type] as? FileAttributeType {
            switch fileType {
            case .typeRegular, .typeDirectory, .typeSymbolicLink:
                // The file is a regular file, directory, or symbolic link
                return true
            default:
                // The file is a socket, pipe, or another type not supported
                return false
            }
        }
    } catch {
        printOS("Error getting file attributes: \(error)")
    }
    return false
}




// --- Pearcleaner Uninstall --
func uninstallPearcleaner(appState: AppState, locations: Locations) {
    
    // Unload Sentinel Monitor if running
    launchctl(load: false)

    // Get app info for Pearcleaner
    let appInfo = AppInfoFetcher.getAppInfo(atPath: Bundle.main.bundleURL)

    // Find application files for Pearcleaner
    AppPathFinder(appInfo: appInfo!, appState: appState, locations: locations, completion: {
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



// --- Create Application Support folder if it doesn't exist ---
func ensureApplicationSupportFolderExists(appState: AppState) {
    let fileManager = FileManager.default
    let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("com.alienator88.Pearcleaner")

    // Check to make sure Application Support/Pearcleaner folder exists
    if !fileManager.fileExists(atPath: supportURL.path) {
        try! fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
        printOS("Created Application Support/com.alienator88.Pearcleaner folder")
    }
}


// --- Write Log to File for troubleshooting ---
func writeLog(string: String) {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser.path
    let logFilePath = "\(home)/Downloads/log.txt"
    
    // Check if the log file exists, and create it if it doesn't
    if !fileManager.fileExists(atPath: logFilePath) {
        if !fileManager.createFile(atPath: logFilePath, contents: nil, attributes: nil) {
            printOS("Failed to create the log file.")
            return
        }
    }
    
    do {
        if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
            let ns = "\(string)\n"
            fileHandle.seekToEndOfFile()
            fileHandle.write(ns.data(using: .utf8)!)
            fileHandle.closeFile()
        } else {
            printOS("Error opening file for appending")
        }
    }
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


func getCurrentTimestamp() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return dateFormatter.string(from: Date())
}


func formattedDate(_ date: Date?) -> String {
    guard let date = date else { return "N/A" }
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter.string(from: date)
}



