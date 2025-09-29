//
//  FileSearchModels.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 09/29/25.
//

import Foundation
import AppKit

struct FileSearchResult: Identifiable, Hashable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let type: String  // file extension or "Folder"
    let size: Int64
    let dateModified: Date
    let isDirectory: Bool
    let icon: NSImage?

    static func == (lhs: FileSearchResult, rhs: FileSearchResult) -> Bool {
        return lhs.id == rhs.id &&
               lhs.url == rhs.url &&
               lhs.name == rhs.name &&
               lhs.type == rhs.type &&
               lhs.size == rhs.size
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(url)
        hasher.combine(name)
        hasher.combine(type)
    }
}

enum FilterType: Identifiable, Hashable {
    case name(NameFilterType, String)
    case fileExtension(ExtensionFilterType, String)  // comma-separated extensions
    case size(SizeFilterType, Int64, Int64?)  // second param is max for "between"
    case date(DateFilterType, Date, Date?)  // second param is end date for "between"
    case kind(KindFilterType)
    case tags(TagFilterType, String)  // comma-separated tags
    case comment(CommentFilterType, String)

    var id: String {
        switch self {
        case .name(let type, let value):
            return "name_\(type.rawValue)_\(value)"
        case .fileExtension(let type, let value):
            return "extension_\(type.rawValue)_\(value)"
        case .size(let type, let value, let max):
            return "size_\(type.rawValue)_\(value)_\(max ?? 0)"
        case .date(let type, let value, let end):
            return "date_\(type.rawValue)_\(value.timeIntervalSince1970)_\(end?.timeIntervalSince1970 ?? 0)"
        case .kind(let type):
            return "kind_\(type.rawValue)"
        case .tags(let type, let value):
            return "tags_\(type.rawValue)_\(value)"
        case .comment(let type, let value):
            return "comment_\(type.rawValue)_\(value)"
        }
    }

    var displayText: String {
        switch self {
        case .name(let type, let value):
            return "\(type.displayName): \(value)"
        case .fileExtension(let type, let value):
            return "\(type.displayName): \(value)"
        case .size(let type, let value, let max):
            if let max = max, type == .between {
                return "\(type.displayName): \(formatBytes(value)) - \(formatBytes(max))"
            }
            return "\(type.displayName): \(formatBytes(value))"
        case .date(let type, let value, let end):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            if let end = end, type == .createdBetween || type == .modifiedBetween {
                return "\(type.displayName): \(formatter.string(from: value)) - \(formatter.string(from: end))"
            }
            return "\(type.displayName): \(formatter.string(from: value))"
        case .kind(let type):
            return "Kind: \(type.displayName)"
        case .tags(let type, let value):
            return "\(type.displayName): \(value)"
        case .comment(let type, let value):
            return "\(type.displayName): \(value)"
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

enum NameFilterType: String, CaseIterable {
    case contains
    case doesntContain
    case startsWith
    case endsWith
    case equals
    case regex

    var displayName: String {
        switch self {
        case .contains: return "Name contains"
        case .doesntContain: return "Name doesn't contain"
        case .startsWith: return "Name starts with"
        case .endsWith: return "Name ends with"
        case .equals: return "Name equals"
        case .regex: return "Name matches regex"
        }
    }
}

enum ExtensionFilterType: String, CaseIterable {
    case includes
    case excludes

    var displayName: String {
        switch self {
        case .includes: return "Extension is"
        case .excludes: return "Extension is not"
        }
    }
}

enum SizeFilterType: String, CaseIterable {
    case greaterThan
    case lessThan
    case between
    case equals

    var displayName: String {
        switch self {
        case .greaterThan: return "Size >"
        case .lessThan: return "Size <"
        case .between: return "Size between"
        case .equals: return "Size ="
        }
    }
}

enum DateFilterType: String, CaseIterable {
    case createdBefore
    case createdAfter
    case createdBetween
    case modifiedBefore
    case modifiedAfter
    case modifiedBetween

    var displayName: String {
        switch self {
        case .createdBefore: return "Created before"
        case .createdAfter: return "Created after"
        case .createdBetween: return "Created between"
        case .modifiedBefore: return "Modified before"
        case .modifiedAfter: return "Modified after"
        case .modifiedBetween: return "Modified between"
        }
    }
}

enum KindFilterType: String, CaseIterable {
    case file
    case folder
    case package
    case alias

    var displayName: String {
        switch self {
        case .file: return "File"
        case .folder: return "Folder"
        case .package: return "Package"
        case .alias: return "Alias"
        }
    }
}

enum SortColumn: String, CaseIterable {
    case name
    case type
    case size
    case dateModified
    case path

    var displayName: String {
        switch self {
        case .name: return "Name"
        case .type: return "Type"
        case .size: return "Size"
        case .dateModified: return "Date Modified"
        case .path: return "Path"
        }
    }
}

enum SortOrder {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

enum TagFilterType: String, CaseIterable {
    case hasTag
    case hasAnyOfTags
    case hasAllOfTags
    case doesntHaveTag

    var displayName: String {
        switch self {
        case .hasTag: return "Has tag"
        case .hasAnyOfTags: return "Has any of tags"
        case .hasAllOfTags: return "Has all of tags"
        case .doesntHaveTag: return "Doesn't have tag"
        }
    }
}

enum CommentFilterType: String, CaseIterable {
    case contains
    case doesntContain
    case equals
    case isEmpty

    var displayName: String {
        switch self {
        case .contains: return "Comment contains"
        case .doesntContain: return "Comment doesn't contain"
        case .equals: return "Comment equals"
        case .isEmpty: return "Comment is empty"
        }
    }
}