//
//  HomebrewPackage.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import Foundation

// MARK: - Legacy Model (for search/list views)

struct HomebrewSearchResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let displayName: String?  // Human-readable app name (e.g., "FreeMacSoft AppCleaner" instead of "appcleaner")
    let description: String?
    let homepage: String?
    let license: String?
    let version: String?
    let dependencies: [String]?
    let caveats: String?

    // Common fields (from JWS)
    let tap: String?
    let fullName: String?
    let isDeprecated: Bool
    let deprecationReason: String?
    let deprecationDate: String?
    let isDisabled: Bool
    let disableDate: String?
    let disableReason: String?
    let conflictsWith: [String]?
    let conflictsWithReasons: [String]?

    // Formula-specific fields (from JWS)
    let isBottled: Bool?
    let isKegOnly: Bool?
    let kegOnlyReason: String?
    let buildDependencies: [String]?
    let optionalDependencies: [String]?
    let recommendedDependencies: [String]?
    let usesFromMacos: [String]?
    let aliases: [String]?
    let versionedFormulae: [String]?
    let requirements: String?

    // Cask-specific fields (from JWS)
    let caskName: [String]?
    let autoUpdates: Bool?
    let artifacts: [String]?
    let url: String?
    let appcast: String?
}

// MARK: - Type-Safe Package Details Models

/// Enum wrapper for type-safe package details
enum PackageDetailsType {
    case formula(FormulaDetails)
    case cask(CaskDetails)

    var name: String {
        switch self {
        case .formula(let details): return details.name
        case .cask(let details): return details.name
        }
    }

    var isCask: Bool {
        switch self {
        case .formula: return false
        case .cask: return true
        }
    }
}

/// Base protocol with fields common to both formulae and casks
protocol HomebrewPackageDetails {
    var name: String { get }
    var description: String? { get }
    var homepage: String? { get }
    var license: String? { get }
    var version: String? { get }
    var dependencies: [String]? { get }
    var caveats: String? { get }
    var tap: String? { get }
    var fullName: String? { get }
    var isDeprecated: Bool { get }
    var deprecationReason: String? { get }
    var deprecationDate: String? { get }
    var isDisabled: Bool { get }
    var disableDate: String? { get }
    var disableReason: String? { get }
    var conflictsWith: [String]? { get }
    var conflictsWithReasons: [String]? { get }
}

/// Formula-specific package details
struct FormulaDetails: HomebrewPackageDetails {
    // Common fields
    let name: String
    let description: String?
    let homepage: String?
    let license: String?
    let version: String?
    let dependencies: [String]?
    let caveats: String?
    let tap: String?
    let fullName: String?
    let isDeprecated: Bool
    let deprecationReason: String?
    let deprecationDate: String?
    let isDisabled: Bool
    let disableDate: String?
    let disableReason: String?
    let conflictsWith: [String]?
    let conflictsWithReasons: [String]?

    // Formula-specific fields
    let isBottled: Bool?
    let isKegOnly: Bool?
    let kegOnlyReason: String?
    let buildDependencies: [String]?
    let optionalDependencies: [String]?
    let recommendedDependencies: [String]?
    let usesFromMacos: [String]?
    let aliases: [String]?
    let versionedFormulae: [String]?
    let requirements: String?
    let service: ServiceInfo?

    // Replacement suggestions
    let deprecationReplacementFormula: String?
    let deprecationReplacementCask: String?
    let disableReplacementFormula: String?
    let disableReplacementCask: String?
}

/// Cask-specific package details
struct CaskDetails: HomebrewPackageDetails {
    // Common fields
    let name: String
    let description: String?
    let homepage: String?
    let license: String?
    let version: String?
    let dependencies: [String]?
    let caveats: String?
    let tap: String?
    let fullName: String?
    let isDeprecated: Bool
    let deprecationReason: String?
    let deprecationDate: String?
    let isDisabled: Bool
    let disableDate: String?
    let disableReason: String?
    let conflictsWith: [String]?
    let conflictsWithReasons: [String]?

    // Cask-specific fields
    let caskName: [String]?
    let autoUpdates: Bool?
    let artifacts: [String]?
    let url: String?
    let appcast: String?
    let minimumMacOSVersion: String?
    let architectureRequirement: ArchRequirement?
    let bundleVersion: String?         // CFBundleVersion from API (e.g., "7390.122" or "446000104")
    let bundleShortVersion: String?    // CFBundleShortVersionString from API

    // Replacement suggestions
    let deprecationReplacementFormula: String?
    let deprecationReplacementCask: String?
    let disableReplacementFormula: String?
    let disableReplacementCask: String?
}

/// Service/daemon information for formulae
struct ServiceInfo {
    let run: [String]?  // Command array
    let runType: String?  // immediate, interval, cron, etc.
    let workingDir: String?
    let keepAlive: Bool?
}

/// Architecture requirement for casks
enum ArchRequirement: String {
    case intel = "x86_64"
    case arm = "arm64"
    case universal = "universal"

    var displayName: String {
        switch self {
        case .intel: return "Intel only"
        case .arm: return "Apple Silicon only"
        case .universal: return "Universal (Intel & Apple Silicon)"
        }
    }
}

struct HomebrewAnalytics {
    let install30d: Int?
    let install90d: Int?
    let install365d: Int?
}

// Lightweight model for installed packages list (only name + description + version displayed)
struct OutdatedVersionInfo: Equatable, Hashable {
    let installed: String
    let available: String
}

struct InstalledPackage: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let displayName: String?  // Human-readable app name from Ruby file (e.g., "Battery Toolkit" for casks, nil for formulae)
    let description: String?
    let version: String?
    let isCask: Bool
    var isPinned: Bool
    let tap: String?        // e.g., "homebrew/core", "mhaeuser/mhaeuser"
    let tapRbPath: String?  // Cached path to tap's .rb file for version checking
    let installedOnRequest: Bool  // True if user explicitly installed (not as dependency) - formulae only, always true for casks

    static func == (lhs: InstalledPackage, rhs: InstalledPackage) -> Bool {
        return lhs.name == rhs.name && lhs.isCask == rhs.isCask
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(isCask)
    }
}

struct HomebrewPackageInfo: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let isCask: Bool
    let installedOn: Date?
    let versions: [String]
    let sizeInBytes: Int64?
    let isPinned: Bool
    let isOutdated: Bool
    let description: String?
    let homepage: String?
    let tap: String?
    let installedPath: String?  // Cellar path for formulae, Caskroom path for casks
    let fileCount: Int?  // Number of files in installation

    var displayVersion: String {
        return versions.joined(separator: ", ")
    }

    func formattedInstallDate(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM y (E), HH:mm"
        return dateFormatter.string(from: date)
    }

    func formattedSize(size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    static func == (lhs: HomebrewPackageInfo, rhs: HomebrewPackageInfo) -> Bool {
        return lhs.name == rhs.name && lhs.isCask == rhs.isCask
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(isCask)
    }

    // Full initializer (for backward compatibility with old loadInstalledPackages)
    init(
        name: String,
        isCask: Bool,
        installedOn: Date?,
        versions: [String],
        sizeInBytes: Int64?,
        isPinned: Bool,
        isOutdated: Bool,
        description: String?,
        homepage: String?,
        tap: String?,
        installedPath: String?,
        fileCount: Int?
    ) {
        self.name = name
        self.isCask = isCask
        self.installedOn = installedOn
        self.versions = versions
        self.sizeInBytes = sizeInBytes
        self.isPinned = isPinned
        self.isOutdated = isOutdated
        self.description = description
        self.homepage = homepage
        self.tap = tap
        self.installedPath = installedPath
        self.fileCount = fileCount
    }

}
