//
//  Trash.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/18/24.
//



import Foundation

//class TrashManager {
//    private var fileLocations: [URL: URL] = [:] // Maps original location to trash location
//
//    // Function to move files to Trash and track their original locations
//    func delete(fileURLs: [URL]) {
//        let fileManager = FileManager.default
//        let trashURL = try! fileManager.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: nil, create: false)
//
//        for originalURL in fileURLs {
//            let destinationURL = trashURL.appendingPathComponent(originalURL.lastPathComponent)
//
//            do {
//                // The resultingItemURL is the new location of the item in the trash.
//                var resultingItemURL: NSURL?
//                try fileManager.trashItem(at: originalURL, resultingItemURL: &resultingItemURL)
//                if let trashPath = resultingItemURL as URL? {
//                    // Track the original URL and its corresponding location in the Trash
//                    fileLocations[originalURL] = trashPath
//                }
//            } catch {
//                print("Error moving file to Trash: \(error)")
//            }
//        }
//    }
//
//    // Function to undo the deletion of files, moving them back from Trash to their original locations
//    func undoDelete() {
//        let fileManager = FileManager.default
//
//        for (originalURL, trashURL) in fileLocations {
//            do {
//                // Attempt to move the item back to its original location
//                try fileManager.moveItem(at: trashURL, to: originalURL)
//            } catch {
//                print("Error moving file back from Trash: \(error)")
//            }
//        }
//
//        // Clear the tracking dictionary after undoing the deletions
//        fileLocations.removeAll()
//    }
//}






//import Foundation
//
//func moveToTrash(fileURLs: [URL], completion: @escaping () -> Void = {}) {
//    for fileURL in fileURLs {
//        do {
//            try _ = fileURL.checkResourceIsReachable()
//        } catch {
//            printOS(error.localizedDescription)
//        }
//    }
//    let target: NSAppleEventDescriptor = .init(bundleIdentifier: "com.apple.finder")
//    let event: NSAppleEventDescriptor = .init(eventClass: kAECoreSuite,
//                                              eventID: AEEventID(kAEDelete),
//                                              targetDescriptor: target,
//                                              returnID: AEReturnID(kAutoGenerateReturnID),
//                                              transactionID: AETransactionID(kAnyTransactionID))
//    let fileList: NSAppleEventDescriptor = fileURLs.enumerated().reduce(into: .init(listDescriptor: ())) {
//        (result: inout NSAppleEventDescriptor, element: (offset: Int, element: URL)) in
//        if let nativePath: NSAppleEventDescriptor = .init(
//            descriptorType: typeFileURL,
//            data: element.element.absoluteString.data(using: .utf8)
//        ) {
//            result.insert(nativePath, at: element.offset + 1)
//        }
//    }
//
//    event.setParam(fileList, forKeyword: keyDirectObject)
//
//    do {
//        try event.sendEvent(options: .noReply, timeout: TimeInterval(kAEDefaultTimeout))
//    } catch let error as NSError {
//        if case -600 = error.code {
//            printOS("Finder is not running.")
//        } else {
//            printOS(error.description)
//        }
//    }
//
//    completion()
//}

