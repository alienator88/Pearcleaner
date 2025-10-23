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
    @EnvironmentObject var updater: Updater
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    @State private var collapsedCategories: Set<String> = []
    @State private var hiddenSidebar: Bool = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.updater.checkAppStore") private var checkAppStore: Bool = true
    @AppStorage("settings.updater.checkHomebrew") private var checkHomebrew: Bool = true
    @AppStorage("settings.updater.checkSparkle") private var checkSparkle: Bool = true
    @AppStorage("settings.updater.includeSparklePreReleases") private var includeSparklePreReleases: Bool = false
    @AppStorage("settings.updater.includeHomebrewFormulae") private var includeHomebrewFormulae: Bool = false

    private var totalUpdateCount: Int {
        updateManager.updatesBySource.values.reduce(0) { $0 + $1.count }
    }

    private var allSourcesDisabled: Bool {
        !checkAppStore && !checkHomebrew && !checkSparkle
    }

    private var hasVisibleUpdates: Bool {
        updateManager.updatesBySource.values.contains { !$0.isEmpty }
    }

    @ViewBuilder
    private var resultsCountBar: some View {
        if updateManager.hasUpdates || updateManager.lastScanDate != nil {
            HStack(spacing: 12) {
                // Update count
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

                // Timeline
                if let lastScan = updateManager.lastScanDate {
                    TimelineView(.periodic(from: lastScan, by: 1.0)) { _ in
                        Text("Updated \(formatRelativeTime(lastScan))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    var body: some View {
        ZStack {
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
                if updateManager.isScanning || updateManager.lastScanDate == nil {
                // Loading state - centered (shown when scanning OR before first scan)
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
            } else if !hasVisibleUpdates || allSourcesDisabled {
                // Empty state - centered (shown when no visible updates OR all sources disabled)
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
                        // Pearcleaner self-update banner (appears first, before categories)
                        // Only show if user hasn't disabled update checking AND update is available
                        if updater.updateFrequency != .none && updater.updateAvailable {
                            PearcleanerUpdateBanner()
                            Divider()
                                .padding(.vertical)
                        }

                        // Show categories only if their checkbox is enabled
                        if checkAppStore {
                            CategorySection(
                                title: "App Store",
                                icon: ifOSBelow(macOS: 14) ? "cart.fill" : "storefront.fill",
                                apps: updateManager.updatesBySource[.appStore] ?? [],
                                searchText: searchText,
                                collapsed: (updateManager.updatesBySource[.appStore]?.isEmpty ?? true) || collapsedCategories.contains("App Store"),
                                onToggle: { toggleCategory("App Store") },
                                onUpdateAll: {
                                    Task { await updateManager.updateAll(source: .appStore) }
                                },
                                isFirst: true
                            )
                        }

                        if checkHomebrew {
                            CategorySection(
                                title: "Homebrew",
                                icon: "mug",
                                apps: updateManager.updatesBySource[.homebrew] ?? [],
                                searchText: searchText,
                                collapsed: (updateManager.updatesBySource[.homebrew]?.isEmpty ?? true) || collapsedCategories.contains("Homebrew"),
                                onToggle: { toggleCategory("Homebrew") },
                                onUpdateAll: {
                                    Task { await updateManager.updateAll(source: .homebrew) }
                                },
                                isFirst: !checkAppStore
                            )
                        }

                        if checkSparkle {
                            CategorySection(
                                title: "Sparkle",
                                icon: "sparkles",
                                apps: updateManager.updatesBySource[.sparkle] ?? [],
                                searchText: searchText,
                                collapsed: (updateManager.updatesBySource[.sparkle]?.isEmpty ?? true) || collapsedCategories.contains("Sparkle"),
                                onToggle: { toggleCategory("Sparkle") },
                                onUpdateAll: nil,  // No "Update All" for Sparkle
                                isFirst: !checkAppStore && !checkHomebrew
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(scrollIndicators ? .visible : .hidden)
            }

                // Beta footer
                if !updateManager.isScanning && updateManager.lastScanDate != nil {
                    Link("While in beta, report issues with missing or incorrect updates here", destination: URL(string: "https://github.com/alienator88/Pearcleaner/issues/381")!)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                        .padding(.vertical, 8)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity)
                }
            }
            .opacity(hiddenSidebar ? 0.5 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            UpdaterDetailsSidebar(
                hiddenSidebar: $hiddenSidebar,
                checkAppStore: $checkAppStore,
                checkHomebrew: $checkHomebrew,
                checkSparkle: $checkSparkle,
                includeSparklePreReleases: $includeSparklePreReleases,
                includeHomebrewFormulae: $includeHomebrewFormulae
            )
        }
        .animation(animationEnabled ? .spring(response: 0.35, dampingFraction: 0.8) : .none, value: hiddenSidebar)
        .transition(.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdaterViewShouldRefresh"))) { _ in
            Task {
                await updateManager.scanForUpdates()
            }
        }
        .toolbar {
            TahoeToolbarItem(placement: .navigation) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Updater")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Check for app updates from App Store, Homebrew and Sparkle")
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

                Button {
                    hiddenSidebar.toggle()
                } label: {
                    Label("Hidden", systemImage: "sidebar.trailing")
                }
                .help("Show hidden updates")
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
struct CategorySection<TrailingContent: View>: View {
    let title: String
    let icon: String
    let apps: [UpdateableApp]
    let searchText: String
    let collapsed: Bool
    let onToggle: () -> Void
    let onUpdateAll: (() -> Void)?
    let isFirst: Bool
    let trailingContent: (() -> TrailingContent)?
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @StateObject private var updateManager = UpdateManager.shared

    // Initializer for categories without trailing content
    init(
        title: String,
        icon: String,
        apps: [UpdateableApp],
        searchText: String,
        collapsed: Bool,
        onToggle: @escaping () -> Void,
        onUpdateAll: (() -> Void)?,
        isFirst: Bool
    ) where TrailingContent == EmptyView {
        self.title = title
        self.icon = icon
        self.apps = apps
        self.searchText = searchText
        self.collapsed = collapsed
        self.onToggle = onToggle
        self.onUpdateAll = onUpdateAll
        self.isFirst = isFirst
        self.trailingContent = nil
    }

    // Initializer for categories with trailing content
    init(
        title: String,
        icon: String,
        apps: [UpdateableApp],
        searchText: String,
        collapsed: Bool,
        onToggle: @escaping () -> Void,
        onUpdateAll: (() -> Void)?,
        isFirst: Bool,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent
    ) {
        self.title = title
        self.icon = icon
        self.apps = apps
        self.searchText = searchText
        self.collapsed = collapsed
        self.onToggle = onToggle
        self.onUpdateAll = onUpdateAll
        self.isFirst = isFirst
        self.trailingContent = trailingContent
    }

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
                        .opacity(filteredApps.isEmpty ? 0 : 1)
                        .frame(width: 10)

                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                        .frame(width: 20)

                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    Text(verbatim: "(\(filteredApps.count))")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Spacer()

                    // Optional trailing content (e.g., Sparkle pre-release toggle)
                    if let trailingContent = trailingContent {
                        trailingContent()
                    }

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
            .padding(.top, isFirst ? 0 : 20)

            // Packages in category (only if not collapsed)
            if !collapsed {
                if filteredApps.isEmpty {
                    // Empty state
                    Text("No \(title.lowercased()) apps to update")
                        .font(.callout)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(searchText.isEmpty ? apps : filteredApps) { app in
                            UpdateRowView(
                                app: app,
                                onHideToggle: { app in
                                    updateManager.hideApp(app)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

