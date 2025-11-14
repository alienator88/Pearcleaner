//
//  PackageView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 8/10/25.
//

import SwiftUI
import AlinFoundation

enum PackageSortOption: String, CaseIterable {
    case packageName = "Name"
    case packageId = "ID"
    case installer = "Installer"

    var displayName: String {
        return self.rawValue
    }

    var systemImage: String {
        switch self {
        case .packageName: return "list.bullet"
        case .packageId: return "number"
        case .installer: return "app.badge"
        }
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

    // NEW: Additional metadata from private PKG APIs
    let packageGroups: [String]           // Groups this package belongs to
    let additionalInfo: String            // Extra package information
    let isSecure: Bool                    // Whether package is signed/secure
    let receiptStoragePaths: [String]     // All receipt file paths
    let totalSizeFromBOM: Int64           // Total installed size from BOM
    let totalFilesInBOM: Int              // Total file count from BOM

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
    @ObservedObject private var consoleManager = GlobalConsoleManager.shared
    @State private var packages: [PackageInfo] = []
    @State private var packageIds: [String] = []
    @State private var isLoading: Bool = false
    @State private var lastRefreshDate: Date?
    @State private var searchText: String = ""
    @State private var expandedPackages: Set<String> = []
    @State private var sortOption: PackageSortOption = .packageName
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    // Uninstall sheet state
    @State private var uninstallSheetWindow: NSWindow?
    @State private var packageToUninstall: PackageInfo?
    @State private var filesToUninstall: [String] = []
    @State private var selectedFilesToUninstall: Set<String> = []

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
            } else if filteredPackages.isEmpty && !isLoading {
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
                        ForEach(filteredPackages, id: \.id) { package in
                            PackageRowView(
                                package: package,
                                isExpanded: expandedPackages.contains(package.packageId),
                                sortOption: sortOption
                            ) {
                                toggleExpansion(for: package.packageId)
                            } onForget: {
                                forgetPackage(package)
                            } onUninstall: {
                                uninstallPackage(package)
                            } onRefresh: {
                                refreshPackages()
                            } onUpdateBomFiles: { updatedBomFiles in
                                // Update the local BOM files for this package
                                if let packageIndex = packages.firstIndex(where: { $0.packageId == package.packageId }) {
                                    packages[packageIndex].bomFiles = updatedBomFiles
                                }
                            }
                            .onAppear {
                                loadBOMFilesIfNeeded(for: package.packageId)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PackagesViewShouldUndo"))) { _ in
            // Refresh packages when undo is performed
            refreshPackages()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PackagesViewShouldRefresh"))) { _ in
            // Refresh packages
            refreshPackages()
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
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        consoleManager.showConsole.toggle()
                    }
                } label: {
                    Label("Console", systemImage: consoleManager.showConsole ? "terminal.fill" : "terminal")
                }
                .help("Toggle console output")
                
                Menu {
                    ForEach(PackageSortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            Label(option.displayName, systemImage: option.systemImage)
                        }
                    }
                } label: {
                    Label(sortOption.displayName, systemImage: sortOption.systemImage)
                }
                .labelStyle(.titleAndIcon)
                .menuIndicator(.hidden)

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
                if #available(macOS 10.5, *) {
                    // Find the package by ID
                    guard let package = self.packages.first(where: { $0.packageId == packageId }) else {
                        continuation.resume(returning: [])
                        return
                    }

                    // Get all receipts to find the one matching this package ID
                    let receipts = PKGManager.getAllPackages(volume: "/")
                    guard let receipt = receipts.first(where: { ($0.packageIdentifier() as? String) == packageId }) else {
                        continuation.resume(returning: [])
                        return
                    }

                    // Use PKG API to get files from BOM
                    let files = PKGManager.getPackageFiles(receipt: receipt, installLocation: package.installLocation)

                    // Filter out app bundle internals, keep only top-level .app paths
                    let filteredFiles = filterAppBundleInternals(files)

                    continuation.resume(returning: filteredFiles)
                } else {
                    // Fallback for older macOS
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private func refreshPackages() {
        GlobalConsoleManager.shared.appendOutput("Refreshing packages...\n", source: CurrentPage.packages.title)
        isLoading = true
        packages = []
        packageIds = []

        Task {
            let loadedPackages = await loadPackagesFromPKGAPI()

            await MainActor.run {
                self.packages = loadedPackages
                self.packageIds = loadedPackages.map { $0.packageId }
                self.lastRefreshDate = Date()
                self.isLoading = false
                GlobalConsoleManager.shared.appendOutput("✓ Loaded \(loadedPackages.count) packages\n", source: CurrentPage.packages.title)
            }
        }
    }

    private func loadPackagesFromPKGAPI() async -> [PackageInfo] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if #available(macOS 10.5, *) {
                    // Use private PKG API to get all receipts
                    let receipts = PKGManager.getAllPackages(volume: "/")

                    // Convert receipts to PackageInfo objects
                    let packages = receipts.compactMap { receipt in
                        PKGManager.getPackageInfo(from: receipt)
                    }

                    continuation.resume(returning: packages)
                } else {
                    // Fallback for older macOS (shouldn't happen)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    
    private func forgetPackage(_ package: PackageInfo) {
        GlobalConsoleManager.shared.appendOutput("Starting forget operation for \(package.displayName)...\n", source: CurrentPage.packages.title)
        Task {
            await performPackageForget(package)
        }
    }

    private func uninstallPackage(_ package: PackageInfo) {
        GlobalConsoleManager.shared.appendOutput("Starting uninstall operation for \(package.displayName)...\n", source: CurrentPage.packages.title)
        Task {
            await prepareUninstall(package)
        }
    }

    private func performPackageForget(_ package: PackageInfo) async {
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

                // Get receipt file paths to delete directly (no shell command needed)
                let receiptPaths = package.receiptStoragePaths

                if receiptPaths.isEmpty {
//                    printOS("⚠️ No receipt paths found for package \(package.packageName)")
                    continuation.resume(returning: false)
                    return
                }

                // Use FileManagerUndo to safely delete receipt files to trash
                let receiptURLs = receiptPaths.map { URL(fileURLWithPath: $0) }
                let success = FileManagerUndo.shared.deleteFiles(at: receiptURLs, bundleName: "PKG-\(package.packageName)")

                if !success {
                    printOS("Failed to forget package.")
                }

                continuation.resume(returning: success)
            }
        }

        await MainActor.run {
            if success {
                GlobalConsoleManager.shared.appendOutput("✓ Completed forget operation for \(package.displayName)\n", source: CurrentPage.packages.title)
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

    private func prepareUninstall(_ package: PackageInfo) async {
        // Ensure BOM files are loaded before showing the sheet
        var updatedPackage = package

        if !package.bomFilesLoaded {
            // Show sheet with loading state
            await MainActor.run {
                self.packageToUninstall = package
                self.filesToUninstall = []
                self.selectedFilesToUninstall = []
                self.showUninstallSheet(package: package, files: [])
            }

            // Load BOM files in background
            let bomFiles = await loadBOMFiles(for: package.packageId)

            // Update package with loaded files
            await MainActor.run {
                if let index = packages.firstIndex(where: { $0.packageId == package.packageId }) {
                    packages[index].bomFiles = bomFiles
                    packages[index].bomFilesLoaded = true
                    updatedPackage = packages[index]
                }
            }
        }

        let (existingFiles, _) = getBomFilesByExistence(for: updatedPackage)

        await MainActor.run {
            if existingFiles.isEmpty {
                // Close the sheet if it was open
                if let sheetWindow = self.uninstallSheetWindow,
                   let parentWindow = NSApp.keyWindow {
                    parentWindow.endSheet(sheetWindow)
                }
                self.uninstallSheetWindow = nil

                showCustomAlert(
                    title: "No Files Found",
                    message: "No files found to uninstall for package '\(package.displayName)'.\n\nWould you like to forget this package? This will remove it from system records only.",
                    style: .informational,
                    onOk: {
                        forgetPackage(package)
                    }
                )
                return
            }

            // Set all data
            self.packageToUninstall = updatedPackage
            self.filesToUninstall = existingFiles
            self.selectedFilesToUninstall = Set(existingFiles) // All checked by default

            // Show the sheet
            self.showUninstallSheet(package: updatedPackage, files: existingFiles)
        }
    }

    private func showUninstallSheet(package: PackageInfo, files: [String]) {
        guard let parentWindow = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            return
        }

        // Create the SwiftUI view
        let contentView = PackageUninstallSheet(
            package: package,
            files: files,
            selectedFiles: $selectedFilesToUninstall,
            onConfirm: {
                if let sheetWindow = self.uninstallSheetWindow {
                    parentWindow.endSheet(sheetWindow)
                }
                self.uninstallSheetWindow = nil
                Task {
                    await performFullUninstall(package, selectedFiles: Array(self.selectedFilesToUninstall))
                }
            },
            onCancel: {
                if let sheetWindow = self.uninstallSheetWindow {
                    parentWindow.endSheet(sheetWindow)
                }
                self.uninstallSheetWindow = nil
            }
        )

        // If sheet already exists, update its content
        if let existingSheet = uninstallSheetWindow,
           let hostingController = existingSheet.contentViewController as? NSHostingController<PackageUninstallSheet> {
            hostingController.rootView = contentView
            return
        }

        // Create new sheet window
        let hostingController = NSHostingController(rootView: contentView)

        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        sheetWindow.title = "Uninstall Package"
        sheetWindow.contentViewController = hostingController
        sheetWindow.isReleasedWhenClosed = false

        // Present as sheet
        parentWindow.beginSheet(sheetWindow)

        self.uninstallSheetWindow = sheetWindow
    }

    private func performFullUninstall(_ package: PackageInfo, selectedFiles: [String]) async {
        // Step 1: Delete BOM files using FileManagerUndo (moves to Trash with undo support)
        let bomFilesSuccess = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if selectedFiles.isEmpty {
                    continuation.resume(returning: true)
                    return
                }

                // Convert file paths to URLs
                let urls = selectedFiles.map { URL(fileURLWithPath: $0) }

                // Use FileManagerUndo to move files to Trash (supports undo)
                let bundleName = "Package - \(package.displayName)"
                let success = FileManagerUndo.shared.deleteFiles(at: urls, bundleName: bundleName)

                continuation.resume(returning: success)
            }
        }

        // Step 2: Delete receipt files (must use privileged commands as they're system files)
        let receiptsSuccess = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let receiptPaths = package.receiptStoragePaths

                guard !receiptPaths.isEmpty else {
                    continuation.resume(returning: true)
                    return
                }

                // Use FileManagerUndo to safely delete receipt files to trash
                let receiptURLs = receiptPaths.map { URL(fileURLWithPath: $0) }
                let success = FileManagerUndo.shared.deleteFiles(at: receiptURLs, bundleName: "PKG-\(package.packageId)")

                continuation.resume(returning: success)
            }
        }

        await MainActor.run {
            if bomFilesSuccess && receiptsSuccess {
                // Remove the package from the local array
                packages.removeAll { $0.packageId == package.packageId }
                packageIds.removeAll { $0 == package.packageId }

                // Also remove from expanded packages if it was expanded
                expandedPackages.remove(package.packageId)
            } else {
                var message = "Failed to fully uninstall package '\(package.displayName)'."
                if !bomFilesSuccess {
                    message += " Some files could not be deleted."
                }
                if !receiptsSuccess {
                    message += " Receipt files could not be removed."
                }

                showCustomAlert(
                    title: "Uninstall Failed",
                    message: message,
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
    let sortOption: PackageSortOption
    let onToggleExpansion: () -> Void
    let onForget: () -> Void
    let onUninstall: () -> Void
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
                    
                    HStack(alignment: .center, spacing: 8) {
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

                        // Security badge
                        if package.isSecure {
                            HStack(spacing: 2) {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                Text("Secure")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.green)
                            .help("This package is signed and verified. The package was cryptographically signed by the developer and its integrity has been verified.")
                        } else {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.caption2)
                                Text("Unsigned")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.orange)
                            .help("This package is unsigned or unverified. The package was not cryptographically signed, or its signature could not be verified.")
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

                        // Version, file count, size
                        HStack {
                            Text("Version: \(package.version)")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                            if package.totalFilesInBOM > 0 {
                                Text(verbatim: "•")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                                Text("\(package.totalFilesInBOM) files")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }

                            if package.totalSizeFromBOM > 0 {
                                Text(verbatim: "•")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                                Text(formatBytes(package.totalSizeFromBOM))
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }

                            Spacer()
                        }

                        // Package groups
                        HStack(spacing: 6) {
                            if !package.packageGroups.isEmpty {
                                ForEach(package.packageGroups.prefix(3), id: \.self) { group in
                                    Text(formatGroupName(group))
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundStyle(Color.blue)
                                        .cornerRadius(4)
                                }

                                if package.packageGroups.count > 3 {
                                    Text(verbatim: "+\(package.packageGroups.count - 3)")
                                        .font(.caption2)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                }
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
                            onForget()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .foregroundStyle(.orange)
                        .disabled(isPerformingAction)
                        .help("Remove package from system records (does not delete files)")

                        Divider().frame(height: 10)

                        Button("Uninstall") {
                            onUninstall()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .foregroundStyle(.red)
                        .disabled(isPerformingAction)
                        .help("Completely remove package: delete all files, receipts, and forget package")
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
                    
                    // Additional info (if available)
                    if !package.additionalInfo.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Additional Info:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            Text(package.additionalInfo)
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                        .padding(8)
                        .background(ThemeColors.shared(for: colorScheme).secondaryBG.opacity(0.3))
                        .cornerRadius(6)
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

                    // Receipt storage paths (collapsible)
                    if package.receiptStoragePaths.count > 1 {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(package.receiptStoragePaths, id: \.self) { path in
                                    Text(path)
                                        .font(.caption2)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                            .padding(.top, 4)
                        } label: {
                            Text("Receipt Storage Paths (\(package.receiptStoragePaths.count))")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                        .padding(.bottom, 8)
                    }

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

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatGroupName(_ group: String) -> String {
        // Remove common prefixes to make badges more readable
        let cleanedGroup = group
            .replacingOccurrences(of: "com.apple.group.", with: "")
            .replacingOccurrences(of: "com.apple.", with: "")

        return cleanedGroup
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
                // Use FileManagerUndo to safely delete file to trash
                let fileURL = URL(fileURLWithPath: filePath)
                let success = FileManagerUndo.shared.deleteFiles(at: [fileURL], bundleName: "PKG-\(package.packageId)")
                continuation.resume(returning: success)
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
                // Use FileManagerUndo to safely delete files to trash
                let fileURLs = filePaths.map { URL(fileURLWithPath: $0) }
                let success = FileManagerUndo.shared.deleteFiles(at: fileURLs, bundleName: "PKG-\(package.packageId)")
                continuation.resume(returning: success)
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
        "/private/var", "/etc", "/tmp", "/opt", "/opt/local", "/opt/local/bin", "/opt/local/lib",
        // Additional high-risk directories that should NEVER be deleted as parent directories
        "/Library/Extensions",  // Kernel extensions
        "/Library/Audio", "/Library/Audio/Plug-Ins", "/Library/Audio/Plug-Ins/HAL",  // Audio plugins
        "/Library/Audio/Plug-Ins/Components", "/Library/Audio/Plug-Ins/VST", "/Library/Audio/Plug-Ins/VST3",
        "/Library/Preferences",  // System preferences
        "/Library/LaunchAgents", "/Library/LaunchDaemons",  // Launch items
        "/Library/Components"  // System components
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
        // Filter out system directories themselves (but NOT their children)
        // e.g., filter "/Library/Extensions" but allow "/Library/Extensions/Foo.kext"
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

// Helper function to remove redundant child paths for known bundle types
// This collapses bundle internals (e.g., Foo.app/Contents/...) into just the bundle (Foo.app)
// SAFETY: Only collapses recognized bundle extensions, never arbitrary directories
private func removeRedundantChildPaths(_ paths: [String]) -> [String] {
    // Comprehensive list of macOS bundle types that should be collapsed
    let bundleExtensions = [
        // Applications & System
        ".app", ".appex", ".xpc",

        // Drivers & Kernel
        ".kext", ".driver",

        // Plugins & Components
        ".plugin", ".bundle", ".component",
        ".vst", ".vst3", ".au",

        // Frameworks & Libraries
        ".framework", ".dylib",

        // System Services
        ".service", ".prefPane", ".menu",
        ".qlgenerator", ".saver", ".mdimporter",
        ".action", ".workflow",

        // Development
        ".xcodeproj", ".xcworkspace", ".playground",
        ".xcframework", ".dSYM",

        // Miscellaneous
        ".pkg", ".lpkg", ".clr", ".slideSaver"
    ]

    let sortedPaths = paths.sorted()
    var result: [String] = []

    for path in sortedPaths {
        var isInsideBundle = false

        // Check if this path is inside a known bundle type
        for existingPath in result {
            // Only treat as redundant if parent is a recognized bundle
            let isBundle = bundleExtensions.contains { existingPath.hasSuffix($0) }
            if isBundle && path.hasPrefix(existingPath + "/") {
                isInsideBundle = true
                break
            }
        }

        if !isInsideBundle {
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

// MARK: - Package Uninstall Sheet

struct PackageUninstallSheet: View {
    let package: PackageInfo
    let files: [String]
    @Binding var selectedFiles: Set<String>
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme

    private var filteredFiles: [String] {
        if searchText.isEmpty {
            return files
        }
        return files.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        StandardSheetView(
            title: "Uninstall Package",
            width: 600,
            height: 500,
            onClose: onCancel
        ) {
            // Content
            VStack(spacing: 0) {
                // Subtitle with package name
                VStack(spacing: 8) {
                    Text(package.displayName)
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    Text("\(selectedFiles.count) of \(files.count) file\(files.count == 1 ? "" : "s") selected")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    TextField("Filter files...", text: $searchText)
                        .textFieldStyle(.plain)

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
                .padding(.top, 12)

                Divider()
                    .padding(.top, 12)

                // File list or loading state
                if files.isEmpty {
                    // Loading state
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading package files...")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .frame(minHeight: 200)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredFiles, id: \.self) { file in
                                HStack(spacing: 8) {
                                    Button {
                                        toggleSelection(file)
                                    } label: {
                                        Image(systemName: selectedFiles.contains(file) ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(selectedFiles.contains(file) ? .blue : ThemeColors.shared(for: colorScheme).secondaryText)
                                    }
                                    .buttonStyle(.plain)

                                    Text(file)
                                        .font(.caption)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .background(filteredFiles.firstIndex(of: file).map { $0 % 2 == 0 } == true ? Color.clear : ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.05))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 400)
                }
            }
        } selectionControls: {
            Button(selectedFiles.count == files.count ? "Deselect All" : "Select All") {
                if selectedFiles.count == files.count {
                    selectedFiles.removeAll()
                } else {
                    selectedFiles = Set(files)
                }
            }
            .buttonStyle(.borderless)
            .disabled(files.isEmpty)
        } actionButtons: {
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Button("Move to Trash") {
                onConfirm()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedFiles.isEmpty || files.isEmpty)
        }
    }

    private func toggleSelection(_ file: String) {
        if selectedFiles.contains(file) {
            selectedFiles.remove(file)
        } else {
            selectedFiles.insert(file)
        }
    }
}

