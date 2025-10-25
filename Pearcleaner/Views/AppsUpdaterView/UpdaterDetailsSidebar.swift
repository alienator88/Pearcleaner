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
    @Binding var includeHomebrewFormulae: Bool
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
                        includeHomebrewFormulae: $includeHomebrewFormulae
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
    @Binding var includeHomebrewFormulae: Bool
    @StateObject private var updateManager = UpdateManager.shared
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.updater.debugLogging") private var debugLogging: Bool = true

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

            // App Store checkbox
            Button(action: {
                checkAppStore.toggle()
                if checkAppStore {
                    Task { await updateManager.scanForUpdates() }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: checkAppStore ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(checkAppStore ? .blue : ThemeColors.shared(for: colorScheme).secondaryText)
                        .font(.title3)

                    Image(systemName: ifOSBelow(macOS: 14) ? "cart.fill" : "storefront.fill")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .font(.caption)
                        .frame(width: 16)

                    Text("App Store")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }
            .buttonStyle(.plain)

            // Homebrew checkbox with formulae toggle
            HStack(spacing: 8) {
                Button(action: {
                    checkHomebrew.toggle()
                    if checkHomebrew {
                        Task { await updateManager.scanForUpdates() }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: checkHomebrew ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checkHomebrew ? .blue : ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.title3)

                        Image(systemName: "mug")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.caption)
                            .frame(width: 16)

                        Text("Homebrew")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Formulae toggle button
                Button(action: {
                    includeHomebrewFormulae.toggle()
                    Task { await updateManager.scanForUpdates() }
                }) {
                    Image(systemName: includeHomebrewFormulae ? "terminal.fill" : "terminal")
                        .foregroundStyle(includeHomebrewFormulae ? .orange : ThemeColors.shared(for: colorScheme).secondaryText)
                }
                .buttonStyle(.plain)
                .help(includeHomebrewFormulae ? "Disable CLI tools (formulae)" : "Enable CLI tools (formulae)")
            }

            HStack(spacing: 8) {
                Button(action: {
                    checkSparkle.toggle()
                    if checkSparkle {
                        Task { await updateManager.scanForUpdates() }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: checkSparkle ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checkSparkle ? .blue : ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.title3)

                        Image(systemName: "sparkles")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.caption)
                            .frame(width: 16)

                        Text("Sparkle")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                .buttonStyle(.plain)

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
            .toggleStyle(.checkbox)
            .help("Enable verbose logging for update checker troubleshooting")
        }
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
        }
    }

    private var sourceColor: Color {
        switch app.source {
        case .appStore: return .blue
        case .homebrew: return .orange
        case .sparkle: return .purple
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
