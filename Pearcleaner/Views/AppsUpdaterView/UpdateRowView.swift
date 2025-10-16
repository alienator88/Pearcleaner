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
        if app.status != .idle {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(statusText(for: app.status))
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
        } else {
            Button(app.source == .sparkle ? "Open to Update" : "Update") {
                Task { await updateManager.updateApp(app) }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)
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
                    HStack(spacing: 4) {
                        Text(app.appInfo.appName)
                            .font(.headline)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                        // Show version inline
                        if let availableVersion = app.availableVersion {
                            Text(verbatim: "(\(app.appInfo.appVersion) → \(availableVersion))")
                                .font(.footnote)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        } else if app.source == .sparkle {
                            Text(verbatim: "(\(app.appInfo.appVersion))")
                                .font(.footnote)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
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

                    // Source label
                    Text(app.source.rawValue)
                        .font(.caption)
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
