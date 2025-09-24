//
//  LipoSidebarView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 8/9/25.
//

import AlinFoundation
import SwiftUI

// Break up the sidebar into smaller components
struct LipoSidebarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Binding var infoSidebar: Bool
    let excludedApps: Set<String>
    @Binding var prune: Bool
    @Binding var filterMinSavings: Bool
    let onRemoveExcluded: (String) -> Void
    let totalSpaceSaved: UInt64
    let savingsAllApps: UInt64

    var body: some View {
        if infoSidebar {
            HStack {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    LipoDescriptionSection()
                    Divider()
                    LipoSavingsSection(
                        totalSpaceSaved: totalSpaceSaved, savingsAllApps: savingsAllApps)
                    Divider()
                    LipoExcludedAppsSection(
                        excludedApps: excludedApps, onRemoveExcluded: onRemoveExcluded)
                    Spacer()
                    LipoOptionsSection(prune: $prune, filterMinSavings: $filterMinSavings)
                }
                .padding()
                .frame(width: 280)
                .ifGlassSidebar()
            }
            .background(.black.opacity(0.00000000001))
            .transition(.move(edge: .trailing))
            .onTapGesture {
                infoSidebar = false
            }
        }
    }
}

// Description component
struct LipoDescriptionSection: View {
    @State private var showFullDescription = false
    @Environment(\.colorScheme) var colorScheme
    private let shortDescription =
        "App lipo targets the Mach-O binaries inside your universal app bundles and removes any unused architectures..."
    private let fullDescription =
        "App lipo targets the Mach-O binaries inside your universal app bundles and removes any unused architectures, such as x86_64 or arm64, leaving only the architectures your computer actually supports. The list shows only universal type apps, not your full app list. After lipo, the green portion will be removed from your app's binary. It's recommended to open an app at least once before lipo to make sure macOS has cached the signature. Privileged Helper is required to perform this action on certain applications."

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(showFullDescription ? fullDescription : shortDescription)
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button(showFullDescription ? "Less" : "More") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFullDescription.toggle()
                }
            }
            .font(.caption2)
            .buttonStyle(.link)
        }
    }
}

struct LipoSavingsSection: View {
    let totalSpaceSaved: UInt64
    let savingsAllApps: UInt64

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 0) {
                Text("Total Saved:")
                Spacer()
                Text(formatByte(size: Int64(totalSpaceSaved)).human)
                    .foregroundStyle(.green)
            }
            HStack(spacing: 0) {
                Text("Approximate Savings:")
                Spacer()
                Text(formatByte(size: Int64(savingsAllApps)).human)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// Excluded apps component
struct LipoExcludedAppsSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    let excludedApps: Set<String>
    let onRemoveExcluded: (String) -> Void

    // Create a computed property that sorts the excluded apps alphabetically
    private var sortedExcludedApps: [String] {
        Array(excludedApps).sorted { appPath1, appPath2 in
            let app1 = appState.sortedApps.first(where: { $0.path.path == appPath1 })
            let app2 = appState.sortedApps.first(where: { $0.path.path == appPath2 })

            let name1 = app1?.appName ?? ""
            let name2 = app2?.appName ?? ""

            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Excluded Apps")
                .font(.subheadline)
                .fontWeight(.medium)

            if excludedApps.isEmpty {
                Text("No apps excluded")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .italic()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(sortedExcludedApps, id: \.self) { appPath in
                            LipoExcludedAppRow(appPath: appPath, onRemoveExcluded: onRemoveExcluded)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

// Individual excluded app row component
struct LipoExcludedAppRow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    let appPath: String
    let onRemoveExcluded: (String) -> Void

    var body: some View {
        if let appInfo = appState.sortedApps.first(where: { $0.path.path == appPath }) {
            HStack {
                if let appIcon = appInfo.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(appInfo.appName)
                        .font(.caption)
                        .lineLimit(1)
                    Text(appInfo.appVersion)
                        .font(.caption2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    onRemoveExcluded(appPath)
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
}

// Prune toggle component
struct LipoOptionsSection: View {
    @Binding var prune: Bool
    @Binding var filterMinSavings: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Text("Click to dismiss").font(.caption).foregroundStyle(
                ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
            Spacer()
            Menu {
                Toggle(
                    isOn: $prune,
                    label: {
                        Text("Remove unused languages during lipo")
                            .font(.caption)
                    })

                Toggle(
                    isOn: $filterMinSavings,
                    label: {
                        Text("Only show apps with savings of 1MB+")
                            .font(.caption)
                    })
            } label: {
                Label("Options", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

        }

    }
}

struct LipoLegend: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4).fill(.green).frame(width: 12, height: 12)
            Text("Approximate Savings").foregroundStyle(
                ThemeColors.shared(for: colorScheme).secondaryText)
        }
    }
}
