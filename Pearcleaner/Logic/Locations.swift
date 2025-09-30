//
//  Locations.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/10/23.
//

import Foundation


class Locations: ObservableObject {
    struct Category {
        let name: String
        var paths: [String]
    }

    struct PluginCategory {
        let name: String
        var subcategories: [String: [String]]
    }

    let cacheDir: String
    let tempDir: String

    var apps: Category
    var reverse: Category
    var plugins: PluginCategory

    init() {
        let (cacheDir, tempDir) = darwinCT()
        self.cacheDir = cacheDir
        self.tempDir = tempDir

        self.apps = Category(name: "Apps", paths: [
            "\(home)",
            "\(home)/.config",
            "\(home)/Documents",
            "\(home)/Desktop", // for steam game shortcuts
            "\(home)/Applications",
            "\(home)/Library",
            "\(home)/Library/Application Scripts",
            "\(home)/Library/Application Support",
            "\(home)/Library/Application Support/Steam/steamapps",
            "\(home)/Library/Application Support/Steam/steamapps/common",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments",
            "\(home)/Library/Containers",
            "\(home)/Library/Caches",
            "\(home)/Library/Caches/com.crashlytics",
            "\(home)/Library/Caches/com.google.SoftwareUpdate",
            "\(home)/Library/Caches/com.google.Keystone",
            "\(home)/Library/Caches/org.sparkle-project.Sparkle",
            "\(home)/Library/Caches/com.segment.analytics",
            "\(home)/Library/Caches/SentryCrash",
            "\(home)/Library/Caches/Rollbar",
            "\(home)/Library/Caches/Amplitude",
            "\(home)/Library/Caches/Realm",
            "\(home)/Library/Caches/Parse",
            "\(home)/Library/Group Containers",
            "\(home)/Library/HTTPStorages",
            "\(home)/Library/Internet Plug-Ins",
            "\(home)/Library/LaunchAgents",
            "\(home)/Library/Logs",
            "\(home)/Library/Logs/DiagnosticReports",
            "\(home)/Library/Preferences",
            "\(home)/Library/PreferencePanes",
            "\(home)/Library/Preferences/ByHost",
            "\(home)/Library/Saved Application State",
            "\(home)/Library/Services",
            "\(home)/Library/WebKit",
            "/Applications",
            "/Users/Shared",
            "/Users/Library",
            "/Users/Shared/Library/Application Support",
            "/Library",
            "/Library/Application Support",
            "/Library/Application Support/CrashReporter",
            "/Library/Caches",
            "/Library/Extensions",
            "/Library/Internet Plug-Ins",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            "/Library/Logs",
            "/Library/Logs/DiagnosticReports",
            "/Library/Preferences",
            "/Library/PrivilegedHelperTools",
            "/private/var/db/receipts",
            "/private/tmp",
            "/usr/local/bin",
            "/usr/local/etc",
            "/usr/local/opt",
            "/usr/local/sbin",
            "/usr/local/share",
            "/usr/local/var",
            cacheDir,
            tempDir
        ])

        // Append Application Support subfolders for deeper search
        let subfolders = listAppSupportDirectories()
        for folder in subfolders {
            self.apps.paths.append("\(home)/Library/Application Support/\(folder)")
        }




        self.reverse = Category(name: "Reverse", paths: [
            "\(home)/Library/Application Scripts",
            "\(home)/Library/Application Support",
            "\(home)/Library/Application Support/Caches",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments",
            "\(home)/Library/Containers",
            "\(home)/Library/Caches",
            "\(home)/Library/HTTPStorages",
            "\(home)/Library/Internet Plug-Ins",
            "\(home)/Library/LaunchAgents",
            "\(home)/Library/Logs",
            "\(home)/Library/Preferences",
            "\(home)/Library/PreferencePanes",
            "\(home)/Library/Preferences/ByHost",
            "\(home)/Library/Saved Application State",
            "\(home)/Library/WebKit",
            "/Users/Shared/Library/Application Support",
            "/Library/Application Support",
            "/Library/Application Support/CrashReporter",
            "/Library/Internet Plug-Ins",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            "/Library/PrivilegedHelperTools",
        ])

        self.plugins = PluginCategory(name: "Plugins", subcategories: [
            "Audio": [
                // Audio Components, VST, AU, etc.
                "\(home)/Library/Audio/Plug-Ins/Components",
                "\(home)/Library/Audio/Plug-Ins/HAL",
                "\(home)/Library/Audio/Plug-Ins/MAS",
                "\(home)/Library/Audio/Plug-Ins/VST",
                "\(home)/Library/Audio/Plug-Ins/VST3",
                "\(home)/Library/Audio/Plug-Ins/CLAP",
                "/Library/Audio/Plug-Ins/HAL",
                "/Library/Audio/Plug-Ins/VST",
                "/Library/Audio/Plug-Ins/VST3",
                "/Library/Audio/Plug-Ins/CLAP",
                "/Library/Audio/Plug-Ins/Components",
                "/Library/Application Support/Avid/Audio/Plug-Ins",
                "/Library/Application Support/Digidesign/Plug-Ins"
            ],

            "PreferencePanes": [
                // System Preference Panes (.prefPane)
                "/Library/PreferencePanes",
                "\(home)/Library/PreferencePanes"
            ],

            "QuickLook": [
                // QuickLook Generators (.qlgenerator)
                "/Library/QuickLook",
                "\(home)/Library/QuickLook"
            ],

            "Screen Savers": [
                // Screen Savers (.saver)
                "/Library/Screen Savers",
                "\(home)/Library/Screen Savers"
            ],

            "Internet Plug-Ins": [
                // Browser plugins (.plugin, .webplugin)
                "/Library/Internet Plug-Ins",
                "\(home)/Library/Internet Plug-Ins"
            ],

            "Core Image": [
                // Core Image filters (.plugin)
                "/Library/CoreImage",
                "\(home)/Library/CoreImage"
            ],

            "ColorPickers": [
                // Color Picker plugins (.colorPicker)
                "/Library/ColorPickers",
                "\(home)/Library/ColorPickers"
            ],

            "Fonts": [
                // Font files (.ttf, .otf, .dfont, .ttc)
                "\(home)/Library/Fonts",
            ],

            "Dictionaries": [
                // Dictionary files (.dictionary)
                "/Library/Dictionaries",
                "\(home)/Library/Dictionaries"
            ],

            "Automator": [
                // Automator Actions (.action, .workflow)
                "/Library/Automator",
                "\(home)/Library/Automator"
            ],

            "Safari Extensions": [
                // Safari Extensions (.safariextz, .appex)
                "/Library/Safari/Extensions",
                "\(home)/Library/Safari/Extensions"
            ],

            "Motion Templates": [
                // Final Cut Pro and Motion templates
                "\(home)/Movies/Motion Templates",
                "/Library/Application Support/Final Cut Pro System Support/Plug-ins"
            ],

            "Spotlight": [
                // Spotlight importers (.mdimporter)
                "/Library/Spotlight",
                "\(home)/Library/Spotlight"
            ],

            "Services": [
                // System Services (.service)
                "/Library/Services",
                "\(home)/Library/Services"
            ],

            "Address Book": [
                // Address Book plugins
                "\(home)/Library/Address Book Plug-Ins"
            ],

            "Contextual Menu": [
                // Context menu plugins
                "/Library/Contextual Menu Items",
                "\(home)/Library/Contextual Menu Items"
            ],

            "Input Methods": [
                // Input method editors
                "/Library/Input Methods",
                "\(home)/Library/Input Methods"
            ],

            "Widgets": [
                // Dashboard and notification widgets (.wdgt, .appex)
                "/Library/Widgets",
                "\(home)/Library/Widgets"
            ]
        ])
    }
}
