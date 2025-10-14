//
//  AppsUpdaterView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import SwiftUI
import AlinFoundation

struct AppsUpdaterView: View {
    @StateObject private var updateManager = UpdateManager.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    @State private var collapsedCategories: Set<String> = []
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    private var totalUpdateCount: Int {
        updateManager.updatesBySource.values.reduce(0) { $0 + $1.count }
    }

    @ViewBuilder
    private var resultsCountBar: some View {
        if updateManager.hasUpdates {
            HStack {
                Text("\(totalUpdateCount) update\(totalUpdateCount == 1 ? "" : "s")")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                if updateManager.isScanning {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar (matching Homebrew style)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .controlGroup(Capsule(style: .continuous), level: .primary)
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Results count bar
            resultsCountBar

            // Category-based list
            if updateManager.isScanning {
                // Loading state - centered
                VStack(alignment: .center, spacing: 10) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Scanning for updates...")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !updateManager.hasUpdates {
                // Empty state - centered
                VStack(alignment: .center, spacing: 10) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    Text("All apps up to date")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Homebrew Category
                        if let homebrewApps = updateManager.updatesBySource[.homebrew],
                           !homebrewApps.isEmpty {
                            CategorySection(
                                title: "Homebrew",
                                icon: "mug",
                                apps: homebrewApps,
                                searchText: searchText,
                                collapsed: collapsedCategories.contains("Homebrew"),
                                onToggle: { toggleCategory("Homebrew") },
                                onUpdateAll: {
                                    Task { await updateManager.updateAll(source: .homebrew) }
                                },
                                isFirst: true
                            )
                        }

                        // App Store Category
                        if let appStoreApps = updateManager.updatesBySource[.appStore],
                           !appStoreApps.isEmpty {
                            CategorySection(
                                title: "App Store",
                                icon: "storefront.fill",
                                apps: appStoreApps,
                                searchText: searchText,
                                collapsed: collapsedCategories.contains("App Store"),
                                onToggle: { toggleCategory("App Store") },
                                onUpdateAll: {
                                    Task { await updateManager.updateAll(source: .appStore) }
                                },
                                isFirst: updateManager.updatesBySource[.homebrew]?.isEmpty ?? true
                            )
                        }

                        // Sparkle Category
                        if let sparkleApps = updateManager.updatesBySource[.sparkle],
                           !sparkleApps.isEmpty {
                            CategorySection(
                                title: "Sparkle",
                                icon: "sparkles",
                                apps: sparkleApps,
                                searchText: searchText,
                                collapsed: collapsedCategories.contains("Sparkle"),
                                onToggle: { toggleCategory("Sparkle") },
                                onUpdateAll: nil,  // No "Update All" for Sparkle
                                isFirst: (updateManager.updatesBySource[.homebrew]?.isEmpty ?? true) &&
                                        (updateManager.updatesBySource[.appStore]?.isEmpty ?? true)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(scrollIndicators ? .visible : .hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            TahoeToolbarItem(placement: .navigation) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Updater")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Check for app updates from multiple sources")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    BetaBadge()
                }
            }

            ToolbarItem { Spacer() }

            TahoeToolbarItem(isGroup: true) {
                Button {
                    Task { await updateManager.scanForUpdates() }
                } label: {
                    Label("Refresh", systemImage: "arrow.counterclockwise")
                }
                .disabled(updateManager.isScanning)
                .help("Scan for app updates")
            }
        }
        .task {
            await updateManager.scanForUpdates()
        }
    }

    private func toggleCategory(_ name: String) {
        if collapsedCategories.contains(name) {
            collapsedCategories.remove(name)
        } else {
            collapsedCategories.insert(name)
        }
    }
}

// Category section component (matching Homebrew layout)
struct CategorySection: View {
    let title: String
    let icon: String
    let apps: [UpdateableApp]
    let searchText: String
    let collapsed: Bool
    let onToggle: () -> Void
    let onUpdateAll: (() -> Void)?
    let isFirst: Bool
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    private var filteredApps: [UpdateableApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter {
            $0.appInfo.appName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header (collapsible)
            Button(action: {
                withAnimation(.easeInOut(duration: animationEnabled ? 0.3 : 0)) {
                    onToggle()
                }
            }) {
                HStack {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .frame(width: 10)

                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)

                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    Text(verbatim: "(\(filteredApps.count))")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Spacer()

                    // Show "Update All" button if more than 1 app
                    if let onUpdateAll = onUpdateAll, filteredApps.count > 1 {
                        Button {
                            onUpdateAll()
                        } label: {
                            Text("Update All")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .padding(.top, isFirst ? 0 : 12)

            // Packages in category (only if not collapsed)
            if !collapsed {
                LazyVStack(spacing: 8) {
                    ForEach(searchText.isEmpty ? apps : filteredApps) { app in
                        UpdateRowView(app: app)
                    }
                }
            }
        }
    }
}

