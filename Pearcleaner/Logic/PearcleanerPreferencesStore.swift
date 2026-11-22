//
//  PearcleanerPreferencesStore.swift
//  Pearcleaner
//
//  Pins folder preference reads and writes to the application preferences
//  domain, so the CLI sees exactly what the GUI saved even when
//  UserDefaults.standard resolves to a different container.
//

import Foundation

enum FolderPreferenceKey: String, CaseIterable {
    case applications = "settings.folders.apps"
    case orphanExclusions = "settings.folders.zombie"
    case appFileExclusions = "settings.folders.appsExclusion"
}

protocol FolderPreferencesStoring {
    func stringArray(for key: FolderPreferenceKey) -> [String]?
    func set(_ value: [String], for key: FolderPreferenceKey)
}

final class PearcleanerPreferencesStore: FolderPreferencesStoring {
    static let currentDomainIdentifier = Bundle.main.bundleIdentifier ?? "com.alienator88.Pearcleaner"
    static let migrationDomainIdentifiers = [
        "pear",
    ]
    static let shared = PearcleanerPreferencesStore()

    private let domainIdentifier: String
    private let migrationDomains: [String]

    init(
        domainIdentifier: String = PearcleanerPreferencesStore.currentDomainIdentifier,
        migrationDomainIdentifiers: [String] = PearcleanerPreferencesStore.migrationDomainIdentifiers
    ) {
        self.domainIdentifier = domainIdentifier
        self.migrationDomains = migrationDomainIdentifiers

        migrateMissingFolderPreferences()
    }

    func stringArray(for key: FolderPreferenceKey) -> [String]? {
        synchronize(domainIdentifier)
        return storedValue(for: key, domainIdentifier: domainIdentifier) as? [String]
    }

    func set(_ value: [String], for key: FolderPreferenceKey) {
        CFPreferencesSetValue(
            key.rawValue as CFString,
            value as CFArray,
            domainIdentifier as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        synchronize(domainIdentifier)
    }

    private func migrateMissingFolderPreferences() {
        synchronize(domainIdentifier)
        for sourceDomain in migrationDomains {
            synchronize(sourceDomain)
        }

        for key in FolderPreferenceKey.allCases
        where storedValue(for: key, domainIdentifier: domainIdentifier) == nil {
            var foundStoredArray = false
            var migratedValues: [String] = []
            var seenValues = Set<String>()

            for sourceDomain in migrationDomains {
                guard let sourceValues = storedValue(
                    for: key,
                    domainIdentifier: sourceDomain
                ) as? [String] else {
                    continue
                }

                foundStoredArray = true
                for value in sourceValues where seenValues.insert(value).inserted {
                    migratedValues.append(value)
                }
            }

            if foundStoredArray {
                set(migratedValues, for: key)
            }
        }
    }

    private func storedValue(
        for key: FolderPreferenceKey,
        domainIdentifier: String
    ) -> Any? {
        CFPreferencesCopyValue(
            key.rawValue as CFString,
            domainIdentifier as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }

    private func synchronize(_ domainIdentifier: String) {
        CFPreferencesSynchronize(
            domainIdentifier as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }
}
