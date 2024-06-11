//
//  AppState.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI
import FinderSync

let home = FileManager.default.homeDirectoryForCurrentUser.path

class AppState: ObservableObject {
    @Published var appInfo: AppInfo
    @Published var appInfoStore: [AppInfo] = []
    @Published var trashedFiles: [AppInfo] = []
    @Published var zombieFile: ZombieFile
    @Published var sortedApps: [AppInfo] = []
    @Published var selectedItems = Set<URL>()
    @Published var alertType = AlertType.off
    @Published var currentView = CurrentDetailsView.empty
    @Published var showAlert: Bool = false
    @Published var sidebar: Bool = true
    @Published var releases = [Release]()
    @Published var progressBar: (String, Double) = ("Ready", 0.0)
    @Published var reload: Bool = false
    @Published var showProgress: Bool = false
    @Published var finderExtensionEnabled: Bool = false
    @Published var updateAvailable: Bool = false
    @Published var featureAvailable: Bool = false
    @Published var permissionsOkay: Bool = true
    @Published var permissionResults: PermissionsCheckResults?
    @Published var showUninstallAlert: Bool = false
    @Published var oneShotMode: Bool = false



    init() {
        self.appInfo = AppInfo(
            id: UUID(),
            path: URL(fileURLWithPath: ""),
            bundleIdentifier: "",
            appName: "",
            appVersion: "",
            appIcon: nil,
            webApp: false,
            wrapped: false,
            system: false,
            bundleSize: 0,
            files: [],
            fileSize: [:],
            fileSizeLogical: [:],
            fileIcon: [:]
        )

        self.zombieFile = ZombieFile(
            id: UUID(),
            fileSize: [:],
            fileSizeLogical: [:],
            fileIcon: [:]
        )

        updateExtensionStatus()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateExtensionStatus),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

    }

    @objc func updateExtensionStatus() {
        let extensionStatus = FIFinderSyncController.isExtensionEnabled
        DispatchQueue.main.async {
            self.finderExtensionEnabled = extensionStatus
        }
    }

    func triggerUninstallAlert() {
        self.showUninstallAlert = true
    }

}






struct AppInfo: Identifiable, Equatable, Hashable {
    let id: UUID
    let path: URL
    let bundleIdentifier: String
    let appName: String
    let appVersion: String
    let appIcon: NSImage?
    let webApp: Bool
    let wrapped: Bool
    let system: Bool
    var bundleSize: Int64
    var files: [URL]
    var fileSize: [URL:Int64]
    var fileSizeLogical: [URL:Int64]
    var fileIcon: [URL:NSImage?]
    var totalSize: Int64 
    {
        return fileSize.values.reduce(0, +)
    }
    var totalSizeLogical: Int64
    {
        return fileSizeLogical.values.reduce(0, +)
    }


    static let empty = AppInfo(id: UUID(), path: URL(fileURLWithPath: ""), bundleIdentifier: "", appName: "", appVersion: "", appIcon: nil, webApp: false, wrapped: false, system: false, bundleSize: 0, files: [], fileSize: [:], fileSizeLogical: [:], fileIcon: [:])

}



struct ZombieFile: Identifiable, Equatable, Hashable {
    let id: UUID
    var fileSize: [URL:Int64]
    var fileSizeLogical: [URL:Int64]
    var fileIcon: [URL:NSImage?]
    var totalSize: Int64
    {
        return fileSize.values.reduce(0, +)
    }
    var totalSizeLogical: Int64
    {
        return fileSizeLogical.values.reduce(0, +)
    }


    static let empty = ZombieFile(id: UUID(), fileSize: [:], fileSizeLogical: [:], fileIcon: [:])

}





enum CurrentTabView:Int
{
    case general
    case interface
    case folders
    case update
    case about
    
    var title: String {
        switch self {
        case .general: return "General"
        case .interface: return "Interface"
        case .folders: return "Folders"
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
    case zombie
}

enum NewWindow:Int
{
    case update
    case no_update
    case perm
    case feature
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
