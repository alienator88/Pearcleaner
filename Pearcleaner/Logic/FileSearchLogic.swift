//
//  FileSearchLogic.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 09/29/25.
//

import Foundation
import AppKit
import AlinFoundation

// Import SearchType from FileSearchView
enum SearchType: String, CaseIterable {
    case filesAndFolders = "Files & Folders"
    case filesOnly = "Files Only"
    case foldersOnly = "Folders Only"
}

class FileSearchEngine {
    private var shouldStop = false
    private let fileManager = FileManager.default
    private var caseSensitive = false
    private var searchType: SearchType = .filesAndFolders
    private var excludeSystemFolders = true
    private var searchRootPath = ""

    // Common system folder names to exclude (relative to macOS root)
    private let systemFoldersToExclude = [
        "System",
        "private",
        "usr",
        "bin",
        "sbin",
        "cores",
        "dev",
        "etc"
    ]

    func stop() {
        shouldStop = true
    }

    func search(
        rootPath: String,
        filters: [FilterType],
        includeSubfolders: Bool,
        includeHiddenFiles: Bool,
        caseSensitive: Bool,
        searchType: SearchType,
        excludeSystemFolders: Bool,
        onBatchFound: @escaping ([FileSearchResult]) -> Void,
        completion: @escaping () -> Void
    ) {
        self.caseSensitive = caseSensitive
        self.searchType = searchType
        self.excludeSystemFolders = excludeSystemFolders
        self.searchRootPath = rootPath
        Task(priority: .high) {
            await performSearch(
                rootPath: rootPath,
                filters: filters,
                includeSubfolders: includeSubfolders,
                includeHiddenFiles: includeHiddenFiles,
                onBatchFound: onBatchFound
            )
            completion()
        }
    }

    private func performSearch(
        rootPath: String,
        filters: [FilterType],
        includeSubfolders: Bool,
        includeHiddenFiles: Bool,
        onBatchFound: @escaping ([FileSearchResult]) -> Void
    ) async {
        var batch: [FileSearchResult] = []
        let batchSize = 1  // Update UI as soon as first result is found for immediate feedback

        // Pre-specify resource keys for better performance
        let resourceKeys: [URLResourceKey] = [
            .totalFileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .isAliasFileKey,
            .isPackageKey,
            .tagNamesKey,
            .fileResourceIdentifierKey  // For Finder comments via extended attributes
        ]

        if includeSubfolders {
            // Check if this path looks like a macOS root (has typical system structure)
            if isMacOSRootStructure(rootPath) {
                // Prioritize Users folder first for faster results
                let usersPath = (rootPath as NSString).appendingPathComponent("Users")
                await searchFolder(usersPath, resourceKeys: resourceKeys, includeHiddenFiles: includeHiddenFiles, filters: filters, batch: &batch, batchSize: batchSize, onBatchFound: onBatchFound)

                if shouldStop { return }

                // Then search other top-level directories
                do {
                    let topLevelContents = try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: rootPath), includingPropertiesForKeys: [], options: [])
                    for topLevelURL in topLevelContents {
                        if shouldStop { break }

                        // Skip Users since we already searched it
                        if topLevelURL.lastPathComponent == "Users" { continue }

                        // Skip system folders if enabled
                        if excludeSystemFolders && shouldExcludeSystemPath(topLevelURL.path) { continue }

                        await searchFolder(topLevelURL.path, resourceKeys: resourceKeys, includeHiddenFiles: includeHiddenFiles, filters: filters, batch: &batch, batchSize: batchSize, onBatchFound: onBatchFound)
                    }
                } catch {
                    printOS("Error reading root directory: \(error)")
                }
            } else {
                // For non-macOS-root paths, use standard enumerator
                await searchFolder(rootPath, resourceKeys: resourceKeys, includeHiddenFiles: includeHiddenFiles, filters: filters, batch: &batch, batchSize: batchSize, onBatchFound: onBatchFound)
            }
        } else {
            // Single-level search
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: URL(fileURLWithPath: rootPath),
                    includingPropertiesForKeys: resourceKeys,
                    options: includeHiddenFiles ? [] : [.skipsHiddenFiles]
                )

                for fileURL in contents {
                    if shouldStop {
                        break
                    }

                    // Skip system folders if enabled
                    if excludeSystemFolders && shouldExcludeSystemPath(fileURL.path) {
                        continue
                    }

                    if let result = await processItem(url: fileURL, filters: filters) {
                        batch.append(result)

                        if batch.count >= batchSize {
                            await flushBatch(&batch, onBatchFound: onBatchFound)
                        }
                    }
                }
            } catch {
                printOS("Error reading directory: \(rootPath), error: \(error)")
            }
        }

        // Flush remaining items
        if !batch.isEmpty {
            await flushBatch(&batch, onBatchFound: onBatchFound)
        }
    }

    private func searchFolder(
        _ folderPath: String,
        resourceKeys: [URLResourceKey],
        includeHiddenFiles: Bool,
        filters: [FilterType],
        batch: inout [FileSearchResult],
        batchSize: Int,
        onBatchFound: @escaping ([FileSearchResult]) -> Void
    ) async {
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: folderPath),
            includingPropertiesForKeys: resourceKeys,
            options: includeHiddenFiles ? [] : [.skipsHiddenFiles]
        ) else {
            return
        }

        // Drive the enumerator manually to avoid Sequence.makeIterator in async context (Swift 6)
        while !shouldStop, let fileURL = enumerator.nextObject() as? URL {
            // Skip system folders if enabled
            if excludeSystemFolders && shouldExcludeSystemPath(fileURL.path) {
                continue
            }

            // Check if item matches all filters
            if let result = await processItem(url: fileURL, filters: filters) {
                batch.append(result)

                // Flush batch when it reaches batch size
                if batch.count >= batchSize {
                    await flushBatch(&batch, onBatchFound: onBatchFound)
                }
            }
        }
    }

    private func flushBatch(
        _ batch: inout [FileSearchResult],
        onBatchFound: @escaping ([FileSearchResult]) -> Void
    ) async {
        let batchCopy = batch
        batch.removeAll()

        await MainActor.run {
            onBatchFound(batchCopy)
        }
    }

    private func processItem(url: URL, filters: [FilterType]) async -> FileSearchResult? {
        // Use hasDirectoryPath for faster directory detection
        let isDirectory = url.hasDirectoryPath
        let name = url.lastPathComponent
        let type = isDirectory ? "Folder" : (url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased())

        // Apply search type filter first (early return for performance)
        switch searchType {
        case .filesOnly:
            if isDirectory { return nil }
        case .foldersOnly:
            if !isDirectory { return nil }
        case .filesAndFolders:
            break
        }

        do {
            let resourceValues = try url.resourceValues(
                forKeys: [.totalFileSizeKey, .contentModificationDateKey, .creationDateKey, .isAliasFileKey, .isPackageKey, .tagNamesKey]
            )

            let isAlias = resourceValues.isAliasFile ?? false
            let isPackage = resourceValues.isPackage ?? false
            // Only get size for files, not directories (optimization)
            let size = isDirectory ? 0 : (resourceValues.totalFileSize.map { Int64($0) } ?? 0)
            let dateModified = resourceValues.contentModificationDate ?? Date()
            let dateCreated = resourceValues.creationDate ?? Date()
            let tags = resourceValues.tagNames ?? []

            // Get Finder comment via extended attributes
            let comment = getFinderComment(for: url)

            // Apply all filters
            for filter in filters {
                if !matchesFilter(
                    filter: filter,
                    name: name,
                    url: url,
                    type: type,
                    size: size,
                    dateModified: dateModified,
                    dateCreated: dateCreated,
                    isDirectory: isDirectory,
                    isAlias: isAlias,
                    isPackage: isPackage,
                    tags: tags,
                    comment: comment
                ) {
                    return nil  // Does not match this filter, skip
                }
            }

            // Get icon
            let icon = getIconForFileOrFolderNS(atPath: url)

            return FileSearchResult(
                url: url,
                name: name,
                type: type,
                size: size,
                dateModified: dateModified,
                isDirectory: isDirectory,
                icon: icon
            )
        } catch {
            return nil
        }
    }

    private func matchesFilter(
        filter: FilterType,
        name: String,
        url: URL,
        type: String,
        size: Int64,
        dateModified: Date,
        dateCreated: Date,
        isDirectory: Bool,
        isAlias: Bool,
        isPackage: Bool,
        tags: [String],
        comment: String
    ) -> Bool {
        switch filter {
        case .name(let nameFilter, let value):
            return matchesNameFilter(nameFilter: nameFilter, name: name, value: value)

        case .fileExtension(let extFilter, let extensions):
            let extList = extensions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            let fileExt = url.pathExtension.lowercased()

            switch extFilter {
            case .includes:
                return extList.contains(fileExt)
            case .excludes:
                return !extList.contains(fileExt)
            }

        case .size(let sizeFilter, let value, let max):
            return matchesSizeFilter(sizeFilter: sizeFilter, size: size, value: value, max: max)

        case .date(let dateFilter, let value, let end):
            return matchesDateFilter(dateFilter: dateFilter, dateModified: dateModified, dateCreated: dateCreated, value: value, end: end)

        case .kind(let kindFilter):
            return matchesKindFilter(kindFilter: kindFilter, isDirectory: isDirectory, isAlias: isAlias, isPackage: isPackage)

        case .tags(let tagFilter, let value):
            return matchesTagsFilter(tagFilter: tagFilter, tags: tags, value: value)

        case .comment(let commentFilter, let value):
            return matchesCommentFilter(commentFilter: commentFilter, comment: comment, value: value)
        }
    }

    private func matchesNameFilter(nameFilter: NameFilterType, name: String, value: String) -> Bool {
        let nameToCompare = caseSensitive ? name : name.lowercased()
        let valueToCompare = caseSensitive ? value : value.lowercased()

        switch nameFilter {
        case .contains:
            return nameToCompare.contains(valueToCompare)
        case .doesntContain:
            return !nameToCompare.contains(valueToCompare)
        case .startsWith:
            return nameToCompare.hasPrefix(valueToCompare)
        case .endsWith:
            return nameToCompare.hasSuffix(valueToCompare)
        case .equals:
            return nameToCompare == valueToCompare
        case .regex:
            let regexOptions: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: value, options: regexOptions) else {
                return false
            }
            let range = NSRange(name.startIndex..., in: name)
            return regex.firstMatch(in: name, range: range) != nil
        }
    }

    private func matchesSizeFilter(sizeFilter: SizeFilterType, size: Int64, value: Int64, max: Int64?) -> Bool {
        switch sizeFilter {
        case .greaterThan:
            return size > value
        case .lessThan:
            return size < value
        case .between:
            guard let max = max else { return false }
            return size >= value && size <= max
        case .equals:
            return size == value
        }
    }

    private func matchesDateFilter(
        dateFilter: DateFilterType,
        dateModified: Date,
        dateCreated: Date,
        value: Date,
        end: Date?
    ) -> Bool {
        switch dateFilter {
        case .createdBefore:
            return dateCreated < value
        case .createdAfter:
            return dateCreated > value
        case .createdBetween:
            guard let end = end else { return false }
            return dateCreated >= value && dateCreated <= end
        case .modifiedBefore:
            return dateModified < value
        case .modifiedAfter:
            return dateModified > value
        case .modifiedBetween:
            guard let end = end else { return false }
            return dateModified >= value && dateModified <= end
        }
    }

    private func matchesKindFilter(
        kindFilter: KindFilterType,
        isDirectory: Bool,
        isAlias: Bool,
        isPackage: Bool
    ) -> Bool {
        switch kindFilter {
        case .file:
            return !isDirectory && !isPackage
        case .folder:
            return isDirectory && !isPackage
        case .package:
            return isPackage
        case .alias:
            return isAlias
        }
    }

    private func matchesTagsFilter(tagFilter: TagFilterType, tags: [String], value: String) -> Bool {
        let tagNames = tags.map { $0.lowercased() }

        switch tagFilter {
        case .hasTag:
            let searchTag = value.lowercased()
            return tagNames.contains(searchTag)

        case .hasAnyOfTags:
            let searchTags = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            return searchTags.contains(where: { tagNames.contains($0) })

        case .hasAllOfTags:
            let searchTags = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            return searchTags.allSatisfy({ tagNames.contains($0) })

        case .doesntHaveTag:
            let searchTag = value.lowercased()
            return !tagNames.contains(searchTag)
        }
    }

    private func matchesCommentFilter(commentFilter: CommentFilterType, comment: String, value: String) -> Bool {
        let commentToCompare = caseSensitive ? comment : comment.lowercased()
        let valueToCompare = caseSensitive ? value : value.lowercased()

        switch commentFilter {
        case .contains:
            return commentToCompare.contains(valueToCompare)
        case .doesntContain:
            return !commentToCompare.contains(valueToCompare)
        case .equals:
            return commentToCompare == valueToCompare
        case .isEmpty:
            return comment.isEmpty
        }
    }

    private func getFinderComment(for url: URL) -> String {
        // Finder comments are stored in the kMDItemFinderComment extended attribute
        guard let data = url.withUnsafeFileSystemRepresentation({ path -> Data? in
            guard let path = path else { return nil }
            let attrName = "com.apple.metadata:kMDItemFinderComment"
            let length = getxattr(path, attrName, nil, 0, 0, 0)
            guard length > 0 else { return nil }
            var data = Data(count: length)
            let result = data.withUnsafeMutableBytes { buffer in
                getxattr(path, attrName, buffer.baseAddress, length, 0, 0)
            }
            return result > 0 ? data : nil
        }) else {
            return ""
        }

        // Parse the property list to get the comment string
        if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? String {
            return plist
        }

        return ""
    }

    private func shouldExcludeSystemPath(_ path: String) -> Bool {
        // If we're searching a macOS root structure, check if this path is a system folder
        // For example: /Volumes/Macintosh HD 2/System or /System

        // Get the path relative to the search root
        let relativePath: String
        if path.hasPrefix(searchRootPath) {
            relativePath = String(path.dropFirst(searchRootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            relativePath = path
        }

        // Get the first path component
        let components = relativePath.components(separatedBy: "/")
        guard let firstComponent = components.first, !firstComponent.isEmpty else {
            return false
        }

        // Check if the first component matches any system folder
        return systemFoldersToExclude.contains(firstComponent)
    }

    private func isMacOSRootStructure(_ path: String) -> Bool {
        // Check if this path has a typical macOS system structure
        // by looking for key directories: System, Users, Library, Applications
        let systemPath = (path as NSString).appendingPathComponent("System")
        let usersPath = (path as NSString).appendingPathComponent("Users")
        let libraryPath = (path as NSString).appendingPathComponent("Library")

        var isSystemDir: ObjCBool = false
        var isUsersDir: ObjCBool = false
        var isLibraryDir: ObjCBool = false

        let hasSystem = fileManager.fileExists(atPath: systemPath, isDirectory: &isSystemDir) && isSystemDir.boolValue
        let hasUsers = fileManager.fileExists(atPath: usersPath, isDirectory: &isUsersDir) && isUsersDir.boolValue
        let hasLibrary = fileManager.fileExists(atPath: libraryPath, isDirectory: &isLibraryDir) && isLibraryDir.boolValue

        // If it has at least System and Users, it's likely a macOS root
        return hasSystem && hasUsers && hasLibrary
    }
}
