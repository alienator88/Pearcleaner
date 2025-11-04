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
    @Binding var checkAppStore: Bool
    @Binding var checkHomebrew: Bool
    @Binding var checkSparkle: Bool
    @Binding var includeSparklePreReleases: Bool
    @Binding var showUnsupported: Bool
    @StateObject private var updateManager = UpdateManager.shared
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        if hiddenSidebar {
            HStack {
                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    UpdaterSourceCheckboxSection(
                        checkAppStore: $checkAppStore,
                        checkHomebrew: $checkHomebrew,
                        checkSparkle: $checkSparkle,
                        includeSparklePreReleases: $includeSparklePreReleases,
                        showUnsupported: $showUnsupported
                    )
                    Divider()
                    UpdaterHiddenHeaderSection(hiddenCount: updateManager.hiddenUpdates.count)
                    UpdaterHiddenAppsSection(hiddenApps: updateManager.hiddenUpdates)
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
    @Binding var checkAppStore: Bool
    @Binding var checkHomebrew: Bool
    @Binding var checkSparkle: Bool
    @Binding var includeSparklePreReleases: Bool
    @Binding var showUnsupported: Bool
    @StateObject private var updateManager = UpdateManager.shared
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.updater.debugLogging") private var debugLogging: Bool = true
    @AppStorage("settings.updater.showAutoUpdatesInHomebrew") private var showAutoUpdatesInHomebrew: Bool = false
    @State private var isResetting = false
    @State private var showResetConfirmation = false

    private var selectedSourcesCount: Int {
        [checkAppStore, checkHomebrew, checkSparkle].filter { $0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Text("Sources")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                Text(verbatim: "(\(selectedSourcesCount))")
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }

            // App Store checkbox with reset button
            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { checkAppStore },
                    set: { newValue in
                        checkAppStore = newValue
                        if newValue {
                            Task { await updateManager.scanForUpdates() }
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
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isResetting)
                .help("Reset App Store (fixes stuck downloads)")
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
                    get: { checkHomebrew },
                    set: { newValue in
                        checkHomebrew = newValue
                        if newValue {
                            Task { await updateManager.scanForUpdates() }
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
                    showAutoUpdatesInHomebrew.toggle()
                    Task { await updateManager.scanForUpdates() }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(showAutoUpdatesInHomebrew ? .blue : ThemeColors.shared(for: colorScheme).secondaryText)
                }
                .buttonStyle(.plain)
                .help(showAutoUpdatesInHomebrew ? "Hide auto-updating apps from Homebrew" : "Show auto-updating apps in Homebrew")
            }

            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { checkSparkle },
                    set: { newValue in
                        checkSparkle = newValue
                        if newValue {
                            Task { await updateManager.scanForUpdates() }
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
                    includeSparklePreReleases.toggle()
                    Task { await updateManager.scanForUpdates() }
                }) {
                    if #available(macOS 14.0, *) {
                        Image(systemName: includeSparklePreReleases ? "flask.fill" : "flask")
                            .foregroundStyle(includeSparklePreReleases ? .green : ThemeColors.shared(for: colorScheme).secondaryText)
                    } else {
                        Image(systemName: "testtube.2")
                            .foregroundStyle(includeSparklePreReleases ? .green : ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                .buttonStyle(.plain)
                .help(includeSparklePreReleases ? "Disable pre-releases" : "Enable pre-releases")
            }

            // Debug logging toggle
            Divider()
                .padding(.vertical, 4)

            Toggle(isOn: Binding(
                get: { debugLogging },
                set: { newValue in
                    debugLogging = newValue
                    if !newValue {
                        UpdaterDebugLogger.shared.clearLogs()
                    } else {
                        Task { await updateManager.scanForUpdates() }
                    }
                }
            )) {
                HStack(spacing: 6) {
                    Image(systemName: "ladybug.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .frame(width: 16)

                    Text("Debug Logging")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }
            .toggleStyle(CircleCheckboxToggleStyle())
            .help("Enable verbose logging and bundle cache flushing for troubleshooting")

            // Show unsupported apps toggle
            Toggle(isOn: Binding(
                get: { showUnsupported },
                set: { newValue in
                    showUnsupported = newValue
                }
            )) {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.gray)
                        .font(.caption)
                        .frame(width: 16)

                    Text("Show Unsupported Apps")
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
                    await updateManager.scanForUpdates(forceReload: true)
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

// Header info component
struct UpdaterHiddenHeaderSection: View {
    let hiddenCount: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Text("Hidden Updates")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

            Text(verbatim: "(\(hiddenCount))")
                .font(.headline)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
        }
    }
}

// Hidden apps list component
struct UpdaterHiddenAppsSection: View {
    let hiddenApps: [UpdateableApp]
    @StateObject private var updateManager = UpdateManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hiddenApps.isEmpty {
                Text("No hidden updates")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .italic()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(hiddenApps) { app in
                            UpdaterHiddenAppRow(app: app)
                        }
                    }
                }
            }
        }
    }
}

// Individual hidden app row component
struct UpdaterHiddenAppRow: View {
    let app: UpdateableApp
    @StateObject private var updateManager = UpdateManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false

    private var sourceIcon: String {
        switch app.source {
        case .appStore: return ifOSBelow(macOS: 14) ? "cart.fill" : "storefront.fill"
        case .homebrew: return "mug"
        case .sparkle: return "sparkles"
        case .unsupported: return "questionmark.circle"
        }
    }

    private var sourceColor: Color {
        switch app.source {
        case .appStore: return .blue
        case .homebrew: return .orange
        case .sparkle: return .purple
        case .unsupported: return .gray
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
                Text(app.appInfo.appName)
                    .font(.caption)
                    .lineLimit(1)
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
                updateManager.unhideApp(app)
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

    var body: some View {
        HStack {
            Text("Click to dismiss")
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            Spacer()
        }
    }
}
