//
//  AppState.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI
import AlinFoundation
import FinderSync

let home = FileManager.default.homeDirectoryForCurrentUser.path

class AppState: ObservableObject {
    // MARK: - Singleton Instance
    static let shared = AppState()
    
    @Published var appInfo: AppInfo
    @Published var zombieFile: ZombieFile
    @Published var sortedApps: [AppInfo] = []
    @Published var selectedItems = Set<URL>()
    @Published var currentView = CurrentDetailsView.empty
    @Published var currentPage = CurrentPage.applications
    @Published var showAlert: Bool = false
    @Published var sidebar: Bool = true
    @Published var reload: Bool = false
    @Published var showProgress: Bool = false
    @Published var progressStep: Int = 0
    @Published var leftoverProgress: (String, Double) = ("", 0.0)
    @Published var finderExtensionEnabled: Bool = false
    @Published var showUninstallAlert: Bool = false
    @Published var externalMode: Bool = false
    @Published var multiMode: Bool = false
    @Published var externalPaths: [URL] = [] // for handling multiple app from drops or deeplinks
    @Published var selectedEnvironment: PathEnv? // for handling dev environments
    @Published var trashError: Bool = false
    
    // Volume information
    @Published var volumeInfos: [VolumeInfo] = []
    @Published var volumeAnimationShown: Bool = false
    
    // Per-app sensitivity level storage
    @Published var perAppSensitivity: [String: SearchSensitivityLevel] = [:]

    func getBundleSize(for appInfo: AppInfo, updateState: @escaping (Int64) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Step 1: Check if the size is available and not 0 in the sortedApps cache
            if let existingAppInfo = self.sortedApps.first(where: { $0.path == appInfo.path }) {
                if existingAppInfo.bundleSize > 0 {
                    // Cached size is available, update the state immediately
                    DispatchQueue.main.async {
                        updateState(existingAppInfo.bundleSize)
                    }
                    return
                }
            }
            
            // Step 2: If we reach here, we need to calculate the size
            let calculatedSize = totalSizeOnDisk(for: appInfo.path).logical
            DispatchQueue.main.async {
                // Update the state and the array
                updateState(calculatedSize)
                
                if let index = self.sortedApps.firstIndex(where: { $0.path == appInfo.path }) {
                    var updatedAppInfo = self.sortedApps[index]
                    updatedAppInfo.bundleSize = calculatedSize
                    updatedAppInfo.arch = isOSArm() ? .arm : .intel
                    self.sortedApps[index] = updatedAppInfo
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
            cask: nil,
            steam: false,
            bundleSize: 0,
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
        let extensionStatus = FIFinderSyncController.isExtensionEnabled
        DispatchQueue.main.async {
            self.finderExtensionEnabled = extensionStatus
        }
    }

    func triggerUninstallAlert() {
        self.showUninstallAlert = true
    }
    
    // Add this method to restore zombie file associations
    func restoreZombieAssociations() {
        let zombieStorage = ZombieFileStorage.shared
        
        // Clean up invalid associations first
        let validAppPaths = sortedApps.map { $0.path }
        zombieStorage.cleanupInvalidAssociations(validAppPaths: validAppPaths)
        
        // For each app that has associations, add the zombie file URLs to their fileSize dictionary
        // The actual sizes will be calculated later during the scan
        for appInfo in sortedApps {
            let associatedFiles = zombieStorage.getAssociatedFiles(for: appInfo.path)
            
            // Add zombie files to this app's file tracking
            // We'll add them with size 0 - the real sizes will be calculated during scan
            for zombieFile in associatedFiles {
                // Only add if the file still exists
                if FileManager.default.fileExists(atPath: zombieFile.path) {
                    // Add to the current appInfo if it matches, or find and update the correct one
                    if let appIndex = sortedApps.firstIndex(where: { $0.path == appInfo.path }) {
                        sortedApps[appIndex].fileSize[zombieFile] = 0 // Placeholder size
                        sortedApps[appIndex].fileSizeLogical[zombieFile] = 0 // Placeholder size
                        // Icon will be fetched during normal scan process
                    }
                }
            }
        }
    }
    
    func loadVolumeInfo() {
        DispatchQueue.global(qos: .userInitiated).async {
            var volumes: [VolumeInfo] = []
            
            // First, add root volume (/)
            if let rootVolume = self.getVolumeInfo(for: URL(fileURLWithPath: "/")) {
                volumes.append(rootVolume)
                
                #if DEBUG
                // Duplicate for testing
                let duplicateRoot = VolumeInfo(
                    name: "\(rootVolume.name) Debug",
                    path: rootVolume.path,
                    icon: rootVolume.icon,
                    totalSpace: rootVolume.totalSpace,
                    usedSpace: rootVolume.usedSpace,
                    realAvailableSpace: rootVolume.realAvailableSpace,
                    purgeableSpace: rootVolume.purgeableSpace,
                    isExternal: false
                )
                volumes.append(duplicateRoot)
                #endif
            }
            
            // Then enumerate all mounted volumes in /Volumes
            let volumesPath = "/Volumes"
            if let volumeContents = try? FileManager.default.contentsOfDirectory(atPath: volumesPath) {
                for volumeName in volumeContents {
                    // Skip dot folders (hidden folders like .timemachine)
                    if volumeName.hasPrefix(".") {
                        continue
                    }
                    
                    let volumePath = "\(volumesPath)/\(volumeName)"
                    let volumeURL = URL(fileURLWithPath: volumePath)
                    
                    // Resolve symlinks
                    let resolvedURL = volumeURL.resolvingSymlinksInPath()
                    
                    // Skip if it's the same as root (to avoid duplicates)
                    if resolvedURL.path == "/" {
                        continue
                    }
                    
                    // Skip Time Machine volumes
                    if !self.isTimeMachineVolume(url: resolvedURL) {
                        if let volumeInfo = self.getVolumeInfo(for: resolvedURL, displayName: volumeName) {
                            volumes.append(volumeInfo)
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                // Preserve hasAnimated state from existing volumes
                for i in 0..<volumes.count {
                    if let existingVolume = self.volumeInfos.first(where: { $0.path == volumes[i].path }) {
                        volumes[i].hasAnimated = existingVolume.hasAnimated
                    }
                }
                self.volumeInfos = volumes
            }
        }
    }
    
    private func getVolumeInfo(for url: URL, displayName: String? = nil) -> VolumeInfo? {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey
        ]
        
        guard let resource = try? url.resourceValues(forKeys: Set(keys)),
              let total = resource.volumeTotalCapacity,
              let availableWithPurgeable = resource.volumeAvailableCapacity,
              let realAvailable = resource.volumeAvailableCapacityForImportantUsage else { 
            return nil 
        }
        
        // Use regular available capacity if important usage capacity is 0 (common for DMGs)
        let effectiveAvailable = realAvailable > 0 ? Int(realAvailable) : availableWithPurgeable
        let finderTotalAvailable = Int64(effectiveAvailable)
        let realAvailableSpace = Int64(availableWithPurgeable)
        let purgeableSpace = max(0, finderTotalAvailable - realAvailableSpace)
        let realUsedSpace = Int64(total) - finderTotalAvailable
        let name = displayName ?? resource.volumeName ?? url.lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        
        // Debug prints
//        print("=== Volume: \(name) ===")
//        print("Total: \(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file))")
//        print("Available (with purgeable): \(ByteCountFormatter.string(fromByteCount: Int64(availableWithPurgeable), countStyle: .file))")
//        print("Available (important usage): \(ByteCountFormatter.string(fromByteCount: Int64(realAvailable), countStyle: .file))")
//        print("Calculated used: \(ByteCountFormatter.string(fromByteCount: realUsedSpace, countStyle: .file))")
//        print("Calculated purgeable: \(ByteCountFormatter.string(fromByteCount: purgeableSpace, countStyle: .file))")
//        print("========================")
        
        // Check if volume is external (removable or ejectable)
        let isRemovable = resource.volumeIsRemovable ?? false
        let isEjectable = resource.volumeIsEjectable ?? false
        let isExternal = isRemovable || isEjectable
        
        return VolumeInfo(
            name: name,
            path: url.path,
            icon: Image(nsImage: icon),
            totalSpace: Int64(total),
            usedSpace: realUsedSpace,
            realAvailableSpace: realAvailableSpace,
            purgeableSpace: purgeableSpace,
            isExternal: isExternal
        )
    }
    
    private func isTimeMachineVolume(url: URL) -> Bool {
        let backupsPath = url.appendingPathComponent("Backups.backupdb")
        let tmDirectoryPath = url.appendingPathComponent(".com.apple.timemachine")
        
        // Check for common Time Machine indicators
        let hasBackupsDB = FileManager.default.fileExists(atPath: backupsPath.path)
        let hasTMDirectory = FileManager.default.fileExists(atPath: tmDirectoryPath.path)
        
        // Check if volume name contains "TimeMachine"
        let volumeName = url.lastPathComponent.lowercased()
        let isNamedTimeMachine = volumeName.contains("timemachine") ||
                                 volumeName.contains("time machine") ||
                                 volumeName.contains("time_machine")

        return hasBackupsDB || hasTMDirectory || isNamedTimeMachine
    }
    

}

struct VolumeInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let icon: Image
    let totalSpace: Int64
    let usedSpace: Int64
    let realAvailableSpace: Int64
    let purgeableSpace: Int64
    let isExternal: Bool
    var hasAnimated: Bool = false
    
    static func == (lhs: VolumeInfo, rhs: VolumeInfo) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.path == rhs.path &&
               lhs.totalSpace == rhs.totalSpace &&
               lhs.usedSpace == rhs.usedSpace &&
               lhs.realAvailableSpace == rhs.realAvailableSpace &&
               lhs.purgeableSpace == rhs.purgeableSpace &&
               lhs.isExternal == rhs.isExternal &&
               lhs.hasAnimated == rhs.hasAnimated
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
    let cask: String?
    let steam: Bool // New property to mark Steam games
    var bundleSize: Int64 // Only used in the app list view
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

    var executableURL: URL? {
        let infoPlistURL = path.appendingPathComponent("Contents/Info.plist")
        guard let info = NSDictionary(contentsOf: infoPlistURL) as? [String: Any],
              let execName = info["CFBundleExecutable"] as? String else {
            return nil
        }
        return path.appendingPathComponent("Contents/MacOS").appendingPathComponent(execName)
    }

    var averageColor: Color? {
        Color(appIcon?.averageColor ?? .clear)
    }

    var isEmpty: Bool {
        return path == URL(fileURLWithPath: "./") && bundleIdentifier.isEmpty && appName.isEmpty
    }
    
    static let empty = AppInfo(id: UUID(), path: URL(fileURLWithPath: ""), bundleIdentifier: "", appName: "", appVersion: "", appIcon: nil, webApp: false, wrapped: false, system: false, arch: .empty, cask: nil, steam: false, bundleSize: 0, fileSize: [:], fileSizeLogical: [:], fileIcon: [:], creationDate: nil, contentChangeDate: nil, lastUsedDate: nil)
    
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

struct AssociatedZombieFile: Codable {
    let appPath: URL  // Unique identifier for the app
    let filePath: URL  // The zombie file to be processed
}

class ZombieFileStorage {
    static let shared = ZombieFileStorage()
    var associatedFiles: [URL: [URL]] = [:] // Key: App Path, Value: Zombie File URLs
    
    // UserDefaults key for persistence
    private let associationsKey = "settings.general.zombie.associations"
    
    private init() {
        loadAssociations()
    }
    
    // Load associations from UserDefaults
    private func loadAssociations() {
        if let data = UserDefaults.standard.data(forKey: associationsKey),
           let storedAssociations = try? JSONDecoder().decode([String: [String]].self, from: data) {
            
            associatedFiles = storedAssociations.reduce(into: [URL: [URL]]()) { result, pair in
                let appURL = URL(fileURLWithPath: pair.key)
                let zombieURLs = pair.value.map { URL(fileURLWithPath: $0) }
                result[appURL] = zombieURLs
            }
        }
    }
    
    // Save associations to UserDefaults
    private func saveAssociations() {
        let storableAssociations = associatedFiles.reduce(into: [String: [String]]()) { result, pair in
            result[pair.key.path] = pair.value.map { $0.path }
        }
        
        if let encoded = try? JSONEncoder().encode(storableAssociations) {
            UserDefaults.standard.set(encoded, forKey: associationsKey)
        }
    }
    
    func addAssociation(appPath: URL, zombieFilePath: URL) {
        if associatedFiles[appPath] == nil {
            associatedFiles[appPath] = []
        }
        if !associatedFiles[appPath]!.contains(zombieFilePath) {
            associatedFiles[appPath]?.append(zombieFilePath)
            saveAssociations()
        }
    }
    
    func getAssociatedFiles(for appPath: URL) -> [URL] {
        return associatedFiles[appPath] ?? []
    }
    
    func isPathAssociated(_ path: URL) -> Bool {
        return associatedFiles.values.contains { $0.contains(path) }
    }
    
    func clearAssociations(for appPath: URL) {
        associatedFiles[appPath] = nil
        saveAssociations()
    }
    
    func removeAssociation(appPath: URL, zombieFilePath: URL) {
        guard var associatedFilesList = associatedFiles[appPath] else { return }
        associatedFilesList.removeAll { $0 == zombieFilePath }
        
        if associatedFilesList.isEmpty {
            associatedFiles.removeValue(forKey: appPath) // Remove key if no files are left
        } else {
            associatedFiles[appPath] = associatedFilesList
        }
        saveAssociations()
    }
    
    // Clean up associations for apps that no longer exist
    func cleanupInvalidAssociations(validAppPaths: [URL]) {
        let currentAppPaths = Set(associatedFiles.keys)
        let validAppPathsSet = Set(validAppPaths)
        let invalidPaths = currentAppPaths.subtracting(validAppPathsSet)
        
        for invalidPath in invalidPaths {
            associatedFiles.removeValue(forKey: invalidPath)
        }
        
        if !invalidPaths.isEmpty {
            saveAssociations()
        }
    }
}


enum Arch {
    case arm
    case intel
    case universal
    case empty
    
    var type: String {
        switch self {
        case .arm:
            return "arm"
        case .intel:
            return "intel"
        case .universal:
            return String(localized: "universal")
        case .empty:
            return ""
        }
    }
}

enum CurrentPage:Int, CaseIterable, Identifiable
{
    case applications
    case orphans
    case development
    case lipo
    case launchItems
    case package

    var id: Int { rawValue }
    
    var details: (title: String, icon: String) {
        switch self {
        case .applications:
            return (String(localized: "Apps"), "square.grid.3x3.fill.square")
        case .orphans:
            return (String(localized: "Orphans"), "doc.text.magnifyingglass")
        case .development:
            return (String(localized: "Dev"), "hammer.circle")
        case .lipo:
            return (String(localized: "Lipo"), "square.split.1x2")
        case .launchItems:
            return (String(localized: "Services"), "gearshape.2")
        case .package:
            return (String(localized: "Packages"), "shippingbox")
        }
    }
    
    var title: String { details.title }
    var icon: String { details.icon }
}

//MARK: Sorting for sidebar apps list
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

//MARK: Sorting for file list view
enum SortOptionList: String, CaseIterable {
    case name = "name"
    case path = "path"
    case size = "size"

    var title: String {
        switch self {
        case .name: return String(localized: "Name")
        case .path: return String(localized: "Path")
        case .size: return String(localized: "Size")
        }
    }
    
    var systemImage: String {
        switch self {
        case .name: return "list.bullet"
        case .path: return "folder"
        case .size: return "number"
        }
    }
}


enum CurrentTabView:Int, CaseIterable
{
    case general
    case interface
    case folders
    case update
    case helper
    case about
    
    var title: String {
        switch self {
        case .general: return String(localized: "General")
        case .interface: return String(localized: "Interface")
        case .folders: return String(localized: "Folders")
        case .update: return String(localized: "Update")
        case .helper: return String(localized: "Helper")
        case .about: return String(localized: "About")
        }
    }
}

enum CurrentDetailsView:Int
{
    case empty
    case files
    case zombie
    case terminal
}

extension AppState {
    // Call this when switching to view an app to ensure associated files are loaded
    func loadAssociatedFilesForCurrentApp() {
        guard !appInfo.isEmpty else { return }
        
        let associatedFiles = ZombieFileStorage.shared.getAssociatedFiles(for: appInfo.path)
        
        for zombieFile in associatedFiles {
            if FileManager.default.fileExists(atPath: zombieFile.path) {
                // Add to current app's tracking if not already present
                if appInfo.fileSize[zombieFile] == nil {
                    appInfo.fileSize[zombieFile] = 0 // Will be calculated during scan
                    appInfo.fileSizeLogical[zombieFile] = 0
                }
            }
        }
    }
}
