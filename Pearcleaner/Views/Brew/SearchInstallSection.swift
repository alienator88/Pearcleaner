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
    @EnvironmentObject var brewManager: HomebrewManager
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var searchQuery: String = ""
    @State private var searchType: HomebrewSearchType = .installed
    @State private var selectedPackage: HomebrewSearchResult?
    @State private var drawerOpen: Bool = false
    @State private var hasLoadedInitialData: Bool = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    private var displayedResults: [HomebrewSearchResult] {
        let source: [HomebrewSearchResult]
        switch searchType {
        case .formulae:
            source = brewManager.allAvailableFormulae
        case .casks:
            source = brewManager.allAvailableCasks
        case .installed:
            // Convert installed packages to search results for display
            let installedFormulae = brewManager.installedFormulae.map { convertToSearchResult($0) }
            let installedCasks = brewManager.installedCasks.map { convertToSearchResult($0) }
            source = (installedFormulae + installedCasks).sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        // Source is already sorted, just filter if needed
        if searchQuery.isEmpty {
            return source
        } else {
            return source.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    private func convertToSearchResult(_ package: InstalledPackage) -> HomebrewSearchResult {
        // Basic conversion - full data will be fetched on demand when Info is clicked
        return HomebrewSearchResult(
            name: package.name,
            description: package.description,
            homepage: nil,
            license: nil,
            version: package.version,
            dependencies: nil,
            caveats: nil,
            tap: nil,
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar with picker - FULL WIDTH, NOT AFFECTED BY DRAWER
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
                    // Clear search and close drawer when switching tabs
                    searchQuery = ""
                    if drawerOpen {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            drawerOpen = false
                            selectedPackage = nil
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Results count and cache timestamp
            if !displayedResults.isEmpty || searchType == .installed {
                HStack {
                    if searchType == .installed {
                        Text("\(displayedResults.count) package\(displayedResults.count == 1 ? "" : "s")")
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

                        if let lastRefresh = brewManager.lastCacheRefresh {
                            Text("Cached: \(lastRefresh.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }

            // LIST + DRAWER AREA (GeometryReader for drawer layout)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left: Results List
                    VStack(alignment: .leading, spacing: 0) {
                        // Results or loading state
                        // Only show progress view for JWS data (available packages), not for installed packages
                        let isLoading = (searchType == .installed && brewManager.isLoadingPackages) ||
                                       (searchType != .installed && brewManager.isLoadingAvailablePackages)

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
                                    Text("This may take a moment on first launch")
                                        .font(.caption)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                }

                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else if displayedResults.isEmpty && !searchQuery.isEmpty {
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
                                    ForEach(displayedResults) { result in
                                        SearchResultRowView(
                                            result: result,
                                            isCask: {
                                                if searchType == .installed {
                                                    return brewManager.installedCasks.contains(where: { $0.name == result.name })
                                                } else {
                                                    return searchType == .casks || brewManager.allAvailableCasks.contains(where: { $0.name == result.name })
                                                }
                                            }(),
                                            isSelected: selectedPackage?.name == result.name && drawerOpen,
                                            isDimmed: drawerOpen && selectedPackage?.name != result.name,
                                            onInfoTapped: {
                                                selectedPackage = result
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    drawerOpen = true
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                            .scrollIndicators(scrollIndicators ? .automatic : .never)
                        }
                    }
                    .frame(width: drawerOpen ? geometry.size.width * (2.0/3.0) : geometry.size.width)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if drawerOpen {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                drawerOpen = false
                            }
                        }
                    }

                    // Right: Details Drawer
                    if drawerOpen, let package = selectedPackage {
                        PackageDetailsDrawer(
                            package: package,
                            isCask: {
                                if searchType == .installed {
                                    return brewManager.installedCasks.contains(where: { $0.name == package.name })
                                } else {
                                    return brewManager.allAvailableCasks.contains(where: { $0.name == package.name })
                                }
                            }(),
                            onClose: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    drawerOpen = false
                                }
                            }
                        )
                        .frame(width: geometry.size.width * (1.0/3.0))
                        .transition(.move(edge: .trailing))
                    }
                }
            }
        }
        .onAppear {
            // Only load data once, not every time the tab is switched
            guard !hasLoadedInitialData else { return }
            hasLoadedInitialData = true

            Task {
                // 1. Load installed packages FIRST (blocks UI with progress view)
                await brewManager.loadInstalledPackages()

                // 2. After installed packages finish, load JWS data in background (doesn't block UI)
                Task {
                    var needsRefresh = false
                    if let lastRefresh = brewManager.lastCacheRefresh {
                        let fiveDaysAgo = Date().addingTimeInterval(-5 * 24 * 60 * 60)
                        needsRefresh = lastRefresh < fiveDaysAgo
                    }

                    await brewManager.loadAvailablePackages(appState: appState, forceRefresh: needsRefresh)
                }
            }
        }
    }
}

// MARK: - Search Result Row View

struct SearchResultRowView: View {
    let result: HomebrewSearchResult
    let isCask: Bool
    let isSelected: Bool
    let isDimmed: Bool
    let onInfoTapped: () -> Void
    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false
    @State private var isInstalling: Bool = false
    @State private var showInstallAlert: Bool = false

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

        // Only compute if JWS data is loaded (to avoid blocking streaming)
        let availablePackages = isCask ? brewManager.allAvailableCasks : brewManager.allAvailableFormulae
        guard !availablePackages.isEmpty else { return false }

        let shortName = result.name.components(separatedBy: "/").last ?? result.name

        // Find the installed package
        let installedPackage: InstalledPackage?
        if isCask {
            installedPackage = brewManager.installedCasks.first { $0.name == result.name || $0.name == shortName }
        } else {
            installedPackage = brewManager.installedFormulae.first { $0.name == result.name || $0.name == shortName }
        }

        guard let installed = installedPackage,
              let installedVersion = installed.version else {
            return false
        }

        // Find the package in JWS data to get latest version
        guard let jws = availablePackages.first(where: { $0.name == result.name || $0.name == shortName }),
              let latestVersion = jws.version else {
            return false
        }

        // Compare versions - simple string comparison
        return installedVersion != latestVersion
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Package icon
            ZStack {
                Circle()
                    .fill((isCask ? Color.purple : Color.green).opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: isCask ? "shippingbox.fill" : "cube.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isCask ? .purple : .green)
            }

            // Package name and description
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                if let description = result.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .lineLimit(2)
                } else {
                    Text(isCask ? "Cask" : "Formula")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }

            Spacer()

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
            if isInstalling {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Installing...")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            } else if isOutdated {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Update")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            } else if isAlreadyInstalled {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Installed")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
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
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ?
                    ThemeColors.shared(for: colorScheme).secondaryBG.opacity(0.8) :
                    ThemeColors.shared(for: colorScheme).secondaryBG
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? ThemeColors.shared(for: colorScheme).accent : Color.clear, lineWidth: 2)
                )
        )
        .opacity(isDimmed ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDimmed)
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
                        // Package header with close button
                        PackageHeaderSection(package: displayedPackage, isCask: isCask, colorScheme: colorScheme, onClose: onClose)

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

                        // Install button at bottom
                        Spacer()
                        InstallButtonSection(
                            package: displayedPackage,
                            isCask: isCask,
                            isInstalling: $isInstalling,
                            isAlreadyInstalled: isAlreadyInstalled,
                            showInstallAlert: $showInstallAlert,
                            brewManager: brewManager,
                            colorScheme: colorScheme
                        )
                    }
                    .padding()
                }
            }
        }
        .background(ThemeColors.shared(for: colorScheme).primaryBG)
        .onAppear {
            loadFullPackageInfoIfNeeded()
            loadAnalytics()
            loadInstalledPackagesIfNeeded()
        }
    }

    private func loadFullPackageInfoIfNeeded() {
        // If package data is incomplete (from installed package), fetch full info from API
        guard needsFullData else { return }

        Task {
            isLoadingFullPackageInfo = true
            do {
                // Search for the package in the JWS files/API
                let results = try await HomebrewController.shared.searchPackages(
                    query: package.name,
                    cask: isCask
                )
                // Find exact match
                if let match = results.first(where: { $0.name == package.name }) {
                    fullPackageInfo = match
                }
            } catch {
                printOS("Failed to load full package info: \(error.localizedDescription)")
                // Keep using the limited package data
            }
            isLoadingFullPackageInfo = false
        }
    }

    private func loadAnalytics() {
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
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Package name with close button
            HStack {
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

                Spacer()

                // Close button
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                .buttonStyle(.plain)
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

                    if let isBottled = package.isBottled, isBottled {
                        Text("(bottled)")
                            .font(.caption2)
                            .foregroundStyle(.blue)
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

            // Auto-updates (casks only)
            if isCask {
                DetailRow(
                    label: "Auto-updates",
                    value: package.autoUpdates == true ? "Yes" : (package.autoUpdates == false ? "No" : "N/A"),
                    colorScheme: colorScheme,
                    isNA: package.autoUpdates == nil
                )
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
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Installed")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .frame(maxWidth: .infinity)
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
