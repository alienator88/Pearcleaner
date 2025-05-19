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
import AudioToolbox


func resizeWindowAuto(windowSettings: WindowSettings, title: String) {
    if let window = NSApplication.shared.windows.first(where: { $0.title == title }) {
        printOS(windowSettings.loadWindowSettings())
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


func playTrashSound(undo: Bool = false) {
    let soundName = undo ? "poof item off dock.aif" : "drag to trash.aif"
    let path = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/\(soundName)"
    let url = URL(fileURLWithPath: path)

    var soundID: SystemSoundID = 0
    AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
    AudioServicesPlaySystemSound(soundID)
}


// Check if pear symlink exists
func checkCLISymlink() -> Bool {
    let filePath = "/usr/local/bin/pear"
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: filePath) else { return false }

    do {
        let destination = try fileManager.destinationOfSymbolicLink(atPath: filePath)
        return destination == Bundle.main.executablePath
    } catch {
        return false
    }
}

// Fix legacy pearcleaner symlink if it exists
func fixLegacySymlink() {
    let legacyPath = "/usr/local/bin/pearcleaner"
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: legacyPath) {
        manageSymlink(install: false, symlinkName: "pearcleaner")
        manageSymlink(install: true, symlinkName: "pear")
    }
}

// Install/uninstall symlink for CLI
func manageSymlink(install: Bool, symlinkName: String = "pear") {
    @AppStorage("settings.general.cli") var isCLISymlinked = false

    guard let appPath = Bundle.main.executablePath else {
        printOS("Error: Unable to get the executable path.")
        return
    }

    let symlinkPath = "/usr/local/bin/\(symlinkName)"
    let symlinkExists = FileManager.default.fileExists(atPath: symlinkPath)
    let binPathExists = directoryExists(at: "/usr/local/bin")

    if install && symlinkExists {
        printOS("Symlink already exists at \(symlinkPath). No action needed.")
        return
    }

    if !install && !symlinkExists {
        printOS("Symlink does not exist at \(symlinkPath). No action needed.")
        return
    }

    // Prepare privileged commands
    var command = ""

    if install {
        // Create the /usr/local/bin directory if it doesn't exist, then create symlink
        if !binPathExists {
            command += "mkdir -p /usr/local/bin && "
        }
        command += "ln -s '\(appPath)' '\(symlinkPath)'"
    } else {
        // Remove the symlink
        command = "rm '\(symlinkPath)'"
    }

    // Perform privileged commands
    if HelperToolManager.shared.isHelperToolInstalled {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            let _ = await HelperToolManager.shared.runCommand(command)
            semaphore.signal()
        }
        semaphore.wait()
    } else {
        let result = performPrivilegedCommands(commands: command)
        if !result.0 {
            printOS("Symlink failed: \(result.1)")
        }
    }

    updateOnMain {
        isCLISymlinked = checkCLISymlink()
        if install {
            printOS("Symlink created successfully at \(symlinkPath).")
        } else {
            printOS("Symlink removed successfully from \(symlinkPath).")
        }
    }
}

func directoryExists(at path: String) -> Bool {
    let fileManager = FileManager.default
    return fileManager.fileExists(atPath: path, isDirectory: nil)
}





// Open trash folder
func openTrash() {
    if let trashURL = try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
        NSWorkspace.shared.open(trashURL)
    }
}

// Check if restricted app
func isRestricted(atPath path: URL) -> Bool {
    if path.path.contains("/Applications/Safari") || path.path.contains(Bundle.main.name) || path.path.contains("/Applications/Utilities") {
        return true
    } else {
        return false
    }
}


// Check app bundle architecture
func checkAppBundleArchitecture(at appBundlePath: String) -> Arch {
    let bundleURL = URL(fileURLWithPath: appBundlePath)
    let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
    guard let infoDict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any],
          let executableName = infoDict["CFBundleExecutable"] as? String else {
        return .empty
    }
    let executableURL = bundleURL.appendingPathComponent("Contents/MacOS").appendingPathComponent(executableName)
    guard let fileData = try? Data(contentsOf: executableURL) else {
        return .empty
    }

    // Check for fat (universal) binary
    let magic = fileData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    let FAT_MAGIC: UInt32 = 0xcafebabe
    if magic == FAT_MAGIC {
        let numArchs = fileData.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        var offset = 8
        var archs: [Arch] = []
        for _ in 0..<numArchs {
            let archData = fileData.subdata(in: offset..<(offset + 20)).withUnsafeBytes { ptr in
                FatArch(
                    cpuType: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                    cpuSubtype: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian,
                    offset: ptr.load(fromByteOffset: 8, as: UInt32.self).bigEndian,
                    size: ptr.load(fromByteOffset: 12, as: UInt32.self).bigEndian,
                    align: ptr.load(fromByteOffset: 16, as: UInt32.self).bigEndian
                )
            }
            if archData.cpuType == 0x0100000c { archs.append(.arm) }
            else if archData.cpuType == 0x01000007 { archs.append(.intel) }
            offset += 20
        }
        return archs.count == 1 ? archs.first! : .universal
    } else {
        // Lipo binary: read cpu type from header
        guard fileData.count >= 8 else { return .empty }
        let cputype = fileData.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        if cputype == 0x0100000c { return .arm }
        else if cputype == 0x01000007 { return .intel }
        else { return .empty }
    }
}


// Main function that now directly uses the Mach-O helper
func thinAppBundleArchitecture(at appBundlePath: URL, of arch: Arch, multi: Bool = false) -> (Bool, [String: UInt64]?) {
    // Reset bundle size to 0 before starting
    updateOnMain {
        if let index = AppState.shared.sortedApps.firstIndex(where: { $0.path == appBundlePath }) {
            var updatedAppInfo = AppState.shared.sortedApps[index]
            updatedAppInfo.bundleSize = 0
            AppState.shared.sortedApps[index] = updatedAppInfo
        }
    }

    // Skip if already single architecture
    guard arch == .universal else {
        printOS("Lipo: Skipping, app is already single architecture: \(arch)")
        return (false, nil)
    }

    // Extract executable name from Info.plist
    let executableName: String
    let infoPlistPath = appBundlePath.appendingPathComponent("Contents/Info.plist")

    if let infoPlist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any],
       let bundleExecutable = infoPlist["CFBundleExecutable"] as? String {
        executableName = bundleExecutable
    } else {
        printOS("Lipo: Failed to read Info.plist or CFBundleExecutable not found")
        return (false, nil)
    }

    // Get full path to executable
    let executablePath = appBundlePath.appendingPathComponent("Contents/MacOS/\(executableName)").path

    // Get size before lipo (lipo/Mach-O)
    guard let preAttributes = try? FileManager.default.attributesOfItem(atPath: executablePath),
          let preLipoSize = preAttributes[.size] as? UInt64 else {
        printOS("Lipo: Failed to get pre-lipo size for executable at \(executablePath)")
        return (false, nil)
    }

    // Use privileged thinning if helper is installed, otherwise fallback to Mach-O thinning
    var success: Bool
    if HelperToolManager.shared.isHelperToolInstalled {
        let semaphore = DispatchSemaphore(value: 0)
        success = false
        Task {
            let result = await HelperToolManager.shared.runThinning(atPath: executablePath)
            success = result.0
            semaphore.signal()
        }
        semaphore.wait()
    } else {
        success = thinBinaryUsingMachO(executablePath: executablePath)
    }

    // Update the app bundle timestamp to refresh Finder
    if success {
        // Get size after lipo
        guard let postAttributes = try? FileManager.default.attributesOfItem(atPath: executablePath),
              let postLipoSize = postAttributes[.size] as? UInt64 else {
            printOS("Lipo: Failed to get post-lipo size for executable at \(executablePath)")
            return (success, nil)
        }

        if !multi {
            // Update app sizes after lipo in sortedApps array and the AppInfo active object
            AppState.shared.getBundleSize(for: AppState.shared.appInfo) { newSize in
                let newFileSize = totalSizeOnDisk(for: AppState.shared.appInfo.path)
                updateOnMain {
                    // Create a new appInfo instance with updated size values
                    var updatedAppInfo = AppState.shared.appInfo
                    updatedAppInfo.bundleSize = newSize
                    updatedAppInfo.fileSize[AppState.shared.appInfo.path] = newFileSize.real
                    updatedAppInfo.fileSizeLogical[AppState.shared.appInfo.path] = newFileSize.logical
                    updatedAppInfo.arch = isOSArm() ? .arm : .intel
                    // Replace the whole appInfo object
                    AppState.shared.appInfo = updatedAppInfo

                    let savingsPercentage = Int((Double(preLipoSize - postLipoSize) / Double(preLipoSize)) * 100)
                    let title = String(format: NSLocalizedString("Space Savings: %d%%", comment: "Lipo result title"), savingsPercentage)
                    let message = String(format: NSLocalizedString("Lipo'd File:\n\n%@", comment: "Lipo result message"), executablePath)
                    showCustomAlert(title: title, message: message, style: .informational)
                }
            }
        } else { // Update the appInfo in sortedApps array
            let calculatedSize = totalSizeOnDisk(for: appBundlePath).logical
            DispatchQueue.main.async {
                // Update the array
                if let index = AppState.shared.sortedApps.firstIndex(where: { $0.path == appBundlePath }) {
                    var updatedAppInfo = AppState.shared.sortedApps[index]
                    updatedAppInfo.bundleSize = calculatedSize
                    updatedAppInfo.arch = isOSArm() ? .arm : .intel
                    AppState.shared.sortedApps[index] = updatedAppInfo
                }
            }
        }

        return (success, ["pre": preLipoSize, "post": postLipoSize])

    }

    return (success, nil)
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


// Open app settings
func openAppSettings() {
    if #available(macOS 14.0, *) {
        @Environment(\.openSettings) var openSettings
        openSettings()
    } else {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
            printOS("Error getting localized name: \(error)")
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
            printOS("Error getting localized name: \(error)")
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
            //            printOS("The URL does not point to a valid UUID container.")
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
            printOS("Error accessing the Containers directory: \(error)")
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



func sendStartNotificationFW() {
    DistributedNotificationCenter.default().postNotificationName(Notification.Name("Pearcleaner.StartFileWatcher"), object: nil, userInfo: nil, deliverImmediately: true)
}

func sendStopNotificationFW() {
    DistributedNotificationCenter.default().postNotificationName(Notification.Name("Pearcleaner.StopFileWatcher"), object: nil, userInfo: nil, deliverImmediately: true)
}
