//
//  AppState.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI

let home = FileManager.default.homeDirectoryForCurrentUser.path

class AppState: ObservableObject
{
    @Published var appInfo: AppInfo
    @Published var paths: [URL] = []
    @Published var sortedApps: (userApps: [AppInfo], systemApps: [AppInfo]) = ([], [])
    @Published var selectedItems = Set<URL>()
    @Published var alertType = AlertType.off
    @Published var currentView = CurrentDetailsView.empty
    @Published var showAlert: Bool = false
    @Published var sidebar: Bool = true
    @Published var isReminderVisible: Bool = false
    @Published var releases = [Release]()
    @Published var progressBar: (String, Double) = ("Ready", 0.0)
//    @Published var progressManager = ProgressManager()
    @Published var reload: Bool = false

    
    //Window
//    @Published var winWidth: CGFloat = 1020
    
    init() {
        self.appInfo = AppInfo(
            id: UUID(),
            path: URL(fileURLWithPath: ""),
            bundleIdentifier: "",
            appName: "",
            appVersion: "",
            appIcon: nil,
            webApp: false,
            wrapped: false
        )
    }
}


//class ProgressManager: ObservableObject {
//    @Published var progress: Double = 0.0
//    @Published var total: Double = 0.0
//    @Published var status: String = "Ready"
//
//    func setTotal(_ total: Double) {
//        DispatchQueue.main.async {
//            self.total = total
//        }
//    }
//
//    func updateProgress() {
//        DispatchQueue.main.async {
//            self.progress = min(max(0.0, self.progress + 1.0), Double(self.total))
//        }
//    }
//
//    func updateStatus(status: String) {
//        DispatchQueue.main.async {
//            self.status = status
//        }
//    }
//
//    func resetProgress() {
//        DispatchQueue.main.async {
//            self.progress = 0.0
//        }
//    }
//}



struct AppInfo: Identifiable, Hashable {
    let id: UUID
    let path: URL
    let bundleIdentifier: String
    let appName: String
    let appVersion: String
    let appIcon: NSImage?
    let webApp: Bool
    let wrapped: Bool

    static let empty = AppInfo(id: UUID(), path: URL(fileURLWithPath: ""), bundleIdentifier: "", appName: "", appVersion: "", appIcon: nil, webApp: false, wrapped: false)
}


enum CurrentTabView:Int
{
    case general
    case permissions
    case sentinel
    case update
    case about
    
    var title: String {
        switch self {
        case .general: return "General"
        case .permissions: return "Permissions"
        case .sentinel: return "Sentinel"
        case .update: return "Update"
        case .about: return "About"
        }
    }
}

enum CurrentDetailsView:Int
{
    case empty
    case files
    case apps
}

enum NewWindow:Int
{
    case update
    case no_update
    case perm
}


enum AlertType:Int
{
    case diskAccess
    case update
    case no_update
    case restartApp
    case off
}



enum DisplayMode: Int, CaseIterable {
    case system, dark, light
    
    var colorScheme: ColorScheme? {
        get {
            switch self {
            case .system: return nil
            case .dark: return ColorScheme.dark
            case .light: return ColorScheme.light
            }
        }
        set {
            switch newValue {
            case .none:
                self = .system
            case .dark?:
                self = .dark
            case .light?:
                self = .light
            default:
                break
            }
        }
    }
    
    var description: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
}



//let (cacheDir, tempDir) = darwinCT()
//let locations: [String] = [
//    "\(home)/Library",
//    "\(home)/Library/Application Scripts",
//    "\(home)/Library/Application Support",
//    "\(home)/Library/Application Support/CrashReporter",
//    "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments",
//    "\(home)/Library/Containers",
//    "\(home)/Library/Group Containers",
//    "\(home)/Library/Caches",
//    "\(home)/Library/HTTPStorages",
//    "\(home)/Library/Group Containers",
//    "\(home)/Library/Internet Plug-Ins",
//    "\(home)/Library/LaunchAgents",
//    "\(home)/Library/Logs",
//    "\(home)/Library/Preferences",
//    "\(home)/Library/Preferences/ByHost",
//    "\(home)/Library/Saved Application State",
//    "\(home)/Library/WebKit",
//    "/Users/Shared",
//    "/Users/Library",
//    "/Library",
//    "/Library/Application Support",
//    "/Library/Application Support/CrashReporter",
//    "/Library/Caches",
//    "/Library/Extensions",
//    "/Library/Internet Plug-Ins",
//    "/Library/LaunchAgents",
//    "/Library/LaunchDaemons",
//    "/Library/Logs",
//    "/Library/Logs/DiagnosticReports",
//    "/Library/Preferences",
//    "/Library/PrivilegedHelperTools",
//    "/private/var/db/receipts",
//    "/private/tmp",
//    "/usr/local/bin",
//    "/usr/local/etc",
//    "/usr/local/opt",
//    "/usr/local/sbin",
//    "/usr/local/share",
//    "/usr/local/var",
//    cacheDir,
//    tempDir
//]
