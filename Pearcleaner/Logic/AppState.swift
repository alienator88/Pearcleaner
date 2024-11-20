//
//  AppState.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI
import AlinFoundation
//import FinderSync

let home = FileManager.default.homeDirectoryForCurrentUser.path

class AppState: ObservableObject {
    @Published var appInfo: AppInfo
    @Published var trashedFiles: [AppInfo] = []
    @Published var zombieFile: ZombieFile
    @Published var sortedApps: [AppInfo] = []
    @Published var selectedItems = Set<URL>()
    @Published var currentView = CurrentDetailsView.empty
    @Published var currentPage = CurrentPage.applications
    @Published var showAlert: Bool = false
    @Published var sidebar: Bool = true
    @Published var reload: Bool = false
    @Published var showProgress: Bool = false
    @Published var leftoverProgress: (String, Double) = ("", 0.0)
    @Published var finderExtensionEnabled: Bool = false
    @Published var showUninstallAlert: Bool = false
    @Published var sentinelMode: Bool = false
//    @Published var showConditionBuilder: Bool = false
    @Published var externalPaths: [URL] = [] // for handling multiple app from drops or deeplinks

    func getBundleSize(for appInfo: AppInfo, updateState: @escaping (Int64) -> Void) {
        // Step 1: Check if the size is available and not 0 in the sortedApps cache
        if let existingAppInfo = sortedApps.first(where: { $0.path == appInfo.path }),
           existingAppInfo.bundleSize != 0 {
            // Size is available in the cache, update the state
            DispatchQueue.main.async {
                updateState(existingAppInfo.bundleSize)
            }
            return
        }

        // Step 2: If we reach here, we need to calculate the size
        DispatchQueue.global(qos: .userInitiated).async {
            let calculatedSize = totalSizeOnDisk(for: appInfo.path).logical
            DispatchQueue.main.async {
                // Update the state and the array
                updateState(calculatedSize)
                if let index = self.sortedApps.firstIndex(where: { $0.path == appInfo.path }) {
                    self.sortedApps[index].bundleSize = calculatedSize
                }
            }
        }
    }

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
//            files: [],
            fileSize: [:],
            fileSizeLogical: [:],
            fileIcon: [:],
            creationDate: nil,
            contentChangeDate: nil,
            lastUsedDate: nil
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
        let task = Process()
        let pipe = Pipe()

        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", "pluginkit -m -i com.alienator88.Pearcleaner"]
        task.standardOutput = pipe
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        if let output = String(data: data, encoding: .utf8) {
            // Check if the output starts with a '+' indicating it's enabled
            let extensionStatus = output.contains("+")
            DispatchQueue.main.async {
                self.finderExtensionEnabled = extensionStatus
            }
        }
//        let extensionStatus = FIFinderSyncController.isExtensionEnabled
//        DispatchQueue.main.async {
//            self.finderExtensionEnabled = extensionStatus
//        }
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
    var bundleSize: Int64 // Only used in the app list view
//    var files: [URL]
    var fileSize: [URL:Int64]
    var fileSizeLogical: [URL:Int64]
    var fileIcon: [URL:NSImage?]
    let creationDate: Date?
    let contentChangeDate: Date?
    let lastUsedDate: Date?
    var totalSize: Int64
    {
        return fileSize.values.reduce(0, +)
    }
    var totalSizeLogical: Int64
    {
        return fileSizeLogical.values.reduce(0, +)
    }

    var isEmpty: Bool {
        return path == URL(fileURLWithPath: "./") && bundleIdentifier.isEmpty && appName.isEmpty
    }

    static let empty = AppInfo(id: UUID(), path: URL(fileURLWithPath: ""), bundleIdentifier: "", appName: "", appVersion: "", appIcon: nil, webApp: false, wrapped: false, system: false, arch: .empty, bundleSize: 0, fileSize: [:], fileSizeLogical: [:], fileIcon: [:], creationDate: nil, contentChangeDate: nil, lastUsedDate: nil)

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

enum CurrentPage:Int, CaseIterable, Identifiable
{
    case applications
    case orphans
    case development

    var id: Int { rawValue }

    var details: (title: String, icon: String) {
        switch self {
        case .applications:
            return (String(localized: "Applications"), "square.grid.3x3.fill.square")
        case .orphans:
            return (String(localized: "Orphaned Files"), "doc.text.magnifyingglass")
        case .development:
            return (String(localized: "Development"), "hammer.circle")
        }
    }

    var title: String { details.title }
    var icon: String { details.icon }
}

enum SortOption:Int, CaseIterable, Identifiable {
    case alphabetical
    case size
    case creationDate
    case contentChangeDate
    case lastUsedDate

    var id: Int { rawValue }

    var title: String {
        let titles: [String] = [
            String(localized: "App Name"),
            String(localized: "App Size"),
            String(localized: "Install Date"),
            String(localized: "Modified Date"),
            String(localized: "Last Used Date")
        ]
        return titles[rawValue]
    }
}


enum CurrentTabView:Int
{
    case general
    case interface
    case folders
    case update
//    case tips
    case about
    
    var title: String {
        switch self {
        case .general: return String(localized: "General")
        case .interface: return String(localized: "Interface")
        case .folders: return String(localized: "Folders")
        case .update: return String(localized: "Update")
        case .about: return String(localized: "About")
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
