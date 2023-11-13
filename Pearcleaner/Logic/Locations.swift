//
//  Locations.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/10/23.
//

import Foundation


struct Locations {
    struct Category {
        let name: String
        var paths: [String]
    }
    
    let home: String
    let cacheDir: String
    let tempDir: String
    
    var apps: Category
    var widgets: Category
    var plugins: Category
    
    init() {
        self.home = FileManager.default.homeDirectoryForCurrentUser.path
        let (cacheDir, tempDir) = darwinCT()
        self.cacheDir = cacheDir
        self.tempDir = tempDir
        
        self.apps = Category(name: "Apps", paths: [
            "\(home)/Library",
            "\(home)/Library/Application Scripts",
            "\(home)/Library/Application Support",
            "\(home)/Library/Application Support/CrashReporter",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments",
            "\(home)/Library/Containers",
            "\(home)/Library/Group Containers",
            "\(home)/Library/Caches",
            "\(home)/Library/HTTPStorages",
            "\(home)/Library/Group Containers",
            "\(home)/Library/Internet Plug-Ins",
            "\(home)/Library/LaunchAgents",
            "\(home)/Library/Logs",
            "\(home)/Library/Preferences",
            "\(home)/Library/Preferences/ByHost",
            "\(home)/Library/Saved Application State",
            "\(home)/Library/WebKit",
            "/Users/Shared",
            "/Users/Library",
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
        
        self.widgets = Category(name: "Widgets", paths: [
            // User
            "~/Library/Widgets",
            // System
            "/Library/Widgets"
        ])
        
        self.plugins = Category(name: "Plugins", paths: [
            // User
            "~/Library/Contextual Menu Items",
            "~/Library/InputManagers",
            "~/Library/Internet Plug-Ins",
            "~/Library/Mail/Bundles",
            "~/Library/PreferencePanes",
            "~/Library/QuickLook",
            "~/Library/QuickTime",
            "~/Library/Screen Savers",
            "~/Library/Spotlight",
            // System
            "/Library/Contextual Menu Items",
            "/Library/InputManagers",
            "/Library/Internet Plug-Ins",
            "/Library/Mail/Bundles",
            "/Library/PreferencePanes",
            "/Library/QuickLook",
            "/Library/QuickTime",
            "/Library/Screen Savers",
            "/Library/Spotlight",
        ])
    }
}
