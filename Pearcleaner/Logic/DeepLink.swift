//
//  DeepLink.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/9/23.
//

import Foundation
import SwiftUI

class DeeplinkManager {
    @Binding var showPopover: Bool
    @AppStorage("settings.general.mini") private var mini: Bool = false

    init(showPopover: Binding<Bool>) {
        _showPopover = showPopover
    }

    class DeepLinkConstants {
        static let scheme = "pear"
        static let host = "com.alienator88.Pearcleaner"
        static let query = "path"
    }
    
    func manage(url: URL, appState: AppState, locations: Locations) {
        // This handles dropping an app onto Pearcleaner
        if url.pathExtension == "app" {
            handleAppBundle(url: url, appState: appState, locations: locations)
            // This handles sentinel monitor launch
        } else if url.scheme == DeepLinkConstants.scheme,
                  url.host == DeepLinkConstants.host,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let queryItems = components.queryItems {
            if let path = queryItems.first(where: { $0.name == DeepLinkConstants.query })?.value {
                let pathURL = URL(fileURLWithPath: path)
                let appInfo = AppInfoFetcher.getAppInfo(atPath: pathURL)
                showAppInFiles(appInfo: appInfo!, appState: appState, locations: locations, showPopover: $showPopover)
            } else {
                printOS("No path query parameter found in the URL")
            }
        } else {
            printOS("URL does not match the expected scheme and host")
        }
    }

    
    func handleAppBundle(url: URL, appState: AppState, locations: Locations) {
        let appInfo = AppInfoFetcher.getAppInfo(atPath: url)
        showAppInFiles(appInfo: appInfo!, appState: appState, locations: locations, showPopover: $showPopover)
    }
    
}
