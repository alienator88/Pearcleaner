//
//  CaskZapHarvester.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/22/26.
//

import Foundation

/// Reads zap/trash/delete/uninstall directives from installed Homebrew cask receipts
/// so regular app uninstall can also catch paths Homebrew itself would remove on --zap.
enum CaskZapHarvester {

    /// Returns leftover paths declared by the installed cask that matches the given app,
    /// or an empty array when the app is not a cask or brew is not installed.
    static func zapPaths(for appInfo: AppInfo) -> [URL] {
        guard HomebrewController.shared.isInstalled else { return [] }

        guard let token = caskToken(for: appInfo) else { return [] }
        guard let receipt = loadReceipt(token: token) else { return [] }

        var paths: [String] = []

        if let artifacts = receipt["uninstall_artifacts"] as? [[String: Any]] {
            for artifact in artifacts {
                for directive in artifactsDirectives(in: artifact, keys: ["zap"]) {
                    paths.append(contentsOf: stringPaths(from: directive, keys: ["trash", "delete", "rmdir"]))
                }
                // Plain uninstall directives also list real leftover paths (launchctl plists etc.)
                for directive in artifactsDirectives(in: artifact, keys: ["uninstall"]) {
                    paths.append(contentsOf: stringPaths(from: directive, keys: ["trash", "delete", "rmdir"]))
                }
            }
        }

        // Fallback: some receipts (older brew versions) store artifacts at top level
        if paths.isEmpty, let artifacts = receipt["artifacts"] as? [[String: Any]] {
            for artifact in artifacts {
                for directive in artifactsDirectives(in: artifact, keys: ["zap", "uninstall"]) {
                    paths.append(contentsOf: stringPaths(from: directive, keys: ["trash", "delete", "rmdir"]))
                }
            }
        }

        // Caskroom folder for the token
        let caskroomPath = "\(HomebrewController.shared.brewPrefix)/Caskroom/\(token)"
        paths.append(caskroomPath)

        // Keep only paths that exist and expand ~ and $HOME
        let expanded = paths.compactMap { expand($0) }
        return expanded
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .filter { !isInsideAppBundle(path: $0, appPath: appInfo.path) }
    }

    // MARK: - Token lookup

    /// Finds the cask token whose installed app matches appInfo, by receipt scan.
    private static func caskToken(for appInfo: AppInfo) -> String? {
        let caskroom = URL(fileURLWithPath: "\(HomebrewController.shared.brewPrefix)/Caskroom")
        guard FileManager.default.fileExists(atPath: caskroom.path) else { return nil }

        let appPath = appInfo.path.standardizedFileURL.path
        let appName = appInfo.appName.lowercased()
        let bundleId = appInfo.bundleIdentifier.lowercased()

        let tokens = (try? FileManager.default.contentsOfDirectory(atPath: caskroom.path)) ?? []
        for token in tokens {
            let receiptPath = caskroom.appendingPathComponent(token).appendingPathComponent(".metadata").appendingPathComponent("INSTALL_RECEIPT.json")
            guard let receipt = loadReceipt(token: token, receiptPath: receiptPath.path) else { continue }

            // Match by installed app artifact path
            if let artifacts = receipt["uninstall_artifacts"] as? [[String: Any]] {
                for artifact in artifacts {
                    if let appArray = artifact["app"] as? [String], let installedApp = appArray.first {
                        let installedPath = expand("/Applications/\(installedApp)")?.path ?? ""
                        if installedPath == appPath { return token }
                    }
                }
            }

            // Fallback match by name/bundle id embedded in token
            let tokenLower = token.lowercased()
            if bundleId.contains(tokenLower) || tokenLower.contains(appName.replacingOccurrences(of: " ", with: "-")) {
                return token
            }
        }
        return nil
    }

    private static func loadReceipt(token: String, receiptPath: String? = nil) -> [String: Any]? {
        let path = receiptPath ?? "\(HomebrewController.shared.brewPrefix)/Caskroom/\(token)/.metadata/INSTALL_RECEIPT.json"
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let receipt = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return receipt
    }

    // MARK: - Directive helpers

    private static func artifactsDirectives(in artifact: [String: Any], keys: [String]) -> [[String: Any]] {
        var directives: [[String: Any]] = []
        for key in keys {
            if let list = artifact[key] as? [[String: Any]] {
                directives.append(contentsOf: list)
            } else if let single = artifact[key] as? [String: Any] {
                directives.append(single)
            }
        }
        return directives
    }

    private static func stringPaths(from directive: [String: Any], keys: [String]) -> [String] {
        var result: [String] = []
        for key in keys {
            if let list = directive[key] as? [String] {
                result.append(contentsOf: list)
            } else if let single = directive[key] as? String {
                result.append(single)
            }
        }
        return result
    }

    private static func expand(_ path: String) -> URL? {
        var expanded = path
        if expanded.hasPrefix("~/") {
            expanded = NSHomeDirectory() + expanded.dropFirst(1)
        }
        expanded = expanded.replacingOccurrences(of: "${HOME}", with: NSHomeDirectory())
        guard expanded.hasPrefix("/") else { return nil } // skip glob/relative entries like ~/Library/Logs/**/*.log
        return URL(fileURLWithPath: expanded).standardizedFileURL
    }

    private static func isInsideAppBundle(path: URL, appPath: URL) -> Bool {
        let app = appPath.standardizedFileURL.path
        let p = path.standardizedFileURL.path
        return p == app || p.hasPrefix(app + "/")
    }
}