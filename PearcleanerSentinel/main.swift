//
//  main.swift
//  PearcleanerSentinel
//
//  Created by Alin Lupascu on 11/9/23.
//


import AppKit

main()

var globalFileWatcher: FileWatcher?

func startGlobalFileWatcher() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    globalFileWatcher = FileWatcher(["\(home)/.Trash"])
    globalFileWatcher?.queue = DispatchQueue.global()
    globalFileWatcher?.callback = { event in
        checkApp(file: event.path)
    }
    globalFileWatcher?.start()
}

func stopGlobalFileWatcher() {
    globalFileWatcher?.stop()
    globalFileWatcher = nil
}

func setupNotificationListener() {
    let notificationCenter = DistributedNotificationCenter.default()
    notificationCenter.addObserver(forName: Notification.Name("Pearcleaner.StartFileWatcher"), object: nil, queue: nil) { notification in
        print("Received start notification")
        startGlobalFileWatcher()
    }
    notificationCenter.addObserver(forName: Notification.Name("Pearcleaner.StopFileWatcher"), object: nil, queue: nil) { notification in
        print("Received stop notification")
        stopGlobalFileWatcher()
    }
}

func main() {
    setupNotificationListener()
    startGlobalFileWatcher()
    RunLoop.main.run()
}


func checkApp(file: String) {
    let app = URL(fileURLWithPath: file)
    let appExt = app.pathExtension
    if appExt == "app" {
        if let appBundle = Bundle(url: app) {
            if appBundle.bundleIdentifier == "com.alienator88.Pearcleaner" {
                return
            } else {
                if FileManager.default.isInTrash(app) {
                    NSWorkspace.shared.open(URL(string: "pear://openApp?path=\(file)")!)
                }
            }
        } else {
            print("Error: Unable to get bundle information for \(file)")
        }
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
