//
//  DeepLink.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/9/23.
//

import Foundation
import SwiftUI
import AlinFoundation

class DeeplinkManager {
    private var urlQueue: [URL] = []
    private var isProcessing = false
    let updater: Updater
    let fsm: FolderSettingsManager
    @AppStorage("settings.general.oneshot") private var oneShotMode: Bool = false
    @State private var windowController = WindowManager()

    init(updater: Updater, fsm: FolderSettingsManager) {
        self.updater = updater
        self.fsm = fsm
    }

    struct DeepLinkActions {
        static let openPearcleaner = "openPearcleaner"
        static let openSettings = "openSettings"
        static let openPermissions = "openPermissions"
        static let uninstallApp = "uninstallApp"
        static let checkOrphanedFiles = "checkOrphanedFiles"
        static let checkDevEnv = "checkDevEnv"
        static let appLipo = "appLipo"
        static let checkUpdates = "checkUpdates"
        static let appsPaths = "appsPaths"
        static let orphanedPaths = "orphanedPaths"
        static let refreshAppsList = "refreshAppsList"
        static let resetSettings = "resetSettings"

        static let allActions = [
            openPearcleaner,
            openSettings,
            openPermissions,
            uninstallApp,
            checkOrphanedFiles,
            checkDevEnv,
            appLipo,
            checkUpdates,
            appsPaths,
            orphanedPaths,
            refreshAppsList,
            resetSettings
        ]
    }

    func manage(url: URL, appState: AppState, locations: Locations) {
        // Set externalMode to true
        updateOnMain {
            appState.externalMode = true
        }

        guard let scheme = url.scheme, scheme == "pear" else {
            guard !url.path.isEmpty else {
                printOS("DLM: URL path is empty.")
                return
            }
            handleAsPathOrDropped(url: url, appState: appState, locations: locations)
            return
        }

        if let host = url.host, DeepLinkActions.allActions.contains(host) {
            switch host {
            case DeepLinkActions.uninstallApp:
                handleAsPathOrDropped(url: url, appState: appState, locations: locations)
            default:
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                   let queryItems = components.queryItems {
                    handleAppFunctions(action: host, queryItems: queryItems, appState: appState, fsm: fsm)
                } else {
                    handleAppFunctions(action: host, queryItems: [], appState: appState, fsm: fsm)
                }
            }
        } else {
            // Host is nil or not in actions, treat as dropped/path scenario
            handleAsPathOrDropped(url: url, appState: appState, locations: locations)
        }
    }

    private func handleAsPathOrDropped(url: URL, appState: AppState, locations: Locations) {
        urlQueue.append(url)
        processQueue(appState: appState, locations: locations)
        if appState.appInfo.isEmpty {
            loadNextAppInfo(appState: appState, locations: locations)
        }
    }

    private func processQueue(appState: AppState, locations: Locations) {
        guard !isProcessing, let nextURL = urlQueue.first else { return }

        isProcessing = true

        // Process the next URL in the queue
        if nextURL.pathExtension == "app" {
            handleDroppedApps(url: nextURL, appState: appState, locations: locations)
        } else if nextURL.scheme == "pear" {
            handleDeepLinkedApps(url: nextURL, appState: appState, locations: locations)
        }

        // Remove processed URL and set up for the next one
        urlQueue.removeFirst()
        isProcessing = false

        // Process the next URL if there are any left in the queue
        if !urlQueue.isEmpty {
            processQueue(appState: appState, locations: locations)
        }
    }

    private func handleDroppedApps(url: URL, appState: AppState, locations: Locations) {
        // Ensure the dropped app path is added only if it's not already in externalPaths
        if !appState.externalPaths.contains(url) {
            appState.externalPaths.append(url)
        }

        // If no app is currently loaded, load the first app in the array
        if appState.appInfo.isEmpty {
            loadNextAppInfo(appState: appState, locations: locations)
        }
    }

    func handleDeepLinkedApps(url: URL, appState: AppState, locations: Locations) {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {

            // Check for "path" query item first
            if let path = queryItems.first(where: { $0.name == "path" })?.value {
                let pathURL = URL(fileURLWithPath: path)

                guard FileManager.default.fileExists(atPath: pathURL.path) else {
                    printOS("DLM: sent path doesn't exist: \(pathURL.path)")
                    return
                }

                // Add path only if it's not already in externalPaths
                if !appState.externalPaths.contains(pathURL) {
                    appState.externalPaths.append(pathURL)
                }

                // Load the first app in externalPaths if no app is currently loaded
                if appState.appInfo.isEmpty {
                    loadNextAppInfo(appState: appState, locations: locations)
                }
            }
            // If "path" is not available, check for "name" query item
            else if let name = queryItems.first(where: { $0.name == "name" })?.value?.lowercased() {
                reloadAppsList(appState: appState, fsm: fsm) {
                    let matchType = queryItems.first(where: { $0.name == "matchType" })?.value?.lowercased() ?? "exact"

                    if let matchedApp = appState.sortedApps.first(where: { appInfo in
                        let appNameLowercased = appInfo.appName.lowercased()
                        switch matchType {
                        case "contains":
                            return appNameLowercased.contains(name)
                        case "exact":
                            return appNameLowercased == name
                        default:
                            return false
                        }
                    }) {
                        let pathURL = matchedApp.path

                        // Add path only if it's not already in externalPaths
                        if !appState.externalPaths.contains(pathURL) {
                            appState.externalPaths.append(pathURL)
                        }

                        // Load the first app in externalPaths if no app is currently loaded
                        if appState.appInfo.isEmpty {
                            self.loadNextAppInfo(appState: appState, locations: locations)
                        }
                    } else {
                        printOS("DLM: No app found matching the name '\(name)' with matchType: \(matchType)")
                    }
                }

            } else {
                printOS("DLM: No valid query items for 'path' or 'name' found in the URL.")
            }
        } else {
            printOS("DLM: URL does not match the expected scheme pear://")
        }
    }


    private func loadNextAppInfo(appState: AppState, locations: Locations) {
        guard let nextPath = appState.externalPaths.first else { return }

        // Fetch app info
        guard let appInfo = AppInfoFetcher.getAppInfo(atPath: nextPath) else {
            printOS("DLM: Failed to get appInfo for path: \(nextPath.path)")
            return
        }

        // Pass the appInfo and trigger showAppInFiles to handle display and animations
        showAppInFiles(appInfo: appInfo, appState: appState, locations: locations)
    }

    private func handleAppFunctions(action: String, queryItems: [URLQueryItem], appState: AppState, fsm: FolderSettingsManager) {

        switch action {
        case DeepLinkActions.openPearcleaner:
            appState.currentPage = .applications
            break
        case DeepLinkActions.openSettings:
            if let page = queryItems.first(where: { $0.name == "name" })?.value {
                // Query parameter provided - match to specific tab
                let search = page.lowercased()
                let allPages = CurrentTabView.allCases
                if let matchedPage = allPages.first(where: { $0.title.lowercased().contains(search) }) {
                    openAppSettingsWindow(tab: matchedPage, updater: updater)
                }
            } else {
                // No query parameter - open with saved preference (or general if none saved)
                openAppSettingsWindow(updater: updater)
            }
            break
        case DeepLinkActions.openPermissions:
            windowController.open(with: PermissionsSheetView().ignoresSafeArea(), width: 300, height: 250, material: .hudWindow)
            break
        case DeepLinkActions.checkOrphanedFiles:
            appState.currentPage = .orphans
            break
        case DeepLinkActions.checkDevEnv:
            if let envName = queryItems.first(where: { $0.name == "name" })?.value {
                let search = envName.lowercased()
                let allEnvs = PathLibrary.getPaths()
                if let matchedEnv = allEnvs.first(where: { $0.name.lowercased().contains(search) }) {
                    updateOnMain() {
                        appState.selectedEnvironment = matchedEnv
                    }
                }
            }
            appState.currentPage = .development
            break
        case DeepLinkActions.appLipo:
            appState.currentPage = .lipo
            break
        case DeepLinkActions.checkUpdates:
            updater.checkForUpdates(sheet: true)
            break
        case DeepLinkActions.appsPaths:
            if let actionType = queryItems.first(where: { $0.name == "add" || $0.name == "remove" })?.name,
               let pathValue = queryItems.first(where: { $0.name == "path" })?.value {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: pathValue, isDirectory: &isDirectory), isDirectory.boolValue {
                    switch actionType {
                    case "add":
                        fsm.addPath(pathValue)
                    case "remove":
                        fsm.removePath(pathValue)
                    default:
                        printOS("DLM: Invalid action type for appsPaths: \(actionType)")
                    }
                } else {
                    printOS("DLM: Provided path '\(pathValue)' does not exist or is not a directory.")
                }

            } else {
                printOS("DLM: Missing 'add' or 'remove' action, or 'path' query item for appsPaths.")
            }
            break
        case DeepLinkActions.orphanedPaths:
            if let actionType = queryItems.first(where: { $0.name == "add" || $0.name == "remove" })?.name,
               let pathValue = queryItems.first(where: { $0.name == "path" })?.value {

                switch actionType {
                case "add":
                    fsm.addPathZ(pathValue)
                case "remove":
                    fsm.removePathZ(pathValue)
                default:
                    printOS("DLM: Invalid action type for orphanedPaths: \(actionType)")
                }
            } else {
                printOS("DLM: Missing 'add' or 'remove' action, or 'path' query item for orphanedPaths.")
            }
            break
        case DeepLinkActions.refreshAppsList:
            reloadAppsList(appState: appState, fsm: fsm)
            break
        case DeepLinkActions.resetSettings:
            DispatchQueue.global(qos: .background).async {
                UserDefaults.standard.dictionaryRepresentation().keys.forEach(UserDefaults.standard.removeObject(forKey:))
            }
            break
        default:
            break
        }
    }

}
