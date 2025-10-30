//
//  UpdateRowView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import SwiftUI
import AlinFoundation

struct UpdateRowView: View {
    let app: UpdateableApp
    let onHideToggle: (UpdateableApp) -> Void
    @StateObject private var updateManager = UpdateManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false
    @State private var isExpanded: Bool = false

    private var sourceColor: Color {
        switch app.source {
        case .homebrew:
            return .green
        case .appStore:
            return .purple
        case .sparkle:
            return .orange
        case .unsupported:
            return .gray
        }
    }

    private var sourceIcon: String {
        switch app.source {
        case .homebrew:
            return "terminal"
        case .appStore:
            return "macwindow"
        case .sparkle:
            return "sparkles"
        case .unsupported:
            return "questionmark.circle"
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        // For unsupported apps, show explanatory message instead of action buttons
        if app.source == .unsupported {
            Text("No update mechanism detected")
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
        } else {
            switch app.status {
            case .idle:
                Button {
                    if app.isIOSApp, let appStoreURL = app.appStoreURL {
                        // iOS apps: Open App Store page
                        openInAppStore(urlString: appStoreURL)
                    } else {
                        // Regular apps: Use CommerceKit or open to update
                        Task { await updateManager.updateApp(app) }
                    }
                } label: {
                    Text(app.isIOSApp ? "Update in App Store" : "Update")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)

            case .checking, .downloading, .extracting, .installing, .verifying:
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(statusText(for: app.status))
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

            case .completed, .failed:
                // Show status text without spinner
                Text(statusText(for: app.status))
                    .font(.caption)
                    .foregroundStyle(app.status == .completed ? .green : .red)
            }
        }
    }

    @ViewBuilder
    private var secondaryActionButtons: some View {
        // No secondary actions for unsupported apps
        if app.source != .unsupported {
            // View Changes button (shown for all sources, disabled for Homebrew)
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                Text(isExpanded ? "Close" : "View Changes")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
            }
            .buttonStyle(.plain)
            .disabled(app.source == .homebrew)

            // Hide button (always shown, positioned last - furthest trailing)
            Button {
                onHideToggle(app)
            } label: {
                Image(systemName: "eye.slash")
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .buttonStyle(.plain)
            .help("Hide update")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(alignment: .center, spacing: 12) {
                // Selection checkbox
                Button(action: {
                    updateManager.toggleAppSelection(app)
                }) {
                    EmptyView()
                }
                .buttonStyle(CircleCheckboxButtonStyle(isSelected: app.isSelectedForUpdate))
                .disabled(app.source == .unsupported)
                .opacity(app.source == .unsupported ? 0.5 : 1.0)

                // App icon (use actual app icon if available, fallback to source icon)
                if let appIcon = app.appInfo.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                } else {
                    // Fallback to source icon with colored background
                    ZStack {
                        Circle()
                            .fill(sourceColor.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: sourceIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(sourceColor)
                    }
                }

                // App name and version
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(app.appInfo.appName)
                            .font(.title2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                        // Pre-release indicator (Sparkle only)
                        if app.source == .sparkle && app.isPreRelease {
                            if #available(macOS 14.0, *) {
                                ZStack {
                                    Image(systemName: "flask.fill")
                                        .font(.body)
                                        .foregroundStyle(.green)
                                }
                                .frame(width: 20)
                                .help("Pre-release")
                            } else {
                                ZStack {
                                    Image(systemName: "testtube.2")
                                        .font(.body)
                                        .foregroundStyle(.green)
                                }
                                .frame(width: 20)
                                .help("Pre-release")
                            }
                        }

                        // Info button for App Store apps
                        if app.source == .appStore, let appStoreURL = app.appStoreURL {
                            Button {
                                openInAppStore(urlString: appStoreURL)
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                            }
                            .buttonStyle(.plain)
                            .help("View in App Store")
                        }
                    }

                    // Version info (larger font)
                    buildVersionText(for: app, colorScheme: colorScheme)
                        .font(.callout)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

                Spacer()

                // Action buttons
                actionButtons

                // Secondary actions (info button, etc.)
                secondaryActionButtons
            }
            .padding()

            // Expanded release notes (Sparkle and App Store)
            if isExpanded, (app.source == .sparkle || app.source == .appStore) {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        // Release title
                        if let title = app.releaseTitle {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }

                        // Release date
                        if let date = app.releaseDate {
                            Text("Released: \(formatDate(date))")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }

                        // Release description (HTML or plain text)
                        if let description = app.releaseDescription {
                            ScrollView {
                                if let nsAttributedString = try? NSAttributedString(
                                    data: Data(description.utf8),
                                    options: [.documentType: NSAttributedString.DocumentType.html,
                                             .characterEncoding: String.Encoding.utf8.rawValue],
                                    documentAttributes: nil
                                ) {
                                    // Create standardized attributed string with system body font
                                    let standardizedString = standardizeFont(in: nsAttributedString)

                                    Text(standardizedString)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                } else {
                                    // Fallback: show raw text if HTML parsing fails
                                    Text(description)
                                        .font(.body)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(maxHeight: 200)
                        }

                        // Release notes link (separate clickable link)
                        if let link = app.releaseNotesLink, let url = URL(string: link) {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                        .font(.caption)
                                    Text("View Full Release Notes")
                                        .font(.body)
                                }
                                .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .background {
            // Sparkle progress bar with twinkle effects (only for Sparkle apps)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if app.source == .sparkle {
                        // Show progress fill for active update statuses
                        switch app.status {
                        case .downloading, .extracting, .installing, .verifying:
                            SparkleProgressBar(
                                maxWidth: geometry.size.width,
                                progress: app.progress,
                                height: geometry.size.height
                            )
                        default:
                            EmptyView()
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .animation(.linear(duration: 0.3), value: app.progress)
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
    }

    private func statusText(for status: UpdateStatus) -> String {
        switch status {
        case .idle:
            return ""
        case .checking:
            return "Checking..."
        case .downloading:
            return "Downloading..."
        case .extracting:
            return "Extracting..."
        case .installing:
            return "Installing..."
        case .verifying:
            return "Verifying installation..."
        case .completed:
            return "Completed"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    private func openInAppStore(urlString: String) {
        // Convert the https:// URL to macappstore:// URL (mas CLI approach)
        // Example: https://apps.apple.com/us/app/slack/id803453959
        //       -> macappstore://apps.apple.com/us/app/slack/id803453959
        guard var urlComponents = URLComponents(string: urlString) else {
            return
        }

        urlComponents.scheme = "macappstore"

        if let url = urlComponents.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func formatDate(_ dateString: String) -> String {
        // Try to parse Sparkle date format (e.g., "26 September 2025 10:00:00 +0700")
        let sparkleFormatter = DateFormatter()
        sparkleFormatter.dateFormat = "dd MMMM yyyy HH:mm:ss Z"
        sparkleFormatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = sparkleFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        // Try to parse App Store ISO 8601 date format (e.g., "2025-10-06T20:58:03Z")
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        // If parsing fails, return the original string
        return dateString
    }

    private func standardizeFont(in nsAttributedString: NSAttributedString) -> AttributedString {
        // Create a mutable version and override all fonts to system body font
        let mutableString = NSMutableAttributedString(attributedString: nsAttributedString)
        let systemFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let range = NSRange(location: 0, length: mutableString.length)
        mutableString.addAttribute(.font, value: systemFont, range: range)

        // Convert back to AttributedString for SwiftUI
        return (AttributedString(mutableString))
    }

    private func buildVersionText(for app: UpdateableApp, colorScheme: ColorScheme) -> Text {
        guard let availableVersion = app.availableVersion else {
            // No available version (shouldn't happen, but handle gracefully)
            if app.source == .sparkle, let installedBuild = app.appInfo.appBuildNumber {
                return Text("\(app.appInfo.appVersion) (\(installedBuild))")
            }
            return Text(app.appInfo.appVersion)
        }

        // Clean Homebrew versions for display (strip commit hash)
        let displayInstalledVersion = app.source == .homebrew ?
            app.appInfo.appVersion.stripBrewRevisionSuffix() : app.appInfo.appVersion
        let displayAvailableVersion = app.source == .homebrew ?
            availableVersion.stripBrewRevisionSuffix() : availableVersion

        // Smart version display with build numbers (Sparkle only)
        if app.source == .sparkle {
            let installedBuild = app.appInfo.appBuildNumber
            let availableBuild = app.availableBuildNumber

            // Check if builds differ (for green highlighting)
            let buildsDiffer = installedBuild != nil && availableBuild != nil && installedBuild != availableBuild

            // Check if marketing versions match (both present and equal)
            if !displayInstalledVersion.isEmpty && !displayAvailableVersion.isEmpty &&
               displayInstalledVersion == displayAvailableVersion {
                // Scenario 1: Marketing versions match → "6.7 (6134) → 6.7 (6135)"
                var result = Text("\(displayInstalledVersion)")
                if let build = installedBuild {
                    result = result + Text(" (\(build))")
                }
                result = result + Text(" → \(displayAvailableVersion) (")
                if let build = availableBuild {
                    let buildText = Text(build)
                    result = result + (buildsDiffer ? buildText.foregroundColor(.green) : buildText)
                }
                result = result + Text(")")
                if app.isIOSApp {
                    result = result + Text(" (iOS apps have to be updated in the App Store)")
                }
                return result
            } else if displayAvailableVersion.isEmpty, let availableBuild = availableBuild {
                // Scenario 2: Remote lacks marketing version → "6.7 (6134) → build 6135"
                var result = Text("\(displayInstalledVersion)")
                if let build = installedBuild {
                    result = result + Text(" (\(build))")
                }
                result = result + Text(" → build ")
                let buildText = Text(availableBuild)
                result = result + (buildsDiffer ? buildText.foregroundColor(.green) : buildText)
                if app.isIOSApp {
                    result = result + Text(" (iOS apps have to be updated in the App Store)")
                }
                return result
            } else {
                // Scenario 3: Normal case → "6.7 (6134) → 6.8 (6135)"
                var result = Text("\(displayInstalledVersion)")
                if let build = installedBuild {
                    result = result + Text(" (\(build))")
                }
                result = result + Text(" → \(displayAvailableVersion)")
                if let build = availableBuild {
                    result = result + Text(" (\(build))")
                }
                if app.isIOSApp {
                    result = result + Text(" (iOS apps have to be updated in the App Store)")
                }
                return result
            }
        } else {
            // Non-Sparkle sources: show marketing versions only
            var result = Text("\(displayInstalledVersion) → \(displayAvailableVersion)")
            if app.isIOSApp {
                result = result + Text(" (iOS apps have to be updated in the App Store)")
            }
            return result
        }
    }
}
