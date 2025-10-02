//
//  SearchInstallSection.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import SwiftUI
import AlinFoundation

enum HomebrewSearchType: String, CaseIterable {
    case all = "All"
    case formulae = "Formulae"
    case casks = "Casks"
}

struct SearchInstallSection: View {
    @EnvironmentObject var brewManager: HomebrewManager
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var searchQuery: String = ""
    @State private var searchType: HomebrewSearchType = .all
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    private var displayedResults: [HomebrewSearchResult] {
        let source: [HomebrewSearchResult]
        switch searchType {
        case .all:
            source = brewManager.allAvailableFormulae + brewManager.allAvailableCasks
        case .formulae:
            source = brewManager.allAvailableFormulae
        case .casks:
            source = brewManager.allAvailableCasks
        }

        if searchQuery.isEmpty {
            return source
        } else {
            return source.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar with picker on right
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Results count and cache timestamp
            if !displayedResults.isEmpty {
                HStack {
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
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }

            // Results or loading state
            if brewManager.isLoadingAvailablePackages {
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
                                isCask: result.name.contains("/") ? false : (searchType == .casks || brewManager.allAvailableCasks.contains(where: { $0.name == result.name }))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(scrollIndicators ? .automatic : .never)
            }
        }
        .onAppear {
            Task {
                // Check if cache is older than 5 days
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

// MARK: - Search Result Row View

struct SearchResultRowView: View {
    let result: HomebrewSearchResult
    let isCask: Bool
    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false
    @State private var isInstalling: Bool = false
    @State private var showInstallAlert: Bool = false
    @State private var isExpanded: Bool = false

    private var isAlreadyInstalled: Bool {
        if isCask {
            return brewManager.installedCasks.contains { $0.name == result.name }
        } else {
            return brewManager.installedFormulae.contains { $0.name == result.name }
        }
    }

    private var hasAdditionalDetails: Bool {
        result.homepage != nil || result.license != nil || result.version != nil ||
        result.dependencies != nil || result.caveats != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
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

                // Info button (only show if additional details available)
                if hasAdditionalDetails {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "info.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                    }
                    .buttonStyle(.plain)
                }

                // Install/Installed status
                if isInstalling {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Installing...")
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

            // Expanded details section
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal)

                    if let version = result.version {
                        DetailRow(label: "Version", value: version, colorScheme: colorScheme)
                    }

                    if let license = result.license {
                        DetailRow(label: "License", value: license, colorScheme: colorScheme)
                    }

                    if let homepage = result.homepage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Homepage")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            Link(homepage, destination: URL(string: homepage)!)
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.horizontal)
                    }

                    if let dependencies = result.dependencies, !dependencies.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dependencies")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            Text(dependencies.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        .padding(.horizontal)
                    }

                    if let caveats = result.caveats {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            Text(caveats)
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                        .frame(height: 8)
                }
            }
        }
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
                Task {
                    isInstalling = true
                    do {
                        try await HomebrewController.shared.installPackage(name: result.name, cask: isCask)
                        await brewManager.loadInstalledPackages()
                    } catch {
                        printOS("Error installing package: \(error)")
                    }
                    isInstalling = false
                }
            }
        } message: {
            Text("This will install \(result.name) using Homebrew. This may take several minutes.")
        }
    }
}

// MARK: - Detail Row Helper

struct DetailRow: View {
    let label: String
    let value: String
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            Text(value)
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
        }
        .padding(.horizontal)
    }
}
