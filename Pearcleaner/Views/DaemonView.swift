//
//  DaemonView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 8/10/25.
//

import SwiftUI
import AlinFoundation

struct LaunchItem: Identifiable, Hashable, Equatable {
    let id = UUID()
    let label: String
    let path: String
    let domain: String // user, system, gui, etc.
    let status: String // loaded, unloaded, error
    let pid: String?
    let type: LaunchItemType
    let bundlePath: String?
    let embeddedPlistPaths: [String] // Additional embedded plist locations
    
    enum LaunchItemType: String, CaseIterable {
        case agent = "Launch Agent"
        case daemon = "Launch Daemon"
        case service = "XPC Service"
        
        var systemImage: String {
            switch self {
            case .agent: return "person.circle"
            case .daemon: return "gear.circle"
            case .service: return "network.circle"
            }
        }
    }
}

struct DaemonView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var launchItems: [LaunchItem] = []
    @State private var isLoading: Bool = false
    @State private var lastRefreshDate: Date?
    @State private var selectedFilter: LaunchItemFilter = .all
    @State private var searchText: String = ""
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    
    enum LaunchItemFilter: String, CaseIterable {
        case all = "All"
        case loaded = "Loaded"
        case unloaded = "Unloaded"
        case running = "Running"
        case agents = "Launch Agents"
        case daemons = "Launch Daemons"
        case services = "XPC Services"
        
        var systemImage: String {
            switch self {
            case .all: return "list.bullet"
            case .loaded: return "checkmark.circle"
            case .unloaded: return "xmark.circle"
            case .running: return "play.circle"
            case .agents: return "person.circle"
            case .daemons: return "gear.circle"
            case .services: return "network"
            }
        }
    }
    
    private var filteredItems: [LaunchItem] {
        var items = launchItems.filter { !$0.label.hasPrefix("com.apple.") }

        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                item.label.localizedCaseInsensitiveContains(searchText) ||
                item.path.localizedCaseInsensitiveContains(searchText) ||
                (item.bundlePath?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply type/status filter
        switch selectedFilter {
        case .all:
            return items
        case .loaded:
            return items.filter { isItemLoaded($0) }
        case .unloaded:
            return items.filter { !isItemLoaded($0) }
        case .running:
            return items.filter { isItemRunning($0) }
        case .agents:
            return items.filter { $0.type == .agent }
        case .daemons:
            return items.filter { $0.type == .daemon }
        case .services:
            return items.filter { $0.type == .service }
        }
    }
    
    private func isItemLoaded(_ item: LaunchItem) -> Bool {
        // Simple logic: if status is "Not Loaded", it's not loaded
        // If it has any other status, it was found in launchctl list and is loaded
        return item.status != "Not Loaded"
    }

    private func isItemRunning(_ item: LaunchItem) -> Bool {
        // An item is running if it's loaded AND has a PID (same logic as friendlyStatus)
        if item.status == "Not Loaded" {
            return false
        }
        
        if let statusCode = Int(item.status), statusCode == 0 {
            return item.pid != nil && item.pid != "-" && !item.pid!.isEmpty
        }
        
        return false
    }
    
    private func friendlyStatus(for item: LaunchItem) -> String {
        // Handle our custom "Not Loaded" status first
        if item.status == "Not Loaded" {
            return "Not Loaded"
        }
        
        // Check if it's a numeric status code
        if let statusCode = Int(item.status) {
            switch statusCode {
            case 0:
                // If it has a PID, it's running, otherwise it's just loaded but not active
                if item.pid != nil && item.pid != "-" && !item.pid!.isEmpty {
                    return "Running"
                } else {
                    return "Loaded"
                }
            case -1:
                return "Error (Exit -1)"
            case -2:
                return "Error (Exit -2)"
            case -3:
                return "Error (Exit -3)"
            default:
                if statusCode > 0 {
                    return "Error (Exit \(statusCode))"
                } else {
                    return "Error (\(statusCode))"
                }
            }
        }
        
        // Handle text status (shouldn't happen with new logic, but just in case)
        return item.status.capitalized
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Header with title and controls
            VStack(alignment: .leading, spacing: 15) {
                
                HStack(alignment: .center, spacing: 15) {
                    
                    VStack(alignment: .leading) {
                        Text("Launch Services Manager")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Manage launch agents, daemons, and XPC services")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    BetaBadge(fontSize: 20)

                    Spacer()
                    
                    HStack(spacing: 10) {

                        // Type/Status filter
                        Menu {
                            ForEach(LaunchItemFilter.allCases, id: \.self) { filter in
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    Label(filter.rawValue, systemImage: filter.systemImage)
                                }
                            }
                        } label: {
                            Label(selectedFilter.rawValue, systemImage: selectedFilter.systemImage)
                        }
                        .buttonStyle(ControlGroupButtonStyle(
                            foregroundColor: ThemeColors.shared(for: colorScheme).primaryText,
                            shape: Capsule(style: .continuous),
                            level: .secondary
                        ))

                        Button {
                            refreshLaunchItems()
                        } label: {
                            Label("Refresh", systemImage: isLoading ? "arrow.clockwise" : "arrow.clockwise")
                        }
                        .disabled(isLoading)
                        .buttonStyle(ControlGroupButtonStyle(
                            foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                            shape: Capsule(style: .continuous),
                            level: .secondary,
                            disabled: isLoading
                        ))
                        .help("Refresh launch services list")
                    }
                }
                
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
                .controlGroup(Capsule(style: .continuous), level: .secondary)
            }
            
            if isLoading {
                VStack(alignment: .center, spacing: 10) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading launch services...")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filteredItems.isEmpty {
                VStack(alignment: .center) {
                    Spacer()
                    Image(systemName: selectedFilter.systemImage)
                        .font(.system(size: 48))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text(launchItems.isEmpty ? "No launch services found" : "No items match the current filters")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    if !searchText.isEmpty {
                        Text("Try adjusting your search or filters")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                
                // Stats header
                HStack {
                    Text("\(filteredItems.count) service\(filteredItems.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    
                    if selectedFilter == .all && !launchItems.isEmpty {
                        let loadedCount = filteredItems.filter { isItemLoaded($0) }.count
                        let unloadedCount = filteredItems.count - loadedCount

                        Text("•")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        Text("\(loadedCount) loaded")
                            .font(.caption)
                            .foregroundStyle(.blue)

                        Text("•")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        Text("\(unloadedCount) not loaded")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Spacer()
                    
                    if let lastRefresh = lastRefreshDate {
                        Text("Updated \(formatRelativeTime(lastRefresh))")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredItems, id: \.id) { item in
                            LaunchItemRowView(item: item) {
                                refreshLaunchItems()
                            }
                        }
                    }
                }
                .scrollIndicators(scrollIndicators ? .automatic : .never)
            }
            
//            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .onAppear {
            if launchItems.isEmpty {
                refreshLaunchItems()
            }
        }
    }
    
    private func refreshLaunchItems() {
        isLoading = true
        
        Task {
            let items = await loadLaunchItems()
            
            await MainActor.run {
                self.launchItems = items.sorted { first, second in
                    return first.label.localizedCaseInsensitiveCompare(second.label) == .orderedAscending
                }
                self.lastRefreshDate = Date()
                self.isLoading = false
            }
        }
    }
    
    private func loadLaunchItems() async -> [LaunchItem] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var items: [LaunchItem] = []
                
                // First, get runtime status from launchctl list
                let runtimeStatus = self.getRuntimeStatus()
                
                // First pass: collect all embedded plist locations
                let embeddedPlists = self.collectEmbeddedPlists()
                
                // Scan directories for plist files in priority order
                items.append(contentsOf: self.scanLaunchAgents(runtimeStatus: runtimeStatus, embeddedPlists: embeddedPlists))
                items.append(contentsOf: self.scanLaunchDaemons(runtimeStatus: runtimeStatus, embeddedPlists: embeddedPlists))
                
                // Scan app bundles, but skip any labels we've already found
                items.append(contentsOf: self.scanAppBundles(runtimeStatus: runtimeStatus, existingItems: items))
                
                // Add any services found in launchctl but missing plist files
                items.append(contentsOf: self.addMissingRuntimeServices(runtimeStatus: runtimeStatus, existingItems: items))
                
                continuation.resume(returning: items)
            }
        }
    }
    
    private func collectEmbeddedPlists() -> [String: [String]] {
        var embeddedPlists: [String: [String]] = [:]
        let fileManager = FileManager.default
        
        let appPaths = [
            "/Applications",
            "/System/Applications", 
            "/System/Applications/Utilities",
            "~/Applications"
        ]
        
        for basePath in appPaths {
            let expandedPath = NSString(string: basePath).expandingTildeInPath
            guard let apps = try? fileManager.contentsOfDirectory(atPath: expandedPath) else { continue }
            
            for app in apps where app.hasSuffix(".app") {
                let appPath = "\(expandedPath)/\(app)"
                
                let possiblePaths = [
                    "\(appPath)/Contents/Library/LaunchAgents",
                    "\(appPath)/Contents/Library/LaunchDaemons",
                    "\(appPath)/Contents/Resources/LaunchAgents",
                    "\(appPath)/Contents/Resources/LaunchDaemons",
                    "\(appPath)/Contents/XPCServices",
                    "\(appPath)/Contents/Helpers",
                    "\(appPath)/Contents/MacOS"
                ]
                
                for plistPath in possiblePaths {
                    guard let plistFiles = try? fileManager.contentsOfDirectory(atPath: plistPath) else { continue }
                    
                    for filename in plistFiles where filename.hasSuffix(".plist") {
                        let fullPath = "\(plistPath)/\(filename)"
                        let actualLabel = readLabelFromPlist(path: fullPath)
                        let fallbackLabel = String(filename.dropLast(6))
                        let label = actualLabel ?? fallbackLabel
                        
                        if embeddedPlists[label] == nil {
                            embeddedPlists[label] = []
                        }
                        embeddedPlists[label]?.append(fullPath)
                    }
                }
            }
        }
        
        return embeddedPlists
    }
    
    private func scanLaunchAgents(runtimeStatus: [String: (pid: String?, status: String, isLoaded: Bool)], embeddedPlists: [String: [String]]) -> [LaunchItem] {
        let agentPaths = [
            "~/Library/LaunchAgents",
            "/Library/LaunchAgents",
            "/System/Library/LaunchAgents"
        ]
        
        return scanPlistDirectory(paths: agentPaths, type: .agent, runtimeStatus: runtimeStatus, embeddedPlists: embeddedPlists)
    }
    
    private func scanLaunchDaemons(runtimeStatus: [String: (pid: String?, status: String, isLoaded: Bool)], embeddedPlists: [String: [String]]) -> [LaunchItem] {
        let daemonPaths = [
            "/Library/LaunchDaemons",
            "/System/Library/LaunchDaemons"
        ]
        
        return scanPlistDirectory(paths: daemonPaths, type: .daemon, runtimeStatus: runtimeStatus, embeddedPlists: embeddedPlists)
    }
    
    private func scanPlistDirectory(paths: [String], type: LaunchItem.LaunchItemType, runtimeStatus: [String: (pid: String?, status: String, isLoaded: Bool)], embeddedPlists: [String: [String]]) -> [LaunchItem] {
        var items: [LaunchItem] = []
        let fileManager = FileManager.default
        
        for path in paths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            
            guard let contents = try? fileManager.contentsOfDirectory(atPath: expandedPath) else { 
                continue
            }
            
            for filename in contents where filename.hasSuffix(".plist") {
                let fullPath = "\(expandedPath)/\(filename)"
                
                // Read the actual Label from the plist file instead of using filename
                let actualLabel = readLabelFromPlist(path: fullPath)
                let fallbackLabel = String(filename.dropLast(6))
                let label = actualLabel ?? fallbackLabel
                
                // Get runtime status
                let runtime = runtimeStatus[label]
                let isLoaded = runtime?.isLoaded ?? false
                let status = runtime?.status ?? "0"
                let pid = runtime?.pid
                
                // Determine domain
                let domain = determineDomainFromPath(expandedPath)
                
                // Create custom status based on loaded state
                let displayStatus = isLoaded ? status : "Not Loaded"
                
                // Get embedded plist paths for this label
                let embeddedPaths = embeddedPlists[label] ?? []
                
                let item = LaunchItem(
                    label: label,
                    path: fullPath,
                    domain: domain,
                    status: displayStatus,
                    pid: pid,
                    type: type,
                    bundlePath: nil,
                    embeddedPlistPaths: embeddedPaths
                )
                
                items.append(item)
            }
        }
        
        return items
    }
    
    private func readLabelFromPlist(path: String) -> String? {
        guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let label = plist["Label"] as? String else {
            return nil
        }
        return label
    }
    
    private func determineDomainFromPath(_ path: String) -> String {
        if path.contains("/System/") {
            return "system"
        } else if path.contains("~/Library/") || path.contains("/Users/") {
            return "user"
        } else {
            return "global"
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func addMissingRuntimeServices(runtimeStatus: [String: (pid: String?, status: String, isLoaded: Bool)], existingItems: [LaunchItem]) -> [LaunchItem] {
        var items: [LaunchItem] = []
        let existingLabels = Set(existingItems.map { $0.label })
        
        // Find services in runtime status that don't have plist files
        for (label, runtime) in runtimeStatus {
            // Skip if we already found this service via plist scanning
            if existingLabels.contains(label) { continue }
            
            // Only include non-Apple services (to match our filtering)
            if label.hasPrefix("com.apple.") { continue }
            
            // Skip system application instances (these are temporary)
            if label.hasPrefix("application.") { continue }

            // Determine type based on label patterns
            let type: LaunchItem.LaunchItemType
            if label.contains(".helper") || label.contains(".daemon") {
                type = .daemon
            } else if label.contains(".xpc") || label.contains("Service") {
                type = .service
            } else {
                type = .agent
            }
            
            // Determine domain - check if it was found in system vs user context
            let domain = determineRuntimeDomain(for: label, type: type)
            
            // Determine path description - all runtime-only services get the same description
            let pathDescription = "Runtime Only"

            let item = LaunchItem(
                label: label,
                path: pathDescription,
                domain: domain,
                status: runtime.status,
                pid: runtime.pid,
                type: type,
                bundlePath: nil,
                embeddedPlistPaths: []
            )

            items.append(item)
        }
        
        return items
    }

    private func determineRuntimeDomain(for label: String, type: LaunchItem.LaunchItemType) -> String {
        if label.hasPrefix("com.apple.") {
            return "system"
        } else if label.hasPrefix("application.") {
            return "system"
        } else if label.hasPrefix("~/Library/") || label.hasPrefix("/Users/") {
            return "user"
        } else {
            return "global"
        }
    }

    private func getRuntimeStatus() -> [String: (pid: String?, status: String, isLoaded: Bool)] {
        var statusMap: [String: (pid: String?, status: String, isLoaded: Bool)] = [:]
        
        // Get user context services
        let userResult = runDirectShellCommand(command: "launchctl list")
        if userResult.0 {
            parseStatusOutput(userResult.1, into: &statusMap, context: "user")
        }
        
        // Get system context services (requires sudo for full access)
        let systemResult = runDirectShellCommand(command: "sudo launchctl list")
        if systemResult.0 {
            parseStatusOutput(systemResult.1, into: &statusMap, context: "system")
        }
        
        return statusMap
    }
    
    private func parseStatusOutput(_ output: String, into statusMap: inout [String: (pid: String?, status: String, isLoaded: Bool)], context: String) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("PID") { continue }
            
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 3 else { continue }
            
            let pid = components[0] == "-" ? nil : components[0]
            let status = components[1]
            let label = components[2]
            
            // If it appears in launchctl list, it's loaded (regardless of status code)
            statusMap[label] = (pid: pid, status: status, isLoaded: true)
        }
    }

    private func scanAppBundles(runtimeStatus: [String: (pid: String?, status: String, isLoaded: Bool)], existingItems: [LaunchItem]) -> [LaunchItem] {
        var items: [LaunchItem] = []
        let fileManager = FileManager.default
        let existingLabels = Set(existingItems.map { $0.label })
        
        let appPaths = [
            "/Applications",
            "/System/Applications", 
            "/System/Applications/Utilities",
            "~/Applications"
        ]
        
        for basePath in appPaths {
            let expandedPath = NSString(string: basePath).expandingTildeInPath
            guard let apps = try? fileManager.contentsOfDirectory(atPath: expandedPath) else { continue }
            
            for app in apps where app.hasSuffix(".app") {
                let appPath = "\(expandedPath)/\(app)"
                
                // Check multiple possible locations within app bundles
                let possiblePaths = [
                    "\(appPath)/Contents/Library/LaunchAgents",
                    "\(appPath)/Contents/Library/LaunchDaemons",
                    "\(appPath)/Contents/Resources/LaunchAgents",
                    "\(appPath)/Contents/Resources/LaunchDaemons",
                    "\(appPath)/Contents/XPCServices",
                    "\(appPath)/Contents/Helpers",
                    "\(appPath)/Contents/MacOS"
                ]
                
                for plistPath in possiblePaths {
                    guard let plistFiles = try? fileManager.contentsOfDirectory(atPath: plistPath) else { continue }
                    
                    for filename in plistFiles where filename.hasSuffix(".plist") {
                        let fullPath = "\(plistPath)/\(filename)"
                        
                        // Read the actual Label from the plist file instead of using filename
                        let actualLabel = readLabelFromPlist(path: fullPath)
                        let fallbackLabel = String(filename.dropLast(6))
                        let label = actualLabel ?? fallbackLabel
                        
                        // Skip this embedded plist if we already have an item with the same label
                        // This prioritizes system-installed plists over embedded ones
                        if existingLabels.contains(label) {
                            continue
                        }
                        
                        let runtime = runtimeStatus[label]
                        let isLoaded = runtime?.isLoaded ?? false
                        let status = runtime?.status ?? "0"
                        let pid = runtime?.pid
                        
                        // Determine type based on path
                        let type: LaunchItem.LaunchItemType
                        if plistPath.contains("LaunchAgents") {
                            type = .agent
                        } else if plistPath.contains("LaunchDaemons") {
                            type = .daemon
                        } else {
                            type = .service
                        }
                        
                        let displayStatus = isLoaded ? status : "Not Loaded"
                        
                        let item = LaunchItem(
                            label: label,
                            path: fullPath,
                            domain: type == .daemon ? "global" : "user",
                            status: displayStatus,
                            pid: pid,
                            type: type,
                            bundlePath: appPath,
                            embeddedPlistPaths: []
                        )
                        
                        items.append(item)
                    }
                }
            }
        }
        
        return items
    }
}

struct LaunchItemRowView: View {
    @Environment(\.colorScheme) var colorScheme
    let item: LaunchItem
    let onUpdate: () -> Void
    @State private var isPerformingAction = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack(alignment: .top, spacing: 12) {
                
                // Type icon and status indicator
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(typeColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: item.type.systemImage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(typeColor)
                    }
                    
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                }
                
                // Main content
                VStack(alignment: .leading, spacing: 6) {
                    
                    // Service name and type
                    HStack(alignment: .center) {
                        Text(item.label)
                            .font(.headline)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .lineLimit(1)
                        

                        Text(item.type.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(typeColor.opacity(0.2))
                            .foregroundStyle(typeColor)
                            .cornerRadius(4)

                        Spacer()

                    }
                    
                    // Status and PID
                    HStack {
                        HStack(spacing: 4) {
                            Text("Status:")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            
                            Text(friendlyStatus(for: item))
                                .font(.caption)
                                .foregroundStyle(statusColor)
                        }
                        
                        if let pid = item.pid {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            
                            Text("PID: \(pid)")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                        
                        Spacer()
                    }
                    
                    // Path information
                    if !item.path.isEmpty && item.path != "Not found" {
                        HStack(alignment: .center, spacing: 8) {
                            
                            Button {
                                if let bundlePath = item.bundlePath {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: bundlePath))
                                } else {
                                    let path = URL(fileURLWithPath: item.path)
                                    NSWorkspace.shared.selectFile(path.path, inFileViewerRootedAtPath: path.deletingLastPathComponent().path)
                                }
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                            .help("Open in Finder")
                            
                            VStack(alignment: .leading, spacing: 2) {
                                if let bundlePath = item.bundlePath {
                                    Text("Bundle: \(bundlePath)")
                                        .font(.caption)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                
                                Text("Plist: \(item.path)")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                // Show additional embedded plist locations if they exist
                                if !item.embeddedPlistPaths.isEmpty {
                                    ForEach(Array(item.embeddedPlistPaths.enumerated()), id: \.offset) { index, embeddedPath in
                                        HStack {
                                            Image(systemName: "doc.badge.plus")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                            Text("Also in: \(embeddedPath)")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                // Action buttons
                VStack(spacing: 6) {
                    
                    HStack(spacing: 6) {
                        
                        if isLoaded {
                            Button("Stop") {
                                performLaunchctlAction("unload", showConfirmation: true)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                            .foregroundStyle(.orange)
                            .disabled(isPerformingAction)
                            .help("Unload the service")
                            
                            Button("Restart") {
                                performLaunchctlAction("kickstart", showConfirmation: false)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                            .foregroundStyle(.blue)
                            .disabled(isPerformingAction)
                            .help("Restart the service")
                            
                        } else {
                            Button("Start") {
                                performLaunchctlAction("load", showConfirmation: false)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                            .foregroundStyle(.green)
                            .disabled(isPerformingAction)
                            .help("Load the service")
                        }
                        
                        Button("Remove") {
                            performLaunchctlAction("remove", showConfirmation: true)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .foregroundStyle(.red)
                        .disabled(isPerformingAction)
                        .help("Remove the service registration")
                    }
                    
                    if isPerformingAction {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
        }
        .padding()
        .background(ThemeColors.shared(for: colorScheme).secondaryBG.clipShape(RoundedRectangle(cornerRadius: 8)))
    }
    
    private var isLoaded: Bool {
        // Simple logic: if status is "Not Loaded", it's not loaded
        // If it has any other status, it was found in launchctl list and is loaded
        return item.status != "Not Loaded"
    }

    private var statusColor: Color {
        if item.status.lowercased().contains("error") || (item.status != "Not Loaded" && item.status != "0" && Int(item.status) != nil && Int(item.status)! != 0) {
            return .red
        } else if item.pid != nil && item.pid != "-" && !item.pid!.isEmpty {
            return .green  // Actually running (has PID)
        } else if isLoaded {
            return .blue   // Loaded but not running
        } else {
            return .orange // Not loaded
        }
    }

    private var typeColor: Color {
        switch item.type {
        case .agent: return .blue
        case .daemon: return .purple
        case .service: return .teal
        }
    }
    
    private func friendlyStatus(for item: LaunchItem) -> String {
        // Handle our custom "Not Loaded" status first
        if item.status == "Not Loaded" {
            return "Not Loaded"
        }

        // Check if it's a numeric status code
        if let statusCode = Int(item.status) {
            switch statusCode {
            case 0:
                // If it has a PID, it's running, otherwise it's just loaded but not active
                if item.pid != nil && item.pid != "-" && !item.pid!.isEmpty {
                    return "Running"
                } else {
                    return "Loaded"
                }
            case -1:
                return "Error (Exit -1)"
            case -2:
                return "Error (Exit -2)"
            case -3:
                return "Error (Exit -3)"
            default:
                if statusCode > 0 {
                    return "Error (Exit \(statusCode))"
                } else {
                    return "Error (\(statusCode))"
                }
            }
        }

        // Handle text status (shouldn't happen with new logic, but just in case)
        return item.status.capitalized
    }

    private func performLaunchctlAction(_ action: String, showConfirmation: Bool) {
        let actionText = action.capitalized
        let message = "Are you sure you want to \(action) '\(item.label)'?"
        
        if showConfirmation {
            showCustomAlert(
                title: "Confirm \(actionText)",
                message: message,
                style: .warning,
                onOk: {
                    executeLaunchctlCommand(action)
                }
            )
        } else {
            executeLaunchctlCommand(action)
        }
    }
    
    private func executeLaunchctlCommand(_ action: String) {
        isPerformingAction = true

        Task {
            let needsSudo = isDaemonOrSystemService()
            let command: String
            let domain = item.domain == "user" ? "gui/\(getuid())" : "system"

            // Build the appropriate command based on action and privilege needs
            switch action {
            case "load":
                if !item.path.isEmpty && item.path != "Not found" {
                    command = needsSudo ? "sudo launchctl load '\(item.path)'" : "launchctl load '\(item.path)'"
                } else {
                    command = needsSudo ? "sudo launchctl enable \(domain)/\(item.label)" : "launchctl enable \(domain)/\(item.label)"
                }
            case "unload":
                if !item.path.isEmpty && item.path != "Not found" {
                    command = needsSudo ? "sudo launchctl unload '\(item.path)'" : "launchctl unload '\(item.path)'"
                } else {
                    command = needsSudo ? "sudo launchctl disable \(domain)/\(item.label)" : "launchctl disable \(domain)/\(item.label)"
                }
            case "kickstart":
                command = needsSudo ? "sudo launchctl kickstart -k \(domain)/\(item.label)" : "launchctl kickstart -k \(domain)/\(item.label)"
            case "remove":
                command = needsSudo ? "sudo launchctl remove \(item.label)" : "launchctl remove \(item.label)"
            default:
                await MainActor.run {
                    isPerformingAction = false
                }
                return
            }

            var success = false
            var output = ""

            // Execute command based on privilege requirements
            if needsSudo {
                // Use privileged command execution for daemons/system services
                if HelperToolManager.shared.isHelperToolInstalled {
                    let result = await HelperToolManager.shared.runCommand(command)
                    success = result.0
                    output = result.1
                } else {
                    let result = await Task.detached {
                        return performPrivilegedCommands(commands: command)
                    }.value
                    success = result.0
                    output = result.1
                    if !success {
                        printOS("Privileged launch command failed: \(output)")
                    }
                }
            } else {
                // Use direct shell command for user agents
                let result = await Task.detached {
                    return runDirectShellCommand(command: command)
                }.value
                success = result.0
                output = result.1
                if !success {
                    printOS("User launch command failed: \(output)")
                }
            }

            await MainActor.run {
                isPerformingAction = false

                if success {
                    printOS("Successfully executed: \(command)")
                    // Success - refresh the list after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onUpdate()
                    }
                } else {
                    // Show error
                    showCustomAlert(
                        title: "Action Failed",
                        message: "Failed to \(action) '\(item.label)':\n\(output)",
                        style: .critical
                    )
                }
            }
        }
    }

    private func isDaemonOrSystemService() -> Bool {
        // Check if it's a daemon type
        if item.type == .daemon {
            return true
        }

        // Check if path contains daemon directories
        if item.path.contains("/LaunchDaemons/") ||
            item.path.contains("/System/") ||
            item.label.hasPrefix("com.apple.") {
            return true
        }

        // Check if it's a system domain service
        if item.domain == "system" || item.domain == "global" {
            return true
        }

        return false
    }
}

// Helper function to run shell commands (similar to the one in UndoManager.swift)
private func runDirectShellCommand(command: String) -> (Bool, String) {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", command]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    
    task.launch()
    task.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    
    return (task.terminationStatus == 0, output)
}

