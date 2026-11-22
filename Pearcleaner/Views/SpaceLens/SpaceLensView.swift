//
//  SpaceLensView.swift
//  Pearcleaner
//

import SwiftUI
import AlinFoundation

@MainActor
final class SpaceLensViewModel: ObservableObject {
    @Published var rootNode: SpaceLensNode?
    @Published var focusedNodeID: UUID?
    @Published var phase: SpaceLensScanPhase = .idle
    @Published var lastTarget: URL?
    @Published var lastTargetWasFullDisk = false
    @Published var trashError: String?

    private let scanner = SpaceLensScanner()
    private var scanTask: Task<Void, Never>?
    private(set) var lastTargetUsedHelper = false
    private(set) var scanDepth = 1

    var focusedNode: SpaceLensNode? {
        guard let root = rootNode else { return nil }
        guard let id = focusedNodeID else { return root }
        return root.child(withID: id) ?? root
    }

    var hasAccessErrors: Bool {
        rootNode?.hasAccessErrors() ?? false
    }

    func startScan(target: URL, isFullDisk: Bool, usingHelper: Bool = false, maxDepth: Int = 1) {
        cancelScan()
        lastTarget = target
        lastTargetWasFullDisk = isFullDisk
        lastTargetUsedHelper = usingHelper
        scanDepth = maxDepth
        focusedNodeID = nil
        phase = .scanning(target.path)

        scanTask = Task { [weak self] in
            guard let self else { return }

            let partial: (SpaceLensNode) async -> Void = { tree in
                await MainActor.run {
                    self.rootNode = tree
                }
            }

            var tree: SpaceLensNode?
            if usingHelper {
                tree = await self.scanner.helperScan(duPath: target.path, rootName: target.lastPathComponent, onPartialTree: partial)
            } else {
                tree = await self.scanner.scan(target: target, isFullDisk: isFullDisk, maxDepth: maxDepth, onPartialTree: partial)
            }

            await MainActor.run {
                if let tree {
                    self.rootNode = tree
                    if case .scanning = self.phase {
                        self.phase = .complete
                    }
                } else if case .scanning = self.phase {
                    self.phase = .cancelled
                }
                if self.focusedNodeID != nil && self.rootNode?.child(withID: self.focusedNodeID!) == nil {
                    self.focusedNodeID = nil
                }
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        Task { [scanner] in
            await scanner.cancel()
        }
        if case .scanning = phase {
            phase = .cancelled
        }
        scanTask = nil
    }

    func drill(to node: SpaceLensNode) {
        if node.children.isEmpty && node.accessError == nil && !node.isAggregated {
            expandAndFocus(node: node)
            return
        }
        guard !node.isAggregated else { return }
        focusedNodeID = node.id
    }

    func drillUp(to node: SpaceLensNode) {
        focusedNodeID = node.id == rootNode?.id ? nil : node.id
    }

    // Lazy drill-down: childless folders load their subtree on first click, then focus
    private func expandAndFocus(node: SpaceLensNode) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: node.url.path, isDirectory: &isDir), isDir.boolValue else { return }
        focusedNodeID = node.id
        let skipFirmlinks = node.url.path == "/" || node.url.path == "/System"
        scanTask = Task { [weak self] in
            guard let self else { return }
            if let replacement = await self.scanner.rescanSubtree(at: node.url, skipFirmlinks: skipFirmlinks, maxDepth: self.scanDepth) {
                await MainActor.run {
                    let root = self.rootNode?.replacing(nodeID: node.id, with: replacement) ?? replacement
                    self.rootNode = root.sortedBySize()
                    self.focusedNodeID = replacement.id
                    self.clearStaleFocus()
                }
            }
        }
    }

    func breadcrumbPath() -> [SpaceLensNode] {
        guard let root = rootNode else { return [] }
        guard let id = focusedNodeID else { return [root] }
        return root.path(toID: id)
    }

    func trash(node: SpaceLensNode) {
        do {
            try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
            playTrashSound()
            rescanSubtree(node: node)
        } catch {
            trashError = error.localizedDescription
        }
    }

    private func clearStaleFocus() {
        if let id = focusedNodeID, rootNode?.child(withID: id) == nil {
            focusedNodeID = nil
        }
    }

    func rescanSubtree(node: SpaceLensNode) {
        guard let parent = rootNode?.parent(ofID: node.id) ?? rootNode else { return }
        scanTask = Task { [weak self] in
            guard let self else { return }
            if let replacement = await self.scanner.rescanSubtree(at: node.url, maxDepth: self.scanDepth) {
                await MainActor.run {
                    let root = self.rootNode?.replacing(nodeID: node.id, with: replacement) ?? replacement
                    self.rootNode = root.sortedBySize()
                    self.clearStaleFocus()
                }
            } else {
                await MainActor.run {
                    // Path is gone: drop the stale child and recompute the parent so
                    // ancestors rebalance through the replacing() delta
                    var parentCopy = parent
                    parentCopy.children.removeAll { $0.id == node.id }
                    parentCopy.size = parentCopy.children.reduce(Int64(0)) { $0 + $1.size }
                    let root = self.rootNode?.replacing(nodeID: parent.id, with: parentCopy) ?? parentCopy
                    self.rootNode = root.sortedBySize()
                    self.clearStaleFocus()
                }
            }
        }
    }
}

struct SpaceLensView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var viewModel: SpaceLensViewModel
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var helperManager = HelperToolManager.shared
    // First launch or whenever the user has never switched modes: open with the
    // style picked in Settings. After a manual switch the per-session choice wins.
    @AppStorage("settings.spacelens.displayMode") private var displayModeRaw = UserDefaults.standard.object(forKey: "settings.spacelens.displayMode") as? String ?? UserDefaults.standard.string(forKey: "settings.spacelens.defaultMode") ?? SpaceLensDisplayMode.treemap.rawValue
    @AppStorage("settings.spacelens.lastPath") private var lastPath = ""
    @AppStorage("settings.spacelens.levels") private var levels = 3
    @State private var pendingTrashNode: SpaceLensNode?
    @State private var pendingLevels: Int?
    @State private var keyMonitor: Any?

    private var displayMode: SpaceLensDisplayMode {
        get { SpaceLensDisplayMode(rawValue: displayModeRaw) ?? .treemap }
        set { displayModeRaw = newValue.rawValue }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                if case .scanning(let path) = viewModel.phase {
                    scanProgress(path: path)
                } else if viewModel.rootNode != nil {
                    chart
                } else {
                    emptyState
                }
            }
            .frame(minWidth: 680, minHeight: 380)
        }
        .onAppear {
            if viewModel.phase == .idle, viewModel.rootNode == nil, !lastPath.isEmpty {
                viewModel.startScan(target: URL(fileURLWithPath: lastPath), isFullDisk: false, maxDepth: levels)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SpaceLensViewShouldRefresh"))) { _ in
            if let target = viewModel.lastTarget {
                viewModel.startScan(target: target, isFullDisk: viewModel.lastTargetWasFullDisk,
                                     usingHelper: viewModel.lastTargetUsedHelper, maxDepth: levels)
            }
        }
        // Delete (backspace) goes up one focus level, like Finder's cmd+up in
        // column view. The chart is Canvas-based and never becomes first
        // responder, so onKeyPress would silently swallow nothing; a local
        // NSEvent monitor handles the key while the window is key
        .onAppear {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard event.keyCode == 51, // delete/backspace
                      event.charactersIgnoringModifiers == "\u{7F}",
                      viewModel.focusedNode != nil else { return event }
                goUpOneLevel()
                return nil
            }
        }
        .onDisappear {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
            keyMonitor = nil
        }
        .confirmationDialog(
            String(localized: "Move “\(pendingTrashNode?.name ?? "")” to Trash?"),
            isPresented: Binding(
                get: { pendingTrashNode != nil },
                set: { if !$0 { pendingTrashNode = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Move to Trash"), role: .destructive) {
                if let node = pendingTrashNode {
                    viewModel.trash(node: node)
                }
                pendingTrashNode = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) { pendingTrashNode = nil }
        } message: {
            Text(String(localized: "It stays in Trash until you empty it."))
        }
        .confirmationDialog(
            String(localized: "Change levels to \(pendingLevels ?? levels) and rescan?"),
            isPresented: Binding(
                get: { pendingLevels != nil },
                set: { if !$0 { pendingLevels = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Rescan with \(pendingLevels ?? levels) Levels")) {
                if let value = pendingLevels {
                    applyLevels(value)
                }
                pendingLevels = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) { pendingLevels = nil }
        } message: {
            Text(String(localized: "The depth of folders scanned and shown needs a fresh scan to be accurate."))
        }
        .alert(
            String(localized: "Could not move to Trash"),
            isPresented: Binding(
                get: { viewModel.trashError != nil },
                set: { if !$0 { viewModel.trashError = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.trashError ?? String(localized: "Finder could not move the item."))
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.pie.fill")
                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                .imageScale(.large)
            (Text(String(localized: "Space Lens"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
             + Text(viewModel.rootNode.map { "  \(formatBytes($0.size))" } ?? "")
                .font(.system(size: 12))
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
             + Text(viewModel.rootNode.map { "  \($0.url.path == "/" ? String(localized: "Full Disk") : $0.url.path)" } ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText))
                .lineLimit(1)

            Spacer()

            Menu {
                ForEach(2...6, id: \.self) { level in
                    Button {
                        if level != levels {
                            pendingLevels = level
                        }
                    } label: {
                        if level == levels {
                            Label("\(level)", systemImage: "checkmark")
                        } else {
                            Text("\(level)")
                        }
                    }
                }
            } label: {
                Text(String(localized: "Levels: \(levels)"))
            }
            .fixedSize()
            .frame(width: 100)

            Picker(String(localized: "Mode"), selection: Binding(
                get: { displayMode },
                set: { displayModeRaw = $0.rawValue }
            )) {
                ForEach(SpaceLensDisplayMode.allCases, id: \.self) { mode in
                    Text(mode == .treemap ? String(localized: "Treemap") : String(localized: "Sunburst"))
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 190)

            Button {
                pickFolder()
            } label: {
                Label(String(localized: "Choose Folder"), systemImage: "folder.badge.plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)

            Button {
                startFullDiskScan()
            } label: {
                Label(String(localized: "Full Disk"), systemImage: "internaldrive")
            }
            .buttonStyle(.plain)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)

            if viewModel.hasAccessErrors, case .complete = viewModel.phase {
                rescanWithHelperButton
            }
        }
        .padding()
    }

    private var rescanWithHelperButton: some View {
        VStack(spacing: 2) {
            Button {
                if helperManager.isHelperToolInstalled {
                    startHelperScan()
                } else {
                    NotificationCenter.default.post(name: .helperRequired, object: nil)
                }
            } label: {
                Label(String(localized: "Rescan with Helper"), systemImage: "lock.open")
            }
            .buttonStyle(.plain)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
        }
    }

    // MARK: Scan progress

    @ViewBuilder
    private func scanProgress(path: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Scanning \(path)"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                if let size = viewModel.rootNode?.size {
                    Text(String(localized: "Found \(formatBytes(size)) so far"))
                        .font(.system(size: 11))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }
            Spacer()
            Button {
                viewModel.cancelScan()
            } label: {
                Text(String(localized: "Cancel"))
            }
            .buttonStyle(.plain)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
        }
        .padding()
        Divider()
        if let node = viewModel.rootNode {
            chartBody(for: node)
        } else {
            Spacer()
        }
    }

    // MARK: Chart

    private var chart: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.focusedNodeID != nil {
                breadcrumb
                Divider()
            }
            if case .cancelled = viewModel.phase {
                cancelledBanner
                Divider()
            }
            if let node = viewModel.focusedNode {
                chartBody(for: node)
            } else {
                EmptyView()
            }
        }
    }

    private var cancelledBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.yellow)
            Text(String(localized: "Scan cancelled. Showing partial results."))
                .font(.system(size: 11))
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            Spacer()
            Button {
                if let target = viewModel.lastTarget {
                    viewModel.startScan(target: target, isFullDisk: viewModel.lastTargetWasFullDisk,
                                         usingHelper: viewModel.lastTargetUsedHelper, maxDepth: levels)
                }
            } label: {
                Text(String(localized: "Resume"))
            }
            .buttonStyle(.plain)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func goUpOneLevel() {
        guard let focused = viewModel.focusedNode,
              let parent = viewModel.rootNode?.parent(ofID: focused.id) else { return }
        viewModel.drillUp(to: parent)
    }

    private func chartBody(for node: SpaceLensNode) -> some View {
        Group {
            if displayMode == .treemap {
                SpaceLensTreemapView(focusedNode: node,
                                     maxDepth: levels,
                                     onDrill: { viewModel.drill(to: $0) },
                                     onTrash: { pendingTrashNode = $0 })
            } else {
                SpaceLensSunburstView(focusedNode: node,
                                      maxRings: levels,
                                      onDrill: { viewModel.drill(to: $0) },
                                      onTrash: { pendingTrashNode = $0 })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.shared(for: colorScheme).primaryBG)
    }

    private var breadcrumb: some View {
        HStack(spacing: 4) {
            if viewModel.focusedNode != nil {
                Button {
                    goUpOneLevel()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                .help(String(localized: "Go back (Backspace)"))
            }
            ForEach(Array(viewModel.breadcrumbPath().enumerated()), id: \.element.id) { index, node in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                Button {
                    viewModel.drillUp(to: node)
                } label: {
                    Text(node.name)
                        .font(.system(size: 11, weight: index == viewModel.breadcrumbPath().count - 1 ? .semibold : .regular))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if let focused = viewModel.focusedNode {
                Text(focused.url.path)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.pie")
                .font(.system(size: 42))
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            Text(String(localized: "Pick a folder to see what fills your disk."))
                .font(.system(size: 13))
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            HStack {
                Button {
                    pickFolder()
                } label: {
                    Label(String(localized: "Choose Folder"), systemImage: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                Button {
                    startFullDiskScan()
                } label: {
                    Label(String(localized: "Full Disk"), systemImage: "internaldrive")
                }
                .buttonStyle(.plain)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: Actions

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose a folder to measure")
        if panel.runModal() == .OK, let url = panel.url {
            lastPath = url.path
            viewModel.startScan(target: url, isFullDisk: false, maxDepth: levels)
        }
    }

    private func startFullDiskScan() {
        viewModel.startScan(target: URL(fileURLWithPath: "/"), isFullDisk: true, maxDepth: levels)
    }

    private func startHelperScan() {
        guard let target = viewModel.lastTarget else { return }
        viewModel.startScan(target: target, isFullDisk: viewModel.lastTargetWasFullDisk,
                             usingHelper: true, maxDepth: levels)
    }

    private func applyLevels(_ value: Int) {
        levels = value
        guard let target = viewModel.lastTarget else { return }
        viewModel.startScan(target: target, isFullDisk: viewModel.lastTargetWasFullDisk,
                             usingHelper: viewModel.lastTargetUsedHelper, maxDepth: value)
    }
}
