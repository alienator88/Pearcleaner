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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if infoSidebar {
            HStack {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    ZombieSizeInfoSection(displaySizeTotal: displaySizeTotal, selectedCount: selectedCount, totalCount: totalCount)
                    Divider()
                    ZombieExcludedPathsSection(fsm: fsm)
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
                            ZombieExcludedPathRow(path: path, fsm: fsm)
                        }
                    }
                }
            }
        }
    }
}

// Individual excluded path row component
struct ZombieExcludedPathRow: View {
    @Environment(\.colorScheme) var colorScheme
    let path: String
    @ObservedObject var fsm: FolderSettingsManager
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                    .onHover { hovered in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovered = hovered
                        }
                    }
                
                if isHovered {
                    Text(path)
                        .font(.caption2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .lineLimit(nil) // Allow multiple lines
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            Spacer()
            
            Button {
                fsm.removePathZ(path)
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Remove from exclusion list")
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
