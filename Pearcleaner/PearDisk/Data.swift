////
////  Item.swift
////  PearDisk
////
////  Created by Alin Lupascu on 7/17/24.
////
//
//import Foundation
//import SwiftData
//
//// Data Model
//@Model
//final class Item: Identifiable {
//    @Attribute(.unique) let url: URL
//    let name: String
//    var size: Int64
//    let isDirectory: Bool
//    let parentURL: URL?
//    let timestamp: Date
//
//    init(url: URL, name: String, size: Int64, isDirectory: Bool, parentURL: URL? = nil) {
//        self.url = url
//        self.name = name
//        self.size = size
//        self.isDirectory = isDirectory
//        self.parentURL = parentURL
//        self.timestamp = Date()
//    }
//}
//
//
//// Wipe peardisk.sqlite file
//func wipeSwiftDataStorage() async {
//    let fileManager = FileManager.default
//    guard let urlApp = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
//        print("Could not find the Application Support directory.")
//        return
//    }
//
//    let peardiskURL = urlApp.appendingPathComponent("PearDisk").appendingPathComponent("Database")
//
//    do {
//
//        if fileManager.fileExists(atPath: peardiskURL.path) {
//            try fileManager.removeItem(at: peardiskURL)
//            print("\(peardiskURL.lastPathComponent) has been deleted.")
//        }
//    } catch {
//        print("Error deleting SwiftData storage: \(error)")
//    }
//}
//
//func wipeSwiftDataStorage2() async {
//    guard let container = try? ModelContainer(for: Item.self) else {
//        print("Failed to create ModelContainer.")
//        return
//    }
//
//    let urlApp = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
//
//    if let urlApp = urlApp {
//        let url = urlApp.appendingPathComponent("PearDisk").appendingPathComponent("peardisk.sqlite")
//        if FileManager.default.fileExists(atPath: url.path) {
//            print("Peardisk.sqlite: \(url.path(percentEncoded: false))")
//        }
//    } else {
//        fatalError("Could not find the Application Support directory.")
//    }
//
//
//    await MainActor.run {
//        let context = container.mainContext
//
//        do {
//            try context.delete(model: Item.self)
//            try context.save()
//            print("Peardisk.sqlite has been successfully wiped.")
//        } catch {
//            print("Error wiping SwiftData storage: \(error)")
//        }
//    }
//}
//
//
//
//
//// Print size of peardisk.sqlite file
//func printSwiftDataCacheSize() async {
//    // Get the Application Support directory URL for your app
//    guard let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
//        print("Could not find the Application Support directory.")
//        return
//    }
//
//    // Create the custom directory URL
//    let customDirectoryURL = applicationSupportDirectory.appendingPathComponent("PearDisk").appendingPathComponent("Database")
//    let storeURL = customDirectoryURL.appendingPathComponent("peardisk").appendingPathExtension("sqlite")
//
//    // Check if the store URL exists
//    guard FileManager.default.fileExists(atPath: storeURL.path) else {
//        print("Store file does not exist.")
//        return
//    }
//
//    // Initialize the ModelContainer with the custom store URL
//    let modelConfiguration = ModelConfiguration(url: storeURL)
//
//    do {
//        let container = try ModelContainer(for: Item.self, configurations: modelConfiguration)
//
//        await MainActor.run {
//            let context = container.mainContext
//            let fetchDescriptor = FetchDescriptor<Item>()
//
//            do {
//                let count = try context.fetchCount(fetchDescriptor)
//                print("Number of Item objects: \(count)")
//
//                // Get the size of the store file directly
//                let fileManager = FileManager.default
//                do {
//                    let attributes = try fileManager.attributesOfItem(atPath: storeURL.path)
//                    if let size = attributes[.size] as? Int64 {
//                        let sizeMB = Double(size) / (1024 * 1024)
//                        print("Total size of SwiftData storage: \(String(format: "%.2f", sizeMB)) MB")
//                    } else {
//                        print("Could not retrieve file size.")
//                    }
//                } catch {
//                    print("Could not access file at \(storeURL.path): \(error)")
//                }
//            } catch {
//                print("Error fetching data: \(error)")
//            }
//        }
//    } catch {
//        print("Could not create ModelContainer: \(error)")
//    }
//}
//
//
//
//// Setup Data Model
//func createSharedModelContainer() -> ModelContainer {
//    do {
//        // Get the Application Support directory URL for your app
//        guard let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
//            fatalError("Could not find the Application Support directory.")
//        }
//
//        // Create the custom directory URL
//        let customDirectoryURL = applicationSupportDirectory.appendingPathComponent("PearDisk", isDirectory: true).appendingPathComponent("Database", isDirectory: true)
//
//        // Create the directory if it doesn't exist
//        do {
//            try FileManager.default.createDirectory(at: customDirectoryURL, withIntermediateDirectories: true, attributes: nil)
//        } catch {
//            fatalError("Could not create directory: \(error)")
//        }
//
//        // Create the store URL with the desired filename inside the custom directory
//        let storeURL = customDirectoryURL.appendingPathComponent("peardisk").appendingPathExtension("sqlite")
//
//        // Ensure the directory is accessible for reading and writing
//        let fileManager = FileManager.default
//        var isDirectory: ObjCBool = true
//        if !fileManager.fileExists(atPath: customDirectoryURL.path, isDirectory: &isDirectory) {
//            fatalError("Directory does not exist.")
//        }
//
//        if !fileManager.isWritableFile(atPath: customDirectoryURL.path) {
//            fatalError("Directory is not writable.")
//        }
//
//        if !fileManager.isReadableFile(atPath: customDirectoryURL.path) {
//            fatalError("Directory is not readable.")
//        }
//
//        let modelConfiguration = ModelConfiguration(url: storeURL)
//        return try ModelContainer(for: Item.self, configurations: modelConfiguration)
//    } catch {
//        fatalError("Could not create ModelContainer: \(error)")
//    }
//}
