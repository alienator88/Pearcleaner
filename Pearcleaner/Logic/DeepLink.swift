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
    @Binding var showPopover: Bool
    private var urlQueue: [URL] = []
    private var isProcessing = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.oneshot") private var oneShotMode: Bool = false

    init(showPopover: Binding<Bool>) {
        _showPopover = showPopover
    }

    class DeepLinkConstants {
        static let scheme = "pear"
        static let host = "com.alienator88.Pearcleaner"
        static let query = "path"
        static let brew = "brew"
    }

    func manage(url: URL, appState: AppState, locations: Locations) {
        // Add URL to queue
        urlQueue.append(url)
        processQueue(appState: appState, locations: locations)

        // If no app is currently displayed, load the first app immediately
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
        } else if nextURL.scheme == DeepLinkConstants.scheme, nextURL.host == DeepLinkConstants.host {
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
           let queryItems = components.queryItems,
           let path = queryItems.first(where: { $0.name == DeepLinkConstants.query })?.value {

            let pathURL = URL(fileURLWithPath: path)

            // Add path only if it's not already in externalPaths
            if !appState.externalPaths.contains(pathURL) {
                appState.externalPaths.append(pathURL)
            }

            // Load the first app in externalPaths if no app is currently loaded
            if appState.appInfo.isEmpty {
                loadNextAppInfo(appState: appState, locations: locations)
            }

            // Handle sentinel mode
            if let brewValue = queryItems.first(where: { $0.name == DeepLinkConstants.brew })?.value, brewValue == "true" {
                updateOnMain {
                    appState.sentinelMode = true
                }
            }
        } else {
            printOS("URL does not match the expected scheme and host")
        }
    }

    private func loadNextAppInfo(appState: AppState, locations: Locations) {
        guard let nextPath = appState.externalPaths.first else { return }

        // Fetch app info
        let appInfo = AppInfoFetcher.getAppInfo(atPath: nextPath)

        // Pass the appInfo and trigger showAppInFiles to handle display and animations
        showAppInFiles(appInfo: appInfo!, appState: appState, locations: locations, showPopover: $showPopover)
    }

}
