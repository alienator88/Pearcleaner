//
//  UpdaterSettings.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/21/25.
//

import Foundation

// MARK: - AppStorage Codable Helper Protocol

/// Protocol for types that can be stored in AppStorage as Data
protocol AppStorageCodable: Codable {
    init()
    static func decode(from data: Data) -> Self
    func encode() -> Data
    static func defaultEncoded() -> Data
}

/// Default implementation for all AppStorageCodable types
extension AppStorageCodable {
    /// Decode from Data with fallback to default
    static func decode(from data: Data) -> Self {
        (try? JSONDecoder().decode(Self.self, from: data)) ?? Self()
    }

    /// Encode to Data with fallback to empty
    func encode() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    /// Default encoded value for AppStorage initialization
    static func defaultEncoded() -> Data {
        Self().encode()
    }
}

// MARK: - Sources Settings
struct UpdaterSourcesSettings: AppStorageCodable {
    var homebrew: HomebrewSettings = HomebrewSettings()
    var sparkle: SparkleSettings = SparkleSettings()
    var appStore: AppStoreSettings = AppStoreSettings()

    struct HomebrewSettings: Codable {
        var enabled: Bool = true
        var showAutoUpdates: Bool = true
    }

    struct SparkleSettings: Codable {
        var enabled: Bool = true
        var includePreReleases: Bool = true
    }

    struct AppStoreSettings: Codable {
        var enabled: Bool = true
    }
}

// MARK: - Display Settings
struct UpdaterDisplaySettings: AppStorageCodable {
    var showUnsupported: Bool = true
    var showCurrent: Bool = true
}
