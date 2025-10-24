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
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
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
                Text(app.isIOSApp ? "Update in App Store" : (app.source == .sparkle ? "Open to Update" : "Update"))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)

        case .checking, .downloading, .installing, .verifying:
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

    @ViewBuilder
    private var secondaryActionButtons: some View {
        // View Changes button for Sparkle and App Store apps (if metadata available)
        if (app.source == .sparkle || app.source == .appStore), app.releaseDescription != nil || app.releaseTitle != nil {
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
        }

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

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(alignment: .center, spacing: 12) {
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

                        // Binary extraction warning (Sparkle only)
                        if app.source == .sparkle && app.extractedFromBinary {
                            InfoButton(
                                text: "This app did not expose its Sparkle feed URL in Info.plist. Pearcleaner extracted it from the binary instead. Updates may not work reliably.",
                                color: .orange, warning: true
                            )
                        }

                        // URL picker for multiple Sparkle feed URLs
                        if app.source == .sparkle, let urls = app.alternateSparkleURLs, urls.count > 1 {
                            Menu {
                                ForEach(urls, id: \.self) { url in
                                    Button {
                                        // Refresh the row item with the selected URL
                                        Task {
                                            await updateManager.refreshSparkleAppWithURL(app: app, newURL: url)
                                        }
                                    } label: {
                                        HStack {
                                            Text(url)
                                            if url == (app.currentFeedURL ?? urls.first) {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label("Select Appcast", systemImage: "link.circle")
                                    .labelStyle(.titleOnly)
//                                Image(systemName: "link.circle")
//                                    .font(.body)
//                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                            }
                            .buttonStyle(.bordered)
                            .help("Choose Sparkle feed URL")
                        }

                        // CLI tool indicator (Homebrew formulae only)
                        if app.source == .homebrew && app.appInfo.bundleIdentifier.hasPrefix("com.homebrew.formula.") {
                            ZStack {
                                Image(systemName: "terminal.fill")
                                    .font(.body)
                                    .foregroundStyle(.orange)
                            }
                            .frame(width: 20)
                            .help("CLI Tool (Formula)")
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
                    if let availableVersion = app.availableVersion {
                        // Clean Homebrew versions for display (strip commit hash)
                        let displayInstalledVersion = app.source == .homebrew ?
                            app.appInfo.appVersion.cleanBrewVersionForDisplay() : app.appInfo.appVersion
                        let displayAvailableVersion = app.source == .homebrew ?
                            availableVersion.cleanBrewVersionForDisplay() : availableVersion

                        Text(verbatim: "\(displayInstalledVersion) → \(displayAvailableVersion)\(app.isIOSApp ? " (iOS apps have to be updated in the App Store)" : "")")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    } else if app.source == .sparkle {
                        Text(verbatim: "\(app.appInfo.appVersion)")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
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
}
