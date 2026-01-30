//
//  Conditions.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/15/24.
//

import Foundation

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
    var skipPrefix: [String]
    var allowPrefixes: [String]
    var skipPaths: [String]
}



// Conditions for some apps that need to include/exclude certain files/folders when names are more complicated
var conditions: [Condition] = [
    Condition(
        bundle_id: "com.apple.dt.xcode",
        include: ["com.apple.dt", "xcode", "simulator"],
        exclude: ["com.robotsandpencils.xcodesapp", "com.xcodesorg.xcodesapp", "com.oneminutegames.xcodecleaner", "io.hyperapp.xcodecleaner", "available-xcodes", "xcodes", "cleaner for xcode"],
        includeForce: ["\(home)/Library/Containers/com.apple.iphonesimulator.ShareExtension"]
    ),
    Condition(
        bundle_id: "com.robotsandpencils.xcodesapp",
        include: [],
        exclude: ["com.apple.dt.xcode", "com.oneminutegames.xcodecleaner", "io.hyperapp.xcodecleaner"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.xcodesorg.xcodesapp",
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
        exclude: ["iterm", "chromefeaturestate", "monochrome"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.microsoft.edgemac",
        include: [],
        exclude: ["vscode", "rdc", "appcenter", "office", "oneauth"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.microsoft.teams2",
        include: [],
        exclude: ["office"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "org.mozilla.firefox",
        include: ["firefox"],
        exclude: ["thunderbird"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "org.mozilla.thunderbird",
        include: [],
        exclude: ["firefox"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "org.mozilla.firefox.nightly",
        include: ["mozilla", "firefox"],
        exclude: ["thunderbird"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.logi.optionsplus",
        include: ["logi", "logipluginservice"],
        exclude: ["login", "logic"],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.microsoft.VSCode",
        include: ["vscode"],
        exclude: ["vscodeinsiders", "insiders"],
        includeForce: ["\(home)/Library/Application Support/Code/"]
    ),
    Condition(
        bundle_id: "com.microsoft.VSCodeInsiders",
        include: ["vscodeinsiders", "insiders"],
        exclude: [],
        includeForce: ["\(home)/Library/Application Support/Code - Insiders/"]
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
        bundle_id: "me.mhaeuser.BatteryToolkit",
        include: ["memhaeuser"],
        exclude: [],
        includeForce: nil
    ),
    Condition(
        bundle_id: "jetbrains",
        include: ["jcef"],
        exclude: [],
        includeForce: ["\(home)/Library/Application Support/JetBrains/", "\(home)/Library/Caches/JetBrains/", "\(home)/Library/Logs/JetBrains/"]
    ),
    Condition(
        bundle_id: "company.thebrowser.Browser",
        include: ["firestore"],
        exclude: [],
        includeForce: ["\(home)/Library/Application Support/Arc/", "\(home)/Library/Caches/Arc/"]
    ),
    Condition(
        bundle_id: "com.1password.1password",
        include: ["waveboxapp", "sidekick"],
        exclude: [],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.now.gg.BlueStacks",
        include: ["bst_boost_interprocess"],
        exclude: [],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.electron.sdm",
        include: ["strongdm"],
        exclude: [],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.github.githubclient",
        include: ["comgithubelectron"],
        exclude: [],
        includeForce: nil
    ),
    Condition(
        bundle_id: "com.native-instruments.nativeaccess",
        include: ["comnative", "nativeinstruments"],
        exclude: [],
        includeForce: nil
    ),
]



// Skip some system files/folders
let skipConditions: [SkipCondition] = [
    SkipCondition(
        skipPrefix: ["mobiledocuments", "reminders", "dsstore", "comapplepasswordmanager"],
        allowPrefixes: ["comappleconfigurator", "comappledt", "comappleiwork", "comapplesfsymbols", "comappletestflight", "comapplesharedfilelist", "comapplelssharedfilelist"],
        skipPaths: ["\(home)/.Trash", "/Library/SystemExtensions", "/System/Volumes/Preboot/Cryptexes/App/System/Library/CoreServices/PasswordManagerBrowserExtensionHelper.app/Contents/MacOS/PasswordManagerBrowserExtensionHelper", "\(home)/Library/Application Support/Chromium/NativeMessagingHosts/com.apple.passwordmanager.json", "\(home)/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.apple.passwordmanager.json"]
    )
]


// Library subdirectories that should be excluded from deep (depth=2) search
// These are macOS system directories that never contain third-party app files
let skipDeepSearch: Set<String> = [
    // Core System
    "Apple", "Audio", "Bluetooth", "ColorSync", "Components", "CoreAnalytics",
    "CoreMediaIO", "DirectoryServices", "Filesystems", "GPUBundles", "Graphics",
    "KernelCollections", "OSAnalytics", "OpenDirectory", "Sandbox", "Security",
    "SystemExtensions", "SystemMigration", "SystemProfiler", "StagedDriverExtensions",
    "StagedExtensions", "StartupItems",

    // User Data & System Services (should not be searched)
    "Accessibility", "Accounts", "AppleMediaServices", "Assistant", "Assistants",
    "Autosave Information", "Biome", "Calendars", "CallServices", "CloudStorage",
    "Contacts", "Cookies", "DataAccess", "DataDeliveryServices", "DoNotDisturb",
    "DuetExpertCenter", "Finance", "FinanceBackup", "FrontBoard", "GameKit",
    "GroupContainersAlias", "HomeKit", "IdentityServices", "IntelligencePlatform",
    "Intents", "KeyboardServices", "LanguageModeling", "LockdownMode", "Mail",
    "MediaAnalysis", "Messages", "Metadata", "Mobile Documents", "MobileDevice",
    "News", "Passes", "PersonalizationPortrait", "Photos", "PrivateCloudCompute",
    "Reminders", "ResponseKit", "Safari", "SafariSafeBrowsing", "SafariSandboxBroker",
    "ScreenRecordings", "StatusKit", "Suggestions", "SyncedPreferences", "Translation",
    "UnifiedAssetFramework", "Weather", "homeenergyd", "studentd",

    // Development/System Tools
    "Developer", "Perl", "Ruby", "Java", "Python", "Catacomb", "InstallerSandboxes",
    "Trial", "Updates", "Staging", "ContainerManager", "Daemon Containers",

    // Additional System Directories
    "ColorPickers", "Colors", "Compositions", "Contextual Menu Items", "Documentation",
    "DriverExtensions", "Favorites", "FontCollections", "Fonts", "Image Capture",
    "Input Methods", "Jupyter", "Keyboard", "Keyboard Layouts", "Keychains",
    "Managed Preferences", "PDF Services", "Printers", "QuickLook", "Receipts",
    "Screen Savers", "ScriptingAdditions", "Scripts", "Sharing", "Shortcuts",
    "Sounds", "Speech", "Spelling", "Spotlight", "User Pictures", "User Template",
    "Video", "WebServer", "Workflows",

    // Apple service bundles (com.apple.*)
    "com.apple.AppleMediaServices", "com.apple.WatchListKit", "com.apple.aiml.instrumentation",
    "com.apple.appleaccountd", "com.apple.bluetooth.services.cloud", "com.apple.bluetoothuser",
    "com.apple.familycircled", "com.apple.iTunesCloud", "com.apple.internal.ck"
]


// Skip files/folders during orphaned file search
let skipReverse = ["apple", "temporary", "btserver", "proapps", "scripteditor", "ilife", "livefsd", "siritoday", "addressbook", "animoji", "appstore", "askpermission", "callhistory", "clouddocs", "diskimages", "dock", "facetime", "fileprovider", "instruments", "knowledge", "mobilesync", "syncservices", "homeenergyd", "icloud", "icdd", "networkserviceproxy", "familycircle", "geoservices", "installation", "passkit", "sharedimagecache", "desktop", "mbuseragent", "swiftpm", "baseband", "coresimulator", "photoslegacyupgrade", "photosupgrade", "siritts", "ipod", "globalpreferences", "apmanalytics", "apmexperiment", "avatarcache", "byhost", "contextstoreagent", "mobilemeaccounts", "mobiledocuments", "mobile", "intentbuilderc", "loginwindow", "momc", "replayd", "sharedfilelistd", "clang", "audiocomponent", "csexattrcryptoservice", "livetranscriptionagent", "sandboxhelper", "statuskitagent", "betaenrollmentd", "contentlinkingd", "diagnosticextensionsd", "gamed", "heard", "homed", "itunescloudd", "lldb", "mds", "mediaanalysisd", "metrickitd", "mobiletimerd", "proactived", "ptpcamerad", "studentd", "talagent", "watchlistd", "apptranslocation", "xcrun", "ds_store", "caches", "crashreporter", "trash", "pearcleaner", "amsdatamigratortool", "arfilecache", "assistant", "chromium", "cloudkit", "webkit", "databases", "diagnostic", "cache", "gamekit", "homebrew", "logi", "microsoft", "mozilla", "sync", "google", "sentinel", "hexnode", "sentry", "tvappservices", "reminders", "pbs", "notarytool", "differentialprivacy", "storeassetd", "webpush", "storedownloadd", "fsck", "crash", "python", "discrecording", "photossearch", "pylint", "jamf", "scopedbookmarkagent", "anonymous", "identifier", "isolated", "nobackup", "privacypreservingmeasurement", "symbols", "stickersd", "privatecloudcomputed", "tipsd", "controlcenter", "contactsd", "staticcheck", "index", "segment", "sparkle", "summaryevents", "launchdarkly", "identityservicesd", "embeddedbinaryvalidationutility", "comalienator88", "aaprofilepicture", "minilauncher", "jna", "automator", "locationaccessstored", "spotlight", "cef"]
