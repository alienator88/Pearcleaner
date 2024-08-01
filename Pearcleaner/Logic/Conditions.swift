//
//  Conditions.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/15/24.
//

import Foundation
import SwiftData

struct Condition: Codable {
    var bundle_id: String
    var include: [String]
    var exclude: [String]
    var includeForce: [URL]?
    var excludeForce: [URL]?

    init(bundle_id: String, include: [String], exclude: [String], includeForce: [String]? = nil, excludeForce: [String]? = nil) {
        self.bundle_id = bundle_id.pearFormat()
        self.include = include.map { $0.pearFormat() }
        self.exclude = exclude.map { $0.pearFormat() }
        self.includeForce = includeForce?.compactMap { path in
            if let url = URL(string: path), FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            return nil
        }
        self.excludeForce = excludeForce?.compactMap { path in
            if let url = URL(string: path), FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            return nil
        }
    }
}

struct SkipCondition {
    var skipPrefix: String
    var allowPrefixes: [String]
}



// Conditions for some apps that need to include/exclude certain files/folders when names are more complicated
var conditions: [Condition] = [
    Condition(
        bundle_id: "com.apple.dt.xcode",
        include: ["com.apple.dt", "xcode", "simulator"],
        exclude: ["com.robotsandpencils.xcodesapp", "com.oneminutegames.xcodecleaner", "io.hyperapp.xcodecleaner", "xcodes.json"],
        includeForce: ["\(home)/Library/Containers/com.apple.iphonesimulator.ShareExtension"]
    ),
    Condition(
        bundle_id: "com.robotsandpencils.xcodesapp",
        include: [],
        exclude: ["com.apple.dt.xcode", "com.oneminutegames.xcodecleaner", "io.hyperapp.xcodecleaner"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "io.hyperapp.xcodecleaner",
        include: [],
        exclude: ["com.robotsandpencils.xcodesapp", "com.oneminutegames.xcodecleaner", "com.apple.dt.xcode", "xcodes.json"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "us.zoom.xos",
        include: ["zoom"],
        exclude: [],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.brave.browser",
        include: ["brave"],
        exclude: [],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.okta.mobile",
        include: ["okta"],
        exclude: [],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.google.chrome",
        include: ["google", "chrome"],
        exclude: ["iterm", "chromefeaturestate"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.microsoft.edgemac",
        include: ["microsoft"],
        exclude: ["vscode", "rdc", "appcenter", "office", "oneauth"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "org.mozilla.firefox",
        include: ["mozilla", "firefox"],
        exclude: [],
        includeForce: nil
    ),
    Condition(
        bundle_id: "org.mozilla.firefox.nightly",
        include: ["mozilla", "firefox"],
        exclude: [],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.logi.optionsplus",
        include: ["logi"],
        exclude: ["login", "logic"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.microsoft.vscode",
        include: ["vscode"],
        exclude: [],
        includeForce: ["\(home)/Library/Application Support/Code/"]
    ),
    Condition(
        bundle_id: "com.facebook.archon.developerid",
        include: ["archon.loginhelper"],
        exclude: [],
        includeForce: nil
    ),
    Condition(
        bundle_id: "eu.exelban.stats",
        include: [],
        exclude: ["video"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "jetbrains",
        include: ["jetbrains", "jcef"],
        exclude: [],
        includeForce: nil
    ),
]



// Skip com.apple files/folders since most are system originated, allow some for apps
let skipConditions: [SkipCondition] = [
    SkipCondition(
        skipPrefix: "comapple",
        allowPrefixes: ["comappleconfigurator", "comappledt", "comappleiwork", "comapplesfsymbols", "comappletestflight"]
    )
]


// Skip files/folders during leftover file search
let skipReverse = ["apple", "temporary", "btserver", "proapps", "scripteditor", "ilife", "livefsd", "siritoday", "addressbook", "animoji", "appstore", "askpermission", "callhistory", "clouddocs", "diskimages", "dock", "facetime", "fileprovider", "instruments", "knowledge", "mobilesync", "syncservices", "homeenergyd", "icloud", "icdd", "networkserviceproxy", "familycircle", "geoservices", "installation", "passkit", "sharedimagecache", "desktop", "mbuseragent", "swiftpm", "baseband", "coresimulator", "photoslegacyupgrade", "photosupgrade", "siritts", "ipod", "globalpreferences", "apmanalytics", "apmexperiment", "avatarcache", "byhost", "contextstoreagent", "mobilemeaccounts", "mobiledocuments", "mobile", "intentbuilderc", "loginwindow", "momc", "replayd", "sharedfilelistd", "clang", "audiocomponent", "csexattrcryptoservice", "livetranscriptionagent", "sandboxhelper", "statuskitagent", "betaenrollmentd", "contentlinkingd", "diagnosticextensionsd", "gamed", "heard", "homed", "itunescloudd", "lldb", "mds", "mediaanalysisd", "metrickitd", "mobiletimerd", "proactived", "ptpcamerad", "studentd", "talagent", "watchlistd", "apptranslocation", "xcrun", "ds_store", "caches", "crashreporter", "trash", "pearcleaner", "amsdatamigratortool", "arfilecache", "assistant", "chromium", "cloudkit", "webkit", "databases", "diagnostic", "cache", "gamekit", "homebrew", "logi", "microsoft", "mozilla", "sync", "google", "sentinel", "hexnode", "sentry", "tvappservices", "reminders"]






// Store and load conditions locally via SwiftData
class ConditionManager {
    static let shared = ConditionManager()

    private init() {
        loadConditions()
    }

    // Function to save a condition
    func saveCondition(_ condition: Condition) {
        if condition.include.isEmpty && condition.exclude.isEmpty && (condition.includeForce?.isEmpty ?? true) {
            deleteCondition(bundle_id: condition.bundle_id)
            return
        }
        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()
        let key = "Condition-\(condition.bundle_id)"

        if let encoded = try? encoder.encode(condition) {
            defaults.set(encoded, forKey: key)
            conditions.append(condition)
        }
    }

    // Function to delete a condition from defaults and conditions variable
    func deleteCondition(bundle_id: String) {
        let defaults = UserDefaults.standard
        let key = "Condition-\(bundle_id.pearFormat())"

        // Remove from UserDefaults
        defaults.removeObject(forKey: key)

        // Remove from conditions variable
        conditions.removeAll { $0.bundle_id == bundle_id.pearFormat() }
    }

    // Function to load a condition and append to the global variable
    func loadConditions() {
        let defaults = UserDefaults.standard
        let decoder = JSONDecoder()

        for (key, value) in defaults.dictionaryRepresentation() {
            if key.starts(with: "Condition-"), let savedCondition = value as? Data {
                if let loadedCondition = try? decoder.decode(Condition.self, from: savedCondition) {
                    conditions.append(loadedCondition)
                }
            }
        }
    }

    
}
