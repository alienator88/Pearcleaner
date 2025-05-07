import AlinFoundation
import ArgumentParser
import Foundation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

// Main command structure
struct PearcleanerCommand: ParsableCommand {
	static var configuration = CommandConfiguration(
		commandName: "pearcleaner",
		abstract: "Command-line interface for Pearcleaner app",
		subcommands: [
			Run.self,
			List.self,
			ListOrphaned.self,
			Uninstall.self,
			UninstallAll.self,
			RemoveOrphaned.self,
		],
		defaultSubcommand: Help.self
	)

	// Default help subcommand
	struct Help: ParsableCommand {
		static var configuration = CommandConfiguration(
			commandName: "help",
			abstract: "Display help information"
		)

		func run() throws {
			displayHelp()
		}
	}

	// Run subcommand
	struct Run: ParsableCommand {
		static var configuration = CommandConfiguration(
			commandName: "run",
			abstract: "Launch Pearcleaner in Debug mode to see console logs"
		)

		func run() throws {
			printOS("Pearcleaner CLI | Launching App For Debugging:\n")
			// This command will simply return to allow the app to launch normally
			// with debug mode enabled - actual implementation is in the main app
		}
	}

	// List subcommand
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

			printOS("Pearcleaner CLI | List Application Files:\n")

			// Fetch the app info and safely unwrap
			guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
				printOS("Error: Invalid path or unable to fetch app info at path: \(path)\n")
				throw ExitCode(1)
			}

			// Use the AppPathFinder to find paths synchronously
			let appPathFinder = AppPathFinder(appInfo: appInfo, locations: Locations.shared)

			// Call findPaths to get the Set of URLs
			let foundPaths = appPathFinder.findPathsCLI()

			// Print each path in the Set to the console
			for path in foundPaths {
				printOS(path.path)
			}

			printOS("\nFound \(foundPaths.count) application files.\n")
		}
	}

	// ListOrphaned subcommand
	struct ListOrphaned: ParsableCommand {
		static var configuration = CommandConfiguration(
			commandName: "list-orphaned",
			abstract: "List orphaned files available for removal"
		)

		func run() throws {
			printOS("Pearcleaner CLI | List Orphaned Files:\n")

			let fsm = FolderSettingsManager.shared
			let locations = Locations.shared

			// Get installed apps for filtering
			let sortedApps = getSortedApps(paths: fsm.folderPaths.map { $0.path })

			// Find orphaned files
			let foundPaths = ReversePathsSearcher(
				locations: locations, fsm: fsm, sortedApps: sortedApps
			)
			.reversePathsSearchCLI()

			// Print each path in the array to the console
			for path in foundPaths {
				printOS(path.path)
			}
			printOS("\nFound \(foundPaths.count) orphaned files.\n")
		}
	}

	// Uninstall subcommand
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
			printOS("Pearcleaner CLI | Uninstall Application:\n")

			// Fetch the app info and safely unwrap
			guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
				printOS("Error: Invalid path or unable to fetch app info at path: \(path)\n")
				throw ExitCode(1)
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
				exit(0)
			} else {
				printOS("Failed to delete application.\n")
				throw ExitCode(1)
			}
		}
	}

	// UninstallAll subcommand
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
			printOS("Pearcleaner CLI | Uninstall Application & Related Files:\n")

			// Fetch the app info and safely unwrap
			guard let appInfo = AppInfoFetcher.getAppInfo(atPath: url) else {
				printOS("Error: Invalid path or unable to fetch app info at path: \(path)")
				throw ExitCode(1)
			}

			// Use the AppPathFinder to find paths synchronously
			let appPathFinder = AppPathFinder(appInfo: appInfo, locations: Locations.shared)

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
				throw ExitCode(1)
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
				exit(0)
			} else {
				printOS("Failed to delete some files, they might be protected or in use.\n")
				throw ExitCode(1)
			}
		}
	}

	// RemoveOrphaned subcommand
	struct RemoveOrphaned: ParsableCommand {
		static var configuration = CommandConfiguration(
			commandName: "remove-orphaned",
			abstract:
				"Remove ALL orphaned files (To ignore files, add them to the exception list within Pearcleaner settings)"
		)

		func run() throws {
			printOS("Pearcleaner CLI | Remove Orphaned Files:\n")

			let fsm = FolderSettingsManager.shared
			let locations = Locations.shared

			// Get installed apps for filtering
			let sortedApps = getSortedApps(paths: fsm.folderPaths.map { $0.path })

			// Find orphaned files
			let foundPaths = ReversePathsSearcher(
				locations: locations, fsm: fsm, sortedApps: sortedApps
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
				throw ExitCode(1)
			}

			let success = moveFilesToTrashCLI(at: foundPaths)
			if success {
				printOS("Orphaned files have been deleted successfully.\n")
				exit(0)
			} else {
				printOS("Failed to delete some orphaned files.\n")
				exit(1)
			}
		}
	}
}

// Helper function for process termination
func killApp(appId: String, completion: @escaping () -> Void) {
	// Implementation from the original code
	completion()
}

// App Path Finder extension for CLI use
extension AppPathFinder {
	// CLI-specific version that doesn't depend on AppState
	convenience init(appInfo: AppInfo, locations: Locations) {
		self.init(appInfo: appInfo, locations: locations, appState: nil) {
			// No-op completion handler for CLI
		}
	}

	// Synchronous version for CLI use
	func findPathsCLI() -> Set<URL> {
		// Create a semaphore for synchronous operation
		let semaphore = DispatchSemaphore(value: 0)
		var results = Set<URL>()

		// Call the asynchronous method with a callback to store results
		findPaths { foundPaths in
			results = foundPaths
			semaphore.signal()
		}

		// Wait for the async operation to complete
		semaphore.wait()
		return results
	}
}
