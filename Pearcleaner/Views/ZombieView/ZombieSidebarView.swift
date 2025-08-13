//
//  ZombieSidebarView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 8/9/25.
//

import Foundation
import SwiftUI
import AlinFoundation


// Main zombie sidebar view
struct ZombieSidebarView: View {
    @Binding var infoSidebar: Bool
    let displaySizeTotal: String
    let selectedCount: Int
    let totalCount: Int
    @ObservedObject var fsm: FolderSettingsManager
    @Binding var memoizedFiles: [URL]
    let onRestoreFile: (URL) -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if infoSidebar {
            HStack {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    ZombieSizeInfoSection(displaySizeTotal: displaySizeTotal, selectedCount: selectedCount, totalCount: totalCount)
                    Divider()
                    ZombieExcludedPathsSection(fsm: fsm, memoizedFiles: $memoizedFiles, onRestoreFile: onRestoreFile)
                    Spacer()
                    ZombieSidebarFooter()
                }
                .padding()
                .frame(width: 280)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.2), lineWidth: 1)
                }
            }
            .background(.black.opacity(0.00000000001))
            .transition(.move(edge: .trailing))
            .onTapGesture {
                infoSidebar = false
            }
        }
    }
}

// Size info component
struct ZombieSizeInfoSection: View {
    let displaySizeTotal: String
    let selectedCount: Int
    let totalCount: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("Total Size:")
                Spacer()
                Text(displaySizeTotal)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            }

            HStack(spacing: 0) {
                Text("Selected Items:")
                Spacer()
                Text("\(selectedCount) / \(totalCount)")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
        }
    }
}

// Excluded paths section component
struct ZombieExcludedPathsSection: View {
    @ObservedObject var fsm: FolderSettingsManager
    @Binding var memoizedFiles: [URL]
    let onRestoreFile: (URL) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    private var sortedExcludedPaths: [String] {
        fsm.fileFolderPathsZ.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Excluded Paths")
                .font(.subheadline)
                .fontWeight(.medium)

            if fsm.fileFolderPathsZ.isEmpty {
                Text("No paths excluded")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .italic()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(sortedExcludedPaths, id: \.self) { path in
                            ZombieExcludedPathRow(path: path, fsm: fsm, memoizedFiles: $memoizedFiles, onRestoreFile: onRestoreFile)
                        }
                    }
                }
            }
        }
    }
}

// Individual excluded path row component
struct ZombieExcludedPathRow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    let path: String
    @ObservedObject var fsm: FolderSettingsManager
    @Binding var memoizedFiles: [URL]
    let onRestoreFile: (URL) -> Void
    @State private var isHovered = false
    
    // Check if this path is associated with any app
    private var isAssociated: Bool {
        ZombieFileStorage.shared.isPathAssociated(URL(fileURLWithPath: path))
    }
    
    // Get the app name that this file is associated with
    private var associatedAppName: String? {
        let pathURL = URL(fileURLWithPath: path)
        for (appPath, associatedFiles) in ZombieFileStorage.shared.associatedFiles {
            if associatedFiles.contains(pathURL) {
                // Find the app in sortedApps to get its name
                if let app = appState.sortedApps.first(where: { $0.path == appPath }) {
                    return app.appName
                }
                // Fallback to the app path's last component if not found in sortedApps
                return appPath.lastPathComponent.replacingOccurrences(of: ".app", with: "")
            }
        }
        return nil
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)

                        // Show link icon if this path is associated
                        if isAssociated {
                            Image(systemName: "link")
                                .font(.caption2)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                        }

                        // Show associated app name in parentheses
                        if let appName = associatedAppName {
                            Text("(\(appName))")
                                .font(.caption2)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .onHover { hovered in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovered = hovered
                        }
                    }
                    
                    if isHovered {
                        Text(path)
                            .font(.caption2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .lineLimit(nil)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            
            Spacer()
            
            Button {
                let pathURL = URL(fileURLWithPath: path)
                
                // Remove from exclusion list
                fsm.removePathZ(path)
                
                // If this was an associated file, also remove the association
                if isAssociated {
                    // Find which app this is associated with and remove the association
                    for (appPath, associatedFiles) in ZombieFileStorage.shared.associatedFiles {
                        if associatedFiles.contains(pathURL) {
                            ZombieFileStorage.shared.removeAssociation(appPath: appPath, zombieFilePath: pathURL)
                            break
                        }
                    }
                }
                
                // Restore file to memoized list
                onRestoreFile(pathURL)
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help(isAssociated ? "Remove association and exclusion" : "Remove from exclusion list")
        }
        .padding(8)
        .background(ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.1))
        .cornerRadius(6)
    }
}

// Footer component
struct ZombieSidebarFooter: View {
    var body: some View {
        @Environment(\.colorScheme) var colorScheme
        HStack {
            Text("Click to dismiss")
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
            Spacer()
        }
    }
}
