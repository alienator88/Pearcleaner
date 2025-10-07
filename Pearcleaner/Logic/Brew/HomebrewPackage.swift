//
//  HomebrewPackage.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import Foundation

struct HomebrewSearchResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
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
    let isDisabled: Bool
    let disableDate: String?
    let conflictsWith: [String]?

    // Formula-specific fields (from JWS)
    let isBottled: Bool?
    let isKegOnly: Bool?
    let kegOnlyReason: String?
    let buildDependencies: [String]?
    let aliases: [String]?
    let versionedFormulae: [String]?
    let requirements: String?

    // Cask-specific fields (from JWS)
    let caskName: [String]?
    let autoUpdates: Bool?
    let artifacts: [String]?
}

struct HomebrewAnalytics {
    let install30d: Int?
    let install90d: Int?
    let install365d: Int?
    let installOnRequest30d: Int?
    let installOnRequest90d: Int?
    let installOnRequest365d: Int?
    let buildError30d: Int?
}

// Lightweight model for installed packages list (only name + description + version displayed)
struct InstalledPackage: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let description: String?
    let version: String?
    let isCask: Bool

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
