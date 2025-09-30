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
    case installer = "Installer"
    
    var displayName: String {
        return self.rawValue
    }
}

struct PackageInfo: Identifiable, Hashable, Equatable {
    let id = UUID()
    let packageId: String
    let packageName: String
    let packageFileName: String
    let version: String
    let installDate: String
    let installProcessName: String
    var bomFiles: [String]
    let receiptPath: String
    let installLocation: String
    var bomFilesLoaded: Bool = false

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
    @State private var packageIds: [String] = []
    @State private var isLoading: Bool = false
    @State private var lastRefreshDate: Date?
    @State private var searchText: String = ""
    @State private var expandedPackages: Set<String> = []
    @State private var sortOption: PackageSortOption = .packageId
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.general.permanentDelete") private var permanentDelete: Bool = false

    private var filteredPackages: [PackageInfo] {
        var packages = self.packages.filter { !$0.packageId.hasPrefix("com.apple.") }

        if !searchText.isEmpty {
            packages = packages.filter { package in
                package.displayName.localizedCaseInsensitiveContains(searchText) ||
                package.packageId.localizedCaseInsensitiveContains(searchText) ||
                package.version.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOption {
        case .packageName:
            packages = packages.sorted { first, second in
                return first.displayName.localizedCaseInsensitiveCompare(second.displayName) == .orderedAscending
            }
        case .packageId:
            packages = packages.sorted { first, second in
                return first.packageId.localizedCaseInsensitiveCompare(second.packageId) == .orderedAscending
            }
        case .installer:
            packages = packages.sorted { first, second in
                // Handle empty installer names by putting them at the end
                if first.installProcessName.isEmpty && second.installProcessName.isEmpty {
                    return first.displayName.localizedCaseInsensitiveCompare(second.displayName) == .orderedAscending
                } else if first.installProcessName.isEmpty {
                    return false
                } else if second.installProcessName.isEmpty {
                    return true
                } else {
                    return first.installProcessName.localizedCaseInsensitiveCompare(second.installProcessName) == .orderedAscending
                }
            }
        }

        return packages
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
                        .monospacedDigit()
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    if isLoading {
                        Text("• Loading...")
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
                            } onUpdateBomFiles: { updatedBomFiles in
                                // Update the local BOM files for this package
                                if let packageIndex = packages.firstIndex(where: { $0.packageId == package.packageId }) {
                                    packages[packageIndex].bomFiles = updatedBomFiles
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(scrollIndicators ? .automatic : .never)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding([.horizontal, .bottom], 20)
        .onAppear {
            if packages.isEmpty {
                refreshPackages()
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            TahoeToolbarItem(placement: .navigation) {
                VStack(alignment: .leading) {
                    Text("Package Manager")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Manage packages installed via macOS Installer")
                        .font(.callout)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }

            ToolbarItem { Spacer() }

            TahoeToolbarItem(isGroup: true) {
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
                .labelStyle(.titleAndIcon)

                Button {
                    refreshPackages()
                } label: {
                    Label("Refresh", systemImage: "arrow.counterclockwise")
                }
                .disabled(isLoading)
            }

        }
    }
    
    private func toggleExpansion(for packageId: String) {
        if expandedPackages.contains(packageId) {
            expandedPackages.remove(packageId)
        } else {
            expandedPackages.insert(packageId)
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
                // Try normal shell command first, fallback to fast method if it times out
                var filesResult = runDirectShellCommandWithTimeout(command: "pkgutil --files \"\(packageId)\"", timeout: 2.0)
                
                if !filesResult.0 && filesResult.1.contains("timed out") {
                    // Command timed out, use fast shell command as fallback
                    filesResult = runFastShellCommand(command: "pkgutil --files \"\(packageId)\"")
                }
                
                if filesResult.0 {
                    let allFiles = filesResult.1.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    
                    var installLocation = "/"
                    
                    // First try to get from receipt plist
                    let receiptPath = "/var/db/receipts/\(packageId).plist"
                    
                    var defaultsResult = runDirectShellCommandWithTimeout(command: "defaults read \"\(receiptPath)\"", timeout: 3.0)
                    if !defaultsResult.0 && defaultsResult.1.contains("timed out") {
                        defaultsResult = runFastShellCommand(command: "defaults read \"\(receiptPath)\"")
                    }
                    
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
                        var infoResult = runDirectShellCommandWithTimeout(command: "pkgutil --pkg-info \"\(packageId)\"", timeout: 3.0)
                        if !infoResult.0 && infoResult.1.contains("timed out") {
                            infoResult = runFastShellCommand(command: "pkgutil --pkg-info \"\(packageId)\"")
                        }
                        
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
                    
                    // Remove Apple resource fork files
                    let filteredFiles = allFiles.compactMap { file -> String? in
                        let trimmedFile = file.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if trimmedFile.contains("._") {
                            return nil
                        }
                        
                        var absolutePath: String
                        if trimmedFile.hasPrefix("/") {
                            absolutePath = trimmedFile
                        } else {
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
            let ids = await loadPackageIds()
            
            await MainActor.run {
                self.packageIds = ids
                self.lastRefreshDate = Date()
            }
            
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
                
                await MainActor.run {
                    self.packages.append(contentsOf: batchPackages)
                }
            }
            
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
            let lines = defaultsResult.1.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmedLine.contains("InstallDate = ") {
                    if let startQuote = trimmedLine.firstIndex(of: "\""),
                       let endQuote = trimmedLine.lastIndex(of: "\""),
                       startQuote != endQuote {
                        installDate = String(trimmedLine[trimmedLine.index(after: startQuote)..<endQuote])
                    }
                } else if trimmedLine.contains("PackageFileName = ") {
                    if let startQuote = trimmedLine.firstIndex(of: "\""),
                       let endQuote = trimmedLine.lastIndex(of: "\""),
                       startQuote != endQuote {
                        packageFileName = String(trimmedLine[trimmedLine.index(after: startQuote)..<endQuote])
                    }
                } else if trimmedLine.contains("PackageVersion = ") {
                    if let startQuote = trimmedLine.firstIndex(of: "\""),
                       let endQuote = trimmedLine.lastIndex(of: "\""),
                       startQuote != endQuote {
                        version = String(trimmedLine[trimmedLine.index(after: startQuote)..<endQuote])
                    }
                } else if trimmedLine.contains("InstallPrefixPath = ") {
                    if let startQuote = trimmedLine.firstIndex(of: "\""),
                       let endQuote = trimmedLine.lastIndex(of: "\""),
                       startQuote != endQuote {
                        installLocation = String(trimmedLine[trimmedLine.index(after: startQuote)..<endQuote])
                    }
                } else if trimmedLine.contains("InstallProcessName = ") {
                    if trimmedLine.contains("\"") {
                        if let startQuote = trimmedLine.firstIndex(of: "\""),
                           let endQuote = trimmedLine.lastIndex(of: "\""),
                           startQuote != endQuote {
                            installProcessName = String(trimmedLine[trimmedLine.index(after: startQuote)..<endQuote])
                        }
                    } else {
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
        Task {
            await performPackageRemoval(package)
        }
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
                // Remove the package from the local array
                packages.removeAll { $0.packageId == package.packageId }
                packageIds.removeAll { $0 == package.packageId }
                
                // Also remove from expanded packages if it was expanded
                expandedPackages.remove(package.packageId)
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

}


struct PackageRowView: View {
    @Environment(\.colorScheme) var colorScheme
    let package: PackageInfo
    let isExpanded: Bool
    let permanentDelete: Bool
    let sortOption: PackageSortOption
    let onToggleExpansion: () -> Void
    let onRemove: () -> Void
    let onRefresh: () -> Void
    let onUpdateBomFiles: ([String]) -> Void
    @State private var isPerformingAction = false
    @State private var isHovered = false
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
                }
                
                // Package details
                VStack(alignment: .leading, spacing: 6) {
                    
                    HStack(alignment: .center) {
                        if sortOption == .packageId {
                            Text(package.packageId)
                                .font(.headline)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                .lineLimit(1)
                        } else {
                            Text(package.displayName)
                                .font(.headline)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    
                    // Package details
                    VStack(alignment: .leading, spacing: 4) {
                        if sortOption == .packageId {
                            Text("Name: \(package.displayName)")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
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
                        
                        Divider().frame(height: 10)

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
                    HStack(spacing: 0) {

                        InfoButton(text: "By default, pkgutil shows all file paths from the package which might include system paths like /Library/Application Support, /usr/local, etc. and even files that are already deleted from the system.\n\nThis list of BOM files is filtered as follows:\n- Shows directories that are not system directories. \n- Doesn't show files that are duplicated by listing out all contents of parent directories.\n- Doesn't show files that are already deleted.")

                        Text("Bill of Materials")
                            .font(.headline)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .padding(.horizontal, 5)

                        if package.bomFilesLoaded {
                            let (existingFiles, _) = getBomFilesByExistence(for: package)
                            let count = existingFiles.count
                            
                            Text("\(count) valid \(count == 1 ? "file" : "files") found")
                                .font(.caption2)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                            Spacer()

                            if count > 1 {
                                Button("Remove All") {
                                    removeAllBomFiles()
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.mini)
                                .foregroundStyle(.red)
                                .disabled(isPerformingAction)
                                .help("Delete all remaining package files")
                            }
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
                        let (existingFiles, _) = getBomFilesByExistence(for: package)
                        
                        if existingFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("All valid package files from the BOM list have been removed. You may Forget this package.")
                                    .font(.caption2)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    .opacity(0.8)
                            }
                            .frame(height: 60)
                            .padding(.horizontal, 8)
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(existingFiles.enumerated()), id: \.offset) { index, file in
                                        BomFileRowView(
                                            file: file,
                                            exists: true,
                                            index: index,
                                            colorScheme: colorScheme,
                                            onView: { openFileInFinder(file) },
                                            onRemove: { removeFile(file, from: package) }
                                        )
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? 
                    ThemeColors.shared(for: colorScheme).secondaryBG.opacity(0.8) :
                    ThemeColors.shared(for: colorScheme).secondaryBG
                )
        )
        .onTapGesture {
            onToggleExpansion()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private var packageColor: Color {
        return .green
    }

    private func formatInstallDate(_ dateString: String) -> String {
        // Parse the install date format from pkgutil
        if let timestamp = Double(dateString) {
            let date = Date(timeIntervalSince1970: timestamp)
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            return dateString
        }
    }
    
    private func openFileInFinder(_ filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func removeFile(_ filePath: String, from package: PackageInfo) {
        Task {
            await performFileRemoval(filePath, from: package)
        }
    }

    private func performFileRemoval(_ filePath: String, from package: PackageInfo) async {
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
                // Update BOM files locally using callback
                let updatedBomFiles = package.bomFiles.filter { $0 != filePath }
                onUpdateBomFiles(updatedBomFiles)
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
        
        Task {
            await performBulkFileRemoval(filteredFiles)
        }
    }

    private func performBulkFileRemoval(_ filePaths: [String]) async {
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
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
                // Update BOM files locally using callback
                let updatedBomFiles = package.bomFiles.filter { !filePaths.contains($0) }
                onUpdateBomFiles(updatedBomFiles)
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
    let (existingFiles, _) = getBomFilesByExistence(for: package)
    return existingFiles
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

private func runDirectShellCommandWithTimeout(command: String, timeout: TimeInterval) -> (Bool, String) {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    
    task.launch()
    
    let group = DispatchGroup()
    group.enter()
    
    var completed = false
    var result: (Bool, String) = (false, "")
    
    DispatchQueue.global().async {
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if !completed {
            result = (task.terminationStatus == 0, output)
        }
        completed = true
        group.leave()
    }
    
    let waitResult = group.wait(timeout: .now() + timeout)
    
    if waitResult == .timedOut {
        task.terminate()
        return (false, "Command timed out")
    }
    
    return result
}

private func runFastShellCommand(command: String) -> (Bool, String) {
    let tempFile = "/tmp/pearcleaner_getBOMlist_\(UUID().uuidString)"
    let redirectedCommand = "\(command) > \"\(tempFile)\" 2>&1"
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", redirectedCommand]
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let success = process.terminationStatus == 0
        
        let output: String
        if FileManager.default.fileExists(atPath: tempFile) {
            output = (try? String(contentsOfFile: tempFile)) ?? ""
            try? FileManager.default.removeItem(atPath: tempFile)
        } else {
            output = ""
        }
        
        return (success, output)
    } catch {
        try? FileManager.default.removeItem(atPath: tempFile)
        return (false, "Error: \(error)")
    }
}

extension String {
    var expandingTildeInPath: String {
        return NSString(string: self).expandingTildeInPath
    }
}

private func filterAppBundleInternals(_ files: [String]) -> [String] {
    var appBundles: Set<String> = []
    var filteredFiles: [String] = []
    
    for file in files {
        if file.hasSuffix(".app") {
            appBundles.insert(file)
        }
    }
    
    // Filter out files that are inside .app bundles, keep only the .app bundle itself
    for file in files {
        var shouldInclude = true
        
        for appBundle in appBundles {
            if file.hasPrefix(appBundle + "/") {
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

private func getBomFilesByExistence(for package: PackageInfo) -> (existing: [String], deleted: [String]) {
    let systemDirectoriesToFilter = [
        "/Applications", "/Library", "/Library/Application Support", "/Library/Frameworks",
        "/Library/LaunchAgents", "/Library/LaunchDaemons", "/Library/PreferencePanes",
        "/Library/PrivilegedHelperTools", "/Library/QuickLook", "/Library/Receipts",
        "/Library/StartupItems", "/System", "/System/Library", "/root", "/",
        "/usr", "/usr/bin", "/usr/lib", "/usr/libexec", "/usr/local", "/usr/local/bin",
        "/usr/local/lib", "/usr/local/share", "/usr/sbin", "/usr/share", "/var",
        "/var/db", "/var/log", "/private", "/private/etc", "/private/tmp",
        "/private/var", "/etc", "/tmp", "/opt", "/opt/local", "/opt/local/bin", "/opt/local/lib"
    ]
    
    var existingFiles: [String] = []
    var deletedFiles: [String] = []
    
    // Create a list that includes the install location (if not root) plus all BOM files
    var filesToProcess = package.bomFiles
    
    // Add install location to the list if it's meaningful and not a system directory
    if !package.installLocation.isEmpty && package.installLocation != "/" {
        var installLocationPath = package.installLocation
        if !installLocationPath.hasPrefix("/") {
            installLocationPath = "/" + installLocationPath
        }
        
        if !systemDirectoriesToFilter.contains(installLocationPath) && !filesToProcess.contains(installLocationPath) {
            filesToProcess.append(installLocationPath)
        }
    }
    
    for file in filesToProcess {
        // Filter out system directories
        if systemDirectoriesToFilter.contains(file) {
            continue
        }
        
        // Check if file exists
        if FileManager.default.fileExists(atPath: file) {
            existingFiles.append(file)
        } else {
            deletedFiles.append(file)
        }
    }
    
    // Remove redundant child paths from both existing and deleted files
    let filteredExistingFiles = removeRedundantChildPaths(existingFiles)
    let filteredDeletedFiles = removeRedundantChildPaths(deletedFiles)
    
    return (filteredExistingFiles.sorted(), filteredDeletedFiles.sorted())
}

// Helper function to remove redundant child paths when parent directories are already in the list
private func removeRedundantChildPaths(_ paths: [String]) -> [String] {
    let sortedPaths = paths.sorted()
    var result: [String] = []
    
    for path in sortedPaths {
        var isRedundant = false
        
        for existingPath in result {
            if path.hasPrefix(existingPath + "/") {
                isRedundant = true
                break
            }
        }
        
        if !isRedundant {
            result.append(path)
        }
    }
    
    return result
}

struct BomFileRowView: View {
    let file: String
    let exists: Bool
    let index: Int
    let colorScheme: ColorScheme
    let onView: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: exists ? "doc.text" : "doc.text.fill")
                .font(.caption)
                .foregroundStyle(exists ? 
                    ThemeColors.shared(for: colorScheme).secondaryText : 
                    ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.4))
            
            Text(file)
                .font(.caption)
                .foregroundStyle(exists ? 
                    ThemeColors.shared(for: colorScheme).primaryText : 
                    ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.5))
                .lineLimit(1)
                .truncationMode(.middle)
                .strikethrough(exists ? false : true)
            
            Spacer()
            
            if exists {
                HStack(spacing: 10) {
                    Button("View") {
                        onView()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
                    .foregroundStyle(.blue)
                    .help("Show file in Finder")

                    Divider().frame(height: 10)

                    Button("Remove") {
                        onRemove()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
                    .foregroundStyle(.red)
                    .help("Delete this file")
                }
            } else {
                Text("DELETED")
                    .font(.caption2)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.4))
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 2)
        .background(index % 2 == 0 ? Color.clear : ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.05))
        .opacity(exists ? 1.0 : 0.6)
    }
}

