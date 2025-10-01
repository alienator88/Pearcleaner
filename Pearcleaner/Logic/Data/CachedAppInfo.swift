//
//  CachedAppInfo.swift
//  Pearcleaner
//
//  SwiftData model for caching app metadata
//

import Foundation
import SwiftData
import AppKit

@available(macOS 14.0, *)
@Model
final class CachedAppInfo {
    @Attribute(.unique) var path: String
    var bundleIdentifier: String
    var appName: String
    var appVersion: String
    var appIconData: Data?
    var webApp: Bool
    var wrapped: Bool
    var system: Bool
    var arch: String
    var cask: String?
    var steam: Bool
    var bundleSize: Int64
    var creationDate: Date?
    var contentChangeDate: Date?
    var lastUsedDate: Date?
    var entitlements: [String]?

    // File size dictionaries stored as JSON strings
    var fileSizeJSON: String  // [URL: Int64] serialized
    var fileSizeLogicalJSON: String  // [URL: Int64] serialized

    // Metadata for cache management
    var lastScanned: Date

    init(
        path: String,
        bundleIdentifier: String,
        appName: String,
        appVersion: String,
        appIconData: Data?,
        webApp: Bool,
        wrapped: Bool,
        system: Bool,
        arch: String,
        cask: String?,
        steam: Bool,
        bundleSize: Int64,
        fileSizeJSON: String,
        fileSizeLogicalJSON: String,
        creationDate: Date?,
        contentChangeDate: Date?,
        lastUsedDate: Date?,
        entitlements: [String]?,
        lastScanned: Date
    ) {
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.appVersion = appVersion
        self.appIconData = appIconData
        self.webApp = webApp
        self.wrapped = wrapped
        self.system = system
        self.arch = arch
        self.cask = cask
        self.steam = steam
        self.bundleSize = bundleSize
        self.fileSizeJSON = fileSizeJSON
        self.fileSizeLogicalJSON = fileSizeLogicalJSON
        self.creationDate = creationDate
        self.contentChangeDate = contentChangeDate
        self.lastUsedDate = lastUsedDate
        self.entitlements = entitlements
        self.lastScanned = lastScanned
    }

    // MARK: - Conversion to AppInfo

    func toAppInfo() -> AppInfo? {
        let pathURL = URL(fileURLWithPath: path)

        // Deserialize file size dictionaries
        let fileSize = deserializeFileSizeDict(from: fileSizeJSON)
        let fileSizeLogical = deserializeFileSizeDict(from: fileSizeLogicalJSON)

        // Convert icon data to NSImage
        let appIcon: NSImage? = if let iconData = appIconData {
            NSImage(data: iconData)
        } else {
            nil
        }

        // Convert arch string to Arch enum
        let archEnum: Arch = switch arch {
        case "arm": .arm
        case "intel": .intel
        case "universal": .universal
        default: .empty
        }

        return AppInfo(
            id: UUID(),
            path: pathURL,
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            appVersion: appVersion,
            appIcon: appIcon,
            webApp: webApp,
            wrapped: wrapped,
            system: system,
            arch: archEnum,
            cask: cask,
            steam: steam,
            bundleSize: bundleSize,
            fileSize: fileSize,
            fileSizeLogical: fileSizeLogical,
            fileIcon: [:],  // Icons not cached
            creationDate: creationDate,
            contentChangeDate: contentChangeDate,
            lastUsedDate: lastUsedDate,
            entitlements: entitlements
        )
    }

    // MARK: - Conversion from AppInfo

    static func from(_ appInfo: AppInfo) -> CachedAppInfo {
        // Serialize file size dictionaries
        let fileSizeJSON = serializeFileSizeDict(appInfo.fileSize)
        let fileSizeLogicalJSON = serializeFileSizeDict(appInfo.fileSizeLogical)

        // Convert icon to data
        let iconData = appInfo.appIcon?.tiffRepresentation

        return CachedAppInfo(
            path: appInfo.path.path,
            bundleIdentifier: appInfo.bundleIdentifier,
            appName: appInfo.appName,
            appVersion: appInfo.appVersion,
            appIconData: iconData,
            webApp: appInfo.webApp,
            wrapped: appInfo.wrapped,
            system: appInfo.system,
            arch: appInfo.arch.type,
            cask: appInfo.cask,
            steam: appInfo.steam,
            bundleSize: appInfo.bundleSize,
            fileSizeJSON: fileSizeJSON,
            fileSizeLogicalJSON: fileSizeLogicalJSON,
            creationDate: appInfo.creationDate,
            contentChangeDate: appInfo.contentChangeDate,
            lastUsedDate: appInfo.lastUsedDate,
            entitlements: appInfo.entitlements,
            lastScanned: Date()
        )
    }

    // MARK: - Helper Methods

    private static func serializeFileSizeDict(_ dict: [URL: Int64]) -> String {
        let stringDict = dict.reduce(into: [String: Int64]()) { result, pair in
            result[pair.key.path] = pair.value
        }
        guard let data = try? JSONEncoder().encode(stringDict),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func deserializeFileSizeDict(from json: String) -> [URL: Int64] {
        guard let data = json.data(using: .utf8),
              let stringDict = try? JSONDecoder().decode([String: Int64].self, from: data) else {
            return [:]
        }
        return stringDict.reduce(into: [URL: Int64]()) { result, pair in
            result[URL(fileURLWithPath: pair.key)] = pair.value
        }
    }
}
