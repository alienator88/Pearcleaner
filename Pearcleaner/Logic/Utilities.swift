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
    DispatchQueue.global(qos: .background).async {
        updates()
    }
}


// Resize window
//func resizeWindow(width: CGFloat, height: CGFloat) {
//    if let window = NSApplication.shared.windows.first {
//        let newSize = NSSize(width: width, height: height)
//        window.setContentSize(newSize)
//    }
//}

func resizeWindowAuto(windowSettings: WindowSettings, title: String) {
    if let window = NSApplication.shared.windows.first(where: { $0.title == title }) {
        let newSize = NSSize(width: windowSettings.loadWindowSettings().width, height: windowSettings.loadWindowSettings().height)
        window.setContentSize(newSize)
    }
}


// Check FDA
func checkFullDiskAccessForApp() -> Bool {
    let process = Process()
    process.launchPath = "/usr/bin/sqlite3"
    process.arguments = ["/Library/Application Support/com.apple.TCC/TCC.db", "select client from access where auth_value and service = \"kTCCServiceSystemPolicyAllFiles\" and client = \"com.alienator88.Pearcleaner\""]
    
    let pipe = Pipe()
    let pipeErr = Pipe()
    process.standardOutput = pipe
    process.standardError = pipeErr
    process.launch()
    
    let dataErr = pipeErr.fileHandleForReading.readDataToEndOfFile()

    let output = String(data: dataErr, encoding: .utf8)
    
    // Check if the app is in the results
    if let result = output, result.isEmpty {
        return true
    } else {
        return false
    }
}






// Check for access to Full Disk access
func checkAndRequestFullDiskAccess(appState: AppState, skipAlert: Bool = false) -> Bool {
    @AppStorage("settings.permissions.disk") var diskP: Bool = false
    @AppStorage("settings.permissions.hasLaunched") var hasLaunched: Bool = false

    let process = Process()
    process.launchPath = "/usr/bin/sqlite3"
    process.arguments = ["/Library/Application Support/com.apple.TCC/TCC.db", "select client from access where auth_value and service = \"kTCCServiceSystemPolicyAllFiles\" and client = \"com.alienator88.Pearcleaner\""]
    
    let pipe = Pipe()
    let pipeErr = Pipe()
    process.standardOutput = pipe
    process.standardError = pipeErr
    process.launch()
    
    let dataErr = pipeErr.fileHandleForReading.readDataToEndOfFile()
    
    let output = String(data: dataErr, encoding: .utf8)
    
    // Check if the app is in the results
    if let result = output, result.isEmpty {
        diskP = true
        _ = checkAndRequestAccessibilityAccess(appState: appState)
        return true
    } else {
        diskP = false
        if !skipAlert {
            NewWin.show(appState: appState, width: 500, height: 350, newWin: .perm)
        }
        
        return false
    }

}


// Check for access to System Events
func checkAndRequestAccessibilityAccess(appState: AppState) -> Bool {
    @AppStorage("settings.permissions.events") var diskE: Bool = false

    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let accessEnabled = AXIsProcessTrustedWithOptions(options)
    if accessEnabled {
        diskE = true
        return accessEnabled
    } else {
        diskE = false
        return false

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
func isDarkModeEnabled() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", "defaults read -g AppleInterfaceStyle"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try? process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if !data.isEmpty{
        return true
    } else {
        return false
    }
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
//            window.orderOut(nil)
            window.close()
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


// Check if appearance is dark mode
//func getCasks() -> [String] {
//    let process = Process()
//#if arch(x86_64)
//    let cmd = "/usr/local/bin/brew"
//#elseif arch(arm64)
//    let cmd = "/opt/homebrew/bin/brew"
//#endif
//    process.executableURL = URL(fileURLWithPath: cmd)
//    process.arguments = ["list", "--cask"]
//    let pipe = Pipe()
//    process.standardOutput = pipe
//    process.standardError = pipe
//    try? process.run()
//    process.waitUntilExit() // Ensure the process completes
//    let data = pipe.fileHandleForReading.readDataToEndOfFile()
//    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
//        return output.components(separatedBy: "\n").filter { !$0.isEmpty }.map { $0.replacingOccurrences(of: "-", with: " ") }
//    } else {
//        return []
//    }
//}

// Brew cleanup
func caskCleanup(app: String) {
    Task(priority: .high) {
        let process = Process()
#if arch(x86_64)
        let cmd = "/usr/local/bin/brew"
#elseif arch(arm64)
        let cmd = "/opt/homebrew/bin/brew"
#endif
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "\(cmd) uninstall --cask \(app) --force; \(cmd) cleanup"]
//        let pipe = Pipe()
        process.standardOutput = FileHandle.nullDevice//pipe
        process.standardError = FileHandle.nullDevice//pipe
        try? process.run()
        process.waitUntilExit() // Ensure the process completes
//        let data = pipe.fileHandleForReading.readDataToEndOfFile()
//        let output = (String(data: data, encoding: .utf8) ?? "") as String
//        print(output)
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
    let icon = NSWorkspace.shared.icon(forFile: path.path)
    let nsImage = icon
    return Image(nsImage: nsImage)
}

func getIconForFileOrFolderNS(atPath path: URL) -> NSImage? {
    let icon = NSWorkspace.shared.icon(forFile: path.path)
    let nsImage = icon
    return nsImage
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
func removeApp(appState: AppState, withId id: UUID) {
    DispatchQueue.main.async {
        // Remove from sortedApps if found
        if let index = appState.sortedApps.firstIndex(where: { $0.id == id }) {
            appState.sortedApps.remove(at: index)
            return // Exit the function if the app was found and removed
        }
        // Remove from appInfoStore if found
        if let index = appState.appInfoStore.firstIndex(where: { $0.id == id }) {
            appState.appInfoStore.remove(at: index)
        }
    }
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
        return self.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").lowercased()
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


// --- Trash Relationship ---
extension FileManager {
    public func isInTrash(_ file: URL) -> Bool {
        var relationship: URLRelationship = .other
        try? getRelationship(&relationship, of: .trashDirectory, in: .userDomainMask, toItemAt: file)
        return relationship == .contains
    }
}

// --- Extend print command to also output to the Console ---
func printOS(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { "\($0)" }.joined(separator: separator)
    let log = OSLog(subsystem: "pearcleaner", category: "Application")
    os_log("%@", log: log, type: .default, message)

}



//func totalSizeOnDisk2(for paths: [URL]) -> Int64 {
//    var totalSize = 0
//    
//    let process = Process()
//    process.launchPath = "/usr/bin/du"
//    process.arguments = ["-sk"] + paths.map { (url: URL) -> String in
//        return url.path
//    }
//    let pipe = Pipe()
//    process.standardOutput = pipe
//    process.standardError =  pipe//FileHandle.nullDevice
//
//    try? process.run()
//    process.waitUntilExit()
//    
//    let data = pipe.fileHandleForReading.readDataToEndOfFile()
//    if let output = String(data: data, encoding: .utf8) {
//        let lines = output.components(separatedBy: .newlines)
//        for line in lines {
//            let components = line.components(separatedBy: "\t")
//            if let sizeString = components.first, let size = Int(sizeString) {
//                totalSize += size
//            }
//        }
//    }
//
//    return Int64(totalSize) * 1024 // Convert the size from kilobytes to bytes
//}


// Get total size of folders and files using DU cli command
func totalSizeOnDisk(for paths: [URL]) -> Int64 {
    let fileManager = FileManager.default
    var totalSize: Int64 = 0

    for url in paths {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                // It's a directory, recurse into it
                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], errorHandler: nil) {
                    for case let fileURL as URL in enumerator {
                        do {
                            let fileAttributes = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                            if let fileSize = fileAttributes.totalFileAllocatedSize {
                                totalSize += Int64(fileSize)
                            }
                        } catch {
                            printOS("Error getting file size for \(fileURL): \(error)")
                        }
                    }
                }
            } else {
                // It's a file
                do {
                    let fileAttributes = try url.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                    if let fileSize = fileAttributes.totalFileAllocatedSize {
                        totalSize += Int64(fileSize)
                    }
                } catch {
                    printOS("Error getting file size for \(url): \(error)")
                }
            }
        }
    }

    return totalSize
}

func totalSizeOnDisk(for path: URL) -> Int64 {
    return totalSizeOnDisk(for: [path])
}

// ByteFormatter
func formatByte(size: Int64) -> String {
    let byteCountFormatter = ByteCountFormatter()
    byteCountFormatter.countStyle = .file
    byteCountFormatter.allowedUnits = [.useAll]
    return byteCountFormatter.string(fromByteCount: size)
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


// Alerts
func presentAlert(appState: AppState) -> Alert {

    switch appState.alertType {
    case .update:
        return Alert(title: Text("Update Available 🥳"), message: Text("You may choose to install the update now, otherwise you may check again later from Settings"), primaryButton: .default(Text("Install")) {
            downloadUpdate(appState: appState)
            appState.alertType = .off
        }, secondaryButton: .cancel())
    case .no_update:
        return Alert(title: Text("No Updates 😌"), message: Text("Pearcleaner is on the latest release available"), primaryButton: .cancel(Text("Okay")), secondaryButton: .default(Text("Force Update")) {
            downloadUpdate(appState: appState)
            appState.alertType = .off
        })
    case .diskAccess:
        return Alert(title: Text("Permissions"), message: Text("Pearcleaner requires Full Disk and Accessibility permissions. Drag the app into the Full Disk and Accessibility pane to enable or toggle On if already present."), primaryButton: .default(Text("Allow in Settings")) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
            appState.alertType = .off
        }, secondaryButton: .cancel(Text("Later")))
    case .restartApp:
        return Alert(title: Text("Update Completed!"), message: Text("The application has been updated to the latest version, would you like to restart now?"), primaryButton: .default(Text("Restart")) {
            appState.alertType = .off
            relaunchApp()
        }, secondaryButton: .cancel(Text("Later")))
    case .off:
        return Alert(title: Text(""))
    }
}



// --- Pearcleaner Uninstall --
func uninstallPearcleaner(appState: AppState, locations: Locations) {
    
    // Unload Sentinel Monitor if running
    launchctl(load: false)

    // Get app info for Pearcleaner
    let appInfo = AppInfoFetcher.getAppInfo(atPath: Bundle.main.bundleURL)
//    appState.appInfo = appInfo!

    // Find application files for Pearcleaner
    let pathFinder = AppPathFinder(appInfo: appInfo!, appState: appState, locations: locations)
    pathFinder.findPaths()
//    findPathsForApp(appInfo: appInfo!,appState: appState, locations: locations)

    // Kill Pearcleaner and tell Finder to trash the files
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        let selectedItemsArray = Array(appState.selectedItems).filter { !$0.path.contains(".Trash") }
        let posixFiles = selectedItemsArray.map { "POSIX file \"\($0.path)\", " }.joined().dropLast(3)
        let scriptSource = """
        tell application \"Finder\" to delete { \(posixFiles)" }
        """
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 1; osascript -e '\(scriptSource)'"]
        task.launch()

        NSApp.terminate(nil)
        exit(0)
    }

}



// --- Create Application Support folder if it doesn't exist ---
func ensureApplicationSupportFolderExists(appState: AppState) {
    let fileManager = FileManager.default
    let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Pearcleaner")
    
    // Check to make sure Application Support/Pearcleaner folder exists
    if !fileManager.fileExists(atPath: supportURL.path) {
        try! fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
        printOS("Created Application Support/Pearcleaner folder")
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





func getCurrentTimestamp() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return dateFormatter.string(from: Date())
}




