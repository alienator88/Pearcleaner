//
//  ReversePathsFetch.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/20/24.
//

import Foundation
import AppKit

class ReversePathsSearcher {
    private let appState: AppState
    private let locations: Locations
    private let fileManager = FileManager.default
    private var collection: [URL] = []
    private var fileSize: [URL: Int64] = [:]
    private var fileIcon: [URL: NSImage?] = [:]
    private var skipped: Set<String>
    private let dispatchGroup = DispatchGroup()

    init(appState: AppState, locations: Locations) {
        self.appState = appState
        self.locations = locations
        self.skipped = ["apple", "temporary", "btserver", "proapps", "scripteditor", "ilife", "livefsd", "siritoday", "addressbook", "animoji", "appstore", "askpermission", "callhistory", "clouddocs", "diskimages", "dock", "facetime", "fileprovider", "instruments", "knowledge", "mobilesync", "syncservices", "homeenergyd", "icloud", "icdd", "networkserviceproxy", "familycircle", "geoservices", "installation", "passkit", "sharedimagecache", "desktop", "mbuseragent", "swiftpm", "baseband", "coresimulator", "photoslegacyupgrade", "photosupgrade", "siritts", "ipod", "globalpreferences", "apmanalytics", "apmexperiment", "avatarcache", "byhost", "contextstoreagent", "mobilemeaccounts", "intentbuilderc", "loginwindow", "momc", "replayd", "sharedfilelistd", "clang", "audiocomponent", "csexattrcryptoservice", "livetranscriptionagent", "sandboxhelper", "statuskitagent", "betaenrollmentd", "contentlinkingd", "diagnosticextensionsd", "gamed", "heard", "homed", "itunescloudd", "lldb", "mds", "mediaanalysisd", "metrickitd", "mobiletimerd", "proactived", "ptpcamerad", "studentd", "talagent", "watchlistd", "apptranslocation", "xcrun", "ds_store", "caches", "crashreporter", "trash", "pearcleaner", "amsdatamigratortool", "arfilecache", "assistant", "chromium", "cloudkit", "webkit", "databases", "diagnostic", "cache", "gamekit", "homebrew", "logi", "microsoft", "mozilla", "sync", "google", "sentinel", "hexnode", "sentry", "tvappservices"]
    }

    func reversePathsSearch(completion: @escaping () -> Void = {}) {
        Task(priority: .high) {
            self.processLocations()
            self.calculateFileDetails()
            self.updateAppState()
            completion()
        }
    }

    private func processLocations() {
        let allPaths = appState.appInfoStore.flatMap { $0.files.map { $0.path.pearFormat() } }
        let allNames = appState.appInfoStore.map { $0.appName.pearFormat() }

        for location in locations.reverse.paths where fileManager.fileExists(atPath: location) {
            dispatchGroup.enter()
            processLocation(location, allPaths: allPaths, allNames: allNames)
            dispatchGroup.leave()
        }
    }

    private func processLocation(_ location: String, allPaths: [String], allNames: [String]) {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: location)
            contents.forEach { itemName in
                let itemURL = URL(fileURLWithPath: location).appendingPathComponent(itemName)
                processItem(itemName, itemURL: itemURL, allPaths: allPaths, allNames: allNames)
            }
        } catch {
            printOS("Error processing location: \(location), error: \(error)")
        }
    }

    private func processItem(_ itemName: String, itemURL: URL, allPaths: [String], allNames: [String]) {
        let formattedItemName = itemName.pearFormat()
        let itemPath = itemURL.path.pearFormat()
        let itemLastPathComponent = itemURL.lastPathComponent.pearFormat()

        guard !skipped.contains(where: { formattedItemName.contains($0) }),
//              !allPaths.contains(itemPath),
              !allPaths.contains(where: { $0 == itemPath || $0.hasSuffix("/\(itemLastPathComponent)") }),
              !allNames.contains(formattedItemName),
              isSupportedFileType(at: itemURL.path) else {
            return
        }

        collection.append(itemURL)
    }

    private func calculateFileDetails() {
        collection.forEach { path in
            fileSize[path] = totalSizeOnDisk(for: path)
            fileIcon[path] = getIconForFileOrFolderNS(atPath: path)
        }
    }

    private func updateAppState() {
        dispatchGroup.notify(queue: .main) {
            var updatedZombieFile = ZombieFile.empty
            updatedZombieFile.fileSize = self.fileSize
            updatedZombieFile.fileIcon = self.fileIcon
            self.appState.zombieFile = updatedZombieFile
            self.appState.showProgress = false
        }
    }

}
