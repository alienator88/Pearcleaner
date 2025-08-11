//
//  PackageView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 8/10/25.
//

import SwiftUI
import AlinFoundation

enum PackageSortOption: String, CaseIterable {
    case packageName = "Package Name"
    case packageId = "Package ID"
    
    var displayName: String {
        return self.rawValue
    }
}

struct PackageInfo: Identifiable, Hashable, Equatable {
    let id = UUID()
    let packageId: String
    let packageName: String
    let packageFileName: String // New field for the actual package file name
    let version: String
    let installDate: String
    let installProcessName: String // New field for the process that installed it
    var bomFiles: [String] // Made var for lazy loading
    let receiptPath: String
    let installLocation: String
    var bomFilesLoaded: Bool = false // Track if BOM files have been loaded
    
    // Computed property for display name - prefer package file name over package name
    var displayName: String {
        if !packageFileName.isEmpty {
            // Remove .pkg extension for cleaner display
            let name = packageFileName.hasSuffix(".pkg") ? String(packageFileName.dropLast(4)) : packageFileName
            return name
        } else if !packageName.isEmpty {
            return packageName
        } else {
            return packageId
        }
    }
}

struct PackageView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var packages: [PackageInfo] = []
    @State private var packageIds: [String] = [] // Add this to store package IDs
    @State private var isLoading: Bool = false
    @State private var lastRefreshDate: Date?
    @State private var searchText: String = ""
    @State private var expandedPackages: Set<String> = []
    @State private var sortOption: PackageSortOption = .packageId
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.general.permanentDelete") private var permanentDelete: Bool = false

    private var filteredPackages: [PackageInfo] {
        var packages = self.packages.filter { !$0.packageId.hasPrefix("com.apple.") } // Only user-installed packages

        // Apply search filter
        if !searchText.isEmpty {
            packages = packages.filter { package in
                package.displayName.localizedCaseInsensitiveContains(searchText) ||
                package.packageId.localizedCaseInsensitiveContains(searchText) ||
                package.version.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply sorting
        switch sortOption {
        case .packageName:
            packages = packages.sorted { first, second in
                return first.displayName.localizedCaseInsensitiveCompare(second.displayName) == .orderedAscending
            }
        case .packageId:
            packages = packages.sorted { first, second in
                return first.packageId.localizedCaseInsensitiveCompare(second.packageId) == .orderedAscending
            }
        }

        return packages
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Header with title and controls
            VStack(alignment: .leading, spacing: 15) {
                
                HStack(alignment: .center, spacing: 15) {
                    
                    VStack(alignment: .leading) {
                        Text("Package Manager")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Manage packages installed via macOS Installer")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    BetaBadge(fontSize: 20)

                    Spacer()
                    
                    // Sort menu button
                    Menu {
                        ForEach(PackageSortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                Label(option.displayName, systemImage: "list.bullet")
                            }
                        }
                    } label: {
                        Label(sortOption.displayName, systemImage: "list.bullet")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    .controlSize(.small)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .controlGroup(Capsule(style: .continuous), level: .secondary)
                    .help("Sort packages")
                    
                    Button {
                        refreshPackages()
                    } label: {
                        Label("Refresh", systemImage: isLoading ? "arrow.clockwise" : "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .buttonStyle(.plain)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                    .controlSize(.small)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .controlGroup(Capsule(style: .continuous), level: .secondary)
                    .help("Refresh package list")
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    
                    TextField("Search packages...", text: $searchText)
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

            if isLoading && packages.isEmpty {
                VStack(alignment: .center, spacing: 10) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading packages...")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if packageIds.isEmpty && !isLoading {
                VStack(alignment: .center) {
                    Spacer()
                    Text("No packages found")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                
                // Stats header
                HStack {
                    Text("\(filteredPackages.count) package\(filteredPackages.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    
                    if isLoading {
                        Text("• Loading...")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
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
                        ForEach(filteredPackages, id: \.id) { package in
                            PackageRowView(
                                package: package,
                                isExpanded: expandedPackages.contains(package.packageId),
                                permanentDelete: permanentDelete,
                                sortOption: sortOption
                            ) {
                                toggleExpansion(for: package.packageId)
                            } onRemove: {
                                removePackage(package)
                            } onRefresh: {
                                refreshPackages()
                            }
                        }
                    }
                }
                .scrollIndicators(scrollIndicators ? .automatic : .never)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .onAppear {
            if packages.isEmpty {
                refreshPackages()
            }
        }
    }
    
    private func toggleExpansion(for packageId: String) {
        if expandedPackages.contains(packageId) {
            expandedPackages.remove(packageId)
        } else {
            expandedPackages.insert(packageId)
            // Load BOM files when expanding for the first time
            loadBOMFilesIfNeeded(for: packageId)
        }
    }
    
    private func loadBOMFilesIfNeeded(for packageId: String) {
        // Find the package and check if BOM files are already loaded
        guard let packageIndex = packages.firstIndex(where: { $0.packageId == packageId }),
              !packages[packageIndex].bomFilesLoaded else {
            return
        }
        
        Task {
            let bomFiles = await loadBOMFiles(for: packageId)
            
            await MainActor.run {
                if packageIndex < packages.count {
                    packages[packageIndex].bomFiles = bomFiles
                    packages[packageIndex].bomFilesLoaded = true
                }
            }
        }
    }
    
    private func loadBOMFiles(for packageId: String) async -> [String] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Use pkgutil --files to get just the file paths
                let filesResult = runDirectShellCommand(command: "pkgutil --files \"\(packageId)\"")
                
                if filesResult.0 {
                    let allFiles = filesResult.1.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    
                    // Get the package install location to construct proper absolute paths
                    var installLocation = "/"
                    
                    // First try to get from receipt plist
                    let receiptPath = "/var/db/receipts/\(packageId).plist"
                    let defaultsResult = runDirectShellCommand(command: "defaults read \"\(receiptPath)\"")
                    if defaultsResult.0 {
                        let lines = defaultsResult.1.components(separatedBy: .newlines)
                        for line in lines {
                            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmedLine.contains("InstallPrefixPath = ") {
                                if let startQuote = trimmedLine.firstIndex(of: "\""),
                                   let endQuote = trimmedLine.lastIndex(of: "\""),
                                   startQuote != endQuote {
                                    let location = String(trimmedLine[trimmedLine.index(after: startQuote)..<endQuote])
                                    installLocation = location.isEmpty ? "/" : location
                                    break
                                }
                            }
                        }
                    }
                    
                    // Fallback to pkgutil --pkg-info if needed
                    if installLocation == "/" {
                        let infoResult = runDirectShellCommand(command: "pkgutil --pkg-info \"\(packageId)\"")
                        if infoResult.0 {
                            let lines = infoResult.1.components(separatedBy: .newlines)
                            for line in lines {
                                if line.hasPrefix("location: ") {
                                    let location = String(line.dropFirst("location: ".count))
                                    installLocation = location.isEmpty ? "/" : location
                                    break
                                }
                            }
                        }
                    }
                    
                    // Special handling for apps that should go in /Applications
                    // If we find .app files and install location is "/", try /Applications
                    let hasAppFiles = allFiles.contains { $0.hasSuffix(".app") }
                    if hasAppFiles && installLocation == "/" {
                        // Check if the app exists in /Applications
                        for file in allFiles {
                            if file.hasSuffix(".app") {
                                let appPath = "/Applications/\(file)"
                                if FileManager.default.fileExists(atPath: appPath) {
                                    installLocation = "/Applications"
                                    break
                                }
                            }
                        }
                    }

                    // Ensure install location is absolute
                    if !installLocation.hasPrefix("/") {
                        installLocation = "/" + installLocation
                    }
                    
                    // Simple filtering - only remove Apple resource fork files
                    let filteredFiles = allFiles.compactMap { file -> String? in
                        let trimmedFile = file.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Skip Apple resource fork files (._filename) 
                        if trimmedFile.contains("._") {
                            return nil
                        }
                        
                        // Construct proper absolute path using install location
                        var absolutePath: String
                        if trimmedFile.hasPrefix("/") {
                            // File path is already absolute
                            absolutePath = trimmedFile
                        } else {
                            // File path is relative, combine with install location
                            if installLocation == "/" {
                                absolutePath = "/" + trimmedFile
                            } else {
                                absolutePath = installLocation + "/" + trimmedFile
                            }
                        }
                        
                        return absolutePath
                    }
                    
                    // Second pass: Filter out app bundle internals, keep only top-level .app paths
                    let finalFilteredFiles = filterAppBundleInternals(filteredFiles)
                    
                    continuation.resume(returning: finalFilteredFiles)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private func refreshPackages() {
        isLoading = true
        packages = []
        packageIds = []
        
        Task {
            // First, quickly get the list of package IDs
            let ids = await loadPackageIds()
            
            await MainActor.run {
                self.packageIds = ids
                self.lastRefreshDate = Date()
            }
            
            // Then load each package's details progressively
            await loadPackageDetailsProgressively(for: ids)
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadPackageIds() async -> [String] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let receiptsResult = runDirectShellCommand(command: "pkgutil --pkgs")
                if receiptsResult.0 {
                    let packageIds = receiptsResult.1.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    continuation.resume(returning: packageIds)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func loadPackageDetailsProgressively(for packageIds: [String]) async {
        // Load packages in batches to avoid overwhelming the UI
        let batchSize = 3
        
        for i in stride(from: 0, to: packageIds.count, by: batchSize) {
            let endIndex = min(i + batchSize, packageIds.count)
            let batch = Array(packageIds[i..<endIndex])
            
            // Load batch concurrently
            await withTaskGroup(of: PackageInfo?.self) { group in
                for packageId in batch {
                    group.addTask {
                        return await self.loadPackageInfo(for: packageId)
                    }
                }
                
                var batchPackages: [PackageInfo] = []
                for await packageInfo in group {
                    if let packageInfo = packageInfo {
                        batchPackages.append(packageInfo)
                    }
                }
                
                // Update UI with this batch
                await MainActor.run {
                    self.packages.append(contentsOf: batchPackages)
                }
            }
            
            // Small delay between batches to keep UI responsive
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }
    
    private func loadPackageInfo(for packageId: String) async -> PackageInfo? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let packageInfo = self.getPackageInfo(for: packageId)
                continuation.resume(returning: packageInfo)
            }
        }
    }
    
    private func getPackageInfo(for packageId: String) -> PackageInfo? {
        // First try to get rich info from receipt plist using defaults read
        let receiptPath = "/var/db/receipts/\(packageId).plist"
        let defaultsResult = runDirectShellCommand(command: "defaults read \"\(receiptPath)\"")
        
        let packageName = ""
        var packageFileName = ""
        var version = ""
        var installDate = ""
        var installLocation = ""
        var installProcessName = ""
        
        if defaultsResult.0 {
            // Parse the defaults output
            let lines = defaultsResult.1.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmedLine.contains("InstallDate = ") {
                    // Extract date between quotes
                    if let startQuote = trimmedLine.firstIndex(of: "\""),
                       let endQuote = trimmedLine.lastIndex(of: "\""),
                       startQuote != endQuote {
                        installDate = String(trimmedLine[trimmedLine.index(after: startQuote)..<endQuote])
                    }
                } else if trimmedLine.contains("PackageFileName = ") {
                    // Extract package filename between quotes
                    if let startQuote = trimmedLine.firstIndex(of: "\""),
                       let endQuote = trimmedLine.lastIndex(of: "\""),
                       startQuote != endQuote {
                        packageFileName = String(trimmedLine[trimmedLine.index(after: startQuote)..<endQuote])
                    }
                } else if trimmedLine.contains("PackageVersion = ") {
                    // Extract version between quotes
                    if let startQuote = trimmedLine.firstIndex(of: "\""),
                       let endQuote = trimmedLine.lastIndex(of: "\""),
                       startQuote != endQuote {
                        version = String(trimmedLine[trimmedLine.index(after: startQuote)..<endQuote])
                    }
                } else if trimmedLine.contains("InstallPrefixPath = ") {
                    // Extract install location between quotes
                    if let startQuote = trimmedLine.firstIndex(of: "\""),
                       let endQuote = trimmedLine.lastIndex(of: "\""),
                       startQuote != endQuote {
                        installLocation = String(trimmedLine[trimmedLine.index(after: startQuote)..<endQuote])
                    }
                } else if trimmedLine.contains("InstallProcessName = ") {
                    // Extract process name - might not have quotes
                    if trimmedLine.contains("\"") {
                        if let startQuote = trimmedLine.firstIndex(of: "\""),
                           let endQuote = trimmedLine.lastIndex(of: "\""),
                           startQuote != endQuote {
                            installProcessName = String(trimmedLine[trimmedLine.index(after: startQuote)..<endQuote])
                        }
                    } else {
                        // No quotes, extract after = and before ;
                        let parts = trimmedLine.components(separatedBy: " = ")
                        if parts.count > 1 {
                            let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "; "))
                            installProcessName = value
                        }
                    }
                }
            }
        }
        
        // If defaults read failed or didn't give us enough info, fall back to pkgutil
        if version.isEmpty || installDate.isEmpty {
            let infoResult = runDirectShellCommand(command: "pkgutil --pkg-info \"\(packageId)\"")
            if infoResult.0 {
                let lines = infoResult.1.components(separatedBy: .newlines)
                for line in lines {
                    if version.isEmpty && line.hasPrefix("version: ") {
                        version = String(line.dropFirst("version: ".count))
                    } else if installDate.isEmpty && line.hasPrefix("install-time: ") {
                        installDate = String(line.dropFirst("install-time: ".count))
                    } else if installLocation.isEmpty && line.hasPrefix("location: ") {
                        installLocation = String(line.dropFirst("location: ".count))
                    }
                }
            }
        }
        
        // Don't load BOM files upfront - load them on demand when package is expanded
        let bomFiles: [String] = []
        
        return PackageInfo(
            packageId: packageId,
            packageName: packageName,
            packageFileName: packageFileName,
            version: version,
            installDate: installDate,
            installProcessName: installProcessName,
            bomFiles: bomFiles,
            receiptPath: receiptPath,
            installLocation: installLocation.isEmpty ? "/" : installLocation,
            bomFilesLoaded: false
        )
    }
    
    private func removePackage(_ package: PackageInfo) {
        showCustomAlert(
            title: "Forget Package",
            message: "Are you sure you want to forget package '\(package.displayName)'? This will remove the package from the system's records but will not delete any files. Use the Apps tab to remove the actual app if needed.",
            style: .warning,
            onOk: {
                Task {
                    await performPackageRemoval(package)
                }
            }
        )
    }

    private func performPackageRemoval(_ package: PackageInfo) async {
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                
                // Check if app bundle still exists in common locations
                let appBundleName = self.extractAppBundleName(from: package.bomFiles)
                if let bundleName = appBundleName {
                    let commonAppPaths = [
                        "/Applications/\(bundleName)",
                        "/System/Applications/\(bundleName)",
                        "~/Applications/\(bundleName)".expandingTildeInPath
                    ]
                    
                    for appPath in commonAppPaths {
                        if FileManager.default.fileExists(atPath: appPath) {
                            DispatchQueue.main.async {
                                showCustomAlert(
                                    title: "App Bundle Still Exists",
                                    message: "The app '\(bundleName)' still exists in \(appPath). Please use the Apps tab to fully remove the app and its related files first, then return here to forget the package.",
                                    style: .warning
                                )
                            }
                            continuation.resume(returning: false)
                            return
                        }
                    }
                }
                
                // Use pkgutil --forget to remove the package from the system
                let forgetCommand = "pkgutil --forget \"\(package.packageId)\""
                
                var success = false
                
                // Use privileged command execution since receipts are in protected locations
                if HelperToolManager.shared.isHelperToolInstalled {
                    let semaphore = DispatchSemaphore(value: 0)
                    Task {
                        let result = await HelperToolManager.shared.runCommand(forgetCommand)
                        success = result.0
                        if !success {
                            printOS("Package forget failed: \(result.1)")
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()
                } else {
                    let result = performPrivilegedCommands(commands: forgetCommand)
                    success = result.0
                    if !success {
                        printOS("Package forget failed: \(result.1)")
                    }
                }
                
                continuation.resume(returning: success)
            }
        }
        
        await MainActor.run {
            if success {
                // Refresh the list
                refreshPackages()
            } else {
                showCustomAlert(
                    title: "Forget Failed",
                    message: "Failed to forget package '\(package.displayName)'. The package may require additional permissions or may not exist.",
                    style: .critical
                )
            }
        }
    }
    
    private func extractAppBundleName(from bomFiles: [String]) -> String? {
        // Look for .app bundle in the BOM files
        for file in bomFiles {
            if file.contains(".app/") {
                let components = file.components(separatedBy: "/")
                for component in components {
                    if component.hasSuffix(".app") {
                        return component
                    }
                }
            }
        }
        return nil
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

}

// Add a placeholder row for packages still loading
struct PackagePlaceholderRowView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Package icon placeholder
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    
                    Circle()
                        .fill(.gray)
                        .frame(width: 8, height: 8)
                }
                
                // Package details placeholder
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 20)
                            .frame(maxWidth: 200)
                        
                        Spacer()
                    }
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                        .frame(maxWidth: 150)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                        .frame(maxWidth: 100)
                }
                
                // Action buttons placeholder
                VStack(spacing: 6) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 24)
                }
            }
        }
        .padding()
        .background(ThemeColors.shared(for: colorScheme).secondaryBG.clipShape(RoundedRectangle(cornerRadius: 8)))
        .redacted(reason: .placeholder)
    }
}

struct PackageRowView: View {
    @Environment(\.colorScheme) var colorScheme
    let package: PackageInfo
    let isExpanded: Bool
    let permanentDelete: Bool
    let sortOption: PackageSortOption // Add sort option parameter
    let onToggleExpansion: () -> Void
    let onRemove: () -> Void
    let onRefresh: () -> Void
    @State private var isPerformingAction = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Main package info row
            HStack(alignment: .top, spacing: 12) {
                
                // Package icon and type indicator
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(packageColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(packageColor)
                    }
                    
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                }
                
                // Package details
                VStack(alignment: .leading, spacing: 6) {
                    
                    HStack(alignment: .center) {
                        // Display based on sort option
                        if sortOption == .packageId {
                            // When sorting by package ID, show package ID in bold at top
                            Text(package.packageId)
                                .font(.headline)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                .lineLimit(1)
                        } else {
                            // When sorting by package name, show display name in bold at top
                            Text(package.displayName)
                                .font(.headline)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    
                    // Package details
                    VStack(alignment: .leading, spacing: 4) {
                        // Display the secondary info at bottom based on sort option
                        if sortOption == .packageId {
                            // When sorting by package ID, show "Name: displayName" at bottom
                            Text("Name: \(package.displayName)")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            // When sorting by package name, show "ID: packageId" at bottom
                            Text("ID: \(package.packageId)")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        // Version
                        HStack {
                            Text("Version: \(package.version)")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            
                            if !package.bomFiles.isEmpty {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                                Text("\(package.bomFiles.count) files")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }

                            
                            Spacer()
                        }
                        
                        // Install date
                        if !package.installDate.isEmpty {
                            HStack {
                                Text("Installed:")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                
                                Text(formatInstallDate(package.installDate))
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                
                                Spacer()
                            }
                        }
                        
                        // First location - in the main package details (around line 771)
                        // Install location (if not default)
                        if !package.installLocation.isEmpty && package.installLocation != "/" {
                            HStack {
                                Text("Location:")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                
                                Text(package.installLocation.hasPrefix("/") ? package.installLocation : "/" + package.installLocation)
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Spacer()
                            }
                        }

                        // Install process (if available)
                        if !package.installProcessName.isEmpty {
                            HStack {
                                Text("Installer:")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                
                                Text(package.installProcessName)
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                
                                Spacer()
                            }
                        }

                    }
                    

                }
                
                // Action buttons
                VStack(spacing: 6) {
                    HStack(spacing: 10) {

                        Button(isExpanded ? "Close" : "Details") {
                            onToggleExpansion()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .foregroundStyle(.blue)
                        .disabled(isPerformingAction)
                        .help(isExpanded ? "Hide details" : "Show file details")
                        
                        Button("Remove All") {
                            removeAllBomFiles()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .foregroundStyle(.red)
                        .disabled(isPerformingAction)
                        .help("Delete all remaining package files")
                        
                        Button("Forget") {
                            onRemove()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .foregroundStyle(.orange)
                        .disabled(isPerformingAction)
                        .help("Remove package from system records (does not delete files)")
                    }
                    
                    if isPerformingAction {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            
            // Expanded details
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Bill of Materials")
                            .font(.headline)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        
                        if package.bomFilesLoaded {
                            let filteredFiles = getFilteredBomFiles(for: package)
                            let existingCount = filteredFiles.count
                            let totalCount = package.bomFiles.count
                            
                            Text("(\(existingCount)/\(totalCount))")
                                .font(.headline)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                    }
                    
                    // Receipt information
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Receipt Path:")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            
                            Text(package.receiptPath)
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                        }
                        
                        // Second location - in the expanded details (around line 870)
                        if !package.installLocation.isEmpty {
                            HStack {
                                Text("Install Location:")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                
                                Text(package.installLocation.hasPrefix("/") ? package.installLocation : "/" + package.installLocation)
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Update the BOM files display section (around lines 890-925)
                    if !package.bomFilesLoaded {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading files...")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                        .frame(height: 40)
                    } else {
                        let filteredFiles = getFilteredBomFiles(for: package)
                        
                        if filteredFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("All package files from the BOM list have been removed. It's safe to Forget this package.")
                                    .font(.caption2)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    .opacity(0.8)
                            }
                            .frame(height: 60)
                            .padding(.horizontal, 8)
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(filteredFiles.enumerated()), id: \.offset) { index, file in
                                        HStack {
                                            Image(systemName: "doc.text")
                                                .font(.caption)
                                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                            
                                            Text(file)
                                                .font(.caption)
                                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            
                                            Spacer()
                                            
                                            // Action buttons
                                            HStack(spacing: 10) {
                                                Button("View") {
                                                    openFileInFinder(file)
                                                }
                                                .buttonStyle(.borderless)
                                                .controlSize(.mini)
                                                .foregroundStyle(.blue)
                                                .help("Show file in Finder")
                                                
                                                Button("Remove") {
                                                    removeFile(file, from: package)
                                                }
                                                .buttonStyle(.borderless)
                                                .controlSize(.mini)
                                                .foregroundStyle(.red)
                                                .help("Delete this file")
                                            }
                                        }
                                        .padding(.vertical, 2)
                                        .background(index % 2 == 0 ? Color.clear : ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.05))
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                            .scrollIndicators(scrollIndicators ? .automatic : .never)
                            .background(ThemeColors.shared(for: colorScheme).secondaryBG.opacity(0.5))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding()
        .background(ThemeColors.shared(for: colorScheme).secondaryBG.clipShape(RoundedRectangle(cornerRadius: 8)))
    }
    
    private var packageColor: Color {
        return .green
    }

    private func formatInstallDate(_ dateString: String) -> String {
        // Parse the install date format from pkgutil (usually Unix timestamp)
        if let timestamp = Double(dateString) {
            let date = Date(timeIntervalSince1970: timestamp)
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            // If it's already a formatted string, return as is
            return dateString
        }
    }
    
    // Move these functions INSIDE the PackageRowView struct
    private func openFileInFinder(_ filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func removeFile(_ filePath: String, from package: PackageInfo) {
        showCustomAlert(
            title: "Remove File",
            message: "Are you sure you want to permanently delete '\(filePath)'? This action cannot be undone.",
            style: .warning,
            onOk: {
                Task {
                    await performFileRemoval(filePath)
                }
            }
        )
    }

    private func performFileRemoval(_ filePath: String) async {
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let command = "rm -rf \"\(filePath)\""
                
                if HelperToolManager.shared.isHelperToolInstalled {
                    let semaphore = DispatchSemaphore(value: 0)
                    Task {
                        let result = await HelperToolManager.shared.runCommand(command)
                        let success = result.0
                        if !success {
                            printOS("File removal failed: \(result.1)")
                        }
                        continuation.resume(returning: success)
                        semaphore.signal()
                    }
                    semaphore.wait()
                } else {
                    let result = performPrivilegedCommands(commands: command)
                    if !result.0 {
                        printOS("File removal failed: \(result.1)")
                    }
                    continuation.resume(returning: result.0)
                }
            }
        }
        
        await MainActor.run {
            if success {
                // Now onRefresh is accessible since we're inside PackageRowView
                onRefresh()
            } else {
                showCustomAlert(
                    title: "Removal Failed",
                    message: "Failed to remove '\(filePath)'. The file may require additional permissions or may not exist.",
                    style: .critical
                )
            }
        }
    }

    private func removeAllBomFiles() {
        let filteredFiles = getFilteredBomFiles(for: package)
        
        if filteredFiles.isEmpty {
            showCustomAlert(
                title: "No Files to Remove",
                message: "There are no package files remaining on the system to remove.",
                style: .informational
            )
            return
        }
        
        showCustomAlert(
            title: "Remove All Package Files",
            message: "Are you sure you want to permanently delete all \(filteredFiles.count) remaining files from this package? This action cannot be undone.\n\nFiles to be removed:\n\(filteredFiles.prefix(5).joined(separator: "\n"))\(filteredFiles.count > 5 ? "\n... and \(filteredFiles.count - 5) more" : "")",
            style: .warning,
            onOk: {
                Task {
                    await performBulkFileRemoval(filteredFiles)
                }
            }
        )
    }

    private func performBulkFileRemoval(_ filePaths: [String]) async {
        isPerformingAction = true
        
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Build command to remove all files
                let quotedPaths = filePaths.map { "\"\($0)\"" }.joined(separator: " ")
                let command = "rm -rf \(quotedPaths)"
                
                if HelperToolManager.shared.isHelperToolInstalled {
                    let semaphore = DispatchSemaphore(value: 0)
                    Task {
                        let result = await HelperToolManager.shared.runCommand(command)
                        let success = result.0
                        if !success {
                            printOS("Bulk file removal failed: \(result.1)")
                        }
                        continuation.resume(returning: success)
                        semaphore.signal()
                    }
                    semaphore.wait()
                } else {
                    let result = performPrivilegedCommands(commands: command)
                    if !result.0 {
                        printOS("Bulk file removal failed: \(result.1)")
                    }
                    continuation.resume(returning: result.0)
                }
            }
        }
        
        await MainActor.run {
            isPerformingAction = false
            
            if success {
                // Refresh the package to update the BOM files list
                onRefresh()
            } else {
                showCustomAlert(
                    title: "Removal Failed",
                    message: "Failed to remove some or all package files. Some files may require additional permissions or may not exist.",
                    style: .critical
                )
            }
        }
    }
}

private func getFilteredBomFiles(for package: PackageInfo) -> [String] {
    let systemDirectoriesToFilter = [
        "/Applications", // Only filter the bare Applications directory
        "/Library",
        "/Library/Application Support",
        "/Library/Frameworks",
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons",
        "/Library/PreferencePanes",
        "/Library/PrivilegedHelperTools",
        "/Library/QuickLook",
        "/Library/Receipts",
        "/Library/StartupItems",
        "/System",
        "/System/Library",
        "/root",
        "/",
        "/usr",
        "/usr/bin",
        "/usr/lib",
        "/usr/libexec",
        "/usr/local",
        "/usr/local/bin",
        "/usr/local/lib",
        "/usr/local/share",
        "/usr/sbin",
        "/usr/share",
        "/var",
        "/var/db",
        "/var/log",
        "/private",
        "/private/etc",
        "/private/tmp",
        "/private/var",
        "/etc",
        "/tmp",
        "/opt",
        "/opt/local",
        "/opt/local/bin",
        "/opt/local/lib"
    ]
    

    let filteredFiles = package.bomFiles.filter { file in
        // Filter out system directories (exact matches only)
        if systemDirectoriesToFilter.contains(file) {
            return false
        }
        
        // Check if file still exists
        let exists = FileManager.default.fileExists(atPath: file)
        return exists
    }
    
    return filteredFiles
}

// Helper function to run shell commands
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

extension String {
    var expandingTildeInPath: String {
        return NSString(string: self).expandingTildeInPath
    }
}

private func filterAppBundleInternals(_ files: [String]) -> [String] {
    var appBundles: Set<String> = []
    var filteredFiles: [String] = []
    
    // First, identify all .app bundles
    for file in files {
        if file.hasSuffix(".app") {
            appBundles.insert(file)
        }
    }
    
    // Filter out files that are inside .app bundles, keep only the .app bundle itself
    for file in files {
        var shouldInclude = true
        
        // Check if this file is inside any .app bundle
        for appBundle in appBundles {
            if file.hasPrefix(appBundle + "/") {
                // This file is inside an app bundle, don't include it
                shouldInclude = false
                break
            }
        }
        
        if shouldInclude {
            filteredFiles.append(file)
        }
    }
    
    return filteredFiles
}

