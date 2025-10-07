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

    // Common fields
    var tap: String?
    var fullName: String?
    var isDeprecated: Bool = false
    var deprecationReason: String?
    var isDisabled: Bool = false
    var disableDate: String?
    var conflictsWith: String?  // JSON string of array

    // Formula-specific fields
    var isBottled: Bool?
    var isKegOnly: Bool?
    var kegOnlyReason: String?
    var buildDependencies: String?  // JSON string of array
    var aliases: String?  // JSON string of array
    var versionedFormulae: String?  // JSON string of array
    var requirements: String?

    // Cask-specific fields
    var caskName: String?  // JSON string of array
    var autoUpdates: Bool?
    var artifacts: String?  // JSON string of array

    init(
        name: String,
        packageDescription: String?,
        homepage: String?,
        license: String?,
        version: String?,
        dependencies: String?,
        caveats: String?,
        isCask: Bool,
        cachedAt: Date,
        tap: String? = nil,
        fullName: String? = nil,
        isDeprecated: Bool = false,
        deprecationReason: String? = nil,
        isDisabled: Bool = false,
        disableDate: String? = nil,
        conflictsWith: String? = nil,
        isBottled: Bool? = nil,
        isKegOnly: Bool? = nil,
        kegOnlyReason: String? = nil,
        buildDependencies: String? = nil,
        aliases: String? = nil,
        versionedFormulae: String? = nil,
        requirements: String? = nil,
        caskName: String? = nil,
        autoUpdates: Bool? = nil,
        artifacts: String? = nil
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
        self.tap = tap
        self.fullName = fullName
        self.isDeprecated = isDeprecated
        self.deprecationReason = deprecationReason
        self.isDisabled = isDisabled
        self.disableDate = disableDate
        self.conflictsWith = conflictsWith
        self.isBottled = isBottled
        self.isKegOnly = isKegOnly
        self.kegOnlyReason = kegOnlyReason
        self.buildDependencies = buildDependencies
        self.aliases = aliases
        self.versionedFormulae = versionedFormulae
        self.requirements = requirements
        self.caskName = caskName
        self.autoUpdates = autoUpdates
        self.artifacts = artifacts
    }

    // MARK: - Conversion to HomebrewSearchResult

    func toSearchResult() -> HomebrewSearchResult {
        // Helper to decode JSON string array
        func decodeArray(_ string: String?) -> [String]? {
            guard let string = string,
                  let data = string.data(using: .utf8),
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
            dependencies: decodeArray(dependencies),
            caveats: caveats,
            tap: tap,
            fullName: fullName,
            isDeprecated: isDeprecated,
            deprecationReason: deprecationReason,
            isDisabled: isDisabled,
            disableDate: disableDate,
            conflictsWith: decodeArray(conflictsWith),
            isBottled: isBottled,
            isKegOnly: isKegOnly,
            kegOnlyReason: kegOnlyReason,
            buildDependencies: decodeArray(buildDependencies),
            aliases: decodeArray(aliases),
            versionedFormulae: decodeArray(versionedFormulae),
            requirements: requirements,
            caskName: decodeArray(caskName),
            autoUpdates: autoUpdates,
            artifacts: decodeArray(artifacts)
        )
    }

    // MARK: - Conversion from HomebrewSearchResult

    static func from(_ result: HomebrewSearchResult, isCask: Bool) -> CachedHomebrewPackage {
        // Helper to encode array to JSON string
        func encodeArray(_ array: [String]?) -> String? {
            guard let array = array,
                  let data = try? JSONEncoder().encode(array),
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
            dependencies: encodeArray(result.dependencies),
            caveats: result.caveats,
            isCask: isCask,
            cachedAt: Date(),
            tap: result.tap,
            fullName: result.fullName,
            isDeprecated: result.isDeprecated,
            deprecationReason: result.deprecationReason,
            isDisabled: result.isDisabled,
            disableDate: result.disableDate,
            conflictsWith: encodeArray(result.conflictsWith),
            isBottled: result.isBottled,
            isKegOnly: result.isKegOnly,
            kegOnlyReason: result.kegOnlyReason,
            buildDependencies: encodeArray(result.buildDependencies),
            aliases: encodeArray(result.aliases),
            versionedFormulae: encodeArray(result.versionedFormulae),
            requirements: result.requirements,
            caskName: encodeArray(result.caskName),
            autoUpdates: result.autoUpdates,
            artifacts: encodeArray(result.artifacts)
        )
    }
}
