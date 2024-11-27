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
    @AppStorage("settings.general.cli") var isCLISymlinked = false

    // Get the current running application's bundle binary path
    guard let appPath = Bundle.main.executablePath else {
        printOS("Error: Unable to get the executable path.")
        return
    }

    // Path where the symlink should be created
    let symlinkPath = "/usr/local/bin/pearcleaner"

    // Check if the symlink already exists
    let symlinkExists = checkCLISymlink()

    // Check if /usr/local/bin exists
    let binPathExists = directoryExists(at: "/usr/local/bin")

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
        // AppleScript to optionally create the folder and then create the symlink
        let createBinFolderCommand = binPathExists ? "" : "mkdir -p /usr/local/bin;"
        script = """
        do shell script "\(createBinFolderCommand)ln -s '\(appPath)' '\(symlinkPath)'" with administrator privileges
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
                printOS("Symlink AppleScript Error: \(error)")
                isCLISymlinked = checkCLISymlink()
            } else {
                isCLISymlinked = checkCLISymlink()
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
