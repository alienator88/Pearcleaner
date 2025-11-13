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
    @ObservedObject private var brewController = HomebrewController.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedSection: HomebrewViewSection = .browse
    @State private var isLoadingInitialData: Bool = false
    @State private var drawerOpen: Bool = false
    @State private var selectedPackage: HomebrewSearchResult?
    @State private var selectedPackageIsCask: Bool = false
    @State private var showConsole: Bool = false
    @State private var consoleHeight: Double = 200
    @AppStorage("settings.homebrew.consoleState") private var consoleStateData: Data = Data()
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    // Console state struct
    private struct ConsoleState: Codable {
        var isOpen: Bool
        var height: Double

        static let `default` = ConsoleState(isOpen: false, height: 200)
    }

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

                        // Console View (inset at bottom of VStack)
                        if showConsole {
                            BrewConsoleView(
                                output: brewController.consoleOutput,
                                height: $consoleHeight,
                                onClear: {
                                    Task { @MainActor in
                                        brewController.consoleOutput = ""
                                    }
                                }
                            )
                            .frame(height: consoleHeight)
                            .transition(.move(edge: .bottom))
                        }
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
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.8),
                    value: showConsole)
                .environmentObject(brewManager)
                .onAppear {
                    // Restore console state from AppStorage
                    if let decoded = try? JSONDecoder().decode(ConsoleState.self, from: consoleStateData) {
                        showConsole = decoded.isOpen
                        consoleHeight = decoded.height
                    }
                }
                .task {
                    // Load other data in parallel (installed packages loaded in SearchInstallSection)
                    async let taps: Void = brewManager.loadTaps()
                    async let version: Void = brewManager.loadBrewVersion()
                    async let cache: Void = brewManager.loadCacheSize()
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
                    HomebrewAutoUpdateManager.shared.refreshState()
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showConsole.toggle()
                    }
                } label: {
                    Label("Console", systemImage: showConsole ? "terminal.fill" : "terminal")
                }
                .help("Toggle console output")

                if brewController.isOperationRunning {
                    Button {
                        brewController.cancelOperation()
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                    .help("Cancel running Homebrew operation")
                } else {
                    Button {
                        Task {
                            switch selectedSection {
                            case .browse:
                                await brewManager.loadInstalledPackages()
                                await brewManager.loadAvailablePackages(appState: appState, forceRefresh: true)
                                // Refresh sortedApps to pick up newly installed casks with proper size
                                let folderPaths = await MainActor.run { FolderSettingsManager.shared.folderPaths }
                                await loadAppsAsync(folderPaths: folderPaths)
                                // Update categories to pick up latest app names from sortedApps and re-sort
                                await MainActor.run {
                                    brewManager.updateInstalledCategories()
                                }
                            case .taps:
                                await brewManager.loadTaps()
                            case .autoUpdate:
                                HomebrewAutoUpdateManager.shared.refreshState()
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
        .onChange(of: showConsole) { newValue in
            Task { @MainActor in
                brewController.consoleEnabled = newValue

                // Save console state
                let state = ConsoleState(isOpen: newValue, height: consoleHeight)
                if let encoded = try? JSONEncoder().encode(state) {
                    consoleStateData = encoded
                }

                // When console is hidden, trim output to 300 lines max to prevent memory bloat
                if !newValue {
                    let lines = brewController.consoleOutput.components(separatedBy: "\n")
                    if lines.count > 300 {
                        // Keep last 300 lines
                        brewController.consoleOutput = lines.suffix(300).joined(separator: "\n")
                    }
                }
            }
        }
        .onChange(of: consoleHeight) { newValue in
            // Save console height when changed
            let state = ConsoleState(isOpen: showConsole, height: newValue)
            if let encoded = try? JSONEncoder().encode(state) {
                consoleStateData = encoded
            }
        }
    }
}

// MARK: - Brew Console View

struct BrewConsoleView: View {
    let output: String
    @Binding var height: Double
    let onClear: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var cursorState: CursorState = .normal
    @State private var isHovering: Bool = false

    enum CursorState {
        case normal
        case hovering
        case dragging

        var cursor: NSCursor {
            switch self {
            case .normal: return .arrow
            case .hovering: return .openHand
            case .dragging: return .closedHand
            }
        }

        func apply() {
            cursor.set()
        }
    }



    var body: some View {
        VStack(spacing: 0) {
            // Header with grab handle and clear button
            ZStack {
                // Label on left
                HStack {
                    let title = "Console (\(output.components(separatedBy: "\n").count) lines)"
                    Text(title)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Spacer()
                }

                // Centered resize handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(ThemeColors.shared(for: colorScheme).secondaryText)
                    .frame(width: 30, height: 2)
                    .padding(6)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Reset Size") {
                            height = 200
                        }
                    }
                    .onHover { hovering in
                        isHovering = hovering
                        if cursorState != .dragging {
                            cursorState = hovering ? .hovering : .normal
                            cursorState.apply()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if cursorState != .dragging {
                                    cursorState = .dragging
                                    cursorState.apply()
                                }
                                let newHeight = height - value.translation.height
                                height = min(max(newHeight, 150), 400)
                            }
                            .onEnded { _ in
                                // Restore cursor based on hover state
                                cursorState = isHovering ? .hovering : .normal
                                cursorState.apply()
                            }
                    )

                // Trash button on right
                HStack {
                    Spacer()
                    Button {
                        onClear()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Clear console output")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Console output
            ScrollView {
                ScrollViewReader { proxy in
                    Text(output.isEmpty ? "Ready.." : output)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .id("consoleBottom")
                        .textSelection(.enabled)
                        .lineSpacing(1)
                        .onChange(of: output) { _ in
                            withAnimation {
                                proxy.scrollTo("consoleBottom", anchor: .bottom)
                            }
                        }
                }
            }
        }
        .background(Color.black)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: -5)
    }
}
