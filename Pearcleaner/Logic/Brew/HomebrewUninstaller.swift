//
//  HomebrewUninstaller.swift
//  Pearcleaner
//
//  Created by Pearcleaner on 2025-10-03.
//

import Foundation
import SwiftyJSON
import AlinFoundation
import ServiceManagement

class HomebrewUninstaller {
    static let shared = HomebrewUninstaller()
    private let brewPrefix = "/opt/homebrew"

    private init() {}

    // MARK: - Main Entry Point

    /// Uninstalls a Homebrew package directly without calling brew uninstall
    /// This replicates Homebrew's uninstall behavior using privileged helper for root operations
    func uninstallPackage(name: String, cask: Bool, zap: Bool = true) async throws {
        if cask {
            // Try loading from INSTALL_RECEIPT.json first (instant)
            let caskInfo: JSON
            do {
                caskInfo = try loadCaskInfoFromReceipt(name: name)
            } catch {
                // Fallback to brew info command (slower but works if receipt missing)
                let arguments = ["info", "--json=v2", name]
                let result = try await HomebrewController.shared.runBrewCommand(arguments)

                guard let jsonData = result.output.data(using: String.Encoding.utf8) else {
                    throw HomebrewError.jsonParseError
                }

                let json = try JSON(data: jsonData)
                guard let info = json["casks"].arrayValue.first else {
                    throw HomebrewError.commandFailed("Cask \(name) not found")
                }
                caskInfo = info
            }
            try await uninstallCask(name: name, info: caskInfo, zap: zap)
        } else {
            // Formulae don't need info JSON - brew uninstall handles everything
            try await uninstallFormula(name: name, info: JSON())
        }

        // Run brew cleanup in background without blocking
        Task.detached(priority: .background) {
            try? await HomebrewController.shared.runCleanup()
        }
    }

    // MARK: - INSTALL_RECEIPT Helper

    /// Load cask info from INSTALL_RECEIPT.json (instant, no brew command needed)
    /// Converts receipt format to brew info format for compatibility with uninstallCask()
    private func loadCaskInfoFromReceipt(name: String) throws -> JSON {
        let receiptPath = "\(brewPrefix)/Caskroom/\(name)/.metadata/INSTALL_RECEIPT.json"

        guard FileManager.default.fileExists(atPath: receiptPath) else {
            throw HomebrewError.commandFailed("INSTALL_RECEIPT.json not found for \(name)")
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: receiptPath))
        let receipt = try JSON(data: data)

        // Convert INSTALL_RECEIPT format to brew info format
        var caskInfo = JSON()
        caskInfo["token"] = JSON(name)
        caskInfo["artifacts"] = receipt["uninstall_artifacts"]

        return caskInfo
    }

    // MARK: - Cask Uninstall

    private func uninstallCask(name: String, info: JSON, zap: Bool) async throws {
        let token = info["token"].stringValue

        // Collect all process names and services to kill
        var processNamesToKill: Set<String> = []
        var serviceNamesToKill: Set<String> = []
        var appName: String?

        // Process artifacts (includes uninstall directives and app info)
        if let artifacts = info["artifacts"].array {
            // Collect app name for process killing
            for artifact in artifacts {
                if let appArray = artifact["app"].array, let app = appArray.first?.stringValue {
                    appName = app.replacingOccurrences(of: ".app", with: "")
                    processNamesToKill.insert(appName!)
                }
            }

            // Collect quit and launchctl names from uninstall directives
            for artifact in artifacts {
                if let uninstallDirectives = artifact["uninstall"].array {
                    for directive in uninstallDirectives {
                        if let quit = directive["quit"].string {
                            processNamesToKill.insert(quit)
                        }
                        if let launchctl = directive["launchctl"].string {
                            serviceNamesToKill.insert(launchctl)
                        }
                    }
                }
            }

            // First pass: Process uninstall directives
            for artifact in artifacts {
                if let uninstallDirectives = artifact["uninstall"].array, !uninstallDirectives.isEmpty {
                    try await processCaskUninstallDirectives(uninstallDirectives, caskName: token, allProcessNames: processNamesToKill, allServiceNames: serviceNamesToKill)
                }
            }

            // Process zap directives if requested
            if zap {
                for artifact in artifacts {
                    if let zapDirectives = artifact["zap"].array, !zapDirectives.isEmpty {
                        try await processCaskUninstallDirectives(zapDirectives, caskName: token, allProcessNames: processNamesToKill, allServiceNames: serviceNamesToKill)
                    }
                }
            }

            // Kill any remaining processes (belt and suspenders approach)
            for processName in processNamesToKill {
                try await runPrivilegedCommand("pkill -9 -f '\(processName)' 2>/dev/null || killall -9 '\(processName)' 2>/dev/null || true")
            }

            // Second pass: Remove the app from /Applications or ~/Applications
            for artifact in artifacts {
                if let appArray = artifact["app"].array, let appFullName = appArray.first?.stringValue {
                    let systemAppPath = "/Applications/\(appFullName)"
                    let userAppPath = NSHomeDirectory() + "/Applications/\(appFullName)"

                    if FileManager.default.fileExists(atPath: systemAppPath) {
                        try await runPrivilegedCommand("rm -rf \"\(systemAppPath)\"")
                    } else if FileManager.default.fileExists(atPath: userAppPath) {
                        try FileManager.default.removeItem(atPath: userAppPath)
                    }
                }
            }
        }

        // Remove Caskroom directory and metadata
        let caskroomPath = "\(brewPrefix)/Caskroom/\(token)"
        if FileManager.default.fileExists(atPath: caskroomPath) {
            try await runPrivilegedCommand("rm -rf \"\(caskroomPath)\"")
        }
    }

    private func processCaskUninstallDirectives(_ directives: [JSON], caskName: String, allProcessNames: Set<String>, allServiceNames: Set<String>) async throws {
        // Process directives in the order Homebrew processes them
        // Based on abstract_uninstall.rb from Homebrew source

        for directive in directives {
            if directive["early_script"].dictionaryObject != nil {
                try await handleEarlyScript(directive["early_script"])
            }
        }

        for directive in directives {
            if let launchctl = directive["launchctl"].string {
                try await handleLaunchctl(launchctl)
            }
        }

        for directive in directives {
            if let quit = directive["quit"].string {
                try await handleQuit(quit)
            }
        }

        for directive in directives {
            if directive["signal"].array != nil {
                try await handleSignal(directive["signal"])
            }
        }

        for directive in directives {
            if let loginItem = directive["login_item"].string {
                try await handleLoginItem(loginItem)
            }
        }

        for directive in directives {
            if let kext = directive["kext"].string {
                try await handleKext(kext)
            }
        }

        for directive in directives {
            if directive["script"].dictionaryObject != nil {
                try await handleScript(directive["script"])
            }
        }

        for directive in directives {
            if let pkgutil = directive["pkgutil"].string {
                try await handlePkgutil(pkgutil)
            }
        }

        for directive in directives {
            if let delete = directive["delete"].array {
                for path in delete {
                    try await handleDelete(path.stringValue)
                }
            } else if let delete = directive["delete"].string {
                try await handleDelete(delete)
            }
        }

        for directive in directives {
            if let trash = directive["trash"].array {
                for path in trash {
                    try await handleTrash(path.stringValue)
                }
            } else if let trash = directive["trash"].string {
                try await handleTrash(trash)
            }
        }

        for directive in directives {
            if let rmdir = directive["rmdir"].array {
                for path in rmdir {
                    try await handleRmdir(path.stringValue)
                }
            } else if let rmdir = directive["rmdir"].string {
                try await handleRmdir(rmdir)
            }
        }
    }

    // MARK: - Formula Uninstall

    private func uninstallFormula(name: String, info: JSON) async throws {
        // Try using brew uninstall command first (proper uninstall with symlink cleanup)
        let arguments = ["uninstall", name, "--force"]

        do {
            let result = try await HomebrewController.shared.runBrewCommand(arguments)

            // Check if brew command failed due to permission error
            if result.error.contains("Could not remove") && result.error.contains("keg") {
                // Permission error - fallback to privileged command
                let cellarPath = "\(brewPrefix)/Cellar/\(name)"
                if FileManager.default.fileExists(atPath: cellarPath) {
                    try await runPrivilegedCommand("rm -rf \"\(cellarPath)\"")
                    // Also clean up symlinks (ignore errors if they don't exist)
                    _ = try? await runPrivilegedCommand("rm -f \"\(brewPrefix)/opt/\(name)\"")
                    _ = try? await runPrivilegedCommand("rm -f \"\(brewPrefix)/var/homebrew/linked/\(name)\"")
                }
            } else if !result.error.isEmpty && !result.error.contains("Warning") {
                // Other error - throw it
                throw HomebrewError.commandFailed(result.error)
            }
            // Success - brew uninstall handled everything
        } catch {
            // Fallback: If brew command itself fails, try direct deletion
            let cellarPath = "\(brewPrefix)/Cellar/\(name)"
            if FileManager.default.fileExists(atPath: cellarPath) {
                try await runPrivilegedCommand("rm -rf \"\(cellarPath)\"")
                _ = try? await runPrivilegedCommand("rm -f \"\(brewPrefix)/opt/\(name)\"")
                _ = try? await runPrivilegedCommand("rm -f \"\(brewPrefix)/var/homebrew/linked/\(name)\"")
            } else {
                throw HomebrewError.commandFailed("Formula \(name) is not installed")
            }
        }
    }

    // MARK: - Uninstall Directive Handlers

    private func handleEarlyScript(_ value: JSON) async throws {
        guard let executable = value["executable"].string else { return }

        let args = value["args"].arrayValue.map { $0.stringValue }
        let command = ([executable] + args).joined(separator: " ")

        try await runPrivilegedCommand(command)
    }

    private func handleLaunchctl(_ value: String) async throws {
        // Try both system and user domains
        let systemPlistPath = "/Library/LaunchDaemons/\(value).plist"
        let userPlistPath = NSHomeDirectory() + "/Library/LaunchAgents/\(value).plist"

        // Unload the service and kill the process
        do {
            // Try bootout first (modern launchctl)
            try await runPrivilegedCommand("launchctl bootout system/\(value) 2>/dev/null || launchctl unload \"\(systemPlistPath)\" 2>/dev/null || true")
            // Force kill the process if still running
            try await runPrivilegedCommand("pkill -9 -f '\(value)' 2>/dev/null || true")
        } catch {
            printOS("Failed to unload system service: \(error.localizedDescription)")
        }

        do {
            try await runPrivilegedCommand("launchctl bootout gui/$UID/\(value) 2>/dev/null || launchctl unload \"\(userPlistPath)\" 2>/dev/null || true")
            // Force kill the process if still running
            try await runPrivilegedCommand("pkill -9 -f '\(value)' 2>/dev/null || true")
        } catch {
            printOS("Failed to unload user service: \(error.localizedDescription)")
        }

        // Delete the plist files
        if FileManager.default.fileExists(atPath: systemPlistPath) {
            try await runPrivilegedCommand("rm -f \"\(systemPlistPath)\"")
        }
        if FileManager.default.fileExists(atPath: userPlistPath) {
            try FileManager.default.removeItem(atPath: userPlistPath)
        }
    }

    private func handleQuit(_ value: String) async throws {
        // First try using the bundle ID with killall (works with bundle IDs)
        var command = "killall -15 '\(value)' 2>/dev/null || true"
        do {
            _ = try await runPrivilegedCommand(command)
        } catch {
            printOS("killall failed for \(value): \(error.localizedDescription)")
        }

        // Also try pkill with partial match in case it's a process name
        command = "pkill -15 -f '\(value)' 2>/dev/null || true"
        do {
            _ = try await runPrivilegedCommand(command)
        } catch {
            printOS("pkill failed for \(value): \(error.localizedDescription)")
        }
    }

    private func handleSignal(_ value: JSON) async throws {
        guard let signal = value[0].string,
              let process = value[1].string else { return }

        try await runPrivilegedCommand("pkill -\(signal) \(process)")
    }

    private func handleLoginItem(_ value: String) async throws {
        // Unregister using SMAppService
        let service = SMAppService.loginItem(identifier: value)

        do {
            try await service.unregister()
        } catch {
            printOS("SMAppService unregister failed for \(value): \(error.localizedDescription)")
        }
    }

    private func handleKext(_ value: String) async throws {
        try await runPrivilegedCommand("kextunload -b \(value)")
    }

    private func handleScript(_ value: JSON) async throws {
        guard let executable = value["executable"].string else { return }

        let args = value["args"].arrayValue.map { $0.stringValue }
        let command = ([executable] + args).joined(separator: " ")

        try await runPrivilegedCommand(command)
    }

    private func handlePkgutil(_ value: String) async throws {
        // Get list of files from pkgutil
        let filesResult = try await runPrivilegedCommand("pkgutil --files \(value) 2>/dev/null || echo ''")
        let files = filesResult.components(separatedBy: "\n").filter { !$0.isEmpty }

        // Delete files (they're relative to /)
        for file in files {
            let fullPath = "/\(file)"
            if FileManager.default.fileExists(atPath: fullPath) {
                try await runPrivilegedCommand("rm -rf \"\(fullPath)\"")
            }
        }

        // Forget the package
        try await runPrivilegedCommand("pkgutil --forget \(value)")
    }

    private func handleDelete(_ path: String) async throws {
        let expandedPath = expandPath(path)

        if FileManager.default.fileExists(atPath: expandedPath) {
            // Check if we need privileged access
            if expandedPath.hasPrefix("/Library/") || expandedPath.hasPrefix("/private/") {
                try await runPrivilegedCommand("rm -rf \"\(expandedPath)\"")
            } else {
                try FileManager.default.removeItem(atPath: expandedPath)
            }
        }
    }

    private func handleTrash(_ path: String) async throws {
        let expandedPath = expandPath(path)

        if FileManager.default.fileExists(atPath: expandedPath) {
            let url = URL(fileURLWithPath: expandedPath)
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }

    private func handleRmdir(_ path: String) async throws {
        let expandedPath = expandPath(path)

        if FileManager.default.fileExists(atPath: expandedPath) {
            // Only remove if empty
            let contents = try FileManager.default.contentsOfDirectory(atPath: expandedPath)
            if contents.isEmpty {
                if expandedPath.hasPrefix("/Library/") || expandedPath.hasPrefix("/private/") {
                    try await runPrivilegedCommand("rmdir \"\(expandedPath)\"")
                } else {
                    try FileManager.default.removeItem(atPath: expandedPath)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            return NSString(string: path).expandingTildeInPath
        }
        return path
    }

    @discardableResult
    private func runPrivilegedCommand(_ command: String) async throws -> String {
        let success: Bool
        let output: String

        if HelperToolManager.shared.isHelperToolInstalled {
            let result = await HelperToolManager.shared.runCommand(command)
            success = result.0
            output = result.1
        } else {
            let result = performPrivilegedCommands(commands: command)
            success = result.0
            output = result.1
        }

        if !success {
            throw HomebrewError.commandFailed("Privileged command failed: \(output)")
        }

        return output
    }
}
