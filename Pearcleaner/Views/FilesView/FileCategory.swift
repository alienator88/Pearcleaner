//
//  FileCategory.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/18/25.
//

import Foundation
import SwiftUI
import AppKit
import AlinFoundation

// MARK: - FileCategory Enum

enum FileCategory: String, CaseIterable, Identifiable {
    case application = "Application Bundles"
    case preferences = "Preferences"
    case caches = "Caches"
    case applicationSupport = "Application Support"
    case containers = "Containers"
    case logs = "Logs"
    case launchAgents = "Launch Agents & Daemons"
    case savedState = "Saved Application State"
    case internetPlugins = "Internet Plug-Ins"
    case applicationScripts = "Application Scripts"
    case systemFiles = "System Files"
    case userFiles = "User Files"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .application:
            return "app.fill"
        case .preferences:
            return "gearshape.fill"
        case .caches:
            return "tray.fill"
        case .applicationSupport:
            return "folder.fill"
        case .containers:
            return "cube.box.fill"
        case .logs:
            return "doc.text.fill"
        case .launchAgents:
            return "gearshape.2.fill"
        case .savedState:
            return "clock.arrow.circlepath"
        case .internetPlugins:
            return "network"
        case .applicationScripts:
            return "applescript.fill"
        case .systemFiles:
            return "cpu.fill"
        case .userFiles:
            return "person.fill"
        case .other:
            return "questionmark.folder.fill"
        }
    }

    var sortOrder: Int {
        // Application bundle should always be first
        return FileCategory.allCases.firstIndex(of: self) ?? 100
    }
}

// MARK: - Categorization Function

func categorizeFile(_ url: URL) -> FileCategory {
    let path = url.path

    // Check if it's an app bundle (should be first)
    if url.pathExtension == "app" {
        return .application
    }

    // Check preferences
    if path.contains("/Library/Preferences") {
        return .preferences
    }

    // Check caches
    if path.contains("/Library/Caches") {
        return .caches
    }

    // Check application support
    if path.contains("/Library/Application Support") {
        return .applicationSupport
    }

    // Check containers
    if path.contains("/Library/Containers") || path.contains("/Library/Group Containers") {
        return .containers
    }

    // Check logs
    if path.contains("/Library/Logs") {
        return .logs
    }

    // Check launch agents/daemons
    if path.contains("/LaunchAgents") || path.contains("/LaunchDaemons") {
        return .launchAgents
    }

    // Check saved application state
    if path.contains("/Saved Application State") {
        return .savedState
    }

    // Check internet plug-ins
    if path.contains("/Internet Plug-Ins") {
        return .internetPlugins
    }

    // Check application scripts
    if path.contains("/Application Scripts") {
        return .applicationScripts
    }

    // Check system files
    if path.contains("/Library/Extensions") ||
       path.contains("/Library/PrivilegedHelperTools") ||
       path.contains("/private/var/db/receipts") ||
       path.contains("/HTTPStorages") ||
       path.contains("/Library/WebKit") {
        return .systemFiles
    }

    // Check user files (anything in home directory, excluding ~/Applications)
    if path.hasPrefix(home) && !path.contains("\(home)/Applications") {
        return .userFiles
    }

    // Default to other
    return .other
}

// MARK: - GroupedFiles Struct

struct GroupedFiles {
    let category: FileCategory
    var files: [URL]
    var totalSize: Int64
    var isExpanded: Bool

    // Selection state
    var allSelected: Bool      // All files in category selected
    var someSelected: Bool     // Some (but not all) files selected
}

// MARK: - FileCategoryView Component

struct FileCategoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    let group: GroupedFiles
    let onToggleExpand: () -> Void
    let onToggleSelection: () -> Void
    let fileItemBinding: (URL) -> Binding<Bool>
    let removeAssociation: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category Header
            HStack(spacing: 10) {
                // Expand/Collapse chevron
                Button(action: onToggleExpand) {
                    Image(systemName: group.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .frame(width: 10)
                }
                .buttonStyle(.plain)

                // Category checkbox (select all in category)
                Button(action: onToggleSelection) {
                    Image(systemName: group.allSelected ? "checkmark.circle.fill" :
                          (group.someSelected ? "circle.lefthalf.filled" : "circle"))
                        .foregroundStyle(group.allSelected || group.someSelected ?
                                       ThemeColors.shared(for: colorScheme).accent :
                                       ThemeColors.shared(for: colorScheme).secondaryText)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help(group.allSelected ? "Deselect all files in this category" : "Select all files in this category")

                // Category name
                Text(group.category.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                // File count
                Text(verbatim: "(\(group.files.count))")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                Spacer()

                // Total size
                Text(formatByte(size: group.totalSize).human)
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpand()
            }

            // Files in category (only if expanded)
            if group.isExpanded {
                LazyVStack(spacing: 0) {
                    ForEach(Array(group.files.enumerated()), id: \.element) { index, path in
                        VStack(spacing: 0) {
                            FileDetailsItem(
                                path: path,
                                removeAssociation: removeAssociation,
                                isSelected: fileItemBinding(path)
                            )
                            .padding(.leading, 35) // Indent files under category

                            if index < group.files.count - 1 {
                                Divider()
                                    .padding(.leading, 35)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - ZombieFileCategoryView Component

struct ZombieFileCategoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    let group: GroupedFiles
    let onToggleExpand: () -> Void
    let onToggleSelection: () -> Void
    let fileItemBinding: (URL) -> Binding<Bool>
    @Binding var memoizedFiles: [URL]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category Header
            HStack(spacing: 10) {
                // Expand/Collapse chevron
                Button(action: onToggleExpand) {
                    Image(systemName: group.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .frame(width: 10)
                }
                .buttonStyle(.plain)

                // Category checkbox (select all in category)
                Button(action: onToggleSelection) {
                    Image(systemName: group.allSelected ? "checkmark.circle.fill" :
                          (group.someSelected ? "circle.lefthalf.filled" : "circle"))
                        .foregroundStyle(group.allSelected || group.someSelected ?
                                       ThemeColors.shared(for: colorScheme).accent :
                                       ThemeColors.shared(for: colorScheme).secondaryText)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help(group.allSelected ? "Deselect all files in this category" : "Select all files in this category")

                // Category name
                Text(group.category.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                // File count
                Text(verbatim: "(\(group.files.count))")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                Spacer()

                // Total size
                Text(formatByte(size: group.totalSize).human)
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpand()
            }

            // Files in category (only if expanded)
            if group.isExpanded {
                LazyVStack(spacing: 0) {
                    ForEach(Array(group.files.enumerated()), id: \.element) { index, path in
                        VStack(spacing: 0) {
                            if let fileSize = appState.zombieFile.fileSize[path],
                               let fileIcon = appState.zombieFile.fileIcon[path],
                               let iconImage = fileIcon.map(Image.init(nsImage:)) {
                                ZombieFileDetailsItem(
                                    size: fileSize,
                                    icon: iconImage,
                                    path: path,
                                    memoizedFiles: $memoizedFiles,
                                    isSelected: fileItemBinding(path)
                                )
                                .padding(.leading, 35) // Indent files under category
                            }

                            if index < group.files.count - 1 {
                                Divider()
                                    .padding(.leading, 35)
                            }
                        }
                    }
                }
            }
        }
    }
}
