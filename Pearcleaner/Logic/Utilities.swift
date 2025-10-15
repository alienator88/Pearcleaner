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
import OpenDirectory

func ifOSBelow(macOS major: Int, _ minor: Int = 0, _ patch: Int = 0) -> Bool {
    if !ProcessInfo.processInfo.isOperatingSystemAtLeast(
        OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: patch)
    ) {
        return true
    } else {
        return false
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
    return autoreleasepool {
        let bundleURL = URL(fileURLWithPath: appBundlePath)
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")

        // Read Info.plist in autoreleasepool to release immediately
        let executableName: String? = autoreleasepool {
            guard let infoDict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else {
                return nil
            }
            return infoDict["CFBundleExecutable"] as? String
        }

        guard let execName = executableName else {
            return .empty
        }

        let executableURL = bundleURL.appendingPathComponent("Contents/MacOS").appendingPathComponent(execName)

        // Use FileHandle to read only the header bytes needed for architecture detection
        guard let fileHandle = try? FileHandle(forReadingFrom: executableURL) else {
            return .empty
        }
        defer {
            try? fileHandle.close()
        }

        // Read first 8 bytes for magic and initial header
        guard let headerData = try? fileHandle.read(upToCount: 8), headerData.count >= 4 else {
            return .empty
        }

        // Check for fat (universal) binary
        let magic = headerData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let FAT_MAGIC: UInt32 = 0xcafebabe

        if magic == FAT_MAGIC {
            // Fat binary - read architecture count
            guard headerData.count >= 8 else { return .empty }
            let numArchs = headerData.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            // Read all architecture headers at once (20 bytes each)
            let archHeadersSize = Int(numArchs) * 20
            guard let archHeadersData = try? fileHandle.read(upToCount: archHeadersSize),
                  archHeadersData.count == archHeadersSize else {
                return .empty
            }

            var archs: [Arch] = []
            var offset = 0
            for _ in 0..<numArchs {
                let archData = archHeadersData[offset..<(offset + 20)].withUnsafeBytes { ptr in
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
            // Single architecture Mach-O binary: read cpu type from header
            guard headerData.count >= 8 else { return .empty }

            // Check magic number for 64-bit Mach-O
            let magic = headerData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self) }

            if magic == 0xfeedfacf || magic == 0xcffaedfe {
                // 64-bit Mach-O - read CPU type
                let cputypeLittle = headerData.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
                let cputypeBig = headerData.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

                // ARM64 detection
                if cputypeLittle == 0x0100000c || cputypeBig == 0x0c000001 {
                    return .arm
                }
                // x86_64 detection
                else if cputypeLittle == 0x01000007 || cputypeBig == 0x07000001 {
                    return .intel
                }
            } else if magic == 0xfeedface || magic == 0xcefaedfe {
                // 32-bit Mach-O (less common)
                let cputypeLittle = headerData.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
                let cputypeBig = headerData.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

                // ARM64 and x86_64 with 32-bit magic (edge case)
                if cputypeLittle == 0x0100000c || cputypeBig == 0x0c000001 {
                    return .arm
                }
                else if cputypeLittle == 0x01000007 || cputypeBig == 0x07000001 {
                    return .intel
                }
            }

            return .empty
        }
    }
}


// Main function that now directly uses the Mach-O helper
func thinAppBundleArchitecture(at appBundlePath: URL, of arch: Arch, multi: Bool = false, dryRun: Bool = false) -> (Bool, [String: UInt64]?) {
    // Reset bundle size to 0 before starting (only for real thinning)
    if !dryRun {
        updateOnMain {
            if let index = AppState.shared.sortedApps.firstIndex(where: { $0.path == appBundlePath }) {
                var updatedAppInfo = AppState.shared.sortedApps[index]
                updatedAppInfo.bundleSize = 0
                AppState.shared.sortedApps[index] = updatedAppInfo
            }
        }
    }
    
    // Use privileged helper if installed and needed, otherwise fallback to bundle thinning
    var success: Bool
    var sizes: [String: UInt64]?
    
    if dryRun {
        // For dry run, always use direct calculation without helper tools
        let result = thinAppBundle(at: appBundlePath, dryRun: true)
        success = result.0
        sizes = result.1
    } else if HelperToolManager.shared.isHelperToolInstalled {
        // Use privileged bundle thinning - helper handles the entire bundle with elevated privileges
        let semaphore = DispatchSemaphore(value: 0)
        success = false
        sizes = nil
        
        Task {
            let result = await HelperToolManager.shared.runBundleThinning(bundlePath: appBundlePath.path)
            success = result.0
            if result.0, !result.2.isEmpty {
                sizes = result.2
            }
            semaphore.signal()
        }
        semaphore.wait()
        
        if !success {
            // Helper tool failed, fallback to bundle thinning
            let result = thinAppBundle(at: appBundlePath)
            success = result.0
            sizes = result.1
        }
    } else {
        // No helper tool installed, use comprehensive bundle thinning
        let result = thinAppBundle(at: appBundlePath)
        success = result.0
        sizes = result.1
    }

    // Update the app bundle timestamp to refresh Finder (only for real thinning)
    if success && !dryRun {
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

                    // Show savings information if we have size data
                    if let bundleSizes = sizes,
                       let preSize = bundleSizes["pre"],
                       let postSize = bundleSizes["post"] {
                        let savingsPercentage = Int((Double(preSize - postSize) / Double(preSize)) * 100)
                        let title = String(format: NSLocalizedString("Space Savings: %d%%", comment: "Lipo result title"), savingsPercentage)
                        let message = String(format: NSLocalizedString("Bundle thinning complete.\nTotal space saved from all binaries in bundle.", comment: "Lipo result message"))
                        showCustomAlert(title: title, message: message, style: .informational)
                    }
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
    }

    return (success, sizes)
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


func openAppSettingsWindow(tab: CurrentTabView = .general) {
    @Environment(\.openWindow) var openWindow
    @AppStorage("settings.general.selectedTab") var selectedTab: CurrentTabView = .general

    selectedTab = tab
    openWindow(id: "settings")
}

// Get user profile picture
struct UserProfile {
    let firstName: String?
    let image: NSImage?
}

func getUserProfile() async -> UserProfile {
    // Use Task.detached to completely break QoS inheritance and escalation
    // This prevents the system from escalating to match the caller's QoS
    await Task.detached(priority: .medium) {
        do {
            let session = ODSession.default()
            let node = try ODNode(session: session, type: UInt32(kODNodeTypeLocalNodes))
            let record = try node.record(
                withRecordType: kODRecordTypeUsers,
                name: NSUserName(),
                attributes: ["dsAttrTypeStandard:RealName",
                             kODAttributeTypeJPEGPhoto]
            )

            // First name
            var firstName: String? = nil
            if let realName = (try? record.values(forAttribute: "dsAttrTypeStandard:RealName") as? [String])?.first {
                firstName = realName.components(separatedBy: " ").first
            }

            // JPEG photo
            var resizedImage: NSImage? = nil
            if let dataList = try? record.values(forAttribute: kODAttributeTypeJPEGPhoto) as? [Data],
               let data = dataList.first,
               let img = NSImage(data: data) {
                let targetSize = NSSize(width: 50, height: 50)
                let resized = NSImage(size: targetSize)
                resized.lockFocus()
                img.draw(in: NSRect(origin: .zero, size: targetSize),
                         from: NSRect(origin: .zero, size: img.size),
                         operation: .copy,
                         fraction: 1.0)
                resized.unlockFocus()
                resizedImage = resized
            }

            return UserProfile(firstName: firstName, image: resizedImage)
        } catch {
            printOS("Failed fetching user profile: \(error)")
            return UserProfile(firstName: nil, image: nil)
        }
    }.value
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

extension String {
    func pathWithArrows(separatorColor: Color = .secondary, separatorFont: Font = .caption) -> some View {
        let components = self.dropFirst().components(separatedBy: "/").filter { !$0.isEmpty }

        return HStack(spacing: 4) {
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                Group {
                    Text(component)

                    if index < components.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(separatorFont)
                            .foregroundStyle(separatorColor)
                    }
                }
                .lineLimit(1)
                .truncationMode(.tail)
            }
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
    @Environment(\.colorScheme) var colorScheme

    if path.contains("/Library/Containers/") || path.contains("/Library/Group Containers/") {
        return AnyView(
            Image(systemName: "shippingbox.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 13)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
                .help("Container")
        )
    } else if path.contains("/Library/Application Scripts/") {
        return AnyView(
            Image(systemName: "applescript.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 13)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
                .help("Application Script")
        )
    } else if path.contains(".plist") {
        return AnyView(
            Image(systemName: "doc.badge.gearshape.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 13)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
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
    formatter.dateStyle = .long
    formatter.timeZone = .current // Use the current timezone
    return formatter.string(from: date)
}



// --- Extend String to remove periods, spaces and lowercase the string
extension String {
    func pearFormat() -> String {
        // First, handle non-Latin scripts by preserving Unicode letters
        let preserveUnicode = self.unicodeScalars.compactMap { scalar in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            } else {
                return nil
            }
        }
        
        let result = String(preserveUnicode).lowercased()
        
        // If the result is empty after processing, return the original string
        // to avoid false matches with empty string comparisons
        return result.isEmpty ? self : result
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

func formatRelativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}
