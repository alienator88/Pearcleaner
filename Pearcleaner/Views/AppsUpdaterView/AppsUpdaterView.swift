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
    @ObservedObject private var consoleManager = GlobalConsoleManager.shared
    @State private var searchText = ""
    @State private var collapsedCategories: Set<String> = ["Unsupported"]
    @State private var hiddenSidebar: Bool = false
    @State private var selectedApp: UpdateableApp? = nil
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.updater.checkAppStore") private var checkAppStore: Bool = true
    @AppStorage("settings.updater.checkHomebrew") private var checkHomebrew: Bool = true
    @AppStorage("settings.updater.checkSparkle") private var checkSparkle: Bool = true
    @AppStorage("settings.updater.includeSparklePreReleases") private var includeSparklePreReleases: Bool = false
    @AppStorage("settings.updater.showUnsupported") private var showUnsupported: Bool = true
    @AppStorage("settings.interface.startupView") private var startupView: Int = CurrentPage.applications.rawValue
    @State private var testingSidebar: Bool = true

    private var totalUpdateCount: Int {
        updateManager.updatesBySource
            .filter { $0.key != .unsupported }
            .values
            .reduce(0) { $0 + $1.count }
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

    // Sidebar categories
    private var sidebarCategories: [(String, (UpdateableApp) -> Bool)] {
        var cats: [(String, (UpdateableApp) -> Bool)] = []
        if checkAppStore {
            cats.append(("App Store", { $0.source == .appStore }))
        }
        if checkHomebrew {
            cats.append(("Homebrew", { $0.source == .homebrew }))
        }
        if checkSparkle {
            cats.append(("Sparkle", { $0.source == .sparkle }))
        }
        if showUnsupported {
            cats.append(("Unsupported", { $0.source == .unsupported }))
        }
        return cats
    }

    // All updateable apps for sidebar
    private var allUpdateableApps: [UpdateableApp] {
        updateManager.updatesBySource.values.flatMap { $0 }
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
        Group {
            if testingSidebar {
                ZStack {
                    sidebarTestView
                    .opacity(hiddenSidebar ? 0.5 : 1)

                    UpdaterDetailsSidebar(
                        hiddenSidebar: $hiddenSidebar,
                        checkAppStore: $checkAppStore,
                        checkHomebrew: $checkHomebrew,
                        checkSparkle: $checkSparkle,
                        includeSparklePreReleases: $includeSparklePreReleases,
                        showUnsupported: $showUnsupported
                    )
                }
            } else {
                currentView
            }
        }
        .animation(animationEnabled ? .spring(response: 0.35, dampingFraction: 0.8) : .none, value: hiddenSidebar)
        .transition(.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdaterViewShouldRefresh"))) { _ in
            Task {
                let task = Task { await updateManager.scanForUpdates(forceReload: true) }
                updateManager.currentScanTask = task
                await task.value
            }
        }
        .toolbar {
//            TahoeToolbarItem(placement: .navigation) {
//                HStack {
//                    VStack(alignment: .leading) {
//                        Text("Updater")
//                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
//                            .font(.title2)
//                            .fontWeight(.bold)
//                        Text("Check for app updates from App Store, Homebrew and Sparkle")
//                            .font(.callout)
//                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
//                    }
//                    BetaBadge()
//                }
//            }

            ToolbarItem { Spacer() }

            TahoeToolbarItem(isGroup: true) {

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        consoleManager.showConsole.toggle()
                    }
                } label: {
                    Label("Console", systemImage: consoleManager.showConsole ? "terminal.fill" : "terminal")
                }
                .help("Toggle console output")

                Button {
                    selectAllApps()
                    updateSelectedApps()
                } label: {
                    Label("Update All", systemImage: "arrow.down.circle")
                }
                .help("Update all available apps")
                .disabled(allUpdateableApps.isEmpty || !updateManager.scanningSources.isEmpty)

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
                        GlobalConsoleManager.shared.appendOutput("Refreshing app updates...\n", source: CurrentPage.updater.title)
                        Task {
                            let task = Task { await updateManager.scanForUpdates(forceReload: true) }
                            updateManager.currentScanTask = task
                            await task.value
                            GlobalConsoleManager.shared.appendOutput("✓ Completed update scan\n", source: CurrentPage.updater.title)
                        }
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
            GlobalConsoleManager.shared.appendOutput("Loading app updates...\n", source: CurrentPage.updater.title)
            let task = Task { await updateManager.scanForUpdates() }
            updateManager.currentScanTask = task
            await task.value
            GlobalConsoleManager.shared.appendOutput("✓ Loaded app updates\n", source: CurrentPage.updater.title)
        }
        .onDisappear {
            UpdaterDebugLogger.shared.clearLogs()
        }
    }

    private var currentView: some View {
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
                                let appStoreApps = updateManager.updatesBySource[.appStore] ?? []
                                let filteredApps = searchText.isEmpty ? appStoreApps : appStoreApps.filter {
                                    $0.appInfo.appName.localizedCaseInsensitiveContains(searchText)
                                }
                                let isCollapsed = filteredApps.isEmpty || collapsedCategories.contains("App Store")

                                GroupBox {
                                    if !isCollapsed {
                                        if filteredApps.isEmpty {
                                            Text("No app store apps to update")
                                                .font(.callout)
                                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 8)
                                        } else {
                                            LazyVStack(spacing: 8) {
                                                ForEach(filteredApps) { app in
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
                                .groupBoxStyle(.collapsible(
                                    icon: ifOSBelow(macOS: 14) ? "cart.fill" : "storefront.fill",
                                    title: "App Store",
                                    count: filteredApps.count,
                                    isCollapsed: isCollapsed,
                                    isLoading: updateManager.scanningSources.contains(.appStore),
                                    onToggle: { toggleCategory("App Store") }
                                ))
                                .padding(.top, 0)
                            }

                            if checkHomebrew {
                                let homebrewApps = updateManager.updatesBySource[.homebrew] ?? []
                                let filteredApps = searchText.isEmpty ? homebrewApps : homebrewApps.filter {
                                    $0.appInfo.appName.localizedCaseInsensitiveContains(searchText)
                                }
                                let isCollapsed = filteredApps.isEmpty || collapsedCategories.contains("Homebrew")

                                GroupBox {
                                    if !isCollapsed {
                                        if filteredApps.isEmpty {
                                            Text("No homebrew apps to update")
                                                .font(.callout)
                                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 8)
                                        } else {
                                            LazyVStack(spacing: 8) {
                                                ForEach(filteredApps) { app in
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
                                .groupBoxStyle(.collapsible(
                                    icon: "mug",
                                    title: "Homebrew",
                                    count: filteredApps.count,
                                    isCollapsed: isCollapsed,
                                    isLoading: updateManager.scanningSources.contains(.homebrew),
                                    onToggle: { toggleCategory("Homebrew") }
                                ))
                                .padding(.top, checkAppStore ? 20 : 0)
                            }

                            if checkSparkle {
                                let sparkleApps = updateManager.updatesBySource[.sparkle] ?? []
                                let filteredApps = searchText.isEmpty ? sparkleApps : sparkleApps.filter {
                                    $0.appInfo.appName.localizedCaseInsensitiveContains(searchText)
                                }
                                let isCollapsed = filteredApps.isEmpty || collapsedCategories.contains("Sparkle")

                                GroupBox {
                                    if !isCollapsed {
                                        if filteredApps.isEmpty {
                                            Text("No sparkle apps to update")
                                                .font(.callout)
                                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 8)
                                        } else {
                                            LazyVStack(spacing: 8) {
                                                ForEach(filteredApps) { app in
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
                                .groupBoxStyle(.collapsible(
                                    icon: "sparkles",
                                    title: "Sparkle",
                                    count: filteredApps.count,
                                    isCollapsed: isCollapsed,
                                    isLoading: updateManager.scanningSources.contains(.sparkle),
                                    onToggle: { toggleCategory("Sparkle") }
                                ))
                                .padding(.top, (checkAppStore || checkHomebrew) ? 20 : 0)
                            }

                            if showUnsupported {
                                let unsupportedApps = updateManager.updatesBySource[.unsupported] ?? []
                                let filteredApps = searchText.isEmpty ? unsupportedApps : unsupportedApps.filter {
                                    $0.appInfo.appName.localizedCaseInsensitiveContains(searchText)
                                }
                                let isCollapsed = filteredApps.isEmpty || collapsedCategories.contains("Unsupported")

                                GroupBox {
                                    if !isCollapsed {
                                        if filteredApps.isEmpty {
                                            Text("No unsupported apps to update")
                                                .font(.callout)
                                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 8)
                                        } else {
                                            LazyVStack(spacing: 8) {
                                                ForEach(filteredApps) { app in
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
                                .groupBoxStyle(.collapsible(
                                    icon: "questionmark.circle",
                                    title: "Unsupported",
                                    count: filteredApps.count,
                                    isCollapsed: isCollapsed,
                                    isLoading: false,
                                    onToggle: { toggleCategory("Unsupported") }
                                ))
                                .padding(.top, (checkAppStore || checkHomebrew || checkSparkle) ? 20 : 0)
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

    }

    private var sidebarTestView: some View {
        SidebarDetailLayout {
            GenericSidebarListView(
                items: allUpdateableApps,
                categories: sidebarCategories,
                searchText: $searchText,
                emptyMessage: "No apps to update",
                noResultsMessage: "No matching apps"
            ) { app in
                UpdateRowViewSidebar(
                    app: app,
                    isSelected: selectedApp?.id == app.id,
                    onTap: {
                        if selectedApp?.id == app.id {
                            // Deselect if tapping the same app
                            selectedApp = nil
                        } else {
                            // Select new app
                            selectedApp = app
                        }
                    }
                )
            }
        } detail: {
            Group {
                if let app = selectedApp {
                    UpdateDetailView(appId: app.id)
                } else {
                    VStack {
                        Spacer()
                        Text("Select an app to view details")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.title2)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onChange(of: allUpdateableApps) { newApps in
            // Auto-clear selectedApp if it no longer exists in the updates list
            if let selected = selectedApp,
               !newApps.contains(where: { $0.id == selected.id }) {
                selectedApp = nil
            }
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
        GlobalConsoleManager.shared.appendOutput("Starting update of \(selectedAppsCount) selected app(s)...\n", source: CurrentPage.updater.title)
        Task {
            await updateManager.updateSelectedApps()
            GlobalConsoleManager.shared.appendOutput("✓ Completed update operation\n", source: CurrentPage.updater.title)
        }
    }
}

