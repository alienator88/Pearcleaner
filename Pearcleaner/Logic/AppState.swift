//
//  AppState.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI
//import FinderSync

let home = FileManager.default.homeDirectoryForCurrentUser.path

class AppState: ObservableObject {
    @Published var appInfo: AppInfo
//    @Published var appInfoStore: [AppInfo] = []
    @Published var trashedFiles: [AppInfo] = []
    @Published var zombieFile: ZombieFile
    @Published var sortedApps: [AppInfo] = []
    @Published var selectedItems = Set<URL>()
    @Published var currentView = CurrentDetailsView.empty
    @Published var showAlert: Bool = false
    @Published var sidebar: Bool = true
    @Published var reload: Bool = false
    @Published var showProgress: Bool = false
    @Published var leftoverProgress: (String, Double) = ("", 0.0)
    @Published var finderExtensionEnabled: Bool = false
    @Published var showUninstallAlert: Bool = false
    @Published var oneShotMode: Bool = false
    @Published var showConditionBuilder: Bool = false

    var operationQueueLeftover = OperationQueue()
    @Published var shouldCancelOperations = false

    func cancelQueueOperations() {
        operationQueueLeftover.cancelAllOperations()
        shouldCancelOperations = true
        DispatchQueue.main.async {
            self.leftoverProgress = ("Search canceled", 0.0)
            self.showProgress = false
            self.currentView = .empty
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

//extension ZombieFile {
//    func toItems() -> [Item] {
//        var items: [Item] = []
//
//        for (url, size) in self.fileSize {
//            let name = url.lastPathComponent
//            let isDirectory = url.hasDirectoryPath
//
//            let item = Item(
//                url: url,
//                name: name,
//                size: size,
//                isDirectory: isDirectory
//            )
//
//            items.append(item)
//        }
//
//        return items
//    }
//}


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
