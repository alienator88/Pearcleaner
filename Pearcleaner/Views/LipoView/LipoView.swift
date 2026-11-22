//
//  LipoView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/20/25.
//

import AlinFoundation
import SwiftUI

struct LipoView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var consoleManager = GlobalConsoleManager.shared
    @State private var selectedApps: Set<String> = []
    @State private var isProcessing: Bool = false
    @State private var savingsAllApps: UInt64 = 0
    @State private var bundleAllApps: UInt64 = 0
    @State private var sliceSizesByPath = [String: (bundle: UInt64, savings: UInt64)]()
    @State private var totalSpaceSaved: UInt64 = 0
    @State private var infoSidebar: Bool = false
    @State private var selectedSort: LipoSortOption = .name
    @State private var searchText: String = ""
    @State private var lastRefreshDate: Date?
    @State private var isRefreshing: Bool = false
    @State private var pendingPaths: Set<String> = []
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.lipo.pruneTranslations") private var prune = false
    @AppStorage("settings.lipo.filterMinSavings") private var filterMinSavings = false
    @AppStorage("settings.lipo.showZeroPercentSavings") private var showZeroPercentSavings: Bool =
        false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.lipo.excludedApps") private var excludedAppsData: Data = Data()
    @AppStorage("settings.lipo.warning") private var warning: Bool = false
    @State private var showAlert = false

    enum LipoSortOption: String, CaseIterable {
        case name = "Name"
        case savings = "Savings Size"
        case binary = "Bundle Size"

        var systemImage: String {
            switch self {
            case .name: return "list.bullet"
            case .savings: return "arrow.down.circle"
            case .binary: return "doc.circle"
            }
        }
    }

    // Change to a computed property without setter
    private var excludedApps: Set<String> {
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: excludedAppsData) {
            return decoded
        }
        return Set<String>()
    }

    // Add helper methods for excluded apps management
    private func addToExcluded(_ apps: Set<String>) {
        var current = excludedApps
        current.formUnion(apps)
        if let encoded = try? JSONEncoder().encode(current) {
            excludedAppsData = encoded
        }
    }

    // Rename the helper method to avoid conflict
    private func removeAppFromExcluded(_ appPath: String) {
        var current = excludedApps
        current.remove(appPath)
        if let encoded = try? JSONEncoder().encode(current) {
            excludedAppsData = encoded
        }
        // Sizes will be recalculated per-app on-demand
    }

    // Apps that actually contain more than one architecture slice. This is the
    // same signal the rest of the app uses (`arch == .universal`), so apps that
    // are already thinned or were never universal stay out of the list.
    var universalApps: [AppInfo] {
        var filtered = appState.sortedApps.filter { app in
            app.arch == .universal && !excludedApps.contains(app.path.path)
        }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { app in
                app.appName.localizedCaseInsensitiveContains(searchText)
                    || app.path.path.localizedCaseInsensitiveContains(searchText)
            }
        }

        var result = filtered

        // Hide apps once we know they have no removable architectures.
        if !showZeroPercentSavings {
            result = result.filter { app in
                guard let savings = knownSavings(for: app) else { return true }
                return savings > 0
            }
        }

        if filterMinSavings {
            // Only apply the 1MB+ filter if we have size data calculated
            result = result.filter { app in
                guard let savings = knownSavings(for: app) else { return false }
                return savings >= 1024 * 1024  // 1MB in bytes
            }
        }

        // Apply sorting
        return result.sorted { app1, app2 in
            switch selectedSort {
            case .name:
                return app1.appName.localizedCaseInsensitiveCompare(app2.appName)
                    == .orderedAscending
            case .savings:
                let savings1 = knownSavings(for: app1) ?? 0
                let savings2 = knownSavings(for: app2) ?? 0
                return savings1 > savings2  // Descending order for savings
            case .binary:
                let bundle1 = UInt64(app1.bundleSize)
                let bundle2 = UInt64(app2.bundleSize)
                return bundle1 > bundle2  // Descending order for bundle size
            }
        }
    }

    /// Returns nil while an app has not been analyzed yet.
    private func knownSavings(for app: AppInfo) -> UInt64? {
        if let sizes = sliceSizesByPath[app.path.path] {
            return sizes.savings
        }
        if let cached = app.lipoSavings {
            return UInt64(max(0, cached))
        }
        return nil
    }

    var body: some View {
        ZStack {

            VStack(alignment: .leading, spacing: 0) {

                VStack(alignment: .leading, spacing: 0) {

                    // Add this section back - the main app list content
                    // Search bar
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
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                    .controlGroup(Capsule(style: .continuous), level: .primary)
                    .padding(.top, 5)

                    if universalApps.isEmpty {
                        VStack {
                            Spacer()
                            Text("No apps available for thinning")
                                .font(.title2)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {

                        // Stats header
                        HStack {
                            Text("\(universalApps.count) app\(universalApps.count == 1 ? "" : "s")")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                            if isRefreshing {
                                Text("Refreshing...")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }

                            Spacer()

                            if let lastRefresh = lastRefreshDate {
                                TimelineView(.periodic(from: lastRefresh, by: 1.0)) { _ in
                                    Text("Updated \(formatRelativeTime(lastRefresh))")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                }
                            }

                            LipoLegend()
                        }
                        .padding(.vertical)

                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(universalApps, id: \.path) { app in
                                    LipoAppRowView(
                                        app: app,
                                        savings: knownSavings(for: app),
                                        isCalculating: pendingPaths.contains(app.path.path),
                                        selectedApps: $selectedApps
                                    )
                                }
                            }
                        }
                        .scrollIndicators(scrollIndicators ? .automatic : .never)
                    }
                }
            }
            .opacity(infoSidebar ? 0.5 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
            .safeAreaInset(edge: .bottom) {
                if !selectedApps.isEmpty {
                    HStack {
                        Spacer()

                        HStack(spacing: 10) {
                            Button(selectedApps.count == universalApps.count ? "Deselect All" : "Select All") {
                                if selectedApps.count == universalApps.count {
                                    selectedApps.removeAll()
                                } else {
                                    selectedApps = Set(universalApps.map { $0.path.path })
                                }
                            }
                            .buttonStyle(ControlGroupButtonStyle(
                                foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                shape: Capsule(style: .continuous),
                                level: .primary,
                                skipControlGroup: true
                            ))

                            Divider().frame(height: 10)

                            Button {
                                excludeSelectedApps()
                            } label: {
                                Label {
                                    Text("Exclude \(selectedApps.count) Selected")
                                } icon: {
                                    Image(systemName: "minus.circle")
                                }
                            }
                            .buttonStyle(ControlGroupButtonStyle(
                                foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                shape: Capsule(style: .continuous),
                                level: .primary,
                                skipControlGroup: true
                            ))

                            Divider().frame(height: 10)

                            Button {
                                startLipo()
                            } label: {
                                if !isProcessing {
                                    Label {
                                        Text("Start Lipo")
                                    } icon: {
                                        Image(systemName: "scissors")
                                    }
                                } else {
                                    ProgressView()
                                        .controlSize(.mini)
                                }
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

            // Add the sidebar view
            LipoSidebarView(
                infoSidebar: $infoSidebar, excludedApps: excludedApps, prune: $prune,
                filterMinSavings: $filterMinSavings, onRemoveExcluded: removeAppFromExcluded,
                totalSpaceSaved: totalSpaceSaved, savingsAllApps: savingsAllApps)
        }
        .animation(
            animationEnabled ? .spring(response: 0.35, dampingFraction: 0.8) : .none,
            value: infoSidebar
        )
        .onAppear {
            if !warning {
                showAlert = true
            }
            if lastRefreshDate == nil {
                lastRefreshDate = Date()
            }
            analyzeAppsIfNeeded()
        }
        .onChange(of: appState.sortedApps.filter { $0.arch == .universal }.count) { _ in
            analyzeAppsIfNeeded()
        }
        .onDisappear {
            // No background tasks to cancel with per-app calculation
        }
        .sheet(
            isPresented: $showAlert,
            content: {
                VStack(spacing: 10) {
                    Text("Important")
                        .font(.headline)
                    Divider()
                    Spacer()
                    Text(
                        "Bundle thinning (lipo) is an aggressive operation that modifies the binaries within app bundles by removing unused architectures. While generally safe, some applications may experience issues or fail to launch after this process. It is strongly recommended to create a backup of your applications before proceeding, especially for critical or frequently used apps."
                    )
                    .font(.subheadline)
                    Spacer()
                    Button("Close") {
                        warning = true
                        showAlert = false
                    }
                    .buttonStyle(
                        SimpleButtonStyle(
                            icon: "x.circle.fill", label: String(localized: "Close"),
                            help: String(localized: "Dismiss")))
                    Spacer()
                }
                .padding(15)
                .frame(width: 400, height: 250)
                .background(GlassEffect(material: .hudWindow, blendingMode: .behindWindow))
            })
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LipoViewShouldRefresh"))) { _ in
            refreshList()
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            TahoeToolbarItem(placement: .navigation) {
                VStack(alignment: .leading) {
                    Text("Lipo").foregroundStyle(
                        ThemeColors.shared(for: colorScheme).primaryText
                    ).font(.title2).fontWeight(.bold)
                    Text(
                        "Remove unused architectures from your app binaries to reduce app size"
                    )
                    .font(.callout).foregroundStyle(
                        ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }

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
                
                Menu {
                    ForEach(LipoSortOption.allCases, id: \.self) { sortOption in
                        Button {
                            selectedSort = sortOption
                        } label: {
                            Label(sortOption.rawValue, systemImage: sortOption.systemImage)
                        }
                    }
                } label: {
                    Label(selectedSort.rawValue, systemImage: selectedSort.systemImage)
                }
                .labelStyle(.titleAndIcon)
                .menuIndicator(.hidden)

                Button {
                    refreshList()
                } label: {
                    Label("Refresh", systemImage: "arrow.counterclockwise")
                }
                .disabled(isRefreshing)

                Button {
                    if GlobalConsoleManager.shared.showConsole {
                        GlobalConsoleManager.shared.showConsole.toggle()
                    }
                    infoSidebar.toggle()
                } label: {
                    Label("Info", systemImage: "sidebar.trailing")
                }
                .help("See lipo details")

            }

        }
    }

    private func refreshList() {
        GlobalConsoleManager.shared.appendOutput("Refreshing app list...\n", source: CurrentPage.lipo.title)
        isRefreshing = true

        Task {
            // Clear the cached sizes to force recalculation
            await MainActor.run {
                sliceSizesByPath.removeAll()
                pendingPaths.removeAll()
                savingsAllApps = 0
                bundleAllApps = 0

                // Force a fresh analysis of every universal app, including ones
                // that were already lipo'd since the last refresh.
                for index in AppState.shared.sortedApps.indices {
                    AppState.shared.sortedApps[index].lipoSavings = nil
                }
            }

            // Wait a bit for the UI to update
            try? await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                lastRefreshDate = Date()
                isRefreshing = false
                analyzeAppsIfNeeded()
                GlobalConsoleManager.shared.appendOutput("✓ Refreshed app list\n", source: CurrentPage.lipo.title)
            }
        }
    }

    private func excludeSelectedApps() {
        addToExcluded(selectedApps)
        selectedApps.removeAll()
        // Sizes will be recalculated per-app on-demand
    }

    private func startLipo() {
        GlobalConsoleManager.shared.appendOutput("Starting lipo operation on \(selectedApps.count) app(s)...\n", source: CurrentPage.lipo.title)
        isProcessing = true
        Task {
            var totalPreSize: UInt64 = 0
            var totalPostSize: UInt64 = 0

            for app in universalApps where selectedApps.contains(app.path.path) {
                // Kill app if running before lipo'ing to prevent corruption
                await killApp(appId: app.bundleIdentifier)

                // Use the updated thinAppBundleArchitecture function with multi=true
                let (success, sizes) = thinAppBundleArchitecture(
                    at: app.path, of: app.arch, multi: true)
                if success, let sizes = sizes {
                    totalPreSize += sizes["pre"] ?? 0
                    totalPostSize += sizes["post"] ?? 0
                }

                // Prune languages if enabled
                if prune {
                    do {
                        try await pruneLanguages(in: app.path.path)
                    } catch {
                        printOS("Translation prune error: \(error)")
                    }
                }
            }

            let overallSavings =
                totalPreSize > 0
                ? Int((Double(totalPreSize - totalPostSize) / Double(totalPreSize)) * 100) : 0

            let titleFormat = NSLocalizedString(
                "Space Savings: %d%%\nTotal Space Saved: %@", comment: "Lipo completion title")
            let messageFormat = NSLocalizedString(
                "The total space savings between all the lipo'd apps\nSize Before: %@\nSize After: %@",
                comment: "Lipo completion message")

            let actualSpaceSaved = totalPreSize - totalPostSize
            let title = String(
                format: titleFormat, overallSavings, formatByte(size: Int64(actualSpaceSaved)).human
            )
            let message = String(
                format: messageFormat, formatByte(size: Int64(totalPreSize)).human,
                formatByte(size: Int64(totalPostSize)).human)

            await MainActor.run {
                self.totalSpaceSaved += actualSpaceSaved
                GlobalConsoleManager.shared.appendOutput("✓ Completed lipo operation - saved \(formatByte(size: Int64(actualSpaceSaved)).human)\n", source: CurrentPage.lipo.title)
                showCustomAlert(title: title, message: message, style: .informational)
                self.isProcessing = false

                // Recalculate savings for processed apps to update their display and filter them out
                self.recalculateProcessedApps()
            }
        }
    }

    private func recalculateProcessedApps() {
        // Get a copy of currently selected apps before clearing the selection
        let processedAppPaths = Array(selectedApps)

        // Clear selections since these apps were processed
        selectedApps.removeAll()

        // Recalculate savings for each processed app in the background
        Task {
            for appPath in processedAppPaths {
                let savings = await Self.calculateBundleSavings(
                    at: URL(fileURLWithPath: appPath))

                await MainActor.run {
                    applySavings(savings, forPath: appPath)
                }
            }
        }
    }

    /// Methodically analyze every universal app in the background so the list
    /// does not keep showing uncalculated or already-thinned apps. Work is
    /// deduplicated per path and limited to a few bundles at a time.
    private func analyzeAppsIfNeeded() {
        let candidates = appState.sortedApps.filter { app in
            app.arch == .universal
                && app.lipoSavings == nil
                && !pendingPaths.contains(app.path.path)
                && !excludedApps.contains(app.path.path)
        }
        guard !candidates.isEmpty else { return }

        for app in candidates {
            pendingPaths.insert(app.path.path)
        }

        let batch = candidates.map { ($0.path.path, $0.path) }
        let maxConcurrent = 4

        Task {
            await withTaskGroup(of: (String, UInt64).self) { group in
                var nextIndex = 0

                func addNext() {
                    guard nextIndex < batch.count else { return }
                    let (path, url) = batch[nextIndex]
                    nextIndex += 1
                    group.addTask {
                        let savings = await Self.calculateBundleSavings(at: url)
                        return (path, savings)
                    }
                }

                for _ in 0..<min(maxConcurrent, batch.count) {
                    addNext()
                }

                while let (path, savings) = await group.next() {
                    await MainActor.run {
                        applySavings(savings, forPath: path)
                        pendingPaths.remove(path)
                    }
                    addNext()
                }
            }
        }
    }

    private func applySavings(_ savings: UInt64, forPath path: String) {
        guard let index = appState.sortedApps.firstIndex(where: { $0.path.path == path }) else {
            pendingPaths.remove(path)
            return
        }

        let bundleSize = UInt64(max(0, appState.sortedApps[index].bundleSize))
        appState.sortedApps[index].lipoSavings = Int64(savings)
        sliceSizesByPath[path] = (bundle: bundleSize, savings: savings)

        savingsAllApps = sliceSizesByPath.values.reduce(0) { $0 + $1.savings }
        bundleAllApps = sliceSizesByPath.values.reduce(0) { $0 + $1.bundle }
    }

    private static func calculateBundleSavings(at appPath: URL) async -> UInt64 {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let (success, sizes) = thinAppBundleArchitecture(
                    at: appPath, of: .universal, multi: true, dryRun: true, showAlert: false)

                if success, let sizes = sizes {
                    let preSize = sizes["pre"] ?? 0
                    let postSize = sizes["post"] ?? 0
                    let savings = preSize > postSize ? preSize - postSize : 0
                    continuation.resume(returning: savings)
                } else {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
}

// Per-app row view. Savings are calculated by LipoView in the background so
// rows stay in sync and do not restart calculations when they are recycled.
struct LipoAppRowView: View {
    @Environment(\.colorScheme) var colorScheme
    let app: AppInfo
    let savings: UInt64?
    let isCalculating: Bool
    @Binding var selectedApps: Set<String>

    var body: some View {
        HStack(spacing: 15) {
            appToggle
            appContentView
        }
    }

    private var appToggle: some View {
        Button(action: {
            if selectedApps.contains(app.path.path) {
                selectedApps.remove(app.path.path)
            } else {
                selectedApps.insert(app.path.path)
            }
        }) {
            EmptyView()
        }
        .buttonStyle(CircleCheckboxButtonStyle(isSelected: selectedApps.contains(app.path.path)))
    }

    private var appContentView: some View {
        VStack {
            HStack {
                appIconAndName
                Divider()
                appSizeInfo
                Divider()
                savingsPercentage
                Spacer()
                sizesDisplay
            }
            .padding()
        }
        .background(ThemeColors.shared(for: colorScheme).secondaryBG)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var appIconAndName: some View {
        HStack {
            if let icon = app.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
            Text(app.appName).font(.title3)
        }
    }

    private var appSizeInfo: some View {
        Text(verbatim: "\(formatByte(size: Int64(app.bundleSize)).human)")
            .font(.caption)
            .help("Full app size")
    }

    @ViewBuilder
    private var savingsPercentage: some View {
        if let savings, savings > 0, app.bundleSize > 0 {
            Text("**\(Int((Double(savings) / Double(app.bundleSize)) * 100))%** savings")
                .font(.footnote)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
        }
    }

    @ViewBuilder
    private var sizesDisplay: some View {
        HStack {
            if let savings {
                Text(verbatim: "\(formatByte(size: Int64(savings)).human)")
                    .foregroundStyle(.green)
                    .help("Potential savings from bundle thinning")
            } else if isCalculating {
                Text("Calculating...")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            } else {
                Text("—")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .help("Not analyzed")
            }
        }
    }
}
