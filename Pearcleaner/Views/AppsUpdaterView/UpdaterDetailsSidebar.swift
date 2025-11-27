//
//  UpdaterHiddenSidebar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/16/25.
//

import Foundation
import SwiftUI
import AlinFoundation


// Main updater hidden sidebar view
struct UpdaterDetailsSidebar: View {
    @Binding var hiddenSidebar: Bool
    @Binding var sources: UpdaterSourcesSettings
    @Binding var display: UpdaterDisplaySettings
    @EnvironmentObject var updateManager: UpdateManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        if hiddenSidebar {
            HStack {
                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    UpdaterSourceCheckboxSection(
                        sources: $sources,
                        display: $display
                    )
                    Divider()
                    UpdaterHiddenAppsSection()
                    Spacer()
                    UpdaterHiddenSidebarFooter()
                }
                .padding()
                .frame(width: 280)
                .ifGlassSidebar()
                .padding([.trailing, .bottom], 20)
            }
            .background(.black.opacity(0.00000000001))
            .transition(.move(edge: .trailing))
            .onTapGesture {
                hiddenSidebar = false
            }
        }
    }
}

// Source checkboxes section component
struct UpdaterSourceCheckboxSection: View {
    @Binding var sources: UpdaterSourcesSettings
    @Binding var display: UpdaterDisplaySettings
    @EnvironmentObject var updateManager: UpdateManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isResetting = false
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Categories")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

            // App Store checkbox with reset button
            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { sources.appStore.enabled },
                    set: { newValue in
                        sources.appStore.enabled = newValue
                        if newValue {
                            Task { await updateManager.scanIfNeeded(sources: [.appStore]) }
                        } else {
                            updateManager.updatesBySource[.appStore] = nil
                        }
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: ifOSBelow(macOS: 14) ? "cart.fill" : "storefront.fill")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.caption)
                            .frame(width: 16)

                        Text("App Store")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                .toggleStyle(CircleCheckboxToggleStyle())

                Spacer()

                // Reset button
                Button(action: {
                    showResetConfirmation = true
                }) {
                    if isResetting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "wrench.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .contentShape(Rectangle())
                            .foregroundStyle(.blue)
                            .help("Reset App Store (fixes stuck downloads)")
                    }
                }
                .buttonStyle(.plain)
                .disabled(isResetting)
                .confirmationDialog(
                    "Reset App Store?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) {
                        Task {
                            await performReset()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will:\n• Quit App Store and related processes\n• Clear download cache\n• Fix stuck or failed downloads\n\nYou may need to sign in again.")
                }
            }

            // Homebrew checkbox with auto-updates toggle
            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { sources.homebrew.enabled },
                    set: { newValue in
                        sources.homebrew.enabled = newValue
                        if newValue {
                            Task { await updateManager.scanIfNeeded(sources: [.homebrew]) }
                        } else {
                            updateManager.updatesBySource[.homebrew] = nil
                        }
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "mug")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.caption)
                            .frame(width: 16)

                        Text("Homebrew")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                .toggleStyle(CircleCheckboxToggleStyle())

                Spacer()

                // Auto-updates button
                Button(action: {
                    sources.homebrew.showAutoUpdates.toggle()
                    Task { await updateManager.scanIfNeeded(sources: [.homebrew]) }
                }) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundStyle(sources.homebrew.showAutoUpdates ? .orange : ThemeColors.shared(for: colorScheme).secondaryText)
                        .contentShape(Rectangle())
                        .help(sources.homebrew.showAutoUpdates ? "Hide auto-updating apps from Homebrew" : "Show auto-updating apps in Homebrew")

                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { sources.sparkle.enabled },
                    set: { newValue in
                        sources.sparkle.enabled = newValue
                        if newValue {
                            Task { await updateManager.scanIfNeeded(sources: [.sparkle]) }
                        } else {
                            updateManager.updatesBySource[.sparkle] = nil
                        }
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.caption)
                            .frame(width: 16)

                        Text("Sparkle")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                .toggleStyle(CircleCheckboxToggleStyle())

                Spacer()

                // Pre-releases button
                Button(action: {
//                    let wasEnabled = sources.sparkle.includePreReleases
                    sources.sparkle.includePreReleases.toggle()

                    if sources.sparkle.includePreReleases {
                        // Enabling - rescan to find pre-releases
                        Task { await updateManager.scanIfNeeded(sources: [.sparkle]) }
                    } else {
                        // Disabling - filter existing data without rescanning
                        updateManager.removePreReleaseApps(from: .sparkle)
                    }
                }) {
                    if #available(macOS 14.0, *) {
                        Image(systemName: sources.sparkle.includePreReleases ? "flask.fill" : "flask")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .foregroundStyle(sources.sparkle.includePreReleases ? .green : ThemeColors.shared(for: colorScheme).secondaryText)
                            .contentShape(Rectangle())
                            .help(sources.sparkle.includePreReleases ? "Disable pre-releases" : "Enable pre-releases")
                    } else {
                        Image(systemName: "testtube.2")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .foregroundStyle(sources.sparkle.includePreReleases ? .green : ThemeColors.shared(for: colorScheme).secondaryText)
                            .contentShape(Rectangle())
                            .help(sources.sparkle.includePreReleases ? "Disable pre-releases" : "Enable pre-releases")
                    }
                }
                .buttonStyle(.plain)

            }

            // Current apps toggle
            Toggle(isOn: Binding(
                get: { display.showCurrent },
                set: { newValue in
                    display.showCurrent = newValue
                }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .font(.caption)
                        .frame(width: 16)

                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }
            .toggleStyle(CircleCheckboxToggleStyle())
            .help("Show apps that are already up-to-date")

            // Unsupported apps toggle
            Toggle(isOn: Binding(
                get: { display.showUnsupported },
                set: { newValue in
                    display.showUnsupported = newValue
                }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .font(.caption)
                        .frame(width: 16)

                    Text("Unsupported")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }
            .toggleStyle(CircleCheckboxToggleStyle())
            .help("Show apps without a supported update mechanism")


        }
    }

    // MARK: - Private Methods

    /// Performs App Store reset operation
    private func performReset() async {
        isResetting = true

        let result = await AppStoreReset.reset()

        await MainActor.run {
            isResetting = false

            switch result {
            case .success:
                // Show success notification
                showToast("App Store reset successfully", type: .success)

                // Optionally rescan for updates after reset
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                    await updateManager.scanIfNeeded(forceReload: true, sources: [.appStore])
                }

            case .failure(let error):
                // Show error notification
                showToast("Reset failed: \(error)", type: .error)
            }
        }
    }

    /// Shows a toast notification
    private func showToast(_ message: String, type: ToastType) {
        // Use AppState's toast system if available
        NotificationCenter.default.post(
            name: NSNotification.Name("ToastNotification"),
            object: nil,
            userInfo: ["message": message, "type": type.rawValue]
        )
    }

    /// Toast notification types
    private enum ToastType: String {
        case success
        case error
    }
}

// Hidden apps section component (combines header, list, and manual hide)
struct UpdaterHiddenAppsSection: View {
    @StateObject private var appState = AppState.shared
    @EnvironmentObject var updateManager: UpdateManager
    @Environment(\.colorScheme) var colorScheme

    private var availableApps: [AppInfo] {
        let hiddenBundleIds = Set(updateManager.hiddenUpdates.map { $0.appInfo.bundleIdentifier })
        return appState.sortedApps.filter { !hiddenBundleIds.contains($0.bundleIdentifier) }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with count and plus button
            HStack(spacing: 8) {
                Text("Hidden")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                Text(verbatim: "(\(updateManager.hiddenUpdates.count))")
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                Spacer()

                Menu {
                    if availableApps.isEmpty {
                        Text("All updates are hidden")
                            .disabled(true)
                    } else {
                        ForEach(availableApps, id: \.bundleIdentifier) { app in
                            Button {
                                hideApp(app)
                            } label: {
                                HStack {
                                    if let icon = app.appIcon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                    }
                                    Text(app.appName)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                        .font(.title3)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("Manually hide an app from update checks")
            }

            // List of hidden apps
            if updateManager.hiddenUpdates.isEmpty {
                Text("No hidden updates")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .italic()
                    .padding(.top, 4)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(updateManager.hiddenUpdates) { app in
                            UpdaterHiddenAppRow(app: app)
                        }
                    }
                }
            }
        }
    }

    private func hideApp(_ appInfo: AppInfo) {
        // Determine the update source for this app
        let source: UpdateSource = {
            if appInfo.hasSparkle {
                return .sparkle
            } else if appInfo.brew {
                return .homebrew
            } else if appInfo.isAppStore {
                return .appStore
            } else {
                return .unsupported
            }
        }()

        // Create UpdateableApp instance
        let updateableApp = UpdateableApp(
            appInfo: appInfo,
            availableVersion: nil,
            availableBuildNumber: nil,
            source: source,
            adamID: nil,
            appStoreURL: nil,
            status: .idle,
            progress: 0.0,
            isSelectedForUpdate: false,
            releaseTitle: nil,
            releaseDescription: nil,
            releaseNotesLink: nil,
            releaseDate: nil,
            isPreRelease: false,
            isIOSApp: false,
            foundInRegion: nil,
            appcastItem: nil
        )

        updateManager.hideApp(updateableApp)
    }
}

// Individual hidden app row component
struct UpdaterHiddenAppRow: View {
    let app: UpdateableApp
    @EnvironmentObject var updateManager: UpdateManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false

    private var sourceIcon: String {
        switch app.source {
        case .appStore: return ifOSBelow(macOS: 14) ? "cart.fill" : "storefront.fill"
        case .homebrew: return "mug"
        case .sparkle: return "sparkles"
        case .unsupported: return "questionmark.circle"
        case .current: return "checkmark.circle"
        }
    }

    private var sourceColor: Color {
        switch app.source {
        case .appStore: return .blue
        case .homebrew: return .orange
        case .sparkle: return .purple
        case .unsupported: return .gray
        case .current: return .green
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // App icon (use actual icon if available, fallback to source icon)
            if let appIcon = app.appInfo.appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .cornerRadius(6)
            } else {
                // Fallback to source icon with colored background
                ZStack {
                    Circle()
                        .fill(sourceColor.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: sourceIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(sourceColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(app.appInfo.appName)
                        .lineLimit(1)

                    if let ignoredVersion = updateManager.getIgnoredVersion(for: app) {
                        Text("(Skipped \(ignoredVersion))")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    } else {
                        Text("(Hidden)")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                HStack(spacing: 4) {
                    Image(systemName: sourceIcon)
                        .font(.caption2)
                        .foregroundStyle(sourceColor)

                    Text(app.source.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }

            Spacer()

            // Unhide button
            Button {
                Task {
                    await updateManager.unhideApp(app)
                }
            } label: {
                Image(systemName: "eye")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
            }
            .buttonStyle(.borderless)
            .help("Unhide update")
        }
        .padding(8)
        .background(ThemeColors.shared(for: colorScheme).secondaryText.opacity(isHovered ? 0.15 : 0.1))
        .cornerRadius(6)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovered
            }
        }
    }
}

// Footer component
struct UpdaterHiddenSidebarFooter: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var updateManager: UpdateManager
    @AppStorage("settings.updater.debugLogging") private var debugLogging: Bool = true

    var body: some View {
        HStack {
            Text("Click to dismiss")
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

            Spacer()

            Toggle(isOn: Binding(
                get: { debugLogging },
                set: { newValue in
                    debugLogging = newValue
                    if !newValue {
                        UpdaterDebugLogger.shared.clearLogs()
                    } else {
                        Task { await updateManager.scanIfNeeded() }
                    }
                }
            )) {
                Text("Debug")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .toggleStyle(CircleCheckboxToggleStyle())
            .help("Enable verbose logging and bundle cache flushing for troubleshooting")
        }
    }
}
