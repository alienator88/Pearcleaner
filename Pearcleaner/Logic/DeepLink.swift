//
//  DeepLink.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/9/23.
//

import Foundation
import SwiftUI

class DeeplinkManager {
    
    class DeepLinkConstants {
        static let scheme = "pear"
        static let host = "com.alienator88.Pearcleaner"
        static let query = "path"
    }
    
    func manage(url: URL, appState: AppState) {
        guard url.scheme == DeepLinkConstants.scheme,
              url.host == DeepLinkConstants.host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems
        else {
            print("URL does not match the expected scheme and host")
            return
        }
        
        if let path = queryItems.first(where: { $0.name == DeepLinkConstants.query })?.value {
            let pathURL = URL(fileURLWithPath: path)
            let appInfo = getAppInfo(atPath: pathURL)
            updateOnMain {
                appState.appInfo = appInfo!
                findPathsForApp(appState: appState, appInfo: appState.appInfo)
                appState.currentView = .files
            }
        } else {
            print("No path query parameter found in the URL")
        }
    }
}
