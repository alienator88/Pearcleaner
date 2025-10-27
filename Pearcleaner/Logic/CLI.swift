import AlinFoundation
import ArgumentParser
import Foundation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

// Main command structure
struct PearCLI: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "pear",
        abstract: "Command-line interface for the Pearcleaner app",
        subcommands: [
//            Run.self,
            List.self,
            ListOrphaned.self,
            Uninstall.self,
            UninstallAll.self,
            RemoveOrphaned.self,
            Helper.self,
            AskPassword.self,
        ]
    )

    // For dependency management
    static var locations: Locations!
    static var fsm: FolderSettingsManager!

    // Set up dependencies before running commands
    static func setupDependencies(
        locations: Locations, fsm: FolderSettingsManager
    ) {
        Self.locations = locations
        Self.fsm = fsm
    }

//    struct Run: ParsableCommand {
//        static var configuration = CommandConfiguration(
//            commandName: "run",
//            abstract: "Launch Pearcleaner in Debug mode to see console logs"
//        )
//
//        func run() throws {
//            printOS("Pearcleaner CLI | Launching App For Debugging:\n")
//        }
//    }

    struct List: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List application files available for uninstall at the specified path"
        )

        @Argument(help: "Path to the application")
        var path: String

        func run() throws {
            // Convert the provided string path to a URL
            let url = URL(fileURLWithPath: path)

            // Fetch the app info and safely unwrap
            guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
                printOS("Error: Invalid path or unable to fetch app info at path: \(path)\n")
                Foundation.exit(1)
            }

            // Use the AppPathFinder to find paths synchronously
            let appPathFinder = AppPathFinder(appInfo: appInfo, locations: PearCLI.locations)

            // Call findPaths to get the Set of URLs
            let foundPaths = appPathFinder.findPathsCLI()

            // Print each path in the Set to the console
            for path in foundPaths {
                printOS(path.path)
            }

            printOS("\nFound \(foundPaths.count) application files.\n")
            Foundation.exit(0)
        }
    }

    struct ListOrphaned: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list-orphaned",
            abstract: "List orphaned files available for removal"
        )

        func run() throws {
            // Get installed apps for filtering
            let sortedApps = getSortedApps(paths: PearCLI.fsm.folderPaths)

            // Find orphaned files
            let foundPaths = ReversePathsSearcher(
                locations: PearCLI.locations,
                fsm: PearCLI.fsm,
                sortedApps: sortedApps
            )
                .reversePathsSearchCLI()

            // Print each path in the array to the console
            for path in foundPaths {
                printOS(path.path)
            }
            printOS("\nFound \(foundPaths.count) orphaned files.\n")
            Foundation.exit(0)
        }
    }

    struct Uninstall: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "uninstall",
            abstract: "Uninstall only the application bundle at the specified path"
        )

        @Argument(help: "Path to the application")
        var path: String

        func run() throws {
            // Convert the provided string path to a URL
            let url = URL(fileURLWithPath: path)

            // Fetch the app info and safely unwrap
            guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
                printOS("Error: Invalid path or unable to fetch app info at path: \(path)\n")
                Foundation.exit(1)
            }

            // Create a semaphore for synchronous operation
            let semaphore = DispatchSemaphore(value: 0)
            var operationSuccess = false

            killApp(appId: appInfo.bundleIdentifier) {
                let success = moveFilesToTrashCLI(at: [appInfo.path])
                operationSuccess = success
                semaphore.signal()
            }

            // Wait for the async operation to complete
            semaphore.wait()

            if operationSuccess {
                printOS("Application deleted successfully.\n")
                Foundation.exit(0)
            } else {
                printOS("Failed to delete application.\n")
                Foundation.exit(1)
            }
        }
    }

    struct UninstallAll: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "uninstall-all",
            abstract: "Uninstall application bundle and ALL related files at the specified path"
        )

        @Argument(help: "Path to the application")
        var path: String

        func run() throws {
            // Convert the provided string path to a URL
            let url = URL(fileURLWithPath: path)

            // Fetch the app info and safely unwrap
            guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
                printOS("Error: Invalid path or unable to fetch app info at path: \(path)")
                Foundation.exit(1)
            }

            // Use the AppPathFinder to find paths synchronously
            let appPathFinder = AppPathFinder(appInfo: appInfo, locations: PearCLI.locations)

            // Call findPaths to get the Set of URLs
            let foundPaths = appPathFinder.findPathsCLI()

            // Check if any file is protected (non-writable)
            let protectedFiles = foundPaths.filter {
                !FileManager.default.isWritableFile(atPath: $0.path)
            }

            // If protected files are found, echo message and exit
            if !protectedFiles.isEmpty && !HelperToolManager.shared.isHelperToolInstalled {
                printOS("Protected files detected. Please run this command with sudo:\n")
                printOS("sudo pearcleaner uninstall-all \(path)")
                printOS("\nProtected files:\n")
                for file in protectedFiles {
                    printOS(file.path)
                }
                Foundation.exit(1)
            }

            // Create a semaphore for synchronous operation
            let semaphore = DispatchSemaphore(value: 0)
            var operationSuccess = false

            killApp(appId: appInfo.bundleIdentifier) {
                let success = moveFilesToTrashCLI(at: Array(foundPaths))
                operationSuccess = success
                semaphore.signal()
            }

            // Wait for the async operation to complete
            semaphore.wait()

            if operationSuccess {
                printOS("The application and related files have been deleted successfully.\n")
                Foundation.exit(0)
            } else {
                printOS("Failed to delete some files, they might be protected or in use.\n")
                Foundation.exit(1)
            }
        }
    }

    struct RemoveOrphaned: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "remove-orphaned",
            abstract:
                "Remove ALL orphaned files (To ignore files, add them to the exception list within Pearcleaner settings)"
        )

        func run() throws {

            // Get installed apps for filtering
            let sortedApps = getSortedApps(paths: PearCLI.fsm.folderPaths)

            // Find orphaned files
            let foundPaths = ReversePathsSearcher(
                locations: PearCLI.locations,
                fsm: PearCLI.fsm,
                sortedApps: sortedApps
            )
                .reversePathsSearchCLI()

            // Check if any file is protected (non-writable)
            let protectedFiles = foundPaths.filter {
                !FileManager.default.isWritableFile(atPath: $0.path)
            }

            // If protected files are found, echo message and exit
            if !protectedFiles.isEmpty && !HelperToolManager.shared.isHelperToolInstalled {
                printOS("Protected files detected. Please run this command with sudo:\n")
                printOS("sudo pearcleaner remove-orphaned")
                printOS("\nProtected files:\n")
                for file in protectedFiles {
                    printOS(file.path)
                }
                Foundation.exit(1)
            }

            let success = moveFilesToTrashCLI(at: foundPaths)
            if success {
                printOS("Orphaned files have been deleted successfully.\n")
                Foundation.exit(0)
            } else {
                printOS("Failed to delete some orphaned files.\n")
                Foundation.exit(1)
            }
        }
    }

    struct Helper: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "helper",
            abstract: "Manage privileged helper tool status"
        )

        @Argument(help: "Action: 'enable' or 'disable'. Omit to check status.")
        var action: String?

        func run() throws {
            // If no action provided, return status
            guard let action = action else {
                let semaphore = DispatchSemaphore(value: 0)
                var isEnabled = false

                Task {
                    isEnabled = await isHelperEnabled()
                    semaphore.signal()
                }

                semaphore.wait()

                let status = isEnabled ? "Enabled" : "Disabled"
                printOS(status)
                Foundation.exit(0)
            }

            // Validate action
            guard ["enable", "disable"].contains(action.lowercased()) else {
                printOS("Error: Invalid action. Use 'enable', 'disable', or omit for status.\n")
                Foundation.exit(1)
            }

            // Check current status first
            let semaphore1 = DispatchSemaphore(value: 0)
            var currentlyEnabled = false

            Task {
                currentlyEnabled = await isHelperEnabled()
                semaphore1.signal()
            }

            semaphore1.wait()

            // Pre-check before attempting operation
            if action.lowercased() == "enable" {
                if currentlyEnabled {
                    printOS("Privileged helper is already enabled.\n")
                    Foundation.exit(0)
                }
            } else {
                if !currentlyEnabled {
                    printOS("Privileged helper is already disabled.\n")
                    Foundation.exit(0)
                }
            }

            // Proceed with enable/disable operation
            let semaphore2 = DispatchSemaphore(value: 0)
            var operationSuccess = false
            var errorMessage: String?

            Task {
                if action.lowercased() == "enable" {
                    await HelperToolManager.shared.manageHelperTool(action: .install)
                    operationSuccess = await isHelperEnabled()

                    if !operationSuccess {
                        errorMessage = "Failed to enable privileged helper"
                    }
                } else {
                    await HelperToolManager.shared.manageHelperTool(action: .uninstall)
                    operationSuccess = !(await isHelperEnabled())

                    if !operationSuccess {
                        errorMessage = "Failed to disable privileged helper"
                    }
                }
                semaphore2.signal()
            }

            // Wait for async operation to complete
            semaphore2.wait()

            if operationSuccess {
                if action.lowercased() == "enable" {
                    printOS("Privileged helper enabled successfully.\n")
                } else {
                    printOS("Privileged helper disabled successfully.\n")
                }
                Foundation.exit(0)
            } else {
                printOS("Error: \(errorMessage ?? "Unknown error occurred")\n")
                Foundation.exit(1)
            }
        }

        // Helper function to check if privileged helper is enabled
        private func isHelperEnabled() async -> Bool {
            let result = await HelperToolManager.shared.runCommand("whoami", skipHelperCheck: true)
            return result.0 && result.1.trimmingCharacters(in: .whitespacesAndNewlines) == "root"
        }
    }

    struct AskPassword: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "ask-password",
            abstract: "Display password prompt for sudo operations"
        )

        @Option(name: .long, help: "Message to display")
        var message: String = "Enter your password to continue"

        func run() throws {
            // Initialize NSApplication
            _ = NSApplication.shared

            // Show dialog directly
            let password = Self.showPasswordDialog(message: message)

            if let password = password, !password.isEmpty {
                print(password)
                Darwin.exit(0)
            } else {
                Darwin.exit(1)
            }
        }

        private static func showPasswordDialog(message: String) -> String? {
            let alert = NSAlert()
            alert.messageText = "Pearcleaner"
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            let secureTextField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            secureTextField.placeholderString = "Password"
            alert.accessoryView = secureTextField
            alert.window.initialFirstResponder = secureTextField

            NSApp.activate(ignoringOtherApps: true)

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                let password = secureTextField.stringValue
                return password.isEmpty ? nil : password
            }

            return nil
        }
    }
}
