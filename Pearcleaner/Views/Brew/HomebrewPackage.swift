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
}
