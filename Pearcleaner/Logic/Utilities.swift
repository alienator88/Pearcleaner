//
//  Utilities.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/3/23.
//

import Foundation
import SwiftUI

// Make updates on main thread
func updateOnMain(_ updates: @escaping () -> Void) {
    DispatchQueue.main.async {
        updates()
    }
}


// Execute functions on background thread
func updateOnBackground(_ updates: @escaping () -> Void) {
    DispatchQueue.global(qos: .background).async {
        updates()
    }
}


// Resize window
func resizeWindow(width: CGFloat, height: CGFloat) {
    if let window = NSApplication.shared.windows.first {
        let newSize = NSSize(width: width, height: height)
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
    
//    let data = pipe.fileHandleForReading.readDataToEndOfFile()
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

    let process = Process()
    process.launchPath = "/usr/bin/sqlite3"
    process.arguments = ["/Library/Application Support/com.apple.TCC/TCC.db", "select client from access where auth_value and service = \"kTCCServiceSystemPolicyAllFiles\" and client = \"com.alienator88.Pearcleaner\""]
    
    let pipe = Pipe()
    let pipeErr = Pipe()
    process.standardOutput = pipe
    process.standardError = pipeErr
    process.launch()
    
    //    let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
//            appState.alertType = .diskAccess
//            appState.showAlert = true
        }
        
        return false
    }
    
    
//    let fileURL = URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db")
//    
//    let accessStatus = FileManager.default.isReadableFile(atPath: fileURL.path)
//    print(accessStatus)
//    if accessStatus {
//        diskP = true
//        _ = checkAndRequestAccessibilityAccess(appState: appState)
//        
//        return true
//    } else {
//        diskP = false
//        if !skipAlert {
//            appState.alertType = .diskAccess
//            appState.showAlert = true
//        }
//        
//        return false
//    }
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
    if path.path.contains("Safari") || path.path.contains(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "") {
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


// Relaunch app
func relaunchApp(afterDelay seconds: TimeInterval = 0.5) -> Never {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", "sleep \(seconds); open \"\(Bundle.main.bundlePath)\""]
    task.launch()
    
    NSApp.terminate(nil)
    exit(0)
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
        return self.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "").lowercased()
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


// --- Gradient ---
func schemeGradient(for colorScheme: ColorScheme) -> LinearGradient {
    return LinearGradient(gradient: Gradient(colors: [.pink, .orange]), startPoint: .leading, endPoint: .trailing)
//    switch colorScheme {
//    case .light:
//        return LinearGradient(gradient: Gradient(colors: [Color("AccentColor")]), startPoint: .leading, endPoint: .trailing)
//    case .dark:
//        return LinearGradient(gradient: Gradient(colors: [.pink, .orange]), startPoint: .leading, endPoint: .trailing)
//    @unknown default:
//        return LinearGradient(gradient: Gradient(colors: [Color("AccentColor")]), startPoint: .leading, endPoint: .trailing)
//    }
}



// Get total size of folders and files using DU cli command
func totalSizeOnDisk(for paths: [URL]) -> String? {
    var totalSize = 0
    
    let process = Process()
    process.launchPath = "/usr/bin/du"
    process.arguments = ["-sk"] + paths.map { (url: URL) -> String in
        return url.path
    }
    let pipe = Pipe()
    process.standardOutput = pipe
    
    try? process.run()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let components = line.components(separatedBy: "\t")
            if let sizeString = components.first, let size = Int(sizeString) {
                totalSize += size * 1024  // Convert the size from kilobytes to bytes
            }
        }
    }
    
    let byteCountFormatter = ByteCountFormatter()
    byteCountFormatter.countStyle = .file
    byteCountFormatter.allowedUnits = [.useAll]
    return byteCountFormatter.string(fromByteCount: Int64(totalSize))
}

func totalSizeOnDisk(for path: URL) -> String? {
    return totalSizeOnDisk(for: [path])
}


// Get total size of folders and files using straight swift
extension URL {
    func totalAllocatedSize(includingSubfolders: Bool = false) throws -> Int? {
        return try [self].totalAllocatedSize(includingSubfolders: includingSubfolders)
    }
    
    func totalSizeOnDisk(includingSubfolders: Bool = false) throws -> String? {
        return try [self].totalSizeOnDisk(includingSubfolders: includingSubfolders)
    }
}

extension Array where Element == URL {
    func totalAllocatedSize(includingSubfolders: Bool = false) throws -> Int? {
        var totalSize = 0
        
        for path in self {
//            if path.absoluteString.contains(".app") {
                let resourceValues = try path.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .totalFileAllocatedSizeKey])

            if resourceValues.isDirectory == true || path.pathExtension == "app" {
                    if includingSubfolders {
                        let filePaths = FileManager.default.subpaths(atPath: path.path) ?? []
                        for filePath in filePaths {
                            let fileUrl = path.appendingPathComponent(filePath)
                            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileUrl.path)
                            let fileSize = fileAttributes[.size] as? Int64 ?? 0
                            totalSize += Int(fileSize)
                        }
                    }
                } else {
                    totalSize += resourceValues.totalFileAllocatedSize ?? 0
                }
//            }
            
        }
        
        return totalSize
    }
    
    func totalSizeOnDisk(includingSubfolders: Bool = false) throws -> String? {
        if let totalSize = try self.totalAllocatedSize(includingSubfolders: includingSubfolders) {
            let byteCountFormatter = ByteCountFormatter()
            byteCountFormatter.countStyle = .file
            byteCountFormatter.allowedUnits = [.useBytes, .useKB, .useMB, .useTB]
            return byteCountFormatter.string(fromByteCount: Int64(totalSize))
        }
        return nil
    }
}


// Alerts
func presentAlert(appState: AppState) -> Alert {

    switch appState.alertType {
    case .update:
        return Alert(title: Text("Update Available 🥳"), message: Text("You may choose to install the update now, otherwise you may check again later from Settings"), primaryButton: .default(Text("Install")) {
            downloadUpdate(appState: appState)
//            launchUpdate()
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



// --- Create Application Support folder if it doesn't exist ---
func ensureApplicationSupportFolderExists(appState: AppState) {
    let fileManager = FileManager.default
    let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Pearcleaner")
    
    // Check to make sure Application Support/Support Admin folder exists
    if !fileManager.fileExists(atPath: supportURL.path) {
        try! fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
        print("Created Application Support/Pearcleaner folder")
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
            print("Failed to create the log file.")
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
            print("Error opening file for appending")
        }
    }
}


// --- Load Plist file with launchctl ---
func launchctl(load: Bool) {
    let cmd = load ? "load" : "unload"
    if let plistPath = Bundle.main.path(forResource: "com.alienator88.PearcleanerSentinel", ofType: "plist") {
        var plistContent = try! String(contentsOfFile: plistPath)
        let executableURL = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/PearcleanerSentinel")
        
        // Replace the placeholder with the actual executable path
        plistContent = plistContent.replacingOccurrences(of: "__EXECUTABLE_PATH__", with: executableURL.path)
        
        // Create a temporary plist file with the updated content
        let temporaryPlistURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.alienator88.PearcleanerSentinel.plist")
        
        do {
            try plistContent.write(to: temporaryPlistURL, atomically: false, encoding: .utf8)
        } catch {
            print("Error writing the temporary plist file: \(error)")
            return
        }
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = [cmd, "-w", temporaryPlistURL.path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        task.launch()
        
//        let data = pipe.fileHandleForReading.readDataToEndOfFile()
//        if let output = String(data: data, encoding: .utf8) {
//            print("Output: \(output)")
//        }
    }
}

//func unloadAgent() {
//    if let plistPath = Bundle.main.path(forResource: "com.alienator88.PearcleanerMonitor", ofType: "plist") {
//        var plistContent = try! String(contentsOfFile: plistPath)
//        let executableURL = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/PearcleanerMonitor")
//        
//        // Replace the placeholder with the actual executable path
//        plistContent = plistContent.replacingOccurrences(of: "__EXECUTABLE_PATH__", with: executableURL.path)
//        
//        // Create a temporary plist file with the updated content
//        let temporaryPlistURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.alienator88.PearcleanerMonitor.plist")
//        
//        do {
//            try plistContent.write(to: temporaryPlistURL, atomically: false, encoding: .utf8)
//        } catch {
//            print("Error writing the temporary plist file: \(error)")
//            return
//        }
//        let task = Process()
//        task.launchPath = "/bin/launchctl"
//        task.arguments = ["unload", "-w", temporaryPlistURL.path]
//        
//        let pipe = Pipe()
//        task.standardOutput = pipe
//        task.standardError = pipe
//        
//        task.launch()
//        
////        let data = pipe.fileHandleForReading.readDataToEndOfFile()
////        if let output = String(data: data, encoding: .utf8) {
////            print("Output: \(output)")
////        }
//    }
//}













//import FileWatcher
//
//// MARK: https://github.com/eonist/FileWatcher
//
//func fileW() {
//    let filewatcher = FileWatcher([NSString(string: "~/.Trash").expandingTildeInPath])
//    filewatcher.queue = DispatchQueue.global()
//    filewatcher.callback = { event in
//        print("Something happened here: " + event.path)
//    }
//
//    filewatcher.start()
//}



//extension Array where Element == URL {
//    // DU shell way of getting sizes
//    func totalAllocatedSize2(includingSubfolders: Bool = false) throws -> Int? {
//        var totalSize = 0
//        
//        for path in self {
//            let process = Process()
//            process.launchPath = "/usr/bin/du"
//            process.arguments = ["-sk", path.path]
//            
//            let pipe = Pipe()
//            process.standardOutput = pipe
//            
//            try process.run()
//            process.waitUntilExit()
//            
//            let data = pipe.fileHandleForReading.readDataToEndOfFile()
//            if let output = String(data: data, encoding: .utf8) {
//                let sizeString = output.components(separatedBy: "\t").first ?? ""
//                if let size = Int(sizeString) {
//                    totalSize += size * 1024
//                }
//            }
//        }
//        return totalSize
//    }
//    
//        func totalAllocatedSize(includingSubfolders: Bool = false) throws -> Int? {
//            var totalSize = 0
//    
//            for path in self {
//                if includingSubfolders {
//                    guard
//                        let urls = FileManager.default.enumerator(at: path, includingPropertiesForKeys: nil)?.allObjects as? [URL] else { return nil }
//                    let pathSize = try urls.lazy.reduce(0) {
//                        (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize ?? 0) + $0
//                    }
//                    totalSize += pathSize
//                } else {
//                    let pathSize = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil).lazy.reduce(0) {
//                        (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
//                            .totalFileAllocatedSize ?? 0) + $0
//                    }
//                    totalSize += pathSize
//                }
//            }
//    
//            return totalSize
//        }
//    
//    func totalSizeOnDisk(includingSubfolders: Bool = false) throws -> String? {
//        if let totalSize = try self.totalAllocatedSize(includingSubfolders: includingSubfolders) {
//            let byteCountFormatter = ByteCountFormatter()
//            byteCountFormatter.countStyle = .file
//            byteCountFormatter.allowedUnits = [.useBytes, .useKB, .useMB, .useTB]
//            return byteCountFormatter.string(fromByteCount: Int64(totalSize))
//        }
//        return nil
//    }
//}







//func isSymbolicLink(atPath path: URL) -> Bool {
////    let fileManager = FileManager.default
//
//    do {
////        let path = "/Applications/Safari.app"
////        let url = URL(fileURLWithPath: path)
//        let destinationPath = path.resolvingSymlinksInPath().path
//        print("The symlink at \(path) points to \(destinationPath)")
//        return true
//    } catch {
//        print("An error occurred: \(error)")
//        return false
//    }
//    return false
////    var isDirectory = false
////    let exists = FileManager.default.fileExists(atPath: path, isDirectory: isDirectory)
////    if exists && isDirectory {
////        do {
////            let _ = try FileManager.default.destinationOfSymbolicLink(atPath: path)
////            return true
////        } catch {
////            return false
////        }
////    }
////    return false
//}
