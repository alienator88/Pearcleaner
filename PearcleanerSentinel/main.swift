//
//  main.swift
//  PearcleanerSentinel
//
//  Created by Alin Lupascu on 11/9/23.
//

import Foundation
import AppKit
import FileWatcher

// Start Trash monitoring
fileWatcher()

// Keep alive indefinitely
while true {
    sleep(1)
}

func fileWatcher() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let filewatcher = FileWatcher(["\(home)/.Trash"])
    filewatcher.queue = DispatchQueue.global()
    filewatcher.callback = { event in
        checkApp(file: event.path)
    }
    filewatcher.start()
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
                    NSWorkspace.shared.open(URL(string: "pear://com.alienator88.Pearcleaner?path=\(file)")!)
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






// For testing and outputing logging to file from cmd line tool
func writeLog(string: String) {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser.path
    let logFilePath = "\(home)/Downloads/monitor.txt"
    
    // Check if the log file exists, and create it if it doesn't
    if !fileManager.fileExists(atPath: logFilePath) {
        if !fileManager.createFile(atPath: logFilePath, contents: nil, attributes: nil) {
            print("Failed to create the log file.")
            return
        }
    }
    
    do {
        if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
            let ns = "\(string)\n"
            fileHandle.seekToEndOfFile()
            fileHandle.write(ns.data(using: .utf8)!)
            fileHandle.closeFile()
        } else {
            print("Error opening file for appending")
        }
    }
}













//            let trashContents = getTrashContents()
//            if !trashContents.isEmpty && trashContents.contains(event.path) {
//                NSWorkspace.shared.open(URL(string: "pear://com.alienator88.Pearcleaner?path=\(event.path)")!)
//            }

//func getTrashContents() -> [String] {
//    let fileManager = FileManager.default
//    let trashURLs = fileManager.urls(for: .trashDirectory, in: .userDomainMask)
//    do {
//        let trashContents = try fileManager.contentsOfDirectory(at: trashURLs.first!, includingPropertiesForKeys: nil, options: [])
//        let appFiles = trashContents.filter { $0.pathExtension == "app" }
//        writeLog(string: appFiles.first!.path)
//
//        return appFiles.map { $0.path }
//    } catch {
//        printOS("Failed to get contents of trash directory: \(error)")
//        return []
//    }
//}

//func hasAccessToTrashFolder() -> Bool {
//    let fileManager = FileManager.default
//    let trashURLs = fileManager.urls(for: .trashDirectory, in: .userDomainMask)
//    
//    if let trashURL = trashURLs.first {
//        return fileManager.isReadableFile(atPath: trashURL.path) && fileManager.isWritableFile(atPath: trashURL.path)
//    }
//    
//    return false
//}

//if hasAccessToTrashFolder() {
//    writeLog(string: "Your tool has access to the Trash folder.")
//    printOS("Your tool has access to the Trash folder.")
//} else {
//    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
//        NSWorkspace.shared.open(url)
//    }
//    writeLog(string: "Your tool does not have access to the Trash folder.")
//    printOS("Your tool does not have access to the Trash folder.")
//}


//var dirWatcher: DirMonitor?
//func fileW2() {
//    let home = FileManager.default.homeDirectoryForCurrentUser.path
//    let url = URL(fileURLWithPath: "\(home)/.Trash")
//    dirWatcher = DirMonitor(dir: url, queue: .global())
//    if dirWatcher?.start() == true {
//        NSLog("Started directory monitoring")
//    } else {
//        NSLog("Failed to start directory monitoring")
//    }
//}
//
//class DirMonitor {
//    
//    init(dir: URL, queue: DispatchQueue) {
//        self.dir = dir
//        self.queue = queue
//    }
//    
//    deinit {
//        // The stream has a reference to us via its `info` pointer. If the
//        // client releases their reference to us without calling `stop`, that
//        // results in a dangling pointer. We detect this as a programming error.
//        // There are other approaches to take here (for example, messing around
//        // with weak, or forming a retain cycle that’s broken on `stop`), but
//        // this approach:
//        //
//        // * Has clear rules
//        // * Is easy to implement
//        // * Generate a sensible debug message if the client gets things wrong
//        precondition(self.stream == nil, "released a running monitor")
//        // I added this log line as part of my testing of the deallocation path.
//        NSLog("did deinit")
//    }
//    
//    let dir: URL
//    let queue: DispatchQueue
//    
//    private var stream: FSEventStreamRef? = nil
//    
//    func start() -> Bool {
//        precondition(self.stream == nil, "started a running monitor")
//        
//        // Set up our context.
//        //
//        // `FSEventStreamCallback` is a C function, so we pass `self` to the
//        // `info` pointer so that it get call our `handleUnsafeEvents(…)`
//        // method.  This involves the standard `Unmanaged` dance:
//        //
//        // * Here we set `info` to an unretained pointer to `self`.
//        // * Inside the function we extract that pointer as `obj` and then use
//        //   that to call `handleUnsafeEvents(…)`.
//        
//        var context = FSEventStreamContext()
//        context.info = Unmanaged.passUnretained(self).toOpaque()
//        
//        // Create the stream.
//        //
//        // In this example I wanted to show how to deal with raw string paths,
//        // so I’m not taking advantage of `kFSEventStreamCreateFlagUseCFTypes`
//        // or the even cooler `kFSEventStreamCreateFlagUseExtendedData`.
//        
//        guard let stream = FSEventStreamCreate(nil, { (stream, info, numEvents, eventPaths, eventFlags, eventIds) in
//            let obj = Unmanaged<DirMonitor>.fromOpaque(info!).takeUnretainedValue()
//            obj.handleUnsafeEvents(numEvents: numEvents, eventPaths: eventPaths, eventFlags: eventFlags, eventIDs: eventIds)
//        },
//                                               &context,
//                                               [self.dir.path as NSString] as NSArray,
//                                               UInt64(kFSEventStreamEventIdSinceNow),
//                                               1.0,
//                                               FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
//        ) else {
//            return false
//        }
//        self.stream = stream
//        
//        // Now that we have a stream, schedule it on our target queue.
//        
//        FSEventStreamSetDispatchQueue(stream, queue)
//        guard FSEventStreamStart(stream) else {
//            FSEventStreamInvalidate(stream)
//            self.stream = nil
//            return false
//        }
//        return true
//    }
//    
//    private func handleUnsafeEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>, eventIDs: UnsafePointer<FSEventStreamEventId>) {
//        // This takes the low-level goo from the C callback, converts it to
//        // something that makes sense for Swift, and then passes that to
//        // `handle(events:…)`.
//        //
//        // Note that we don’t need to do any rebinding here because this data is
//        // coming C as the right type.
//        let pathsBase = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
//        let pathsBuffer = UnsafeBufferPointer(start: pathsBase, count: numEvents)
//        let flagsBuffer = UnsafeBufferPointer(start: eventFlags, count: numEvents)
//        let eventIDsBuffer = UnsafeBufferPointer(start: eventIDs, count: numEvents)
//        // As `zip(_:_:)` only handles two sequences, I map over the index.
//        let events = (0..<numEvents).map { i -> (url: URL, flags: FSEventStreamEventFlags, eventIDs: FSEventStreamEventId) in
//            let path = pathsBuffer[i]
//            // We set `isDirectory` to true because we only generate directory
//            // events (that is, we don’t pass
//            // `kFSEventStreamCreateFlagFileEvents` to `FSEventStreamCreate`.
//            // This is generally the best way to use FSEvents, but if you decide
//            // to take advantage of `kFSEventStreamCreateFlagFileEvents` then
//            // you’ll need to code to `isDirectory` correctly.
//            let url: URL = URL(fileURLWithFileSystemRepresentation: path, isDirectory: true, relativeTo: nil)
//            return (url, flagsBuffer[i], eventIDsBuffer[i])
//        }
//        self.handle(events: events)
//    }
//    
//    private func handle(events: [(url: URL, flags: FSEventStreamEventFlags, eventIDs: FSEventStreamEventId)]) {
//        // In this example we just print the events with get, prefixed by a
//        // count so that we can see the batching in action.
//        NSLog("%d", events.count)
//        for (url, flags, eventID) in events {
//            NSLog("%16x %8x %@", eventID, flags, url.path)
//        }
//        for (url, flags, _) in events {
//            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 {
//                NSLog("Removed: \(url.path)")
//            }
//            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 {
//                NSLog("Created: \(url.path)")
//            }
//        }
//        getTrashContents()
//    }
//    
//    func stop() {
//        guard let stream = self.stream else {
//            return          // We accept redundant calls to `stop`.
//        }
//        FSEventStreamStop(stream)
//        FSEventStreamInvalidate(stream)
//        self.stream = nil
//    }
//    
//    func getTrashContents() {
//        let fileManager = FileManager.default
//        let trashURLs = fileManager.urls(for: .trashDirectory, in: .userDomainMask)
//        let trashContents = try? fileManager.contentsOfDirectory(at: trashURLs.first!, includingPropertiesForKeys: nil, options: [])
//        printOS(trashContents as Any)
//    }
//}
