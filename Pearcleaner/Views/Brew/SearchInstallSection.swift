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
    case available = "Available"
}

struct SearchInstallSection: View {
    let onPackageSelected: (HomebrewSearchResult, Bool) -> Void

    @EnvironmentObject var brewManager: HomebrewManager
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var searchQuery: String = ""
    @State private var searchType: HomebrewSearchType = .installed
    @State private var collapsedCategories: Set<String> = []
    @State private var updatingPackages: Set<String> = []
    @State private var isUpdatingAll: Bool = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    private var displayedResults: [HomebrewSearchResult] {
        if searchType == .available {
            // Flat list for Available tab - all packages combined
            let allPackages = brewManager.allAvailableFormulae + brewManager.allAvailableCasks

            if searchQuery.isEmpty {
                return allPackages
            } else {
                return allPackages.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
            }
        } else {
            // Installed uses categorized view
            return []
        }
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
            deprecationDate: nil,
            isDisabled: false,
            disableDate: nil,
            disableReason: nil,
            conflictsWith: nil,
            conflictsWithReasons: nil,
            isBottled: nil,
            isKegOnly: nil,
            kegOnlyReason: nil,
            buildDependencies: nil,
            optionalDependencies: nil,
            recommendedDependencies: nil,
            usesFromMacos: nil,
            aliases: nil,
            versionedFormulae: nil,
            requirements: nil,
            caskName: nil,
            autoUpdates: nil,
            artifacts: nil,
            url: nil,
            appcast: nil
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

                    // Remove from outdated map and category immediately
                    let shortName = package.name.components(separatedBy: "/").last ?? package.name
                    brewManager.outdatedPackagesMap.removeValue(forKey: package.name)
                    brewManager.outdatedPackagesMap.removeValue(forKey: shortName)
                    brewManager.installedByCategory[.outdated]?.removeAll { $0.name == package.name || $0.name == shortName }
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
            .fixedSize()
            .onChange(of: searchType) { _ in
                // Clear search when switching tabs
                searchQuery = ""
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var resultsCountBar: some View {
        HStack {
            let totalCount = searchType == .installed
                ? (brewManager.installedFormulae.count + brewManager.installedCasks.count)
                : (brewManager.allAvailableFormulae.count + brewManager.allAvailableCasks.count)

            Text("\(totalCount) package\(totalCount == 1 ? "" : "s")")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

            // Show outdated count for Installed tab
            if searchType == .installed {
                let outdatedCount = brewManager.outdatedPackagesMap.count
                if outdatedCount > 0 {
                    Text(verbatim: "|")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Text("\(outdatedCount) outdated")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }

            if (searchType == .installed && brewManager.isLoadingPackages) ||
               (searchType == .available && brewManager.isLoadingAvailablePackages) {
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var listContent: some View {
        GeometryReader { geometry in
                    // Results List (full width)
                    VStack(alignment: .leading, spacing: 0) {
                        // Results or loading state
                        if ((searchType == .installed && brewManager.installedFormulae.isEmpty && brewManager.installedCasks.isEmpty) || (searchType == .available && displayedResults.isEmpty)) && !searchQuery.isEmpty {
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
                                        // Show categorized view for installed packages (matches Updater view pattern)
                                        // Outdated category
                                        let outdatedPackages = brewManager.installedByCategory[.outdated] ?? []
                                        let filteredOutdated = searchQuery.isEmpty ? outdatedPackages : outdatedPackages.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }

                                        InstalledCategoryView(
                                            category: .outdated,
                                            packages: filteredOutdated,
                                            isLoading: brewManager.isLoadingOutdated,
                                            collapsed: filteredOutdated.isEmpty || collapsedCategories.contains("Outdated"),
                                            onToggle: {
                                                guard !filteredOutdated.isEmpty && !brewManager.isLoadingOutdated else { return }
                                                withAnimation(.easeInOut(duration: animationEnabled ? 0.3 : 0)) {
                                                    toggleCategoryCollapse(for: "Outdated")
                                                }
                                            },
                                            isFirst: true,
                                            onPackageSelected: onPackageSelected,
                                            updatingPackages: updatingPackages,
                                            brewManager: brewManager,
                                            onUpdateAll: filteredOutdated.count > 1 ? {
                                                updateAllOutdated(packages: filteredOutdated)
                                            } : nil,
                                            colorScheme: colorScheme
                                        )

                                        // Formulae category
                                        let formulaePackages = brewManager.installedByCategory[.formulae] ?? []
                                        let filteredFormulae = searchQuery.isEmpty ? formulaePackages : formulaePackages.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }

                                        InstalledCategoryView(
                                            category: .formulae,
                                            packages: filteredFormulae,
                                            isLoading: brewManager.isLoadingPackages,
                                            collapsed: filteredFormulae.isEmpty || collapsedCategories.contains("Formulae"),
                                            onToggle: {
                                                guard !filteredFormulae.isEmpty && !brewManager.isLoadingPackages else { return }
                                                withAnimation(.easeInOut(duration: animationEnabled ? 0.3 : 0)) {
                                                    toggleCategoryCollapse(for: "Formulae")
                                                }
                                            },
                                            isFirst: false,
                                            onPackageSelected: onPackageSelected,
                                            updatingPackages: updatingPackages,
                                            brewManager: brewManager,
                                            onUpdateAll: nil,
                                            colorScheme: colorScheme
                                        )

                                        // Casks category
                                        let casksPackages = brewManager.installedByCategory[.casks] ?? []
                                        let filteredCasks = searchQuery.isEmpty ? casksPackages : casksPackages.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }

                                        InstalledCategoryView(
                                            category: .casks,
                                            packages: filteredCasks,
                                            isLoading: brewManager.isLoadingPackages,
                                            collapsed: filteredCasks.isEmpty || collapsedCategories.contains("Casks"),
                                            onToggle: {
                                                guard !filteredCasks.isEmpty && !brewManager.isLoadingPackages else { return }
                                                withAnimation(.easeInOut(duration: animationEnabled ? 0.3 : 0)) {
                                                    toggleCategoryCollapse(for: "Casks")
                                                }
                                            },
                                            isFirst: false,
                                            onPackageSelected: onPackageSelected,
                                            updatingPackages: updatingPackages,
                                            brewManager: brewManager,
                                            onUpdateAll: nil,
                                            colorScheme: colorScheme
                                        )
                                    } else {
                                        // Show categorized view for Available tab (matches Installed/Updater view pattern)
                                        // Formulae category
                                        let formulaePackages = brewManager.availableByCategory[.formulae] ?? []
                                        let filteredFormulae = searchQuery.isEmpty ? formulaePackages : formulaePackages.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }

                                        if !filteredFormulae.isEmpty {
                                            AvailableCategoryView(
                                                category: .formulae,
                                                packages: filteredFormulae,
                                                collapsed: collapsedCategories.contains("Formulae"),
                                                onToggle: {
                                                    withAnimation(.easeInOut(duration: animationEnabled ? 0.3 : 0)) {
                                                        toggleCategoryCollapse(for: "Formulae")
                                                    }
                                                },
                                                isFirst: true,
                                                onPackageSelected: onPackageSelected,
                                                updatingPackages: updatingPackages,
                                                brewManager: brewManager,
                                                colorScheme: colorScheme
                                            )
                                        }

                                        // Casks category
                                        let casksPackages = brewManager.availableByCategory[.casks] ?? []
                                        let filteredCasks = searchQuery.isEmpty ? casksPackages : casksPackages.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }

                                        if !filteredCasks.isEmpty {
                                            AvailableCategoryView(
                                                category: .casks,
                                                packages: filteredCasks,
                                                collapsed: collapsedCategories.contains("Casks"),
                                                onToggle: {
                                                    withAnimation(.easeInOut(duration: animationEnabled ? 0.3 : 0)) {
                                                        toggleCategoryCollapse(for: "Casks")
                                                    }
                                                },
                                                isFirst: false,
                                                onPackageSelected: onPackageSelected,
                                                updatingPackages: updatingPackages,
                                                brewManager: brewManager,
                                                colorScheme: colorScheme
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                                .padding(.bottom, 20)
                            }
                            .id(searchType) // Give each tab its own scroll identity
                            .scrollIndicators(scrollIndicators ? .automatic : .never)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
            Task {
                // Load installed packages if not already loaded
                if !brewManager.hasLoadedInstalledPackages {
                    await brewManager.loadInstalledPackages()
                }
            }

            // Load available packages in separate background task (doesn't block UI)
            Task {
                if !brewManager.hasLoadedAvailablePackages {
                    await brewManager.loadAvailablePackages(appState: appState, forceRefresh: false)
                }
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
        return brewManager.outdatedPackagesMap.keys.contains(result.name) ||
               brewManager.outdatedPackagesMap.keys.contains(shortName)
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

    @ViewBuilder
    private var actionButtons: some View {
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
            HStack(spacing: 8) {
                Button("Update") {
                    showUpdateAlert = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)

                Button("Uninstall") {
                    showUninstallAlert = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .frame(alignment: .trailing)
        } else if isAlreadyInstalled {
            Button("Uninstall") {
                showUninstallAlert = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        } else {
            Button("Install") {
                showInstallAlert = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
        }
    }

    @ViewBuilder
    private var secondaryActionButtons: some View {
        // Tap indicator (custom taps only)
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

                        // Update the installed formula's isPinned status
                        await MainActor.run {
                            let shortName = result.name.components(separatedBy: "/").last ?? result.name
                            if let index = brewManager.installedFormulae.firstIndex(where: {
                                $0.name == result.name || $0.name == shortName
                            }) {
                                var updatedFormula = brewManager.installedFormulae[index]
                                updatedFormula.isPinned = !currentlyPinned
                                brewManager.installedFormulae[index] = updatedFormula
                            }
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
                        // Check if package is outdated and show update arrow with versions
                        if let versions = brewManager.getOutdatedVersions(for: result.name) {
                            Text(verbatim: "(\(versions.installed.cleanBrewVersionForDisplay()) → \(versions.available.cleanBrewVersionForDisplay()))")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        } else {
                            Text(verbatim: "(\(version))")
                                .font(.footnote)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
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

            // Install/Uninstall/Update action buttons
            actionButtons

            // Tap indicator, Pin and Info buttons
            secondaryActionButtons



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

                        // Refresh AppState.sortedApps to include newly installed GUI app (casks only)
                        if isCask {
                            let folderPaths = FolderSettingsManager.shared.folderPaths
                            flushBundleCaches(for: AppState.shared.sortedApps)
                            await loadAppsAsync(folderPaths: folderPaths)
                        }
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

                        // Remove from outdated map immediately after successful update
                        let shortName = result.name.components(separatedBy: "/").last ?? result.name
                        brewManager.outdatedPackagesMap.removeValue(forKey: result.name)
                        brewManager.outdatedPackagesMap.removeValue(forKey: shortName)

                        await brewManager.loadInstalledPackages()

                        // Refresh AppState.sortedApps to reflect updated version (casks only)
                        if isCask {
                            let folderPaths = FolderSettingsManager.shared.folderPaths
                            flushBundleCaches(for: AppState.shared.sortedApps)
                            await loadAppsAsync(folderPaths: folderPaths)
                        }
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

                            // Refresh AppState.sortedApps to remove uninstalled app (casks only)
                            let folderPaths = FolderSettingsManager.shared.folderPaths
                            flushBundleCaches(for: AppState.shared.sortedApps)
                            await loadAppsAsync(folderPaths: folderPaths)
                        } else {
                            brewManager.installedFormulae.removeAll { $0.name == result.name || $0.name == shortName }
                        }
                        brewManager.outdatedPackagesMap.removeValue(forKey: result.name)
                        brewManager.outdatedPackagesMap.removeValue(forKey: shortName)
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
    @State private var packageDetails: PackageDetailsType?  // Type-safe package details

    private var isAlreadyInstalled: Bool {
        let shortName = package.name.components(separatedBy: "/").last ?? package.name
        if isCask {
            return brewManager.installedCasks.contains { $0.name == package.name || $0.name == shortName }
        } else {
            return brewManager.installedFormulae.contains { $0.name == package.name || $0.name == shortName }
        }
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
                    Text("Loading package details...")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let packageDetails = packageDetails {
                // Render type-safe package details
                switch packageDetails {
                case .formula(let formula):
                    FormulaDetailsView(
                        formula: formula,
                        analytics: analytics,
                        isInstalling: $isInstalling,
                        isAlreadyInstalled: isAlreadyInstalled,
                        showInstallAlert: $showInstallAlert,
                        brewManager: brewManager,
                        colorScheme: colorScheme
                    )
                case .cask(let cask):
                    CaskDetailsView(
                        cask: cask,
                        analytics: analytics,
                        isInstalling: $isInstalling,
                        isAlreadyInstalled: isAlreadyInstalled,
                        showInstallAlert: $showInstallAlert,
                        brewManager: brewManager,
                        colorScheme: colorScheme
                    )
                }
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
        Task {
            isLoadingFullPackageInfo = true

            do {
                // Extract short name for matching (e.g., "homebrew/core/node" -> "node")
                let shortName = package.name.components(separatedBy: "/").last ?? package.name

                // Fetch type-safe package details from Homebrew API
                packageDetails = try await HomebrewController.shared.getPackageDetailsTyped(
                    name: shortName,
                    cask: isCask
                )
            } catch {
                printOS("Failed to fetch package info for \(package.name): \(error)")
            }

            isLoadingFullPackageInfo = false
        }
    }

    private func loadAnalytics() {
        // Skip analytics for third-party tap packages (only available for homebrew/core and homebrew/cask)
        // If tap is nil, assume it's from the default tap (homebrew/core for formulae, homebrew/cask for casks)
        let tap = package.tap ?? (isCask ? "homebrew/cask" : "homebrew/core")
        guard tap == "homebrew/core" || tap == "homebrew/cask" else {
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

// MARK: - Formula Details View

struct FormulaDetailsView: View {
    let formula: FormulaDetails
    let analytics: HomebrewAnalytics?
    @Binding var isInstalling: Bool
    let isAlreadyInstalled: Bool
    @Binding var showInstallAlert: Bool
    let brewManager: HomebrewManager
    let colorScheme: ColorScheme

    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    @State private var fileCount: Int?
    @State private var totalSize: Int64?

    var body: some View {
        ScrollView(.vertical, showsIndicators: scrollIndicators) {
            VStack(alignment: .leading, spacing: 16) {
                    // Package name and version
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formula.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                        if let version = formula.version {
                            HStack(spacing: 4) {
                                Text(verbatim: "v\(version)")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                                // Show pinned icon if this formula is pinned
                                if let installedFormula = brewManager.installedFormulae.first(where: {
                                    $0.name == formula.name || $0.name == formula.name.components(separatedBy: "/").last
                                }), installedFormula.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }

                // Deprecation/Disable warnings
                if formula.isDeprecated || formula.isDisabled {
                    DeprecationDisableWarning(
                        isDeprecated: formula.isDeprecated,
                        deprecationReason: formula.deprecationReason,
                        deprecationDate: formula.deprecationDate,
                        isDisabled: formula.isDisabled,
                        disableReason: formula.disableReason,
                        disableDate: formula.disableDate,
                        colorScheme: colorScheme
                    )
                }

                // Replacement suggestions
                ReplacementSuggestionsSection(
                    deprecationReplacementFormula: formula.deprecationReplacementFormula,
                    deprecationReplacementCask: formula.deprecationReplacementCask,
                    disableReplacementFormula: formula.disableReplacementFormula,
                    disableReplacementCask: formula.disableReplacementCask,
                    brewManager: brewManager,
                    colorScheme: colorScheme
                )

                // Analytics
                if let analytics = analytics {
                    AnalyticsSection(analytics: analytics, isCask: false, colorScheme: colorScheme)
                }

                Divider()

                // Service info
                if let service = formula.service {
                    ServiceInfoSection(service: service, colorScheme: colorScheme)
                }

                // Basic info
                FormulaDetailsSectionView(
                    formula: formula,
                    fileCount: fileCount,
                    totalSize: totalSize,
                    colorScheme: colorScheme
                )

                // Dependencies
                if (formula.dependencies != nil && !formula.dependencies!.isEmpty) ||
                   (formula.buildDependencies != nil && !formula.buildDependencies!.isEmpty) {
                    DependenciesSection(
                        runtimeDeps: formula.dependencies ?? [],
                        buildDeps: formula.buildDependencies ?? [],
                        installedFormulae: brewManager.installedFormulae.map { $0.name },
                        colorScheme: colorScheme
                    )
                }

                // Caveats
                if let caveats = formula.caveats {
                    CaveatsSection(caveats: caveats, colorScheme: colorScheme)
                }
            }
            .padding()
        }
        .scrollIndicators(scrollIndicators ? .visible : .hidden)
        .onAppear {
            loadInstallationDetails()
        }

        // Install button pinned to bottom
        InstallButtonSection(
            packageName: formula.name,
            isCask: false,
            isInstalling: $isInstalling,
            isAlreadyInstalled: isAlreadyInstalled,
            showInstallAlert: $showInstallAlert,
            brewManager: brewManager,
            colorScheme: colorScheme
        )
        .padding()
    }

    private func loadInstallationDetails() {
        // Only load if formula is installed
        guard isAlreadyInstalled else { return }

        Task {
            let brewPrefix = "/opt/homebrew"

            // Find the installed version from brewManager
            if let installedFormula = brewManager.installedFormulae.first(where: {
                $0.name == formula.name || $0.name == formula.name.components(separatedBy: "/").last
            }), let version = installedFormula.version {
                let cellarPath = "\(brewPrefix)/Cellar/\(formula.name)/\(version)"

                // Calculate file count and total size
                if let enumerator = FileManager.default.enumerator(atPath: cellarPath) {
                    var count = 0
                    var size: Int64 = 0

                    while let _ = enumerator.nextObject() {
                        count += 1
                        // Get file attributes for size
                        if let fileAttributes = enumerator.fileAttributes,
                           let fileSize = fileAttributes[.size] as? Int64 {
                            size += fileSize
                        }
                    }

                    await MainActor.run {
                        fileCount = count
                        totalSize = size
                    }
                }
            }
        }
    }
}

// MARK: - Cask Details View

struct CaskDetailsView: View {
    let cask: CaskDetails
    let analytics: HomebrewAnalytics?
    @Binding var isInstalling: Bool
    let isAlreadyInstalled: Bool
    @Binding var showInstallAlert: Bool
    let brewManager: HomebrewManager
    let colorScheme: ColorScheme

    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: scrollIndicators) {
            VStack(alignment: .leading, spacing: 16) {
                // Package name and version
                VStack(alignment: .leading, spacing: 4) {
                    // Cask display name
                    if let caskNames = cask.caskName, !caskNames.isEmpty {
                        Text(caskNames.joined(separator: ", "))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }

                    // Cask token
                    Text(cask.name)
                        .font(cask.caskName != nil ? .callout : .title2)
                        .fontWeight(cask.caskName != nil ? .medium : .bold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    // Version with auto-updates badge
                    if let version = cask.version {
                        HStack(spacing: 4) {
                            Text(verbatim: "v\(version)")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                            if let autoUpdates = cask.autoUpdates, autoUpdates {
                                Text(verbatim: "(auto_updates)")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                // Deprecation/Disable warnings
                if cask.isDeprecated || cask.isDisabled {
                    DeprecationDisableWarning(
                        isDeprecated: cask.isDeprecated,
                        deprecationReason: cask.deprecationReason,
                        deprecationDate: cask.deprecationDate,
                        isDisabled: cask.isDisabled,
                        disableReason: cask.disableReason,
                        disableDate: cask.disableDate,
                        colorScheme: colorScheme
                    )
                }

                // Replacement suggestions
                ReplacementSuggestionsSection(
                    deprecationReplacementFormula: cask.deprecationReplacementFormula,
                    deprecationReplacementCask: cask.deprecationReplacementCask,
                    disableReplacementFormula: cask.disableReplacementFormula,
                    disableReplacementCask: cask.disableReplacementCask,
                    brewManager: brewManager,
                    colorScheme: colorScheme
                )

                // System requirements
                SystemRequirementsSection(
                    minimumMacOSVersion: cask.minimumMacOSVersion,
                    architectureRequirement: cask.architectureRequirement,
                    colorScheme: colorScheme
                )

                // Analytics
                if let analytics = analytics {
                    AnalyticsSection(analytics: analytics, isCask: true, colorScheme: colorScheme)
                }

                Divider()

                // Basic info
                CaskDetailsSectionView(cask: cask, colorScheme: colorScheme)

                // Dependencies (formula dependencies for casks)
                if let dependencies = cask.dependencies, !dependencies.isEmpty {
                    DependenciesSection(
                        runtimeDeps: dependencies,
                        buildDeps: [],
                        installedFormulae: brewManager.installedFormulae.map { $0.name },
                        colorScheme: colorScheme
                    )
                }

                // Caveats
                if let caveats = cask.caveats {
                    CaveatsSection(caveats: caveats, colorScheme: colorScheme)
                }
            }
            .padding()
        }
        .scrollIndicators(scrollIndicators ? .visible : .hidden)

        // Install button pinned to bottom
        InstallButtonSection(
            packageName: cask.name,
            isCask: true,
            isInstalling: $isInstalling,
            isAlreadyInstalled: isAlreadyInstalled,
            showInstallAlert: $showInstallAlert,
            brewManager: brewManager,
            colorScheme: colorScheme
        )
        .padding()
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
                    Text(verbatim: "v\(version)")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    if let autoUpdates = package.autoUpdates, autoUpdates {
                        Text(verbatim: "(auto_updates)")
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
            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

            if let reason = reason {
                Text("Reason: \(formatReason(reason))")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            }

            if let date = disableDate {
                Text("Will be disabled on \(date)")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Popularity")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

            HStack(spacing: 0) {
                // 365 days
                if let installs365d = analytics.install365d {
                    VStack(spacing: 4) {
                        Text(verbatim: "\(installs365d.formatted())")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        Text("365 days")
                            .font(.caption2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }

                if analytics.install365d != nil && analytics.install90d != nil {
                    Divider()
                        .frame(height: 40)
                }

                // 90 days
                if let installs90d = analytics.install90d {
                    VStack(spacing: 4) {
                        Text(verbatim: "\(installs90d.formatted())")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        Text("90 days")
                            .font(.caption2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }

                if analytics.install90d != nil && analytics.install30d != nil {
                    Divider()
                        .frame(height: 40)
                }

                // 30 days
                if let installs30d = analytics.install30d {
                    VStack(spacing: 4) {
                        Text(verbatim: "\(installs30d.formatted())")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        Text("30 days")
                            .font(.caption2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .frame(maxWidth: .infinity)
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
            // Description (only if present)
            if let description = package.description {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
            }

            // Homepage (only if present)
            if let homepage = package.homepage, let url = URL(string: homepage) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Homepage")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Link(homepage, destination: url)
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                }
            }

            // License (only if present)
            if let license = package.license {
                DetailRow(label: "License", value: license, colorScheme: colorScheme, isNA: false)
            }

            // Tap (only if present)
            if let tap = package.tap {
                DetailRow(label: "Tap", value: tap, colorScheme: colorScheme, isNA: false)
            }

            // Deprecated warning
            if package.isDeprecated {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ Deprecated")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    if let reason = package.deprecationReason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                    if let date = package.deprecationDate {
                        Text("Since: \(date)")
                            .font(.caption2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Disabled warning
            if package.isDisabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🚫 Disabled")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    if let reason = package.disableReason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                    if let date = package.disableDate {
                        Text("Since: \(date)")
                            .font(.caption2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // Installation type (formulae only, only if present)
            if !isCask, let isBottled = package.isBottled {
                DetailRow(
                    label: "Installation",
                    value: isBottled ? "Bottled (pre-built binary)" : "From source",
                    colorScheme: colorScheme,
                    isNA: false
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

            // Requirements (only if present)
            if !isCask, let requirements = package.requirements {
                DetailRow(label: "Requirements", value: requirements, colorScheme: colorScheme, isNA: false)
            }

            // Conflicts (only if present)
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
            }

            // Artifacts (only if present)
            if isCask, let artifacts = package.artifacts, !artifacts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Artifacts")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    ForEach(artifacts, id: \.self) { artifact in
                        Text(verbatim: "• \(artifact)")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                }
            }

            // Aliases (only if present)
            if !isCask, let aliases = package.aliases, !aliases.isEmpty {
                DetailRow(
                    label: "Aliases",
                    value: aliases.joined(separator: ", "),
                    colorScheme: colorScheme,
                    isNA: false
                )
            }

            // Versioned formulae (only if present)
            if !isCask, let versionedFormulae = package.versionedFormulae, !versionedFormulae.isEmpty {
                DetailRow(
                    label: "Other Versions",
                    value: versionedFormulae.joined(separator: ", "),
                    colorScheme: colorScheme,
                    isNA: false
                )
            }

            // Optional dependencies (formulae only)
            if !isCask, let optionalDeps = package.optionalDependencies, !optionalDeps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Optional Dependencies")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text(optionalDeps.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
            }

            // Recommended dependencies (formulae only)
            if !isCask, let recommendedDeps = package.recommendedDependencies, !recommendedDeps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended Dependencies")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text(recommendedDeps.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
            }

            // Uses from macOS (formulae only)
            if !isCask, let usesFromMacos = package.usesFromMacos, !usesFromMacos.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uses from macOS")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text(usesFromMacos.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
            }

            // Download URL (casks only)
            if isCask, let url = package.url {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download URL")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    if let urlObj = URL(string: url) {
                        Link(url, destination: urlObj)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text(url)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            // Appcast URL (casks only)
            if isCask, let appcast = package.appcast {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Appcast URL")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    if let urlObj = URL(string: appcast) {
                        Link(appcast, destination: urlObj)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text(appcast)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
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
                        Text(verbatim: "•")
                        Text(dep)
                        if installedFormulae.contains(dep) {
                            Text(verbatim: "✓")
                                .foregroundStyle(.green)
                        } else {
                            Text(verbatim: "✗")
                                .foregroundStyle(.red)
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
                        Text(verbatim: "•")
                        Text(dep)
                        if installedFormulae.contains(dep) {
                            Text(verbatim: "✓")
                                .foregroundStyle(.green)
                        } else {
                            Text(verbatim: "✗")
                                .foregroundStyle(.red)
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

// MARK: - New Sections for Type-Safe Models

// Combined Deprecation/Disable Warning
struct DeprecationDisableWarning: View {
    let isDeprecated: Bool
    let deprecationReason: String?
    let deprecationDate: String?
    let isDisabled: Bool
    let disableReason: String?
    let disableDate: String?
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 8) {
            if isDeprecated {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("DEPRECATED")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    if let reason = deprecationReason {
                        Text("Reason: \(reason)")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }

                    if let date = deprecationDate {
                        Text("Since: \(date)")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.8))
                .cornerRadius(8)
            }

            if isDisabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("DISABLED")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    if let reason = disableReason {
                        Text("Reason: \(reason)")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }

                    if let date = disableDate {
                        Text("Since: \(date)")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            }
        }
    }
}

// Replacement Suggestions Section
struct ReplacementSuggestionsSection: View {
    let deprecationReplacementFormula: String?
    let deprecationReplacementCask: String?
    let disableReplacementFormula: String?
    let disableReplacementCask: String?
    let brewManager: HomebrewManager
    let colorScheme: ColorScheme

    private var hasReplacements: Bool {
        deprecationReplacementFormula != nil || deprecationReplacementCask != nil ||
        disableReplacementFormula != nil || disableReplacementCask != nil
    }

    var body: some View {
        if hasReplacements {
            VStack(alignment: .leading, spacing: 8) {
                Text("📦 Recommended Replacements")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                VStack(alignment: .leading, spacing: 4) {
                    if let formula = deprecationReplacementFormula ?? disableReplacementFormula {
                        ReplacementButton(name: formula, isCask: false, brewManager: brewManager, colorScheme: colorScheme)
                    }

                    if let cask = deprecationReplacementCask ?? disableReplacementCask {
                        ReplacementButton(name: cask, isCask: true, brewManager: brewManager, colorScheme: colorScheme)
                    }
                }
            }
            .padding()
            .background(ThemeColors.shared(for: colorScheme).accent.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct ReplacementButton: View {
    let name: String
    let isCask: Bool
    let brewManager: HomebrewManager
    let colorScheme: ColorScheme
    @State private var isInstalling = false

    var body: some View {
        Button {
            Task {
                isInstalling = true
                defer { isInstalling = false }

                do {
                    try await HomebrewController.shared.installPackage(name: name, cask: isCask)
                    await brewManager.loadInstalledPackages()
                } catch {
                    printOS("Failed to install replacement \(name): \(error)")
                }
            }
        } label: {
            HStack(spacing: 6) {
                if isInstalling {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                }
                Text("Install \(name)")
                Text(verbatim: "(\(isCask ? "cask" : "formula"))")
                    .font(.caption2)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .font(.caption)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
        }
        .buttonStyle(.plain)
        .disabled(isInstalling)
    }
}

// System Requirements Section (Casks)
struct SystemRequirementsSection: View {
    let minimumMacOSVersion: String?
    let architectureRequirement: ArchRequirement?
    let colorScheme: ColorScheme

    private var hasRequirements: Bool {
        minimumMacOSVersion != nil || architectureRequirement != nil
    }

    var body: some View {
        if hasRequirements {
            VStack(alignment: .leading, spacing: 8) {
                Text("💻 System Requirements")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                VStack(alignment: .leading, spacing: 4) {
                    if let macOSVersion = minimumMacOSVersion {
                        HStack(spacing: 4) {
                            Text(verbatim: "•")
                            Text(verbatim: "macOS: \(macOSVersion)")
                        }
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }

                    if let arch = architectureRequirement {
                        HStack(spacing: 4) {
                            Text(verbatim: "•")
                            Text("Architecture: \(arch.displayName)")
                        }
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// Service Info Section (Formulae)
struct ServiceInfoSection: View {
    let service: ServiceInfo
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("⚙️ Service/Daemon")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

            VStack(alignment: .leading, spacing: 4) {
                if let run = service.run, !run.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Run Command:")
                            .font(.caption2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        Text(run.joined(separator: " "))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                }

                if let runType = service.runType {
                    HStack(spacing: 4) {
                        Text(verbatim: "•")
                        Text("Run Type: \(runType)")
                    }
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }

                if let workingDir = service.workingDir {
                    HStack(spacing: 4) {
                        Text(verbatim: "•")
                        Text("Working Directory: \(workingDir)")
                    }
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }

                if let keepAlive = service.keepAlive, keepAlive {
                    HStack(spacing: 4) {
                        Text(verbatim: "•")
                        Text("Keep Alive: Always")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
}

// Formula-specific details section
struct FormulaDetailsSectionView: View {
    let formula: FormulaDetails
    let fileCount: Int?
    let totalSize: Int64?
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Description
            if let description = formula.description {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
            }

            // Homepage
            if let homepage = formula.homepage, let url = URL(string: homepage) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Homepage")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Link(homepage, destination: url)
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                }
            }

            // License
            if let license = formula.license {
                DetailRow(label: "License", value: license, colorScheme: colorScheme, isNA: false)
            }

            // Tap
            if let tap = formula.tap {
                DetailRow(label: "Tap", value: tap, colorScheme: colorScheme, isNA: false)
            }

            // Installation type
            if let isBottled = formula.isBottled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Installation")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isBottled ? "Bottled (pre-built binary)" : "From source")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                        // Show file count and size if available
                        if let count = fileCount, let size = totalSize {
                            Text(installationSizeText(count: count, size: size))
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                    }
                }
            }

            // Keg-only
            if let isKegOnly = formula.isKegOnly, isKegOnly {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔒 Keg-Only")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    Text(formula.kegOnlyReason ?? "Not symlinked to Homebrew prefix")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            // Requirements
            if let requirements = formula.requirements {
                DetailRow(label: "Requirements", value: requirements, colorScheme: colorScheme, isNA: false)
            }

            // Conflicts
            if let conflicts = formula.conflictsWith, !conflicts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ Conflicts With")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    if let reasons = formula.conflictsWithReasons, reasons.count == conflicts.count {
                        // Show conflicts with their reasons
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(zip(conflicts, reasons)), id: \.0) { conflict, reason in
                                Text(verbatim: "\(conflict): \(reason)")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            }
                        }
                    } else {
                        // No reasons available, just show conflicts
                        Text(conflicts.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }

            // Aliases
            if let aliases = formula.aliases, !aliases.isEmpty {
                DetailRow(
                    label: "Aliases",
                    value: aliases.joined(separator: ", "),
                    colorScheme: colorScheme,
                    isNA: false
                )
            }

            // Versioned formulae
            if let versionedFormulae = formula.versionedFormulae, !versionedFormulae.isEmpty {
                DetailRow(
                    label: "Other Versions",
                    value: versionedFormulae.joined(separator: ", "),
                    colorScheme: colorScheme,
                    isNA: false
                )
            }

            // Optional dependencies
            if let optionalDeps = formula.optionalDependencies, !optionalDeps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Optional Dependencies")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text(optionalDeps.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
            }

            // Recommended dependencies
            if let recommendedDeps = formula.recommendedDependencies, !recommendedDeps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended Dependencies")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text(recommendedDeps.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
            }

            // Uses from macOS
            if let usesFromMacos = formula.usesFromMacos, !usesFromMacos.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uses from macOS")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text(usesFromMacos.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
            }
        }
    }

    private func installationSizeText(count: Int, size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .file
        let sizeString = formatter.string(fromByteCount: size)
        return "(\(count) files, \(sizeString))"
    }
}

// Cask-specific details section
struct CaskDetailsSectionView: View {
    let cask: CaskDetails
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Description
            if let description = cask.description {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
            }

            // Homepage
            if let homepage = cask.homepage, let url = URL(string: homepage) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Homepage")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Link(homepage, destination: url)
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                }
            }

            // License
            if let license = cask.license {
                DetailRow(label: "License", value: license, colorScheme: colorScheme, isNA: false)
            }

            // Tap
            if let tap = cask.tap {
                DetailRow(label: "Tap", value: tap, colorScheme: colorScheme, isNA: false)
            }

            // Conflicts
            if let conflicts = cask.conflictsWith, !conflicts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ Conflicts With")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    if let reasons = cask.conflictsWithReasons, reasons.count == conflicts.count {
                        // Show conflicts with their reasons
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(zip(conflicts, reasons)), id: \.0) { conflict, reason in
                                Text(verbatim: "\(conflict): \(reason)")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            }
                        }
                    } else {
                        // No reasons available, just show conflicts
                        Text(conflicts.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }

            // Artifacts
            if let artifacts = cask.artifacts, !artifacts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Artifacts")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    ForEach(artifacts, id: \.self) { artifact in
                        Text(verbatim: "• \(artifact)")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                }
            }

            // Download URL
            if let url = cask.url {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download URL")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    if let urlObj = URL(string: url) {
                        Link(url, destination: urlObj)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text(url)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            // Appcast URL
            if let appcast = cask.appcast {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Appcast URL")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    if let urlObj = URL(string: appcast) {
                        Link(appcast, destination: urlObj)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text(appcast)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
    }
}

// Updated InstallButtonSection to accept packageName instead of package object
struct InstallButtonSection: View {
    let packageName: String
    let isCask: Bool
    @Binding var isInstalling: Bool
    let isAlreadyInstalled: Bool
    @Binding var showInstallAlert: Bool
    let brewManager: HomebrewManager
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            Spacer()

            if isInstalling {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Installing...")
                        .font(.callout)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            } else if isAlreadyInstalled {
                Text("Installed")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            } else {
                Button("Install") {
                    showInstallAlert = true
                }
                .buttonStyle(.borderedProminent)
                .tint(ThemeColors.shared(for: colorScheme).accent)
            }

            Spacer()
        }
        .frame(height: 44)
        .alert("Install \(packageName)?", isPresented: $showInstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Install") {
                Task { @MainActor in
                    isInstalling = true
                    defer { isInstalling = false }

                    do {
                        try await HomebrewController.shared.installPackage(name: packageName, cask: isCask)
                        await brewManager.loadInstalledPackages()

                        // Refresh AppState.sortedApps to include newly installed GUI app (casks only)
                        if isCask {
                            let folderPaths = FolderSettingsManager.shared.folderPaths
                            flushBundleCaches(for: AppState.shared.sortedApps)
                            await loadAppsAsync(folderPaths: folderPaths)
                        }
                    } catch {
                        printOS("Error installing package \(packageName): \(error)")
                    }
                }
            }
        } message: {
            Text("This will install \(packageName) using Homebrew. This may take several minutes.")
        }
    }
}

// Installed category view component (matches Updater view's CategorySection pattern)
struct InstalledCategoryView: View {
    let category: InstalledCategory
    let packages: [HomebrewSearchResult]
    let isLoading: Bool
    let collapsed: Bool
    let onToggle: () -> Void
    let isFirst: Bool
    let onPackageSelected: (HomebrewSearchResult, Bool) -> Void
    let updatingPackages: Set<String>
    let brewManager: HomebrewManager
    let onUpdateAll: (() -> Void)?
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header (collapsible)
            Button(action: onToggle) {
                HStack {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .frame(width: 10)
                        .opacity(packages.isEmpty ? 0 : 1)

                    Image(systemName: category.icon)
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                        .frame(width: 20)

                    Text(category.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    // Show progress spinner while loading, otherwise show count
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(verbatim: "(\(packages.count))")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    Spacer()

                    // Show "Update All" button if provided
                    if let onUpdateAll = onUpdateAll {
                        Button {
                            onUpdateAll()
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
            .padding(.top, isFirst ? 0 : 20)

            // Packages in category (only if not collapsed)
            if !collapsed {
                LazyVStack(spacing: 8) {
                    ForEach(packages) { result in
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
    }
}

// Available category view component (matches Installed/Updater view pattern)
struct AvailableCategoryView: View {
    let category: AvailableCategory
    let packages: [HomebrewSearchResult]
    let collapsed: Bool
    let onToggle: () -> Void
    let isFirst: Bool
    let onPackageSelected: (HomebrewSearchResult, Bool) -> Void
    let updatingPackages: Set<String>
    let brewManager: HomebrewManager
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header (collapsible)
            Button(action: onToggle) {
                HStack {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .frame(width: 10)

                    Image(systemName: category.icon)
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                        .frame(width: 20)

                    Text(category.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    Text(verbatim: "(\(packages.count))")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .padding(.top, isFirst ? 0 : 20)

            // Packages in category (only if not collapsed)
            if !collapsed {
                LazyVStack(spacing: 8) {
                    ForEach(packages) { result in
                        SearchResultRowView(
                            result: result,
                            isCask: category == .casks,
                            onInfoTapped: {
                                onPackageSelected(result, category == .casks)
                            },
                            updatingPackages: updatingPackages
                        )
                    }
                }
            }
        }
    }
}
