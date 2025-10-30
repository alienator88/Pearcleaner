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
    @State private var collapsedCategories: Set<String> = ["Unsupported"]
    @State private var hiddenSidebar: Bool = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.updater.checkAppStore") private var checkAppStore: Bool = true
    @AppStorage("settings.updater.checkHomebrew") private var checkHomebrew: Bool = true
    @AppStorage("settings.updater.checkSparkle") private var checkSparkle: Bool = true
    @AppStorage("settings.updater.includeSparklePreReleases") private var includeSparklePreReleases: Bool = false
    @AppStorage("settings.updater.showUnsupported") private var showUnsupported: Bool = true

    private var totalUpdateCount: Int {
        updateManager.updatesBySource.values.reduce(0) { $0 + $1.count }
    }

    private var allSourcesDisabled: Bool {
        !checkAppStore && !checkHomebrew && !checkSparkle
    }

    private var hasVisibleUpdates: Bool {
        updateManager.updatesBySource.values.contains { !$0.isEmpty }
    }

    // Collect all apps across all sources (exclude unsupported apps - they can't be updated)
    private var allApps: [UpdateableApp] {
        updateManager.updatesBySource.values.flatMap { $0 }.filter { $0.source != .unsupported }
    }

    // Count selected apps across all sources
    private var selectedAppsCount: Int {
        allApps.filter { $0.isSelectedForUpdate }.count
    }

    // Check if any apps are selected
    private var hasSelectedApps: Bool {
        selectedAppsCount > 0
    }

    private var resultsCountBar: some View {
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

            // Timeline - only show if we have a lastScanDate
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

                // Category-based list - always show categories (even when scanning)
                // Show empty state only when not scanning and no updates
                if !updateManager.isScanning && !hasVisibleUpdates && !allSourcesDisabled && updateManager.lastScanDate != nil {
                    // Empty state - centered (shown only when scan completed with no updates)
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
                                    isScanning: updateManager.scanningSources.contains(.appStore),
                                    collapsed: (updateManager.updatesBySource[.appStore]?.isEmpty ?? true) || collapsedCategories.contains("App Store"),
                                    onToggle: { toggleCategory("App Store") },
                                    isFirst: true
                                )
                            }

                            if checkHomebrew {
                                CategorySection(
                                    title: "Homebrew",
                                    icon: "mug",
                                    apps: updateManager.updatesBySource[.homebrew] ?? [],
                                    searchText: searchText,
                                    isScanning: updateManager.scanningSources.contains(.homebrew),
                                    collapsed: (updateManager.updatesBySource[.homebrew]?.isEmpty ?? true) || collapsedCategories.contains("Homebrew"),
                                    onToggle: { toggleCategory("Homebrew") },
                                    isFirst: !checkAppStore
                                )
                            }

                            if checkSparkle {
                                CategorySection(
                                    title: "Sparkle",
                                    icon: "sparkles",
                                    apps: updateManager.updatesBySource[.sparkle] ?? [],
                                    searchText: searchText,
                                    isScanning: updateManager.scanningSources.contains(.sparkle),
                                    collapsed: (updateManager.updatesBySource[.sparkle]?.isEmpty ?? true) || collapsedCategories.contains("Sparkle"),
                                    onToggle: { toggleCategory("Sparkle") },
                                    isFirst: !checkAppStore && !checkHomebrew
                                )
                            }

                            if showUnsupported {
                                CategorySection(
                                    title: "Unsupported",
                                    icon: "questionmark.circle",
                                    apps: updateManager.updatesBySource[.unsupported] ?? [],
                                    searchText: searchText,
                                    isScanning: false,  // Unsupported apps are calculated instantly, not scanned
                                    collapsed: (updateManager.updatesBySource[.unsupported]?.isEmpty ?? true) || collapsedCategories.contains("Unsupported"),
                                    onToggle: { toggleCategory("Unsupported") },
                                    isFirst: !checkAppStore && !checkHomebrew && !checkSparkle
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(scrollIndicators ? .visible : .hidden)
                }

            }
            .safeAreaInset(edge: .bottom) {
                if hasSelectedApps {
                    HStack {
                        Spacer()

                        HStack(spacing: 10) {
                            Button(selectedAppsCount == allApps.count ? "Deselect All" : "Select All") {
                                if selectedAppsCount == allApps.count {
                                    deselectAllApps()
                                } else {
                                    selectAllApps()
                                }
                            }
                            .buttonStyle(ControlGroupButtonStyle(
                                foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                shape: Capsule(style: .continuous),
                                level: .primary,
                                skipControlGroup: true
                            ))

                            Divider().frame(height: 10)

                            Button("Update \(selectedAppsCount) Selected") {
                                updateSelectedApps()
                            }
                            .buttonStyle(ControlGroupButtonStyle(
                                foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                shape: Capsule(style: .continuous),
                                level: .primary,
                                skipControlGroup: true
                            ))
                        }
                        .controlGroup(Capsule(style: .continuous), level: .primary)

                        Spacer()
                    }
                    .padding([.horizontal, .bottom])
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
                showUnsupported: $showUnsupported
            )
        }
        .animation(animationEnabled ? .spring(response: 0.35, dampingFraction: 0.8) : .none, value: hiddenSidebar)
        .transition(.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdaterViewShouldRefresh"))) { _ in
            Task {
                await updateManager.scanForUpdates(forceReload: true)
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
                    NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/issues/381")!)
                } label: {
                    Label("Report Issue", systemImage: "ladybug.fill")
                }
                .disabled(updateManager.isScanning)
                .help("While in beta, report issues with missing or incorrect updates here")

                if updateManager.isScanning {
                    // Show stop button during scan
                    Button {
                        updateManager.cancelScan()
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                    .help("Stop checking for updates")
                } else {
                    // Show refresh button when not scanning
                    Button {
                        let task = Task { await updateManager.scanForUpdates(forceReload: true) }
                        updateManager.currentScanTask = task
                    } label: {
                        Label("Refresh", systemImage: "arrow.counterclockwise")
                    }
                    .help("Scan for app updates")
                }

                Button {
                    hiddenSidebar.toggle()
                } label: {
                    Label("Hidden", systemImage: "sidebar.trailing")
                }
                .help("Show hidden updates")
            }
        }
        .task {
            let task = Task { await updateManager.scanForUpdates() }
            updateManager.currentScanTask = task
            await task.value
        }
        .onDisappear {
            UpdaterDebugLogger.shared.clearLogs()
        }
    }

    private func toggleCategory(_ name: String) {
        if collapsedCategories.contains(name) {
            collapsedCategories.remove(name)
        } else {
            collapsedCategories.insert(name)
        }
    }

    private func selectAllApps() {
        // Select all apps across all sources (skip unsupported - they can't be updated)
        for (source, apps) in updateManager.updatesBySource {
            guard source != .unsupported else { continue }
            var updatedApps = apps
            for index in updatedApps.indices {
                updatedApps[index].isSelectedForUpdate = true
            }
            updateManager.updatesBySource[source] = updatedApps
        }
    }

    private func deselectAllApps() {
        // Deselect all apps across all sources (skip unsupported - they can't be updated)
        for (source, apps) in updateManager.updatesBySource {
            guard source != .unsupported else { continue }
            var updatedApps = apps
            for index in updatedApps.indices {
                updatedApps[index].isSelectedForUpdate = false
            }
            updateManager.updatesBySource[source] = updatedApps
        }
    }

    private func updateSelectedApps() {
        Task {
            await updateManager.updateSelectedApps()
        }
    }
}

// Category section component (matching Homebrew layout)
struct CategorySection<TrailingContent: View>: View {
    let title: String
    let icon: String
    let apps: [UpdateableApp]
    let searchText: String
    let isScanning: Bool
    let collapsed: Bool
    let onToggle: () -> Void
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
        isScanning: Bool,
        collapsed: Bool,
        onToggle: @escaping () -> Void,
        isFirst: Bool
    ) where TrailingContent == EmptyView {
        self.title = title
        self.icon = icon
        self.apps = apps
        self.searchText = searchText
        self.isScanning = isScanning
        self.collapsed = collapsed
        self.onToggle = onToggle
        self.isFirst = isFirst
        self.trailingContent = nil
    }

    // Initializer for categories with trailing content
    init(
        title: String,
        icon: String,
        apps: [UpdateableApp],
        searchText: String,
        isScanning: Bool,
        collapsed: Bool,
        onToggle: @escaping () -> Void,
        isFirst: Bool,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent
    ) {
        self.title = title
        self.icon = icon
        self.apps = apps
        self.searchText = searchText
        self.isScanning = isScanning
        self.collapsed = collapsed
        self.onToggle = onToggle
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

                    if isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(verbatim: "(\(filteredApps.count))")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    Spacer()

                    // Optional trailing content (e.g., Sparkle pre-release toggle)
                    if let trailingContent = trailingContent {
                        trailingContent()
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

