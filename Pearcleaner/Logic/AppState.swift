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
    @Published var currentView = CurrentDetailsView.empty
    @Published var showAlert: Bool = false
    @Published var sidebar: Bool = true
    @Published var reload: Bool = false
    @Published var showProgress: Bool = false
    @Published var finderExtensionEnabled: Bool = false
    @Published var showUninstallAlert: Bool = false
    @Published var oneShotMode: Bool = false
    @Published var showConditionBuilder: Bool = false



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
            arch: .empty,
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
    var arch: Arch
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


    static let empty = AppInfo(id: UUID(), path: URL(fileURLWithPath: ""), bundleIdentifier: "", appName: "", appVersion: "", appIcon: nil, webApp: false, wrapped: false, system: false, arch: .empty, bundleSize: 0, files: [], fileSize: [:], fileSizeLogical: [:], fileIcon: [:])

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


enum Arch {
    case arm
    case intel
    case universal
    case empty
}


enum CurrentTabView:Int
{
    case general
    case interface
    case folders
    case update
    case tips
    case about
    
    var title: String {
        switch self {
        case .general: return "General"
        case .interface: return "Interface"
        case .folders: return "Folders"
        case .update: return "Update"
        case .tips: return "Tips"
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
