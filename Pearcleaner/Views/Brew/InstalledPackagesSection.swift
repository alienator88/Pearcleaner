//
//  InstalledPackagesSection.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import SwiftUI
import AlinFoundation

enum HomebrewPackageFilter: String, CaseIterable {
    case all = "All"
    case formulae = "Formulae"
    case casks = "Casks"
    case outdated = "Outdated"
}

struct InstalledPackagesSection: View {
    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText: String = ""
    @State private var filter: HomebrewPackageFilter = .all
    @State private var showUpgradeAllAlert: Bool = false
    @State private var isUpgradingAll: Bool = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    private var filteredPackages: [HomebrewPackageInfo] {
        var packages: [HomebrewPackageInfo] = []

        switch filter {
        case .all:
            packages = brewManager.allPackages
        case .formulae:
            packages = brewManager.installedFormulae
        case .casks:
            packages = brewManager.installedCasks
        case .outdated:
            packages = brewManager.outdatedPackages
        }

        if !searchText.isEmpty {
            packages = packages.filter { package in
                package.name.localizedCaseInsensitiveContains(searchText) ||
                (package.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return packages.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search and filter bar
            HStack(spacing: 12) {
                // Search field
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
                .controlGroup(Capsule(style: .continuous), level: .primary)

                // Filter picker
                Picker("", selection: $filter) {
                    ForEach(HomebrewPackageFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 300)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Stats header
            HStack {
                Text("\(filteredPackages.count) package\(filteredPackages.count == 1 ? "" : "s")")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                if brewManager.isLoadingPackages {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

                Spacer()

                if !brewManager.outdatedPackages.isEmpty {
                    Text("\(brewManager.outdatedPackages.count) outdated")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if brewManager.isLoadingPackages {
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
            } else if filteredPackages.isEmpty {
                VStack(alignment: .center) {
                    Spacer()
                    Text("No packages found")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredPackages) { package in
                            HomebrewPackageRow(package: package)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(scrollIndicators ? .automatic : .never)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !brewManager.outdatedPackages.isEmpty {
                HStack {
                    Spacer()

                    Button("Upgrade All Outdated") {
                        showUpgradeAllAlert = true
                    }
                    .buttonStyle(ControlGroupButtonStyle(
                        foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                        shape: Capsule(style: .continuous),
                        level: .primary,
                        skipControlGroup: true
                    ))
                    .disabled(isUpgradingAll)

                    if isUpgradingAll {
                        ProgressView()
                            .scaleEffect(0.8)
                    }

                    Spacer()
                }
                .padding([.horizontal, .bottom])
            }
        }
        .alert("Upgrade All Packages", isPresented: $showUpgradeAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Upgrade") {
                Task {
                    isUpgradingAll = true
                    do {
                        try await HomebrewController.shared.upgradeAllPackages()
                        await brewManager.refreshAll()
                    } catch {
                        printOS("Error upgrading all packages: \(error)")
                    }
                    isUpgradingAll = false
                }
            }
        } message: {
            Text("This will upgrade all \(brewManager.outdatedPackages.count) outdated packages. This may take several minutes.")
        }
    }
}

// MARK: - Package Row View

struct HomebrewPackageRow: View {
    let package: HomebrewPackageInfo
    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false
    @State private var isPerformingAction: Bool = false
    @State private var showUninstallAlert: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Package icon
            ZStack {
                Circle()
                    .fill(packageColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: package.isCask ? "shippingbox.fill" : "cube.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(packageColor)
            }

            // Package details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(package.name)
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    if package.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .help("Version pinned")
                    }

                    if package.isOutdated {
                        Text("OUTDATED")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.orange)
                            )
                    }
                }

                if let description = package.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Label(package.displayVersion, systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    if let tap = package.tap {
                        Label(tap, systemImage: "point.3.filled.connected.trianglepath.dotted")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    Text(package.isCask ? "Cask" : "Formula")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }

            Spacer()

            // Action buttons
            if isPerformingAction {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                HStack(spacing: 10) {
                    // Homepage button
                    if let homepage = package.homepage, let url = URL(string: homepage) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Image(systemName: "safari")
                        }
                        .buttonStyle(.borderless)
                        .help("Open homepage")
                    }

                    Divider().frame(height: 15)

                    // Pin/Unpin button (formulae only)
                    if !package.isCask {
                        Button {
                            Task {
                                isPerformingAction = true
                                do {
                                    if package.isPinned {
                                        try await HomebrewController.shared.unpinPackage(name: package.name)
                                    } else {
                                        try await HomebrewController.shared.pinPackage(name: package.name)
                                    }
                                    await brewManager.loadInstalledPackages()
                                } catch {
                                    printOS("Error toggling pin: \(error)")
                                }
                                isPerformingAction = false
                            }
                        } label: {
                            Image(systemName: package.isPinned ? "pin.slash" : "pin")
                        }
                        .buttonStyle(.borderless)
                        .help(package.isPinned ? "Unpin version" : "Pin version")

                        Divider().frame(height: 15)
                    }

                    // Upgrade button
                    if package.isOutdated {
                        Button {
                            Task {
                                isPerformingAction = true
                                do {
                                    try await HomebrewController.shared.upgradePackage(name: package.name)
                                    if package.isCask {
                                        await brewManager.loadInstalledPackages()
                                    } else {
                                        await brewManager.loadInstalledPackages()
                                    }
                                } catch {
                                    printOS("Error upgrading package: \(error)")
                                }
                                isPerformingAction = false
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle")
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.borderless)
                        .help("Upgrade package")

                        Divider().frame(height: 15)
                    }

                    // Uninstall button
                    Button {
                        showUninstallAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Uninstall package")
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
        .alert("Uninstall \(package.name)?", isPresented: $showUninstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                Task {
                    isPerformingAction = true
                    do {
                        try await HomebrewUninstaller.shared.uninstallPackage(name: package.name, cask: package.isCask)
                        // Remove from array instead of full reload
                        if package.isCask {
                            brewManager.installedCasks.removeAll { $0.id == package.id }
                        } else {
                            brewManager.installedFormulae.removeAll { $0.id == package.id }
                        }
                    } catch {
                        printOS("Error uninstalling package: \(error)")
                    }
                    isPerformingAction = false
                }
            }
        } message: {
            Text("Are you sure you want to uninstall \(package.name)?")
        }
    }

    private var packageColor: Color {
        if package.isOutdated {
            return .orange
        } else if package.isPinned {
            return .blue
        } else if package.isCask {
            return .purple
        } else {
            return .green
        }
    }
}
