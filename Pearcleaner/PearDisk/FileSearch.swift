//
//  FileSearch.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 7/20/24.
//

import Foundation
import SwiftData
import AlinFoundation

enum FastFileSearchError: Error {
    case invalidPath
    case failedToReadDirectory
    case failedToGetFileInfo
}

class FastFileSearch {
    private let queue = DispatchQueue(label: "com.alienator88.Pearcleaner.disk", qos: .userInitiated, attributes: .concurrent)

    func search(url: URL, completion: @escaping (Result<[Item], Error>) -> Void) {
        queue.async {
            do {
                let items = try self.searchRecursive(url: url)
                let sortedItems = items.sorted { $0.size > $1.size }
                DispatchQueue.main.async {
                    completion(.success(sortedItems))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func searchRecursive(url: URL) throws -> [Item] {
        var items: [Item] = []

        guard let path = url.path.cString(using: .utf8) else {
            throw FastFileSearchError.invalidPath
        }

        guard let dir = opendir(path) else {
            throw FastFileSearchError.failedToReadDirectory
        }
        defer { closedir(dir) }

        while let entry = readdir(dir) {
            let name = withUnsafePointer(to: entry.pointee.d_name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen)) {
                    String(cString: $0)
                }
            }

            let exclude = [".", "..", ".DS_Store", ".localized"]
            if exclude.contains(name) { continue }

            let fullURL = url.appendingPathComponent(name)
            let fullPath = fullURL.path

            var st = stat()
            guard lstat(fullPath, &st) == 0 else {
                print("Failed to get file info for \(fullPath)")
                continue
            }

            let isDirectory = (st.st_mode & S_IFMT) == S_IFDIR
            if isDirectory {
                // Recursively search subdirectories
                do {
                    let subItems = try searchRecursive(url: fullURL)
                    items.append(contentsOf: subItems)
                } catch {
                    print("Error processing directory \(fullPath): \(error)")
                }
            } else {
                // Add non-directory files to the items array
                let size = Int64(st.st_size)
                let item = Item(url: fullURL, name: name, size: size)
                items.append(item)
            }
        }

        return items
    }
}
