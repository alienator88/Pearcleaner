//
//  SearchInstallSection.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import SwiftUI
import AlinFoundation

enum HomebrewSearchType: String, CaseIterable {
    case installed = "Installed"
    case formulae = "Formulae"
    case casks = "Casks"
}

struct SearchInstallSection: View {
    let onPackageSelected: (HomebrewSearchResult, Bool) -> Void

    @EnvironmentObject var brewManager: HomebrewManager
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var searchQuery: String = ""
    @State private var searchType: HomebrewSearchType = .installed
    @State private var collapsedCategories: Set<String> = []
    @State private var cachedCategories: [(title: String, packages: [HomebrewSearchResult])] = []
    @State private var updatingPackages: Set<String> = []
    @State private var isUpdatingAll: Bool = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    private var displayedResults: [HomebrewSearchResult] {
        let source: [HomebrewSearchResult]
        switch searchType {
        case .formulae:
            source = brewManager.allAvailableFormulae
        case .casks:
            source = brewManager.allAvailableCasks
        case .installed:
            // For installed, we'll handle categorization in categorizedInstalledPackages
            return []
        }

        // Source is already sorted, just filter if needed
        if searchQuery.isEmpty {
            return source
        } else {
            return source.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    // Update cached categories when data changes
    private func updateCategorizedPackages() {
        let allConverted = (brewManager.installedFormulae + brewManager.installedCasks).map { convertToSearchResult($0) }

        // Filter by search query if needed
        let filtered = searchQuery.isEmpty ? allConverted : allConverted.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }

        // Separate into categories
        var outdated: [HomebrewSearchResult] = []
        var formulae: [HomebrewSearchResult] = []
        var casks: [HomebrewSearchResult] = []

        for result in filtered {
            let isCask = brewManager.installedCasks.contains(where: { $0.name == result.name })

            // Add to type-based category (Formulae or Casks)
            if isCask {
                casks.append(result)
            } else {
                formulae.append(result)
            }

            // Also add to Outdated category if outdated
            if isPackageOutdated(result, isCask: isCask) {
                outdated.append(result)
            }
        }

        // Sort each category alphabetically
        outdated.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        formulae.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        casks.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Build categories in order: Formulae, Casks, Outdated
        var categories: [(title: String, packages: [HomebrewSearchResult])] = []
        if !formulae.isEmpty {
            categories.append((title: "Formulae", packages: formulae))
        }
        if !casks.isEmpty {
            categories.append((title: "Casks", packages: casks))
        }
        if !outdated.isEmpty {
            categories.append((title: "Outdated", packages: outdated))
        }

        cachedCategories = categories
    }

    // Helper to check if a package is outdated (using brew outdated as source of truth)
    private func isPackageOutdated(_ result: HomebrewSearchResult, isCask: Bool) -> Bool {
        let shortName = result.name.components(separatedBy: "/").last ?? result.name

        // Check if package is in the outdated set from brew outdated
        return brewManager.outdatedPackageNames.contains(result.name) ||
               brewManager.outdatedPackageNames.contains(shortName)
    }

    private func convertToSearchResult(_ package: InstalledPackage) -> HomebrewSearchResult {
        // Look up tap info from available packages
        let availablePackages = package.isCask ? brewManager.allAvailableCasks : brewManager.allAvailableFormulae
        let shortName = package.name.components(separatedBy: "/").last ?? package.name

        // Try multiple matching strategies:
        // 1. Exact match on full name
        // 2. Match on short name
        // 3. Match where available package's short name equals installed short name
        let matchingPackage = availablePackages.first(where: {
            if $0.name == package.name {
                return true
            }
            if $0.name == shortName {
                return true
            }
            let availableShortName = $0.name.components(separatedBy: "/").last ?? $0.name
            return availableShortName == shortName
        })

        // Extract tap - pass through directly from available packages
        let tap = matchingPackage?.tap

        return HomebrewSearchResult(
            name: package.name,
            description: package.description,
            homepage: nil,
            license: nil,
            version: package.version,
            dependencies: nil,
            caveats: nil,
            tap: tap,
            fullName: nil,
            isDeprecated: false,
            deprecationReason: nil,
            isDisabled: false,
            disableDate: nil,
            conflictsWith: nil,
            isBottled: nil,
            isKegOnly: nil,
            kegOnlyReason: nil,
            buildDependencies: nil,
            aliases: nil,
            versionedFormulae: nil,
            requirements: nil,
            caskName: nil,
            autoUpdates: nil,
            artifacts: nil
        )
    }

    private func updateAllOutdated(packages: [HomebrewSearchResult]) {
        Task { @MainActor in
            isUpdatingAll = true
            defer { isUpdatingAll = false }

            for package in packages {
                printOS("Starting update for: \(package.name)")
                updatingPackages.insert(package.name)

                do {
                    try await HomebrewController.shared.upgradePackage(name: package.name)
                    printOS("Successfully updated: \(package.name)")

                    // Remove from outdated category immediately after successful update
                    removePackageFromOutdated(packageName: package.name)
                } catch {
                    printOS("Error updating package \(package.name): \(error)")
                }

                updatingPackages.remove(package.name)
                printOS("Finished update for: \(package.name)")
            }

            printOS("All updates complete. Reloading installed packages...")
            // Reload installed packages after all updates complete to refresh everything
            await brewManager.loadInstalledPackages()
        }
    }

    private func removePackageFromOutdated(packageName: String) {
        // Find and update the cached categories to remove this package from Outdated
        var updatedCategories = cachedCategories

        for (index, category) in updatedCategories.enumerated() {
            if category.title == "Outdated" {
                // Remove the package from this category
                let filteredPackages = category.packages.filter { $0.name != packageName }

                if filteredPackages.isEmpty {
                    // Remove the entire category if empty
                    updatedCategories.remove(at: index)
                } else {
                    // Update with filtered packages
                    updatedCategories[index] = (title: "Outdated", packages: filteredPackages)
                }
                break
            }
        }

        cachedCategories = updatedCategories
    }

    private func toggleCategoryCollapse(for category: String) {
        if collapsedCategories.contains(category) {
            collapsedCategories.remove(category)
        } else {
            collapsedCategories.insert(category)
        }
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                TextField("Search...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
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

            // Search type picker
            Picker("", selection: $searchType) {
                ForEach(HomebrewSearchType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
            .onChange(of: searchType) { _ in
                // Clear search when switching tabs
                searchQuery = ""
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var resultsCountBar: some View {
        if (searchType == .installed && !cachedCategories.isEmpty) || (!displayedResults.isEmpty) {
            HStack {
                if searchType == .installed {
                    // Count unique packages (exclude Outdated category since it's duplicates)
                    let totalCount = cachedCategories
                        .filter { $0.title != "Outdated" }
                        .reduce(0) { $0 + $1.packages.count }
                    Text("\(totalCount) package\(totalCount == 1 ? "" : "s")")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    if brewManager.isLoadingPackages {
                        Text("Loading...")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    Spacer()
                } else {
                    Text("\(displayedResults.count) result\(displayedResults.count == 1 ? "" : "s")")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        GeometryReader { geometry in
                    // Results List (full width)
                    VStack(alignment: .leading, spacing: 0) {
                        // Results or loading state
                        // Show loading if actively loading OR if data hasn't been loaded yet
                        let isLoading = (searchType == .installed && (brewManager.isLoadingPackages || !brewManager.hasLoadedInstalledPackages)) ||
                                       (searchType != .installed && (brewManager.isLoadingAvailablePackages || !brewManager.hasLoadedAvailablePackages))

                        if isLoading {
                            VStack(alignment: .center, spacing: 10) {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(1.5)

                                if searchType == .installed {
                                    Text("Loading installed packages...")
                                        .font(.title2)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                } else {
                                    Text("Loading available packages...")
                                        .font(.title2)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                }

                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else if (searchType == .installed && cachedCategories.isEmpty && !searchQuery.isEmpty) ||
                                  (searchType != .installed && displayedResults.isEmpty && !searchQuery.isEmpty) {
                            VStack(alignment: .center) {
                                Spacer()
                                Image(systemName: "exclamationmark.magnifyingglass")
                                    .font(.system(size: 50))
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                Text("No results found")
                                    .font(.title2)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                Text("Try a different search term")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    if searchType == .installed {
                                        // Show categorized view for installed packages
                                        ForEach(cachedCategories, id: \.title) { category in
                                            VStack(alignment: .leading, spacing: 8) {
                                                // Category header (collapsible)
                                                Button(action: {
                                                    withAnimation(.easeInOut(duration: animationEnabled ? 0.3 : 0)) {
                                                        toggleCategoryCollapse(for: category.title)
                                                    }
                                                }) {
                                                    HStack {
                                                        Image(systemName: collapsedCategories.contains(category.title) ? "chevron.right" : "chevron.down")
                                                            .font(.caption)
                                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                                            .frame(width: 10)

                                                        Text(category.title)
                                                            .font(.headline)
                                                            .fontWeight(.semibold)
                                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                                                        Text(verbatim: "(\(category.packages.count))")
                                                            .font(.caption)
                                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                                                        Spacer()

                                                        // Show "Update All" button for Outdated category if more than 1 package
                                                        if category.title == "Outdated" && category.packages.count > 1 {
                                                            Button {
                                                                updateAllOutdated(packages: category.packages)
                                                            } label: {
                                                                Text("Update All")
                                                                    .font(.caption)
                                                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                                                            }
                                                            .buttonStyle(.plain)
                                                        }
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                                .contentShape(Rectangle())
                                                .padding(.top, category.title == cachedCategories.first?.title ? 0 : 12)

                                                // Packages in category (only if not collapsed)
                                                if !collapsedCategories.contains(category.title) {
                                                    ForEach(category.packages) { result in
                                                        SearchResultRowView(
                                                            result: result,
                                                            isCask: brewManager.installedCasks.contains(where: { $0.name == result.name }),
                                                            onInfoTapped: {
                                                                let isCask = brewManager.installedCasks.contains(where: { $0.name == result.name })
                                                                onPackageSelected(result, isCask)
                                                            },
                                                            updatingPackages: updatingPackages
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        // Show flat list for Browse/Formulae/Casks
                                        ForEach(displayedResults) { result in
                                            SearchResultRowView(
                                                result: result,
                                                isCask: searchType == .casks || brewManager.allAvailableCasks.contains(where: { $0.name == result.name }),
                                                onInfoTapped: {
                                                    let isCask = searchType == .casks || brewManager.allAvailableCasks.contains(where: { $0.name == result.name })
                                                    onPackageSelected(result, isCask)
                                                },
                                                updatingPackages: updatingPackages
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                            .scrollIndicators(scrollIndicators ? .automatic : .never)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
            Task {
                // 1. Load installed packages only if not already loaded for this session
                if !brewManager.hasLoadedInstalledPackages {
                    await brewManager.loadInstalledPackages()
                } else if searchType == .installed {
                    // Data already loaded, just update categories for the view
                    updateCategorizedPackages()
                }
            }

            // 2. Load package names in separate background task (doesn't block UI)
            Task {
                if !brewManager.hasLoadedAvailablePackages {
                    await brewManager.loadAvailablePackages(appState: appState, forceRefresh: false)
                }
            }
        }
        .onChange(of: brewManager.isLoadingPackages) { isLoading in
            // Update categories when loading completes
            if !isLoading && searchType == .installed {
                updateCategorizedPackages()
            }
        }
        .onChange(of: brewManager.installedFormulae.count) { _ in
            // Update categories when installed formulae change
            if searchType == .installed {
                updateCategorizedPackages()
            }
        }
        .onChange(of: brewManager.installedCasks.count) { _ in
            // Update categories when installed casks change
            if searchType == .installed {
                updateCategorizedPackages()
            }
        }
        .onChange(of: brewManager.outdatedPackageNames) { _ in
            // Update categories when outdated packages change
            if searchType == .installed {
                updateCategorizedPackages()
            }
        }
        .onChange(of: searchQuery) { _ in
            if searchType == .installed {
                updateCategorizedPackages()
            }
        }
        .onChange(of: searchType) { newType in
            if newType == .installed {
                updateCategorizedPackages()
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchBar
            resultsCountBar
            listContent
        }
    }
}

// MARK: - Search Result Row View

struct SearchResultRowView: View {
    let result: HomebrewSearchResult
    let isCask: Bool
    let onInfoTapped: () -> Void
    let updatingPackages: Set<String>
    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false
    @State private var isInstalling: Bool = false
    @State private var isUninstalling: Bool = false
    @State private var showInstallAlert: Bool = false
    @State private var showUpdateAlert: Bool = false
    @State private var showUninstallAlert: Bool = false
    @State private var localPinState: Bool?  // Local state for immediate UI update

    private var isAlreadyInstalled: Bool {
        // Extract short name from full name (e.g., "mhaeuser/mhaeuser/battery-toolkit" -> "battery-toolkit")
        let shortName = result.name.components(separatedBy: "/").last ?? result.name

        if isCask {
            return brewManager.installedCasks.contains { installedPackage in
                installedPackage.name == result.name || installedPackage.name == shortName
            }
        } else {
            return brewManager.installedFormulae.contains { installedPackage in
                installedPackage.name == result.name || installedPackage.name == shortName
            }
        }
    }

    private var isOutdated: Bool {
        guard isAlreadyInstalled else { return false }

        let shortName = result.name.components(separatedBy: "/").last ?? result.name

        // Check if package is in the outdated set from brew outdated
        return brewManager.outdatedPackageNames.contains(result.name) ||
               brewManager.outdatedPackageNames.contains(shortName)
    }

    private var isPinned: Bool {
        guard !isCask && isAlreadyInstalled else { return false }

        // Use local state if available (for immediate UI update)
        if let localState = localPinState {
            return localState
        }

        let shortName = result.name.components(separatedBy: "/").last ?? result.name

        // Check if package is pinned in installed formulae
        return brewManager.installedFormulae.first(where: { $0.name == result.name || $0.name == shortName })?.isPinned ?? false
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Package icon
            ZStack {
                Circle()
                    .fill((isCask ? Color.purple : Color.green).opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: isCask ? "macwindow" : "terminal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isCask ? .purple : .green)
            }

            // Package name and description
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(result.name)
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    // Show version for installed packages
                    if isAlreadyInstalled, let version = result.version {
                        Text("(\(version))")
                            .font(.footnote)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }

                if let description = result.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Tap indicator (if from third-party tap)
            if let tap = result.tap, tap != "homebrew/core" && tap != "homebrew/cask" {
                Image(systemName: "spigot")
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .help("Installed from tap: \(tap)")
            }

            // Pin button (formulae only, and only if installed)
            if !isCask && isAlreadyInstalled {
                Button {
                    // Capture current state before toggling
                    let currentlyPinned = isPinned

                    // Toggle local state immediately for instant UI feedback
                    localPinState = !currentlyPinned

                    // Perform actual pin/unpin in background
                    Task {
                        do {
                            if currentlyPinned {
                                try await HomebrewController.shared.unpinPackage(name: result.name)
                            } else {
                                try await HomebrewController.shared.pinPackage(name: result.name)
                            }
                        } catch {
                            printOS("Failed to toggle pin: \(error)")
                            // Revert local state on error
                            localPinState = currentlyPinned
                        }
                    }
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 14))
                        .foregroundStyle(isPinned ? .orange : ThemeColors.shared(for: colorScheme).secondaryText)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin version" : "Pin version")
            }

            // Info button
            Button {
                onInfoTapped()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
            }
            .buttonStyle(.plain)

            // Install/Installed/Update status
            if isInstalling || updatingPackages.contains(result.name) {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Installing...")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            } else if isUninstalling {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Uninstalling...")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            } else if isOutdated {
                Button {
                    showUpdateAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Update")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .frame(width: 65, alignment: .trailing)
                }
                .buttonStyle(.plain)

            } else if isAlreadyInstalled {
                Button {
                    showUninstallAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                        Text("Uninstall")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .frame(width: 75, alignment: .trailing)
                }
                .buttonStyle(.plain)
            } else {
                Button("Install") {
                    showInstallAlert = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)

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
        .alert("Install \(result.name)?", isPresented: $showInstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Install") {
                Task { @MainActor in
                    isInstalling = true
                    defer { isInstalling = false }

                    do {
                        try await HomebrewController.shared.installPackage(name: result.name, cask: isCask)
                        await brewManager.loadInstalledPackages()
                    } catch {
                        printOS("Error installing package \(result.name): \(error)")
                    }
                }
            }
        } message: {
            Text("This will install \(result.name) using Homebrew. This may take several minutes.")
        }
        .alert("Update \(result.name)?", isPresented: $showUpdateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Update") {
                Task { @MainActor in
                    isInstalling = true
                    defer { isInstalling = false }

                    do {
                        try await HomebrewController.shared.upgradePackage(name: result.name)
                        await brewManager.loadInstalledPackages()
                    } catch {
                        printOS("Error updating package \(result.name): \(error)")
                    }
                }
            }
        } message: {
            Text("This will upgrade \(result.name) to the latest version using Homebrew. This may take several minutes.")
        }
        .alert("Uninstall \(result.name)?", isPresented: $showUninstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                Task { @MainActor in
                    isUninstalling = true
                    defer { isUninstalling = false }

                    do {
                        try await HomebrewUninstaller.shared.uninstallPackage(name: result.name, cask: isCask, zap: true)

                        // Remove from installed lists instead of full refresh
                        let shortName = result.name.components(separatedBy: "/").last ?? result.name
                        if isCask {
                            brewManager.installedCasks.removeAll { $0.name == result.name || $0.name == shortName }
                        } else {
                            brewManager.installedFormulae.removeAll { $0.name == result.name || $0.name == shortName }
                        }
                        brewManager.outdatedPackageNames.remove(result.name)
                        brewManager.outdatedPackageNames.remove(shortName)
                    } catch {
                        printOS("Error uninstalling package \(result.name): \(error)")
                    }
                }
            }
        } message: {
            Text("This will completely uninstall \(result.name) and remove all associated files. This action cannot be undone.")
        }
    }
}

// MARK: - Package Details Drawer

struct PackageDetailsDrawer: View {
    let package: HomebrewSearchResult
    let isCask: Bool
    let onClose: () -> Void

    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @State private var analytics: HomebrewAnalytics?
    @State private var isLoadingAnalytics: Bool = false
    @State private var isLoadingFullPackageInfo: Bool = false
    @State private var isInstalling: Bool = false
    @State private var showInstallAlert: Bool = false
    @State private var fullPackageInfo: HomebrewSearchResult?  // Full package data from API

    private var isAlreadyInstalled: Bool {
        let shortName = package.name.components(separatedBy: "/").last ?? package.name
        if isCask {
            return brewManager.installedCasks.contains { $0.name == package.name || $0.name == shortName }
        } else {
            return brewManager.installedFormulae.contains { $0.name == package.name || $0.name == shortName }
        }
    }


    // Use full package info if available, otherwise use the passed-in package
    private var displayedPackage: HomebrewSearchResult {
        return fullPackageInfo ?? package
    }

    // Check if package data is incomplete (from installed package conversion)
    private var needsFullData: Bool {
        return package.license == nil && package.dependencies == nil && package.caveats == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content - Show loading OR details
            if isLoadingAnalytics || isLoadingFullPackageInfo {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(isLoadingFullPackageInfo ? "Loading package details..." : "Loading package information...")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Scrollable details
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Package header
                        PackageHeaderSection(package: displayedPackage, isCask: isCask, colorScheme: colorScheme)

                        // Installed info (if package is installed)
                        // Note: InstalledPackage model is now minimal (name+desc only)
                        // No path/size info available in list view
                        // if let installedInfo = installedPackageInfo {
                        //     InstalledInfoSection(packageInfo: installedInfo, colorScheme: colorScheme)
                        // }

                        // Deprecation warning
                        if displayedPackage.isDeprecated || displayedPackage.isDisabled {
                            DeprecationWarningBanner(
                                deprecated: displayedPackage.isDeprecated,
                                reason: displayedPackage.deprecationReason,
                                disableDate: displayedPackage.disableDate,
                                colorScheme: colorScheme
                            )
                        }

                        // Analytics
                        if let analytics = analytics {
                            AnalyticsSection(analytics: analytics, isCask: isCask, colorScheme: colorScheme)
                        }

                        Divider()

                        // Basic info
                        DetailsSectionView(package: displayedPackage, isCask: isCask, colorScheme: colorScheme)

                        // Dependencies
                        if (displayedPackage.dependencies != nil && !displayedPackage.dependencies!.isEmpty) ||
                           (displayedPackage.buildDependencies != nil && !displayedPackage.buildDependencies!.isEmpty) {
                            DependenciesSection(
                                runtimeDeps: displayedPackage.dependencies ?? [],
                                buildDeps: displayedPackage.buildDependencies ?? [],
                                installedFormulae: brewManager.installedFormulae.map { $0.name },
                                colorScheme: colorScheme
                            )
                        }

                        // Caveats
                        if let caveats = displayedPackage.caveats {
                            CaveatsSection(caveats: caveats, colorScheme: colorScheme)
                        }
                    }
                    .padding()
                }
                .scrollIndicators(.visible)

                // Install button pinned to bottom (outside ScrollView)
                InstallButtonSection(
                    package: displayedPackage,
                    isCask: isCask,
                    isInstalling: $isInstalling,
                    isAlreadyInstalled: isAlreadyInstalled,
                    showInstallAlert: $showInstallAlert,
                    brewManager: brewManager,
                    colorScheme: colorScheme
                )
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadFullPackageInfoIfNeeded()
            loadAnalytics()
            loadInstalledPackagesIfNeeded()
        }
    }

    private func loadFullPackageInfoIfNeeded() {
        // If package data is incomplete, fetch full info from API
        guard needsFullData else { return }

        Task {
            isLoadingFullPackageInfo = true

            do {
                // Extract short name for matching (e.g., "homebrew/core/node" -> "node")
                let shortName = package.name.components(separatedBy: "/").last ?? package.name

                // Fetch complete package info from Homebrew API
                fullPackageInfo = try await HomebrewController.shared.getPackageInfo(
                    name: shortName,
                    cask: isCask
                )
            } catch {
                printOS("Failed to fetch package info for \(package.name): \(error)")
                // Keep using partial info from installed package
            }

            isLoadingFullPackageInfo = false
        }
    }

    private func loadAnalytics() {
        // Skip analytics for tap packages (only available for homebrew/core and homebrew/cask)
        guard let tap = package.tap, tap == "homebrew/core" || tap == "homebrew/cask" else {
            return
        }

        Task {
            isLoadingAnalytics = true
            do {
                analytics = try await HomebrewController.shared.getAnalytics(
                    name: package.name,
                    cask: isCask
                )
            } catch {
                printOS("Failed to fetch analytics: \(error)")
            }
            isLoadingAnalytics = false
        }
    }

    private func loadInstalledPackagesIfNeeded() {
        // If installed packages haven't been loaded yet, load them for dependency checking
        if brewManager.installedFormulae.isEmpty && brewManager.installedCasks.isEmpty {
            Task {
                await brewManager.loadInstalledPackages()
            }
        }
    }
}

// MARK: - Package Header Section

struct PackageHeaderSection: View {
    let package: HomebrewSearchResult
    let isCask: Bool
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Package name
            VStack(alignment: .leading, spacing: 4) {
                // Cask name (if available and different from token)
                if let caskNames = package.caskName, !caskNames.isEmpty {
                    Text(caskNames.joined(separator: ", "))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }

                // Package token/name
                Text(package.name)
                    .font(package.caskName != nil ? .callout : .title2)
                    .fontWeight(package.caskName != nil ? .medium : .bold)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            }

            // Version with auto-updates badge
            if let version = package.version {
                HStack(spacing: 4) {
                    Text("v\(version)")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    if let autoUpdates = package.autoUpdates, autoUpdates {
                        Text("(auto_updates)")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }
}

// MARK: - Deprecation Warning Banner

struct DeprecationWarningBanner: View {
    let deprecated: Bool
    let reason: String?
    let disableDate: String?
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("DEPRECATED")
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)

            if let reason = reason {
                Text("Reason: \(formatReason(reason))")
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            if let date = disableDate {
                Text("Will be disabled on \(date)")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.8))
        .cornerRadius(8)
    }

    func formatReason(_ reason: String) -> String {
        switch reason {
        case "fails_gatekeeper_check":
            return "Does not pass macOS Gatekeeper check"
        default:
            return reason.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - Analytics Section

struct AnalyticsSection: View {
    let analytics: HomebrewAnalytics
    let isCask: Bool
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📊 Popularity")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

            VStack(alignment: .leading, spacing: 4) {
                if let installs365d = analytics.install365d {
                    Text("365d: \(installs365d.formatted())")
                }
                if let installs90d = analytics.install90d {
                    Text("90d: \(installs90d.formatted())")
                }
                if let installs30d = analytics.install30d {
                    Text("30d: \(installs30d.formatted())")
                }
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

            // Formula-specific: install-on-request
            if !isCask {
                if let installOnRequest365d = analytics.installOnRequest365d {
                    Text("install-on-request: \(installOnRequest365d.formatted()) (365d)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .padding(.top, 4)
                }

                if let buildError30d = analytics.buildError30d, buildError30d > 0 {
                    Text("build-error: \(buildError30d) (30d)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(ThemeColors.shared(for: colorScheme).accent.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Details Section

struct DetailsSectionView: View {
    let package: HomebrewSearchResult
    let isCask: Bool
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                Text(package.description ?? "N/A")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(package.description == nil ? 0.5 : 1.0))
            }

            // Homepage
            VStack(alignment: .leading, spacing: 4) {
                Text("Homepage")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                if let homepage = package.homepage, let url = URL(string: homepage) {
                    Link(homepage, destination: url)
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                } else {
                    Text("N/A")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
                }
            }

            // License
            DetailRow(label: "License", value: package.license ?? "N/A", colorScheme: colorScheme, isNA: package.license == nil)

            // Tap
            DetailRow(label: "Tap", value: package.tap ?? "N/A", colorScheme: colorScheme, isNA: package.tap == nil)

            // Installation type (formulae only)
            if !isCask {
                DetailRow(
                    label: "Installation",
                    value: package.isBottled == true ? "Bottled (pre-built binary)" : (package.isBottled == false ? "From source" : "N/A"),
                    colorScheme: colorScheme,
                    isNA: package.isBottled == nil
                )
            }

            // Keg-only (formulae only)
            if !isCask {
                if let isKegOnly = package.isKegOnly, isKegOnly {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🔒 Keg-Only")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        Text(package.kegOnlyReason ?? "Not symlinked to Homebrew prefix")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            // Requirements
            if !isCask {
                DetailRow(label: "Requirements", value: package.requirements ?? "N/A", colorScheme: colorScheme, isNA: package.requirements == nil)
            }

            // Conflicts
            if let conflicts = package.conflictsWith, !conflicts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ Conflicts With")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    Text(conflicts.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            } else {
                DetailRow(label: "Conflicts", value: "N/A", colorScheme: colorScheme, isNA: true)
            }

            // Artifacts (casks only)
            if isCask {
                if let artifacts = package.artifacts, !artifacts.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Artifacts")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        ForEach(artifacts, id: \.self) { artifact in
                            Text("• \(artifact)")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                    }
                } else {
                    DetailRow(label: "Artifacts", value: "N/A", colorScheme: colorScheme, isNA: true)
                }
            }

            // Aliases (formulae only)
            if !isCask {
                DetailRow(
                    label: "Aliases",
                    value: (package.aliases?.isEmpty == false) ? package.aliases!.joined(separator: ", ") : "N/A",
                    colorScheme: colorScheme,
                    isNA: package.aliases?.isEmpty != false
                )
            }

            // Versioned formulae (formulae only)
            if !isCask {
                DetailRow(
                    label: "Other Versions",
                    value: (package.versionedFormulae?.isEmpty == false) ? package.versionedFormulae!.joined(separator: ", ") : "N/A",
                    colorScheme: colorScheme,
                    isNA: package.versionedFormulae?.isEmpty != false
                )
            }
        }
    }
}

// MARK: - Dependencies Section

struct DependenciesSection: View {
    let runtimeDeps: [String]
    let buildDeps: [String]
    let installedFormulae: [String]
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dependencies")
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

            if !runtimeDeps.isEmpty {
                if !buildDeps.isEmpty {
                    Text("Runtime:")
                        .font(.caption2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .padding(.leading, 8)
                }

                ForEach(runtimeDeps, id: \.self) { dep in
                    HStack(spacing: 4) {
                        Text("•")
                        Text(dep)
                        if installedFormulae.contains(dep) {
                            Text("✓")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    .padding(.leading, 8)
                }
            }

            if !buildDeps.isEmpty {
                Text("Build only:")
                    .font(.caption2)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .padding(.leading, 8)
                    .padding(.top, 4)

                ForEach(buildDeps, id: \.self) { dep in
                    HStack(spacing: 4) {
                        Text("•")
                        Text(dep)
                        if installedFormulae.contains(dep) {
                            Text("✓")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    .padding(.leading, 8)
                }
            }
        }
    }
}

// MARK: - Caveats Section

struct CaveatsSection: View {
    let caveats: String
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notes")
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            Text(caveats)
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
        }
    }
}

// MARK: - Install Button Section

struct InstallButtonSection: View {
    let package: HomebrewSearchResult
    let isCask: Bool
    @Binding var isInstalling: Bool
    let isAlreadyInstalled: Bool
    @Binding var showInstallAlert: Bool
    let brewManager: HomebrewManager
    let colorScheme: ColorScheme
    @State private var showUninstallAlert: Bool = false
    @State private var isUninstalling: Bool = false

    private var isOutdated: Bool {
        guard isAlreadyInstalled else { return false }
        let shortName = package.name.components(separatedBy: "/").last ?? package.name

        // Find the installed package
        let installedPackage: InstalledPackage?
        if isCask {
            installedPackage = brewManager.installedCasks.first { $0.name == package.name || $0.name == shortName }
        } else {
            installedPackage = brewManager.installedFormulae.first { $0.name == package.name || $0.name == shortName }
        }

        guard let installed = installedPackage,
              let installedVersion = installed.version,
              let latestVersion = package.version else {
            return false
        }

        // Compare versions - simple string comparison
        return installedVersion != latestVersion
    }

    var body: some View {
        if isInstalling {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Installing...")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .frame(maxWidth: .infinity)
        } else if isUninstalling {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Uninstalling...")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .frame(maxWidth: .infinity)
        } else if isOutdated {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.orange)
                Text("Update")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .frame(maxWidth: .infinity)
        } else if isAlreadyInstalled {
            Button("Uninstall") {
                showUninstallAlert = true
            }
            .buttonStyle(ControlGroupButtonStyle(
                foregroundColor: .red,
                shape: Capsule(style: .continuous),
                level: .primary,
                skipControlGroup: true
            ))
            .frame(maxWidth: .infinity)
            .alert("Uninstall \(package.name)?", isPresented: $showUninstallAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Uninstall", role: .destructive) {
                    Task { @MainActor in
                        isUninstalling = true
                        defer { isUninstalling = false }

                        do {
                            try await HomebrewUninstaller.shared.uninstallPackage(name: package.name, cask: isCask, zap: true)

                            // Remove from installed lists instead of full refresh
                            let shortName = package.name.components(separatedBy: "/").last ?? package.name
                            if isCask {
                                brewManager.installedCasks.removeAll { $0.name == package.name || $0.name == shortName }
                            } else {
                                brewManager.installedFormulae.removeAll { $0.name == package.name || $0.name == shortName }
                            }
                            brewManager.outdatedPackageNames.remove(package.name)
                            brewManager.outdatedPackageNames.remove(shortName)
                        } catch {
                            printOS("Error uninstalling package \(package.name): \(error)")
                        }
                    }
                }
            } message: {
                Text("This will completely uninstall \(package.name) and remove all associated files. This action cannot be undone.")
            }
        } else {
            Button("Install") {
                showInstallAlert = true
            }
            .buttonStyle(ControlGroupButtonStyle(
                foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                shape: Capsule(style: .continuous),
                level: .primary,
                skipControlGroup: true
            ))
            .frame(maxWidth: .infinity)
            .alert("Install \(package.name)?", isPresented: $showInstallAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Install") {
                    Task { @MainActor in
                        isInstalling = true
                        defer { isInstalling = false }

                        do {
                            try await HomebrewController.shared.installPackage(name: package.name, cask: isCask)
                            await brewManager.loadInstalledPackages()
                        } catch {
                            printOS("Error installing package \(package.name): \(error)")
                        }
                    }
                }
            } message: {
                Text("This will install \(package.name) using Homebrew. This may take several minutes.")
            }
        }
    }
}

// MARK: - Detail Row Helper

struct DetailRow: View {
    let label: String
    let value: String
    let colorScheme: ColorScheme
    var isNA: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            Text(value)
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(isNA ? 0.5 : 1.0))
        }
    }
}

// MARK: - Installed Info Section

struct InstalledInfoSection: View {
    let packageInfo: HomebrewPackageInfo
    let colorScheme: ColorScheme

    private var sizeText: String {
        if let sizeInBytes = packageInfo.sizeInBytes {
            return packageInfo.formattedSize(size: sizeInBytes)
        } else if let path = packageInfo.installedPath,
                  let dirSize = directorySize(at: path) {
            let formatter = ByteCountFormatter()
            formatter.allowsNonnumericFormatting = false
            formatter.countStyle = .file
            return formatter.string(fromByteCount: dirSize)
        }
        return "size unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✅ Installed")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

            if let path = packageInfo.installedPath, let count = packageInfo.fileCount {
                Text("\(path) (\(count) file\(count == 1 ? "" : "s"), \(sizeText))")
                    .font(.caption2)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }

    private func directorySize(at path: String) -> Int64? {
        guard let enumerator = FileManager.default.enumerator(atPath: path) else {
            return nil
        }

        var totalSize: Int64 = 0
        let basePath = path

        while let file = enumerator.nextObject() as? String {
            let filePath = (basePath as NSString).appendingPathComponent(file)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }

        return totalSize > 0 ? totalSize : nil
    }
}
