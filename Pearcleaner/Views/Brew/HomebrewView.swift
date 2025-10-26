//
//  HomebrewView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import SwiftUI
import AlinFoundation

enum HomebrewViewSection: String, CaseIterable {
    case browse = "Browse"
    case taps = "Taps"
    case autoUpdate = "Auto Update"
    case maintenance = "Maintenance"

    var icon: String {
        switch self {
        case .browse:
            return "magnifyingglass"
        case .taps:
            return "point.3.filled.connected.trianglepath.dotted"
        case .autoUpdate:
            return "clock.arrow.2.circlepath"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        }
    }
}

struct HomebrewView: View {
    @StateObject private var brewManager = HomebrewManager()
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedSection: HomebrewViewSection = .browse
    @State private var isLoadingInitialData: Bool = false
    @State private var drawerOpen: Bool = false
    @State private var selectedPackage: HomebrewSearchResult?
    @State private var selectedPackageIsCask: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if !HomebrewController.shared.isInstalled {
                // Show message when Homebrew is not installed
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Text("Homebrew Not Installed")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    Text("Homebrew is not installed on your system. This feature requires Homebrew to manage packages.")
                        .font(.callout)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button {
                        if let url = URL(string: "https://brew.sh") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Install Homebrew")
                            .font(.callout)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Normal Homebrew view content
                ZStack {
                    VStack(spacing: 0) {
                        // Section Picker
                        HStack {
                            Spacer()
                            Picker("", selection: $selectedSection) {
                                ForEach(HomebrewViewSection.allCases, id: \.self) { section in
                                    Label(section.rawValue, systemImage: section.icon)
                                        .tag(section)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .fixedSize()
                            .disabled(isLoadingInitialData)
                            .opacity(isLoadingInitialData ? 0.5 : 1.0)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 5)


                        // Section Content
                        Group {
                            switch selectedSection {
                            case .browse:
                                SearchInstallSection(
                                    onPackageSelected: { package, isCask in
                                        selectedPackage = package
                                        selectedPackageIsCask = isCask
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            drawerOpen = true
                                        }
                                    }
                                )
                            case .taps:
                                TapManagementSection()
                            case .autoUpdate:
                                AutoUpdateSection()
                            case .maintenance:
                                MaintenanceSection()
                            }
                        }
                        .transition(.opacity)
                        .animation(animationEnabled ? .easeInOut(duration: 0.2) : .none, value: selectedSection)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Package Details Sidebar (overlays entire view)
                    PackageDetailsSidebar(
                        drawerOpen: $drawerOpen,
                        package: selectedPackage,
                        isCask: selectedPackageIsCask,
                        onClose: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                drawerOpen = false
                            }
                        }
                    )
                    .padding([.trailing, .bottom], 20)
                }
                .animation(
                    animationEnabled ? .spring(response: 0.35, dampingFraction: 0.8) : .none,
                    value: drawerOpen)
                .environmentObject(brewManager)
                .task {
                    // Load other data in parallel (installed packages loaded in SearchInstallSection)
                    async let taps: Void = brewManager.loadTaps()
                    async let version: Void = brewManager.loadBrewVersion()
                    async let cache: Void = brewManager.loadDownloadsCacheSize()
                    async let analytics: Void = brewManager.checkAnalyticsStatus()
                    _ = await (taps, version, cache, analytics)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HomebrewViewShouldRefresh"))) { _ in
            Task {
                switch selectedSection {
                case .browse:
                    await brewManager.loadInstalledPackages()
                    await brewManager.loadAvailablePackages(appState: appState, forceRefresh: true)
                case .taps:
                    await brewManager.loadTaps()
                case .autoUpdate:
                    break  // No refresh needed - managed by AutoUpdateSection
                case .maintenance:
                    await brewManager.refreshMaintenance()
                }
            }
        }
        .toolbar {
            TahoeToolbarItem(placement: .navigation) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Homebrew Manager")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Manage Homebrew packages, taps, and maintenance")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                }

            }

            ToolbarItem { Spacer() }

            TahoeToolbarItem(isGroup: true) {
                Button {
                    Task {
                        switch selectedSection {
                        case .browse:
                            await brewManager.loadInstalledPackages()
                            await brewManager.loadAvailablePackages(appState: appState, forceRefresh: true)
                        case .taps:
                            await brewManager.loadTaps()
                        case .autoUpdate:
                            break  // No refresh needed - managed by AutoUpdateSection
                        case .maintenance:
                            await brewManager.refreshMaintenance()
                        }
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.counterclockwise")
                }
                .help("Refresh \(selectedSection.rawValue.lowercased()) data")
            }
        }
    }
}
