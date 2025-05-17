import AlinFoundation
import ArgumentParser
import Foundation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

// Main command structure
struct PearCLI: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "Pear",
    abstract: "Command-line interface for the Pearcleaner app",
    subcommands: [
      Run.self,
      List.self,
      ListOrphaned.self,
      Uninstall.self,
      UninstallAll.self,
      RemoveOrphaned.self,
    ]
  )

  // For dependency management
  static var appState: AppState!
  static var locations: Locations!
  static var fsm: FolderSettingsManager!

  // Set up dependencies before running commands
  static func setupDependencies(
    appState: AppState, locations: Locations, fsm: FolderSettingsManager
  ) {
    Self.appState = appState
    Self.locations = locations
    Self.fsm = fsm
  }

  struct Run: ParsableCommand {
    static var configuration = CommandConfiguration(
      commandName: "run",
      abstract: "Launch Pearcleaner in Debug mode to see console logs"
    )

    func run() throws {
      printOS("Pearcleaner CLI | Launching App For Debugging:\n")
    }
  }

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
}
