//
//  PluginsView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 09/29/25.
//

import SwiftUI
import AlinFoundation

enum PluginSortOption: String, CaseIterable {
    case name = "Name"
    case category = "Category"
    case size = "Size"
    case dateModified = "Date Modified"

    var displayName: String {
        return self.rawValue
    }
}

struct PluginInfo: Identifiable, Hashable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let category: String
    let isDirectory: Bool
    let size: Int64
    let dateModified: Date
    let bundleId: String?
    let customIcon: NSImage?

    var displayName: String {
        return name
    }

    static func == (lhs: PluginInfo, rhs: PluginInfo) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.path == rhs.path &&
               lhs.category == rhs.category &&
               lhs.bundleId == rhs.bundleId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(path)
        hasher.combine(category)
        hasher.combine(bundleId)
    }
}

struct PluginsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @Environment(\.colorScheme) var colorScheme
    @State private var plugins: [String: [PluginInfo]] = [:]
    @State private var allPlugins: [PluginInfo] = []
    @State private var isLoading: Bool = false
    @State private var lastRefreshDate: Date?
    @State private var searchText: String = ""
    @State private var sortOption: PluginSortOption = .name
    @State private var selectedPlugins: Set<UUID> = []
    @State private var selectedPluginPaths: [String] = []
    @State private var collapsedCategories: Set<String> = []
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.general.permanentDelete") private var permanentDelete: Bool = false
    @AppStorage("settings.plugins.collapsedCategories") private var persistedCollapsedCategories: Data = Data()
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    private var filteredPlugins: [PluginInfo] {
        var filteredList = allPlugins

        if !searchText.isEmpty {
            filteredList = filteredList.filter { plugin in
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.path.localizedCaseInsensitiveContains(searchText) ||
                plugin.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOption {
        case .name:
            filteredList = filteredList.sorted { first, second in
                return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            }
        case .category:
            filteredList = filteredList.sorted { first, second in
                if first.category != second.category {
                    return first.category.localizedCaseInsensitiveCompare(second.category) == .orderedAscending
                }
                return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            }
        case .size:
            filteredList = filteredList.sorted { $0.size > $1.size }
        case .dateModified:
            filteredList = filteredList.sorted { $0.dateModified > $1.dateModified }
        }

        return filteredList
    }

    private var groupedPlugins: [String: [PluginInfo]] {
        Dictionary(grouping: filteredPlugins) { $0.category }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

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

            if isLoading && allPlugins.isEmpty {
                VStack(alignment: .center, spacing: 10) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading plugins...")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if allPlugins.isEmpty && !isLoading {
                VStack(alignment: .center) {
                    Spacer()
                    Text("No plugins found")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {

                // Stats header
                HStack {
                    Text("\(filteredPlugins.count) plugin\(filteredPlugins.count == 1 ? "" : "s")")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    if isLoading {
                        Text("Loading...")
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
                }
                .padding(.vertical)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(groupedPlugins.keys.sorted()), id: \.self) { category in
                            if let categoryPlugins = groupedPlugins[category] {
                                PluginCategorySection(
                                    category: category,
                                    plugins: categoryPlugins,
                                    isCollapsed: collapsedCategories.contains(category),
                                    selectedPlugins: $selectedPlugins,
                                    selectedPluginPaths: $selectedPluginPaths,
                                    permanentDelete: permanentDelete,
                                    sortOption: sortOption,
                                    onRemove: removePlugin,
                                    onRefresh: refreshPlugins,
                                    onToggleCategoryCollapse: {
                                        withAnimation(.easeInOut(duration: animationEnabled ? 0.3 : 0)) {
                                            toggleCategoryCollapse(for: category)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .scrollIndicators(scrollIndicators ? .automatic : .never)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, !selectedPlugins.isEmpty ? 10 : 20)
        .onAppear {
            loadCollapsedCategories()

            // Start loading plugins immediately but non-blocking
            if allPlugins.isEmpty {
                Task {
                    await refreshPluginsAsync()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PluginsViewShouldRefresh"))) { _ in
            // Refresh plugins when undo is performed
            Task {
                await refreshPluginsAsync()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !selectedPlugins.isEmpty {
                HStack {
                    Spacer()

                    HStack(spacing: 10) {
                        Button(selectedPlugins.count == filteredPlugins.count ? "Deselect All" : "Select All") {
                            if selectedPlugins.count == filteredPlugins.count {
                                selectedPlugins.removeAll()
                                selectedPluginPaths.removeAll()
                            } else {
                                selectAllItems()
                            }
                        }
                        .buttonStyle(ControlGroupButtonStyle(
                            foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                            shape: Capsule(style: .continuous),
                            level: .primary,
                            skipControlGroup: true
                        ))

                        Divider().frame(height: 10)

                        Button("Delete \(selectedPlugins.count) Selected") {
                            deleteSelectedItems()
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
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            TahoeToolbarItem(placement: .navigation) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Plugin Manager")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Manage third-party plugins and extensions")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                }

            }

            ToolbarItem { Spacer() }

            TahoeToolbarItem(isGroup: true) {
                Menu {
                    ForEach(PluginSortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            Label(option.displayName, systemImage: "list.bullet")
                        }
                    }
                } label: {
                    Label(sortOption.displayName, systemImage: "list.bullet")
                }
                .labelStyle(.titleAndIcon)

                Button {
                    refreshPlugins()
                } label: {
                    Label("Refresh", systemImage: "arrow.counterclockwise")
                }
                .disabled(isLoading)
            }
        }
    }

    // MARK: - Helper Functions

    private func refreshPlugins() {
        Task {
            await refreshPluginsAsync()
        }
    }

    private func refreshPluginsAsync() async {
        await MainActor.run {
            isLoading = true
            plugins = [:]
            allPlugins = []
            selectedPlugins = []
            selectedPluginPaths = []
        }

        // Load plugins with incremental updates
        await loadPluginsIncremental()

        await MainActor.run {
            self.lastRefreshDate = Date()
            self.isLoading = false
        }
    }

    private func loadPluginsIncremental() async {
        let fileManager = FileManager.default
        let pluginCategories = locations.plugins.subcategories

        // Process categories concurrently but update UI incrementally
        await withTaskGroup(of: (String, [PluginInfo]).self) { group in

            // Add tasks for each category
            for (category, paths) in pluginCategories {
                group.addTask {
                    return await self.processCategory(category: category, paths: paths, fileManager: fileManager)
                }
            }

            // Collect results and update UI incrementally
            for await (category, categoryPlugins) in group {
                if !categoryPlugins.isEmpty {
                    await MainActor.run {
                        self.plugins[category] = categoryPlugins
                        self.allPlugins.append(contentsOf: categoryPlugins)
                    }
                }
            }
        }
    }

    private func processCategory(category: String, paths: [String], fileManager: FileManager) async -> (String, [PluginInfo]) {
        var categoryPlugins: [PluginInfo] = []

        for path in paths {
            // Check if path exists before trying to read it
            guard fileManager.fileExists(atPath: path) else { continue }

            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: URL(fileURLWithPath: path),
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )

                for itemURL in contents {
                    do {
                        let resourceValues = try itemURL.resourceValues(
                            forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
                        )

                        let isDirectory = resourceValues.isDirectory ?? false
                        let size: Int64
                        if isDirectory {
                            // Use totalSizeOnDisk for directories/bundles
                            size = totalSizeOnDisk(for: itemURL).real
                        } else {
                            // Use regular fileSize for individual files
                            size = resourceValues.fileSize.map { Int64($0) } ?? 0
                        }
                        let dateModified = resourceValues.contentModificationDate ?? Date()
                        let name = itemURL.lastPathComponent

                        // Filter out system files and hidden files
                        if !name.hasPrefix(".") && !name.hasPrefix("~") {
                            // Check if file matches the expected types for this category
                            if shouldIncludeFile(name: name, isDirectory: isDirectory, category: category) {
                                // Extract bundle info for Audio .driver bundles
                                let bundleId = await extractBundleId(from: itemURL.path, category: category, isDirectory: isDirectory)

                                // Skip Apple system plugins for Audio category
                                if category == "Audio", let bundleId = bundleId, bundleId.contains("com.apple") {
                                    continue
                                }

                                let plugin = PluginInfo(
                                    name: name,
                                    path: itemURL.path,
                                    category: category,
                                    isDirectory: isDirectory,
                                    size: size,
                                    dateModified: dateModified,
                                    bundleId: bundleId,
                                    customIcon: nil
                                )
                                categoryPlugins.append(plugin)
                            }
                        }
                    } catch {
                        // Skip items that can't be read
                        continue
                    }
                }
            } catch {
                // Skip directories that don't exist or can't be read
                continue
            }
        }

        return (category, categoryPlugins)
    }


    private func removePlugin(_ plugin: PluginInfo) {
        Task {
            await performPluginRemoval(plugin)
        }
    }

    private func performPluginRemoval(_ plugin: PluginInfo) async {
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let pluginURL = URL(fileURLWithPath: plugin.path)
                let bundleName = "\(plugin.category) Plugin - \(plugin.name)"
                let success = FileManagerUndo.shared.deleteFiles(at: [pluginURL], bundleName: bundleName)
                continuation.resume(returning: success)
            }
        }

        await MainActor.run {
            if success {
                // Remove the plugin from the local arrays
                allPlugins.removeAll { $0.id == plugin.id }
                selectedPlugins.remove(plugin.id)
                selectedPluginPaths.removeAll { $0 == plugin.path }
            } else {
                showCustomAlert(
                    title: "Deletion Failed",
                    message: "Failed to delete plugin '\(plugin.name)'. The plugin may require additional permissions or may not exist.",
                    style: .critical
                )
            }
        }
    }

    private func selectAllItems() {
        selectedPlugins = Set(filteredPlugins.map { $0.id })
        selectedPluginPaths = filteredPlugins.map { $0.path }
    }

    private func deleteSelectedItems() {
        let pluginsToDelete = allPlugins.filter { selectedPlugins.contains($0.id) }
        let urlsToDelete = pluginsToDelete.map { URL(fileURLWithPath: $0.path) }

        Task {
            let success = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    // Create descriptive bundle name for multiple plugins
                    let categories = Set(pluginsToDelete.map { $0.category })
                    let bundleName: String
                    if categories.count == 1, let category = categories.first {
                        bundleName = "\(category) Plugins (\(pluginsToDelete.count) items)"
                    } else {
                        bundleName = "Mixed Plugins (\(pluginsToDelete.count) items)"
                    }
                    let success = FileManagerUndo.shared.deleteFiles(at: urlsToDelete, bundleName: bundleName)
                    continuation.resume(returning: success)
                }
            }

            await MainActor.run {
                if success {
                    // Remove all deleted plugins from the local arrays
                    let deletedIds = Set(pluginsToDelete.map { $0.id })
                    allPlugins.removeAll { deletedIds.contains($0.id) }
                    selectedPlugins.removeAll()
                    selectedPluginPaths.removeAll()
                } else {
                    showCustomAlert(
                        title: "Deletion Failed",
                        message: "Failed to delete some selected plugins. They may require additional permissions or may not exist.",
                        style: .critical
                    )
                }
            }
        }
    }

    private func toggleCategoryCollapse(for category: String) {
        if collapsedCategories.contains(category) {
            collapsedCategories.remove(category)
        } else {
            collapsedCategories.insert(category)
        }
        saveCollapsedCategories()
    }

    private func loadCollapsedCategories() {
        if let categories = try? JSONDecoder().decode(Set<String>.self, from: persistedCollapsedCategories) {
            collapsedCategories = categories
        }
    }

    private func saveCollapsedCategories() {
        if let encoded = try? JSONEncoder().encode(collapsedCategories) {
            persistedCollapsedCategories = encoded
        }
    }

    private func extractBundleId(from path: String, category: String, isDirectory: Bool) async -> String? {
        // Only process Audio category .driver bundles
        guard category == "Audio",
              isDirectory,
              path.lowercased().hasSuffix(".driver") else {
            return nil
        }

        let infoPlistPath = path + "/Contents/Info.plist"
        guard FileManager.default.fileExists(atPath: infoPlistPath) else {
            return nil
        }

        // Read Info.plist
        if let plistData = NSDictionary(contentsOfFile: infoPlistPath) {
            // Extract bundle identifier
            return plistData["CFBundleIdentifier"] as? String
        }

        return nil
    }

    private func shouldIncludeFile(name: String, isDirectory: Bool, category: String) -> Bool {
        let lowercaseName = name.lowercased()

        switch category {
        case "Audio":
            // Audio category includes all files and directories
            return true

        case "PreferencePanes":
            // System Preference Panes (.prefPane)
            return lowercaseName.hasSuffix(".prefpane")

        case "QuickLook":
            // QuickLook Generators (.qlgenerator)
            return lowercaseName.hasSuffix(".qlgenerator")

        case "Screen Savers":
            // Screen Savers (.saver)
            return lowercaseName.hasSuffix(".saver")

        case "Internet Plug-Ins":
            // Browser plugins (.plugin, .webplugin)
            return lowercaseName.hasSuffix(".plugin") || lowercaseName.hasSuffix(".webplugin")

        case "Core Image":
            // Core Image filters (.plugin)
            return lowercaseName.hasSuffix(".plugin")

        case "ColorPickers":
            // Color Picker plugins (.colorPicker)
            return lowercaseName.hasSuffix(".colorpicker")

        case "Fonts":
            // Font files (.ttf, .otf, .dfont, .ttc)
            return lowercaseName.hasSuffix(".ttf") ||
                   lowercaseName.hasSuffix(".otf") ||
                   lowercaseName.hasSuffix(".dfont") ||
                   lowercaseName.hasSuffix(".ttc")

        case "Dictionaries":
            // Dictionary files (.dictionary)
            return lowercaseName.hasSuffix(".dictionary")

        case "Automator":
            // Automator Actions (.action, .workflow)
            return lowercaseName.hasSuffix(".action") || lowercaseName.hasSuffix(".workflow")

        case "Safari Extensions":
            // Safari Extensions (.safariextz, .appex)
            return lowercaseName.hasSuffix(".safariextz") || lowercaseName.hasSuffix(".appex")

        case "Motion Templates":
            // Final Cut Pro and Motion templates (various extensions, check for directories too)
            return isDirectory || lowercaseName.contains("template") || lowercaseName.hasSuffix(".motn")

        case "Spotlight":
            // Spotlight importers (.mdimporter)
            return lowercaseName.hasSuffix(".mdimporter")

        case "Services":
            // System Services (.service)
            return lowercaseName.hasSuffix(".service")

        case "Address Book":
            // Address Book plugins (usually directories or .plugin files)
            return isDirectory || lowercaseName.hasSuffix(".plugin")

        case "Contextual Menu":
            // Context menu plugins (various formats)
            return isDirectory || lowercaseName.hasSuffix(".plugin") || lowercaseName.hasSuffix(".bundle")

        case "Input Methods":
            // Input method editors (usually .app bundles or directories)
            return isDirectory || lowercaseName.hasSuffix(".app") || lowercaseName.hasSuffix(".bundle")

        case "Widgets":
            // Dashboard and notification widgets (.wdgt, .appex)
            return lowercaseName.hasSuffix(".wdgt") || lowercaseName.hasSuffix(".appex")

        default:
            // For unknown categories, include all files
            return true
        }
    }

}

// MARK: - Plugin Category Section

struct PluginCategorySection: View {
    let category: String
    let plugins: [PluginInfo]
    let isCollapsed: Bool
    @Binding var selectedPlugins: Set<UUID>
    @Binding var selectedPluginPaths: [String]
    let permanentDelete: Bool
    let sortOption: PluginSortOption
    let onRemove: (PluginInfo) -> Void
    let onRefresh: () -> Void
    let onToggleCategoryCollapse: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            Button(action: onToggleCategoryCollapse) {
                HStack {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .frame(width: 10)

                    Text(category)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    Text(verbatim: "(\(plugins.count))")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            // Plugin rows
            if !isCollapsed {
                ForEach(plugins, id: \.id) { plugin in
                    if category == "Audio" {
                        AudioPluginRowView(
                            plugin: plugin,
                            isSelected: selectedPlugins.contains(plugin.id),
                            permanentDelete: permanentDelete,
                            sortOption: sortOption
                        ) {
                            onRemove(plugin)
                        } onRefresh: {
                            onRefresh()
                        } onToggleSelection: {
                            toggleSelection(for: plugin)
                        }
                    } else {
                        PluginRowView(
                            plugin: plugin,
                            isSelected: selectedPlugins.contains(plugin.id),
                            permanentDelete: permanentDelete,
                            sortOption: sortOption
                        ) {
                            onRemove(plugin)
                        } onRefresh: {
                            onRefresh()
                        } onToggleSelection: {
                            toggleSelection(for: plugin)
                        }
                    }
                }
                .transition(.opacity.combined(with: .slide))
            }
        }
    }

    private func toggleSelection(for plugin: PluginInfo) {
        if selectedPlugins.contains(plugin.id) {
            selectedPlugins.remove(plugin.id)
            selectedPluginPaths.removeAll { $0 == plugin.path }
        } else {
            selectedPlugins.insert(plugin.id)
            selectedPluginPaths.append(plugin.path)
        }
    }
}

// MARK: - Plugin Row View

struct PluginRowView: View {
    let plugin: PluginInfo
    let isSelected: Bool
    let permanentDelete: Bool
    let sortOption: PluginSortOption
    let onRemove: () -> Void
    let onRefresh: () -> Void
    let onToggleSelection: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isPerformingAction = false
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {

            // Selection checkbox
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : ThemeColors.shared(for: colorScheme).secondaryText)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Plugin icon and type indicator
            VStack(spacing: 4) {
                ZStack {
                    if plugin.customIcon == nil {
                        Circle()
                            .fill(pluginColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                    }

                    if let customIcon = plugin.customIcon {
                        Image(nsImage: customIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: pluginIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(pluginColor)
                    }
                }
            }

            // Plugin details
            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name)
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    .lineLimit(1)

                Text("Path: \(plugin.path)")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack {
                    Text("Category: \(plugin.category)")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Text(verbatim: "•")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Text("Size: \(formatFileSize(plugin.size))")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Spacer()
                }

                // Bundle ID for .driver bundles
                if let bundleId = plugin.bundleId, !bundleId.isEmpty {
                    HStack {
                        Text("Bundle ID:")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        Text(bundleId)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .textSelection(.enabled)

                        Spacer()
                    }
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Button("View") {
                        openInFinder(plugin.path)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
                    .foregroundStyle(.blue)
                    .disabled(isPerformingAction)
                    .help("Show in Finder")

                    Divider().frame(height: 10)

                    Button("Delete") {
                        onRemove()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
                    .foregroundStyle(.red)
                    .disabled(isPerformingAction)
                    .help("Delete plugin")
                }

                if isPerformingAction {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ?
                    ThemeColors.shared(for: colorScheme).secondaryBG.opacity(0.8) :
                    ThemeColors.shared(for: colorScheme).secondaryBG
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private var pluginColor: Color {
        switch plugin.category {
        case "Audio":
            return .purple
        case "PreferencePanes":
            return .blue
        case "QuickLook":
            return .green
        case "Screen Savers":
            return .orange
        case "Internet Plug-Ins":
            return .red
        case "ColorPickers":
            return .pink
        case "Fonts":
            return .brown
        case "Safari Extensions":
            return .cyan
        case "Widgets":
            return .teal
        default:
            return .gray
        }
    }

    private var pluginIcon: String {
        switch plugin.category {
        case "Audio":
            return "waveform"
        case "PreferencePanes":
            return "gearshape"
        case "QuickLook":
            return "magnifyingglass"
        case "Screen Savers":
            return "display"
        case "Internet Plug-Ins":
            return "globe"
        case "ColorPickers":
            return "paintpalette"
        case "Fonts":
            return "textformat"
        case "Safari Extensions":
            return "safari"
        case "Widgets":
            return "square.grid.3x3"
        default:
            return "puzzlepiece"
        }
    }

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func openInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

}

// MARK: - Audio Plugin Row View (with Related Files Search)

struct AudioPluginRowView: View {
    let plugin: PluginInfo
    let isSelected: Bool
    let permanentDelete: Bool
    let sortOption: PluginSortOption
    let onRemove: () -> Void
    let onRefresh: () -> Void
    let onToggleSelection: () -> Void
    @EnvironmentObject var locations: Locations
    @Environment(\.colorScheme) var colorScheme
    @State private var isPerformingAction = false
    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var relatedFiles: [FileSearchResult] = []
    @State private var isSearching = false
    @State private var searchEngine: FileSearchEngine?
    @State private var selectedRelatedFiles: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main plugin row
            HStack(alignment: .center, spacing: 12) {

                // Selection checkbox
                Button(action: {
                    // When selecting/deselecting plugin, also select/deselect all related files
                    if !isSelected {
                        // Plugin is about to be selected, select all related files
                        selectedRelatedFiles = Set(relatedFiles.map { $0.id })
                    } else {
                        // Plugin is about to be deselected, deselect all related files
                        selectedRelatedFiles.removeAll()
                    }
                    onToggleSelection()
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : ThemeColors.shared(for: colorScheme).secondaryText)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                // Plugin icon and type indicator
                VStack(spacing: 4) {
                    ZStack {
                        if plugin.customIcon == nil {
                            Circle()
                                .fill(pluginColor.opacity(0.2))
                                .frame(width: 32, height: 32)
                        }

                        if let customIcon = plugin.customIcon {
                            Image(nsImage: customIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: pluginIcon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(pluginColor)
                        }
                    }
                }

                // Plugin details
                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.name)
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        .lineLimit(1)

                    Text("Path: \(plugin.path)")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack {
                        Text("Category: \(plugin.category)")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        Text(verbatim: "•")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        Text("Size: \(formatFileSize(plugin.size))")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        Spacer()
                    }

                    // Bundle ID for .driver bundles
                    if let bundleId = plugin.bundleId, !bundleId.isEmpty {
                        HStack {
                            Text("Bundle ID:")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                            Text(bundleId)
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                .textSelection(.enabled)

                            Spacer()
                        }
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Button(isExpanded ? "Close" : "Search") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .foregroundStyle(.blue)
                        .disabled(isPerformingAction)
                        .help(isExpanded ? "Close related files search" : "Search for related files")

                        Divider().frame(height: 10)

                        Button("View") {
                            openInFinder(plugin.path)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .foregroundStyle(.blue)
                        .disabled(isPerformingAction)
                        .help("Show in Finder")

                        Divider().frame(height: 10)

                        Button("Delete") {
                            deletePluginAndRelatedFiles()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .foregroundStyle(.red)
                        .disabled(isPerformingAction)
                        .help("Delete plugin and selected related files")
                    }

                    if isPerformingAction {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            .padding()

            // Expandable related files section
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal)

                    if isSearching {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching for related files...")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    } else if relatedFiles.isEmpty {
                        Text("No related files found")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(relatedFiles.count) related file\(relatedFiles.count == 1 ? "" : "s") found")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                .padding(.horizontal)

                            ForEach(relatedFiles, id: \.id) { result in
                                HStack(spacing: 8) {
                                    // Checkbox for related file
                                    Button(action: {
                                        toggleRelatedFileSelection(result)
                                    }) {
                                        Image(systemName: selectedRelatedFiles.contains(result.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedRelatedFiles.contains(result.id) ? .blue : ThemeColors.shared(for: colorScheme).secondaryText)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)

                                    Image(systemName: result.isDirectory ? "folder.fill" : "doc.fill")
                                        .font(.caption)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                        .frame(width: 12)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.name)
                                            .font(.caption)
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                            .lineLimit(1)

                                        Text(result.url.path)
                                            .font(.system(size: 10))
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    Text(formatFileSize(result.size))
                                        .font(.system(size: 10))
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                                    Button("View") {
                                        NSWorkspace.shared.activateFileViewerSelecting([result.url])
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.mini)
                                    .foregroundStyle(.blue)

                                    Button("Delete") {
                                        deleteRelatedFile(result)
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.mini)
                                    .foregroundStyle(.red)
                                    .help("Delete this file")
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .transition(.opacity.combined(with: .slide))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ?
                    ThemeColors.shared(for: colorScheme).secondaryBG.opacity(0.8) :
                    ThemeColors.shared(for: colorScheme).secondaryBG
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onChange(of: isExpanded) { expanded in
            if expanded {
                // Always search when expanding, clear previous results
                searchForRelatedFiles()
            } else {
                // Stop search if user collapses while searching
                searchEngine?.stop()
            }
        }
    }

    private func searchForRelatedFiles() {
        // Extract plugin name without extension
        let pluginName = (plugin.name as NSString).deletingPathExtension

        searchEngine = FileSearchEngine()
        isSearching = true
        relatedFiles = []
        selectedRelatedFiles.removeAll()

        // Build search filters - search for plugin name
        let filters: [FilterType] = [.name(.contains, pluginName)]

        // If bundle ID exists, also search for that
        if let bundleId = plugin.bundleId, !bundleId.isEmpty {
            // Don't add bundle ID as a filter since we can only search for name
            // Instead, we'll do two searches - one for plugin name, one for bundle ID
            let bundleIdEngine = FileSearchEngine()

            // Search for bundle ID
            bundleIdEngine.search(
                rootPaths: locations.apps.paths,
                filters: [.name(.contains, bundleId)],
                includeSubfolders: false,
                includeHiddenFiles: false,
                caseSensitive: false,
                searchType: .filesAndFolders,
                excludeSystemFolders: true,
                onBatchFound: { results in
                    DispatchQueue.main.async {
                        // Add bundle ID results, avoiding duplicates
                        let existingPaths = Set(self.relatedFiles.map { $0.url.path })
                        let newResults = results.filter { !existingPaths.contains($0.url.path) }
                        self.relatedFiles.append(contentsOf: newResults)
                    }
                },
                completion: { }
            )
        }

        // Search for plugin name across all app-related directories
        searchEngine?.search(
            rootPaths: locations.apps.paths,
            filters: filters,
            includeSubfolders: false,
            includeHiddenFiles: false,
            caseSensitive: false,
            searchType: .filesAndFolders,
            excludeSystemFolders: true,
            onBatchFound: { results in
                DispatchQueue.main.async {
                    self.relatedFiles.append(contentsOf: results)
                }
            },
            completion: {
                DispatchQueue.main.async {
                    self.isSearching = false
                }
            }
        )
    }

    private func toggleRelatedFileSelection(_ file: FileSearchResult) {
        if selectedRelatedFiles.contains(file.id) {
            selectedRelatedFiles.remove(file.id)
        } else {
            selectedRelatedFiles.insert(file.id)
        }
    }

    private func deletePluginAndRelatedFiles() {
        isPerformingAction = true

        Task {
            // Get selected related files
            let selectedFiles = relatedFiles.filter { selectedRelatedFiles.contains($0.id) }
            let relatedURLs = selectedFiles.map { $0.url }

            // If there are selected related files, delete them along with the plugin
            if !relatedURLs.isEmpty {
                let pluginURL = URL(fileURLWithPath: plugin.path)
                let allURLs = [pluginURL] + relatedURLs
                let bundleName = "\(plugin.category) Plugin - \(plugin.name) + \(relatedURLs.count) related file\(relatedURLs.count == 1 ? "" : "s")"

                let success = await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let success = FileManagerUndo.shared.deleteFiles(at: allURLs, bundleName: bundleName)
                        continuation.resume(returning: success)
                    }
                }

                await MainActor.run {
                    isPerformingAction = false
                    if success {
                        // Clear related files and selections
                        relatedFiles.removeAll()
                        selectedRelatedFiles.removeAll()
                        onRefresh()
                    } else {
                        showCustomAlert(
                            title: "Deletion Failed",
                            message: "Failed to delete plugin and related files. They may require additional permissions or may not exist.",
                            style: .critical
                        )
                    }
                }
            } else {
                // No related files selected, just delete the plugin
                await MainActor.run {
                    isPerformingAction = false
                    onRemove()
                }
            }
        }
    }

    private func deleteRelatedFile(_ file: FileSearchResult) {
        Task {
            let success = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let success = FileManagerUndo.shared.deleteFiles(
                        at: [file.url],
                        bundleName: "Related File - \(file.name)"
                    )
                    continuation.resume(returning: success)
                }
            }

            await MainActor.run {
                if success {
                    // Remove from arrays
                    relatedFiles.removeAll { $0.id == file.id }
                    selectedRelatedFiles.remove(file.id)
                } else {
                    showCustomAlert(
                        title: "Deletion Failed",
                        message: "Failed to delete '\(file.name)'. It may require additional permissions or may not exist.",
                        style: .critical
                    )
                }
            }
        }
    }

    private var pluginColor: Color {
        return .purple
    }

    private var pluginIcon: String {
        return "waveform"
    }

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func openInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
