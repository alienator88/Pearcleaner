//
//  CachedHomebrewPackage.swift
//  Pearcleaner
//
//  SwiftData model for caching Homebrew package data
//

import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

@available(macOS 14.0, *)
@Model
final class CachedHomebrewPackage {
    @Attribute(.unique) var uniqueKey: String  // name + isCask for uniqueness
    var name: String
    var packageDescription: String?
    var homepage: String?
    var license: String?
    var version: String?
    var dependencies: String?  // JSON string of array
    var caveats: String?
    var isCask: Bool  // true for cask, false for formula
    var cachedAt: Date

    init(
        name: String,
        packageDescription: String?,
        homepage: String?,
        license: String?,
        version: String?,
        dependencies: String?,
        caveats: String?,
        isCask: Bool,
        cachedAt: Date
    ) {
        self.uniqueKey = "\(name)_\(isCask ? "cask" : "formula")"
        self.name = name
        self.packageDescription = packageDescription
        self.homepage = homepage
        self.license = license
        self.version = version
        self.dependencies = dependencies
        self.caveats = caveats
        self.isCask = isCask
        self.cachedAt = cachedAt
    }

    // MARK: - Conversion to HomebrewSearchResult

    func toSearchResult() -> HomebrewSearchResult {
        let deps = dependencies.flatMap { depString -> [String]? in
            guard let data = depString.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return nil
            }
            return array
        }

        return HomebrewSearchResult(
            name: name,
            description: packageDescription,
            homepage: homepage,
            license: license,
            version: version,
            dependencies: deps,
            caveats: caveats
        )
    }

    // MARK: - Conversion from HomebrewSearchResult

    static func from(_ result: HomebrewSearchResult, isCask: Bool) -> CachedHomebrewPackage {
        let depsString = result.dependencies.flatMap { deps -> String? in
            guard let data = try? JSONEncoder().encode(deps),
                  let string = String(data: data, encoding: .utf8) else {
                return nil
            }
            return string
        }

        return CachedHomebrewPackage(
            name: result.name,
            packageDescription: result.description,
            homepage: result.homepage,
            license: result.license,
            version: result.version,
            dependencies: depsString,
            caveats: result.caveats,
            isCask: isCask,
            cachedAt: Date()
        )
    }
}
