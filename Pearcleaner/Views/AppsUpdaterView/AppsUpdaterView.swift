//
//  AppsUpdaterView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import SwiftUI
import AlinFoundation

struct AppsUpdaterView: View {
    @EnvironmentObject var updateManager: UpdateManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var updater: Updater
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var consoleManager = GlobalConsoleManager.shared
    @State private var searchText = ""
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

    private var totalUpdateCount: Int {
        updateManager.updatesBySource
            .filter { $0.key != .unsupported && $0.key != .current }
            .values
            .reduce(0) { $0 + $1.count }
    }

    private var allSourcesDisabled: Bool {
        !checkAppStore && !checkHomebrew && !checkSparkle
    }

    private var hasVisibleUpdates: Bool {
        updateManager.updatesBySource.values.contains { !$0.isEmpty }
    }

    // Collect all apps across all sources (exclude unsupported and current apps - they can't/don't need updates)
    private var allApps: [UpdateableApp] {
        updateManager.updatesBySource.values.flatMap { $0 }.filter { $0.source != .unsupported && $0.source != .current }
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
    private var sidebarCategories: [(String, (UpdateableApp) -> Bool, Bool, Bool)] {
        var cats: [(String, (UpdateableApp) -> Bool, Bool, Bool)] = []
        if checkAppStore {
            cats.append(("App Store", { $0.source == .appStore }, true, updateManager.scanningSources.contains(.appStore)))
        }
        if checkHomebrew {
            cats.append(("Homebrew", { $0.source == .homebrew }, true, updateManager.scanningSources.contains(.homebrew)))
        }
        if checkSparkle {
            cats.append(("Sparkle", { $0.source == .sparkle }, true, updateManager.scanningSources.contains(.sparkle)))
        }
        // Always show Current category, show Unsupported if enabled (never scanning)
        cats.append(("Current", { $0.source == .current }, false, false))
        if showUnsupported {
            cats.append(("Unsupported", { $0.source == .unsupported }, false, false))
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
        ZStack {
            SidebarDetailLayout {
                GenericSidebarListView(
                    items: allUpdateableApps,
                    categories: sidebarCategories,
                    searchText: $searchText,
                    emptyMessage: "No apps to update",
                    noResultsMessage: "No matching apps",
                    isLoading: updateManager.isScanning,
                    loadingMessage: "Scanning for updates..."
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
            // Skip scan if background scan already completed
            guard updateManager.lastScanDate == nil else {
                GlobalConsoleManager.shared.appendOutput("Using cached updates from background scan\n", source: CurrentPage.updater.title)
                return
            }

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

