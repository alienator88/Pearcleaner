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
                let appInfo = getAppInfo(atPath: pathURL)
                showAppInFiles(appInfo: appInfo!, mini: mini, appState: appState, locations: locations, showPopover: $showPopover)

//                showPopover = false
//                updateOnMain {
//                    appState.appInfo = .empty
//                    if let storedAppInfo = appState.appInfoStore.first(where: { $0.path == appInfo?.path }) {
//                        appState.appInfo = storedAppInfo
////                        appState.paths = storedAppInfo.fileSize.keys.map { $0 }//storedAppInfo.files
//                        appState.selectedItems = Set(storedAppInfo.files)
//                        withAnimation(Animation.easeIn(duration: 0.4)) {
//                            if self.mini {
//                                self.showPopover.toggle()
//                            } else {
//                                appState.currentView = .files
//                            }
//                        }
//                    } else {
//                        // Handle the case where the appInfo is not found in the store
//                        printOS("AppInfo not found in the cached store, searching again")
//                        appState.appInfo = .empty
//                        appState.appInfo = appInfo!
//                        findPathsForApp(appInfo: appInfo!, appState: appState, locations: locations)
//                        withAnimation(Animation.easeIn(duration: 0.4)) {
//                            if self.mini {
//                                self.showPopover.toggle()
//                            } else {
//                                appState.currentView = .files
//                            }
//                        }
//                    }
//                }
            } else {
                printOS("No path query parameter found in the URL")
            }
        } else {
            printOS("URL does not match the expected scheme and host")
        }
    }

    
    func handleAppBundle(url: URL, appState: AppState, locations: Locations) {
        let appInfo = getAppInfo(atPath: url)
        showAppInFiles(appInfo: appInfo!, mini: mini, appState: appState, locations: locations, showPopover: $showPopover)

//        showPopover = false
//        updateOnMain {
//            appState.appInfo = .empty
//            if let storedAppInfo = appState.appInfoStore.first(where: { $0.path == appInfo?.path }) {
//                appState.appInfo = storedAppInfo
////                appState.paths = storedAppInfo.fileSize.keys.map { $0 }//storedAppInfo.files
//                appState.selectedItems = Set(storedAppInfo.files)
//                withAnimation(Animation.easeIn(duration: 0.4)) {
//                    if self.mini {
//                        self.showPopover.toggle()
//                    } else {
//                        appState.currentView = .files
//                    }
//                }
//            } else {
//                // Handle the case where the appInfo is not found in the store
//                printOS("AppInfo not found in the cached store, searching again")
//                appState.appInfo = .empty
//                appState.appInfo = appInfo!
//                findPathsForApp(appInfo: appInfo!, appState: appState, locations: locations)
//                withAnimation(Animation.easeIn(duration: 0.4)) {
//                    if self.mini {
//                        self.showPopover.toggle()
//                    } else {
//                        appState.currentView = .files
//                    }
//                }
//            }
//        }
//        updateOnMain {
//            appState.appInfo = appInfo!
//            findPathsForApp(appState: appState, locations: locations)
//            if self.mini {
//                self.showPopover = true
//            } else {
//                appState.currentView = .files
//            }
//        }
    }
    
}
