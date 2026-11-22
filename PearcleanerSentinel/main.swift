//
//  main.swift
//  PearcleanerSentinel
//
//  Created by Alin Lupascu on 11/9/23.
//


import AppKit
import OSLog

private let logger = Logger(
    subsystem: "com.alienator88.Pearcleaner",
    category: "Sentinel"
)

main()

var globalFileWatcher: FileWatcher?

func startGlobalFileWatcher() {
    guard globalFileWatcher == nil else {
        logger.debug("Trash watcher is already running")
        return
    }

    let home = FileManager.default.homeDirectoryForCurrentUser.path
    globalFileWatcher = FileWatcher(["\(home)/.Trash"])
    globalFileWatcher?.queue = DispatchQueue.global()
    globalFileWatcher?.callback = { event in
        guard event.created || event.renamed else { return }
        checkApp(file: event.path)
    }
    globalFileWatcher?.start()
    logger.info("Started Trash watcher; Sentinel only observes trashed app bundles")
}

func stopGlobalFileWatcher() {
    guard globalFileWatcher != nil else {
        logger.debug("Trash watcher is already stopped")
        return
    }

    globalFileWatcher?.stop()
    globalFileWatcher = nil
    logger.info("Stopped Trash watcher")
}

func setupNotificationListener() {
    let notificationCenter = DistributedNotificationCenter.default()
    notificationCenter.addObserver(forName: Notification.Name("Pearcleaner.StartFileWatcher"), object: nil, queue: nil) { _ in
        logger.debug("Received start notification")
        startGlobalFileWatcher()
    }
    notificationCenter.addObserver(forName: Notification.Name("Pearcleaner.StopFileWatcher"), object: nil, queue: nil) { _ in
        logger.debug("Received stop notification")
        stopGlobalFileWatcher()
    }
}

func main() {
    logger.info("Sentinel launched")
    setupNotificationListener()
    startGlobalFileWatcher()
    RunLoop.main.run()
}


func checkApp(file: String) {
    let app = URL(fileURLWithPath: file)
    guard app.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
          FileManager.default.isInTrash(app) else {
        return
    }

    guard let appBundle = Bundle(url: app) else {
        logger.error("Unable to read bundle information for path: \(file, privacy: .private(mask: .hash))")
        return
    }

    guard appBundle.bundleIdentifier != "com.alienator88.Pearcleaner" else {
        logger.debug("Ignoring Pearcleaner's own app bundle")
        return
    }

    var components = URLComponents()
    components.scheme = "pear"
    components.host = "openApp"
    components.queryItems = [URLQueryItem(name: "path", value: file)]

    guard let deepLink = components.url else {
        logger.error("Unable to create deep link for path: \(file, privacy: .private(mask: .hash))")
        return
    }

    if NSWorkspace.shared.open(deepLink) {
        logger.notice("Opened Pearcleaner for a trashed app bundle: \(file, privacy: .private(mask: .hash))")
    } else {
        logger.error("Failed to open Pearcleaner for path: \(file, privacy: .private(mask: .hash))")
    }
}



// --- Trash Relationship ---
extension FileManager {
    public func isInTrash(_ file: URL) -> Bool {
        var relationship: URLRelationship = .other
        do {
            try getRelationship(&relationship, of: .trashDirectory, in: .userDomainMask, toItemAt: file)
            return relationship == .contains
        } catch {
            return false
        }
    }
}
