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
    
    func manage(url: URL, appState: AppState) {
        if url.pathExtension == "app" {
            handleAppBundle(url: url, appState: appState)
        } else if url.scheme == DeepLinkConstants.scheme,
                  url.host == DeepLinkConstants.host,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let queryItems = components.queryItems {
            if let path = queryItems.first(where: { $0.name == DeepLinkConstants.query })?.value {
                let pathURL = URL(fileURLWithPath: path)
                let appInfo = getAppInfo(atPath: pathURL)
                updateOnMain {
                    appState.appInfo = appInfo!
                    findPathsForApp(appState: appState, appInfo: appState.appInfo)
                    if self.mini {
                        self.showPopover = true
                    } else {
                        appState.currentView = .files
                    }
                }
            } else {
                print("No path query parameter found in the URL")
            }
        } else {
            print("URL does not match the expected scheme and host")
        }
    }
    
//    func manage(url: URL, appState: AppState) {
//        guard url.scheme == DeepLinkConstants.scheme,
//              url.host == DeepLinkConstants.host,
//              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
//              let queryItems = components.queryItems
//        else {
//            print("URL does not match the expected scheme and host")
//            return
//        }
//        
//        if let path = queryItems.first(where: { $0.name == DeepLinkConstants.query })?.value {
//            let pathURL = URL(fileURLWithPath: path)
//            let appInfo = getAppInfo(atPath: pathURL)
//            updateOnMain {
//                appState.appInfo = appInfo!
//                findPathsForApp(appState: appState, appInfo: appState.appInfo)
//                appState.currentView = .files
//            }
//        } else {
//            print("No path query parameter found in the URL")
//        }
//    }
    
    func handleAppBundle(url: URL, appState: AppState) {
        let appInfo = getAppInfo(atPath: url)
        updateOnMain {
            appState.appInfo = appInfo!
            findPathsForApp(appState: appState, appInfo: appState.appInfo)
            if self.mini {
                self.showPopover = true
            } else {
                appState.currentView = .files
            }
        }
    }
    
}
