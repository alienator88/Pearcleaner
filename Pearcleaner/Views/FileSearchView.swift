//
//  FileSearchView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 09/29/25.
//

import SwiftUI
import AlinFoundation

struct FileSearchView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var results: [FileSearchResult] = []
    @State private var selectedResults: Set<FileSearchResult.ID> = []
    @State private var selectedVolume: String = "/"
    @State private var selectedVolumeName: String = "Startup Disk"
    @State private var activeFilters: [FilterType] = []
    @State private var isSearching: Bool = false
    @State private var includeSubfolders: Bool = true
    @State private var includeHiddenFiles: Bool = false
    @State private var caseSensitive: Bool = false
    @State private var excludeSystemFolders: Bool = true
    @State private var searchType: SearchType = .filesAndFolders
    @State private var currentSearcher: FileSearchEngine?
    @State private var sortOrder: [KeyPathComparator<FileSearchResult>] = [.init(\.name, order: .forward)]
    @State private var calculatedFolderSizes: [URL: Int64] = [:]
    @State private var showAddFilterMenu: Bool = false
    @State private var showNameFilterDialog: Bool = false
    @State private var showExtensionFilterDialog: Bool = false
    @State private var showSizeFilterDialog: Bool = false
    @State private var showDateFilterDialog: Bool = false
    @State private var showTagsFilterDialog: Bool = false
    @State private var showCommentFilterDialog: Bool = false
    @State private var searchStartTime: Date?
    @State private var searchElapsedTime: TimeInterval = 0
    @State private var elapsedTimeUpdateTimer: Timer?
    @State private var hasSearched: Bool = false
    @State private var filterText: String = ""
    @State private var editingItemId: UUID?
    @State private var editingText: String = ""
    @State private var deletedItemsCache: [FileSearchResult] = []
    @FocusState private var isEditingFocused: Bool
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    private var sortedResults: [FileSearchResult] {
        let sorted = results.sorted(using: sortOrder)

        // Apply filter text if present
        if filterText.isEmpty {
            return sorted
        } else {
            return sorted.filter { result in
                result.name.localizedCaseInsensitiveContains(filterText) ||
                result.url.path.localizedCaseInsensitiveContains(filterText)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Filter controls
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Volume selector
                    Menu {
                        Button("Startup Disk") {
                            selectedVolume = "/"
                            selectedVolumeName = "Startup Disk"
                        }

                        if !appState.volumeInfos.isEmpty {
                            Divider()
                            ForEach(appState.volumeInfos) { volume in
                                Button(volume.name) {
                                    selectedVolume = volume.path
                                    selectedVolumeName = volume.name
                                }
                            }
                        }

                        Divider()

                        Button("Choose Folder...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.prompt = "Choose"
                            if panel.runModal() == .OK, let url = panel.url {
                                selectedVolume = url.path
                                selectedVolumeName = url.lastPathComponent
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "externaldrive")
                            Text(selectedVolumeName)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(ControlGroupButtonStyle(
                        foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                        shape: Capsule(style: .continuous),
                        level: .primary,
                        skipControlGroup: true
                    ))

                    // Search type selector
                    Menu {
                        ForEach(SearchType.allCases, id: \.self) { type in
                            Button(type.rawValue) {
                                searchType = type
                                // Disable subfolders option when files only, enable for others
                                if type == .filesOnly {
                                    includeSubfolders = false
                                } else {
                                    includeSubfolders = true
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: searchType == .filesOnly ? "doc" : searchType == .foldersOnly ? "folder" : "doc.on.doc")
                            Text(searchType.rawValue)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(ControlGroupButtonStyle(
                        foregroundColor: ThemeColors.shared(for: colorScheme).primaryText,
                        shape: Capsule(style: .continuous),
                        level: .primary,
                        skipControlGroup: true
                    ))

                    // Search options
                    Toggle("Include subfolders", isOn: $includeSubfolders)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                        .disabled(searchType == .filesOnly)

                    Toggle("Exclude system folders", isOn: $excludeSystemFolders)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)

                    Toggle("Include hidden files", isOn: $includeHiddenFiles)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)

                    Toggle("Case sensitive", isOn: $caseSensitive)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)

                    Spacer()
                }

                // Active filters
                if !activeFilters.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(activeFilters.enumerated()), id: \.element.id) { index, filter in
                                FilterChip(filter: filter, onUpdate: { updatedFilter in
                                    activeFilters[index] = updatedFilter
                                }, onRemove: {
                                    removeFilter(filter)
                                })
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 5)

            // Stats header
            if hasSearched || isSearching {
                HStack(spacing: 12) {
                    // Results count - leading aligned, 200 width
                    Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .frame(width: 200, alignment: .leading)

                    Spacer()

                    // Action buttons - centered
                    Button(action: {
                        if selectedResults.count == 1,
                           let selectedId = selectedResults.first,
                           let result = results.first(where: { $0.id == selectedId }) {
                            NSWorkspace.shared.open(result.url)
                        }
                    }) {
                        Label("Open", systemImage: "arrow.up.forward.app")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedResults.count != 1)

                    Button(action: {
                        if selectedResults.count == 1,
                           let selectedId = selectedResults.first,
                           let result = results.first(where: { $0.id == selectedId }) {
                            // Temporarily deselect to force re-render, then reselect
                            selectedResults.removeAll()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                editingItemId = selectedId
                                editingText = result.name
                                selectedResults.insert(selectedId)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isEditingFocused = true
                                }
                            }
                        }
                    }) {
                        Label("Rename", systemImage: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedResults.count != 1)

                    Button(action: {
                        deleteSelectedItems()
                    }) {
                        Label(selectedResults.count > 1 ? "Bulk Delete" : "Delete", systemImage: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedResults.isEmpty)

                    Spacer()

                    // Elapsed time - trailing aligned, 200 width
                    if searchStartTime != nil {
                        Text("Elapsed Time: \(formatElapsedTime(searchElapsedTime))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .frame(width: 200, alignment: .trailing)
                    } else {
                        EmptyView()
                            .frame(width: 200, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical)
            }

            // Results table
            if results.isEmpty && !isSearching {
                VStack {
                    Spacer()
                    if hasSearched {
                        Text("No results")
                            .font(.title2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        Text("Try adjusting your filters")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    } else {
                        Text("Ready to search")
                            .font(.title2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        Text("Add filters and click Play to find files")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                Table(sortedResults, selection: $selectedResults, sortOrder: $sortOrder) {
                        TableColumn("") { result in
                            HStack {
                                Spacer()
                                Button(action: {
                                    toggleSelection(for: result)
                                }) {
                                    Image(systemName: selectedResults.contains(result.id) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(selectedResults.contains(result.id) ? .blue : ThemeColors.shared(for: colorScheme).secondaryText)
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                        }
                        .width(40)

                    TableColumn("") { result in
                        HStack {
                            Spacer()
                            if let icon = result.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            }
                            Spacer()
                        }
                    }
                    .width(40)

                    TableColumn("Name", value: \.name) { result in
                        if editingItemId == result.id {
                            TextField(LocalizedStringKey(""), text: $editingText, onCommit: {
                                if !editingText.isEmpty && editingText != result.name {
                                    performRename(result: result, newName: editingText)
                                }
                                editingItemId = nil
                                isEditingFocused = false
                            })
                            .textFieldStyle(.plain)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .focused($isEditingFocused)
                            .id(result.id)
                        } else {
                            Text(result.name)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                    }
                    .width(min: 150, ideal: 250)

                    TableColumn("Type", value: \.type) { result in
                        Text(result.type)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .width(80)

                    TableColumn("Size", value: \.size) { result in
                        SizeCell(result: result, calculatedFolderSizes: $calculatedFolderSizes)
                    }
                    .width(100)

                    TableColumn("Modified", value: \.dateModified) { result in
                        Text(formatDate(result.dateModified))
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .width(150)
                }
                .onDeleteCommand {
                    if !selectedResults.isEmpty {
                        deleteSelectedItems()
                    }
                }
                .contextMenu(forSelectionType: FileSearchResult.ID.self) { items in
                    if let firstId = items.first,
                       let result = results.first(where: { $0.id == firstId }) {
                        Button("Rename") {
                            selectedResults.removeAll()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                editingItemId = firstId
                                editingText = result.name
                                selectedResults.insert(firstId)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isEditingFocused = true
                                }
                            }
                        }
                        Button("View in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([result.url])
                        }
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result.url.path, forType: .string)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteFile(result)
                        }
                    }
                }
                .scrollIndicators(scrollIndicators ? .automatic : .never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            // Bottom status bar - always visible when there are results
            if !results.isEmpty || isSearching {
                HStack(spacing: 12) {
                    // Select-all text button on far left
                    Button(action: {
                        if selectedResults.count == results.count {
                            selectedResults.removeAll()
                        } else {
                            selectedResults = Set(results.map { $0.id })
                        }
                    }) {
                        Text(selectedResults.count == results.count && !results.isEmpty ? "Deselect All" : "Select All")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)

                    // Path when single item selected
                    if selectedResults.count == 1,
                       let selectedId = selectedResults.first,
                       let selectedResult = results.first(where: { $0.id == selectedId }) {
                        Divider()
                            .frame(height: 12)
                        PathStatusBar(url: selectedResult.url)
                    } else {
                        Spacer()
                    }

                    // Filter field and searching indicator on the right
                    HStack(spacing: 8) {

                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            TextField("Filter", text: $filterText)
                                .textFieldStyle(.plain)
                                .font(.caption)
                                .frame(width: 150)
                            if !filterText.isEmpty {
                                Button(action: { filterText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ThemeColors.shared(for: colorScheme).secondaryBG)
                        .cornerRadius(6)


                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ThemeColors.shared(for: colorScheme).primaryBG)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FileSearchViewShouldUndo"))) { _ in
            // Restore deleted items from cache after undo
            if !deletedItemsCache.isEmpty {
                results.append(contentsOf: deletedItemsCache)
                deletedItemsCache.removeAll()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FileSearchViewShouldRefresh"))) { _ in
            // Re-run search with current parameters if a search has been performed
            if hasSearched {
                startSearch()
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            TahoeToolbarItem(placement: .navigation) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("File Search")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Search for files and folders with advanced filters")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                }

            }

            ToolbarItem { Spacer() }

            TahoeToolbarItem(isGroup: true) {
                Menu {
                    Button("Name") {
                        showNameFilterDialog = true
                    }
                    Button("Extension") {
                        showExtensionFilterDialog = true
                    }
                    Button("Size") {
                        showSizeFilterDialog = true
                    }
                    Button("Date") {
                        showDateFilterDialog = true
                    }
                    Button("Tags") {
                        showTagsFilterDialog = true
                    }
                    Button("Comment") {
                        showCommentFilterDialog = true
                    }
                    Menu("Kind") {
                        ForEach(KindFilterType.allCases, id: \.self) { kind in
                            Button(kind.displayName) {
                                addFilter(.kind(kind))
                            }
                        }
                    }
                } label: {
                    Label("Add Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
                .labelStyle(.titleAndIcon)
                .menuIndicator(.hidden)

                Button {
                    results.removeAll()
                    selectedResults.removeAll()
                    hasSearched = false
                    searchStartTime = nil
                    searchElapsedTime = 0
                    deletedItemsCache.removeAll()
                    activeFilters.removeAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(results.isEmpty)

                if isSearching {
                    Button {
                        stopSearch()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                } else {
                    Button {
                        startSearch()
                    } label: {
                        Label("Search", systemImage: "play.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showNameFilterDialog) {
            NameFilterDialog { type, value in
                addFilter(.name(type, value))
                showNameFilterDialog = false
            } onCancel: {
                showNameFilterDialog = false
            }
        }
        .sheet(isPresented: $showExtensionFilterDialog) {
            ExtensionFilterDialog { type, value in
                addFilter(.fileExtension(type, value))
                showExtensionFilterDialog = false
            } onCancel: {
                showExtensionFilterDialog = false
            }
        }
        .sheet(isPresented: $showSizeFilterDialog) {
            SizeFilterDialog { type, value, max in
                addFilter(.size(type, value, max))
                showSizeFilterDialog = false
            } onCancel: {
                showSizeFilterDialog = false
            }
        }
        .sheet(isPresented: $showDateFilterDialog) {
            DateFilterDialog { type, value, end in
                addFilter(.date(type, value, end))
                showDateFilterDialog = false
            } onCancel: {
                showDateFilterDialog = false
            }
        }
        .sheet(isPresented: $showTagsFilterDialog) {
            TagsFilterDialog { type, value in
                addFilter(.tags(type, value))
                showTagsFilterDialog = false
            } onCancel: {
                showTagsFilterDialog = false
            }
        }
        .sheet(isPresented: $showCommentFilterDialog) {
            CommentFilterDialog { type, value in
                addFilter(.comment(type, value))
                showCommentFilterDialog = false
            } onCancel: {
                showCommentFilterDialog = false
            }
        }
    }

    // MARK: - Helper Functions

    private func toggleSelection(for result: FileSearchResult) {
        if selectedResults.contains(result.id) {
            selectedResults.remove(result.id)
        } else {
            selectedResults.insert(result.id)
        }
    }

    private func addFilter(_ filter: FilterType) {
        activeFilters.append(filter)
    }

    private func removeFilter(_ filter: FilterType) {
        activeFilters.removeAll { $0.id == filter.id }
    }

    private func startSearch() {
        isSearching = true
        hasSearched = true
        results.removeAll()
        selectedResults.removeAll()

        // Start elapsed time tracking
        searchStartTime = Date()
        searchElapsedTime = 0

        // Start a timer to update elapsed time every 0.1 seconds
        elapsedTimeUpdateTimer?.invalidate()
        elapsedTimeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = searchStartTime {
                searchElapsedTime = Date().timeIntervalSince(startTime)
            }
        }

        let searcher = FileSearchEngine()
        currentSearcher = searcher

        searcher.search(
            rootPath: selectedVolume,
            filters: activeFilters,
            includeSubfolders: includeSubfolders,
            includeHiddenFiles: includeHiddenFiles,
            caseSensitive: caseSensitive,
            searchType: searchType,
            excludeSystemFolders: excludeSystemFolders,
            onBatchFound: { batch in
                results.append(contentsOf: batch)
            },
            completion: {
                isSearching = false
                currentSearcher = nil

                // Stop the timer but keep the final elapsed time
                self.elapsedTimeUpdateTimer?.invalidate()
                self.elapsedTimeUpdateTimer = nil
            }
        )
    }

    private func stopSearch() {
        currentSearcher?.stop()
        isSearching = false
        currentSearcher = nil

        // Stop the timer but keep the elapsed time
        elapsedTimeUpdateTimer?.invalidate()
        elapsedTimeUpdateTimer = nil
    }

    private func performActionOnSelected(action: (FileSearchResult) -> Void) {
        let itemsToAction = results.filter { selectedResults.contains($0.id) }
        for item in itemsToAction {
            action(item)
        }
    }

    private func performRename(result: FileSearchResult, newName: String) {
        let newURL = result.url.deletingLastPathComponent().appendingPathComponent(newName)

        // Always use helper for file operations (works for all file types)
        var success = false

        if HelperToolManager.shared.isHelperToolInstalled {
            let command = "/bin/mv \"\(result.url.path)\" \"\(newURL.path)\""
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                let result = await HelperToolManager.shared.runCommand(command)
                success = result.0
                semaphore.signal()
            }
            semaphore.wait()
        } else {
            // Fallback to performPrivilegedCommands if helper not installed
            let command = "/bin/mv \"\(result.url.path)\" \"\(newURL.path)\""
            let result = performPrivilegedCommands(commands: command)
            success = result.0
        }

        if success {
            // Update the result in the list
            if let index = results.firstIndex(where: { $0.id == result.id }) {
                let updatedResult = FileSearchResult(
                    url: newURL,
                    name: newName,
                    type: result.type,
                    size: result.size,
                    dateModified: result.dateModified,
                    isDirectory: result.isDirectory,
                    icon: result.icon
                )
                results[index] = updatedResult
            }
        } else {
            let error = NSError(domain: "com.pearcleaner.rename", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to rename file"])
            showCustomAlert(
                title: "Rename Failed",
                message: "Failed to rename '\(result.name)' to '\(newName)'. Error: \(error.localizedDescription)",
                style: .critical
            )
        }
    }

    private func deleteFile(_ result: FileSearchResult) {
        Task {
            let success = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let success = FileManagerUndo.shared.deleteFiles(at: [result.url], bundleName: "File Search - \(result.name)")
                    continuation.resume(returning: success)
                }
            }

            await MainActor.run {
                if success {
                    // Cache the deleted item before removing
                    deletedItemsCache.append(result)
                    results.removeAll { $0.id == result.id }
                    selectedResults.remove(result.id)
                } else {
                    showCustomAlert(
                        title: "Deletion Failed",
                        message: "Failed to delete '\(result.name)'. The file may require additional permissions or may not exist.",
                        style: .critical
                    )
                }
            }
        }
    }

    private func deleteSelectedItems() {
        let itemsToDelete = results.filter { selectedResults.contains($0.id) }
        let urlsToDelete = itemsToDelete.map { $0.url }

        Task {
            let success = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let bundleName = "File Search (\(itemsToDelete.count) items)"
                    let success = FileManagerUndo.shared.deleteFiles(at: urlsToDelete, bundleName: bundleName)
                    continuation.resume(returning: success)
                }
            }

            await MainActor.run {
                if success {
                    // Cache the deleted items before removing
                    deletedItemsCache.append(contentsOf: itemsToDelete)
                    let deletedIds = Set(itemsToDelete.map { $0.id })
                    results.removeAll { deletedIds.contains($0.id) }
                    selectedResults.removeAll()
                } else {
                    showCustomAlert(
                        title: "Deletion Failed",
                        message: "Failed to delete some selected files. They may require additional permissions or may not exist.",
                        style: .critical
                    )
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatElapsedTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
}

// MARK: - Filter Chip View

struct FilterChip: View {
    let filter: FilterType
    let onUpdate: (FilterType) -> Void
    let onRemove: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var editingText: String = ""
    @State private var isEditing: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            // For name filters, make them editable
            if case .name(let type, let value) = filter {
                if isEditing {
                    TextField(LocalizedStringKey(""), text: $editingText, onCommit: {
                        onUpdate(.name(type, editingText))
                        isEditing = false
                    })
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(minWidth: 60, maxWidth: 200)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                } else {
                    Text(filter.displayText)
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        .onTapGesture {
                            editingText = value
                            isEditing = true
                        }
                }
            } else {
                Text(filter.displayText)
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(ThemeColors.shared(for: colorScheme).secondaryBG)
        )
    }
}

// MARK: - Filter Dialog Views

struct NameFilterDialog: View {
    let onAdd: (NameFilterType, String) -> Void
    let onCancel: () -> Void
    @State private var selectedType: NameFilterType = .contains
    @State private var value: String = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Name Filter")
                .font(.headline)

            Picker("Filter Type", selection: $selectedType) {
                ForEach(NameFilterType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            TextField("Value", text: $value)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    if !value.isEmpty {
                        onAdd(selectedType, value)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(value.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct ExtensionFilterDialog: View {
    let onAdd: (ExtensionFilterType, String) -> Void
    let onCancel: () -> Void
    @State private var selectedType: ExtensionFilterType = .includes
    @State private var value: String = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Extension Filter")
                .font(.headline)

            Picker("Filter Type", selection: $selectedType) {
                ForEach(ExtensionFilterType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            TextField("Extensions (comma-separated, e.g., jpg,png,pdf)", text: $value)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    if !value.isEmpty {
                        onAdd(selectedType, value)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(value.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct SizeFilterDialog: View {
    let onAdd: (SizeFilterType, Int64, Int64?) -> Void
    let onCancel: () -> Void
    @State private var selectedType: SizeFilterType = .greaterThan
    @State private var value: String = ""
    @State private var maxValue: String = ""
    @State private var unit: Int64 = 1_048_576  // MB by default
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Size Filter")
                .font(.headline)

            Picker("Filter Type", selection: $selectedType) {
                ForEach(SizeFilterType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            HStack {
                TextField("Value", text: $value)
                    .textFieldStyle(.roundedBorder)

                Picker("Unit", selection: $unit) {
                    Text("KB").tag(Int64(1_024))
                    Text("MB").tag(Int64(1_048_576))
                    Text("GB").tag(Int64(1_073_741_824))
                }
                .frame(width: 80)
            }

            if selectedType == .between {
                HStack {
                    TextField("Max Value", text: $maxValue)
                        .textFieldStyle(.roundedBorder)
                    Text("(same unit)")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    if let numValue = Int64(value) {
                        let bytes = numValue * unit
                        let maxBytes = selectedType == .between ? (Int64(maxValue) ?? 0) * unit : nil
                        onAdd(selectedType, bytes, maxBytes)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(value.isEmpty || (selectedType == .between && maxValue.isEmpty))
            }
        }
        .padding()
        .frame(width: 350)
    }
}

struct DateFilterDialog: View {
    let onAdd: (DateFilterType, Date, Date?) -> Void
    let onCancel: () -> Void
    @State private var selectedType: DateFilterType = .modifiedAfter
    @State private var date: Date = Date()
    @State private var endDate: Date = Date()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Date Filter")
                .font(.headline)

            Picker("Filter Type", selection: $selectedType) {
                ForEach(DateFilterType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            DatePicker("Date", selection: $date, displayedComponents: [.date])

            if selectedType == .createdBetween || selectedType == .modifiedBetween {
                DatePicker("End Date", selection: $endDate, displayedComponents: [.date])
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    let end = (selectedType == .createdBetween || selectedType == .modifiedBetween) ? endDate : nil
                    onAdd(selectedType, date, end)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct TagsFilterDialog: View {
    let onAdd: (TagFilterType, String) -> Void
    let onCancel: () -> Void
    @State private var selectedType: TagFilterType = .hasTag
    @State private var value: String = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Tags Filter")
                .font(.headline)

            Picker("Filter Type", selection: $selectedType) {
                ForEach(TagFilterType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            if selectedType != .hasAnyOfTags && selectedType != .hasAllOfTags {
                TextField("Tag name", text: $value)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField("Tag names (comma-separated)", text: $value)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    if !value.isEmpty {
                        onAdd(selectedType, value)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(value.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

struct CommentFilterDialog: View {
    let onAdd: (CommentFilterType, String) -> Void
    let onCancel: () -> Void
    @State private var selectedType: CommentFilterType = .contains
    @State private var value: String = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Comment Filter")
                .font(.headline)

            Picker("Filter Type", selection: $selectedType) {
                ForEach(CommentFilterType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            if selectedType != .isEmpty {
                TextField("Value", text: $value)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    onAdd(selectedType, value)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedType != .isEmpty && value.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

// MARK: - Size Cell with Lazy Folder Size Calculation

struct SizeCell: View {
    let result: FileSearchResult
    @Binding var calculatedFolderSizes: [URL: Int64]
    @Environment(\.colorScheme) var colorScheme
    @State private var isCalculating: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if result.isDirectory {
                // For folders, calculate size on demand
                if let cachedSize = calculatedFolderSizes[result.url] {
                    Text(formatBytes(cachedSize))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                } else if isCalculating {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                } else {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                        .onAppear {
                            calculateFolderSize()
                        }
                }
            } else {
                // For files, show the size immediately
                Text(formatBytes(result.size))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
        }
    }

    private func calculateFolderSize() {
        isCalculating = true
        Task.detached(priority: .utility) {
            let size = totalSizeOnDisk(for: result.url)
            await MainActor.run {
                calculatedFolderSizes[result.url] = size
                isCalculating = false
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Path Status Bar

struct PathStatusBar: View {
    let url: URL
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                    Button(action: {
                        openPathComponent(at: index)
                    }) {
                        Text(component.name)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                    .buttonStyle(.plain)
                    .help(component.path)

                    if index < pathComponents.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
            }
        }
    }

    private var pathComponents: [(name: String, path: String)] {
        let path = url.path
        var components: [(String, String)] = []
        var currentPath = ""

        let parts = path.components(separatedBy: "/").filter { !$0.isEmpty }

        // Add root
        components.append(("/", "/"))
        currentPath = "/"

        // Add each component
        for part in parts {
            currentPath += (currentPath == "/" ? "" : "/") + part
            components.append((part, currentPath))
        }

        return components
    }

    private func openPathComponent(at index: Int) {
        let component = pathComponents[index]
        let componentURL = URL(fileURLWithPath: component.path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: componentURL.path)
    }
}
