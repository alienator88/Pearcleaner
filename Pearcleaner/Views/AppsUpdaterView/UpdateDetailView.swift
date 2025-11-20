//
//  UpdateDetailView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/19/25.
//

import SwiftUI
import AlinFoundation

struct UpdateDetailView: View {
    let appId: UUID
    @StateObject private var updateManager = UpdateManager.shared
    @EnvironmentObject var brewManager: HomebrewManager
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @State private var showAdoptionSheet: Bool = false
    @State private var isLoadingCasks: Bool = false

    // Look up live app data from updateManager - this makes the view reactive to status changes
    private var app: UpdateableApp? {
        updateManager.updatesBySource.values
            .flatMap { $0 }
            .first { $0.id == appId }
    }

    private var sourceColor: Color {
        guard let app = app else { return .gray }
        switch app.source {
        case .homebrew:
            return .green
        case .appStore:
            return .purple
        case .sparkle:
            return .orange
        case .unsupported:
            return .gray
        case .current:
            return .green
        }
    }

    private var isNonPrimaryRegion: Bool {
        guard let app = app, app.source == .appStore, let foundRegion = app.foundInRegion else {
            return false
        }
        let primaryRegion = Locale.autoupdatingCurrent.region?.identifier ?? "US"
        return foundRegion != primaryRegion
    }

    var body: some View {
        Group {
            if let app = app {
                contentView(for: app)
            } else {
                VStack {
                    Spacer()
                    Text("App not found")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .font(.title2)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func contentView(for app: UpdateableApp) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header: App icon, name, version, action buttons
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    if let appIcon = app.appInfo.appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(app.appInfo.appName)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                        // Version info with build numbers
                        buildVersionText(for: app, colorScheme: colorScheme)
                            .font(.title3)
                    }

                    Spacer()

                    // Status view (matches UpdateRowView lines 134-148)
                    statusView(for: app)
                }

                // Action buttons in header
                HStack(spacing: 8) {
                    if app.source != .unsupported {
                        actionButton(for: app)
                    }

                    if app.source != .unsupported {
                        Button("Skip Version") {
                            if let availableVersion = app.availableVersion {
                                updateManager.hideApp(app, skipVersion: availableVersion)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ThemeColors.shared(for: colorScheme).secondaryBG)
                        .foregroundStyle(Color.orange)
                        .clipShape(Capsule())
                        .disabled(app.availableVersion == nil)

                        Button("Ignore") {
                            updateManager.hideApp(app, skipVersion: nil)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ThemeColors.shared(for: colorScheme).secondaryBG)
                        .foregroundStyle(Color.red)
                        .clipShape(Capsule())
                    }

                    // Adopt button for non-Homebrew apps
                    if app.source != .homebrew {
                        Button {
                            // Lazy loading: only load casks on first click
                            if brewManager.allAvailableCasks.isEmpty {
                                isLoadingCasks = true
                                Task {
                                    await brewManager.loadAvailablePackages(appState: appState)
                                    await MainActor.run {
                                        isLoadingCasks = false
                                        showAdoptionSheet = true
                                    }
                                }
                            } else {
                                showAdoptionSheet = true
                            }
                        } label: {
                            Text("Adopt")
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ThemeColors.shared(for: colorScheme).secondaryBG)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                        .clipShape(Capsule())
                        .disabled(isLoadingCasks)
                        .opacity(isLoadingCasks ? 0.5 : 1.0)
                    }
                }
                .padding(.leading, 6)
            }

            Divider()

            // Info section (SOURCE, RELEASED, CHECKED)
            HStack(spacing: 40) {
                VStack(alignment: .center, spacing: 4) {
                    Text("RELEASED")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    if let date = app.releaseDate {
                        Text(formatDate(date))
                            .font(.body)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Divider().frame(height: 20)

                VStack(alignment: .center, spacing: 4) {
                    Text("CHANGELOG")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    if let link = app.releaseNotesLink, let url = URL(string: link) {
                        Link(destination: url) {
                            Text("View")
                                .font(.body)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("N/A")
                            .font(.body)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Divider().frame(height: 20)

                VStack(alignment: .center, spacing: 4) {
                    Text("SOURCE")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    HStack(spacing: 6) {
                        Text(app.source.rawValue)
                            .font(.body)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        if app.isIOSApp {
                            Text("(iOS)")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            // Release details (if available)
            if app.source == .sparkle || app.source == .appStore {
                Divider()

                VStack(alignment: .leading, spacing: 16) {
//                    Text("What's New")
//                        .font(.title2)
//                        .fontWeight(.bold)
//                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    // Release title
//                    if let title = app.releaseTitle {
//                        Text(title)
//                            .font(.headline)
//                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
//                    }

                    // Release date
//                    if let date = app.releaseDate {
//                        Text("Released: \(formatDate(date))")
//                            .font(.subheadline)
//                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
//                    }

                    // Release description (HTML formatted) - scrollable section
                    // Priority 1: Fetched external notes, Priority 2: Inline description
                    if let preprocessed = processedReleaseNotes(for: app), !preprocessed.isEmpty {
                        ScrollView {
                            // Try HTML parsing first
                            if let htmlAttributedString = try? NSAttributedString(
                                data: Data(preprocessed.utf8),
                                options: [.documentType: NSAttributedString.DocumentType.html,
                                         .characterEncoding: String.Encoding.utf8.rawValue],
                                documentAttributes: nil
                            ) {
                                // Check if HTML parsing collapsed everything to one line
                                let lineCount = htmlAttributedString.string.split(separator: "\n").count

                                if lineCount == 1, let plainAttributedString = try? NSAttributedString(
                                    data: Data(preprocessed.utf8),
                                    options: [.documentType: NSAttributedString.DocumentType.plain,
                                             .characterEncoding: String.Encoding.utf8.rawValue],
                                    documentAttributes: nil
                                ) {
                                    // Fallback to plain text parsing to preserve formatting
                                    let standardizedString = standardizeFont(in: plainAttributedString)
                                    Text(standardizedString)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                } else {
                                    // HTML parsing preserved structure, use it
                                    let standardizedString = standardizeFont(in: htmlAttributedString)
                                    Text(standardizedString)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                            } else {
                                // HTML parsing failed entirely, show raw text (use original, untrimmed)
                                let originalDescription = (app.fetchedReleaseNotes ?? app.releaseDescription) ?? ""
                                Text(originalDescription)
                                    .font(.body)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                        .scrollIndicators(scrollIndicators ? .visible : .hidden)
                        .frame(maxHeight: .infinity)
                    } else {
                        // No release notes found - show message
                        VStack {
                            Spacer()
                            Text("No release notes were found")
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                .font(.callout)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAdoptionSheet) {
            AdoptionSheetView(
                appInfo: app.appInfo,
                context: .updaterView,
                isPresented: $showAdoptionSheet
            )
        }
    }

    @ViewBuilder
    private func statusView(for app: UpdateableApp) -> some View {
        switch app.status {
        case .checking, .downloading, .extracting, .installing, .verifying:
            HStack(spacing: 6) {
                Text(statusText(for: app.status))
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                CircularProgressView(
                    progress: app.progress,
                    size: 20,
                    lineWidth: 5
                )
            }
        case .completed:
            Text(statusText(for: app.status))
                .font(.caption)
                .foregroundStyle(.green)
        case .failed:
            Text(statusText(for: app.status))
                .font(.caption)
                .foregroundStyle(.red)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private func actionButton(for app: UpdateableApp) -> some View {
        Button {
            if app.isIOSApp, let appStoreURL = app.appStoreURL {
                openInAppStore(urlString: appStoreURL)
            } else if isNonPrimaryRegion, let appStoreURL = app.appStoreURL {
                openInAppStore(urlString: appStoreURL)
            } else {
                Task { await updateManager.updateApp(app) }
            }
        } label: {
            Text(app.isIOSApp || isNonPrimaryRegion ? "Update in App Store" : "Update")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.green)
        .foregroundStyle(.white)
        .clipShape(Capsule())
        .disabled(app.status != .idle)
        .opacity(app.status == .idle ? 1.0 : 0.5)
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

    private func buildVersionText(for app: UpdateableApp, colorScheme: ColorScheme) -> Text {
        guard let availableVersion = app.availableVersion else {
            if app.source == .sparkle, let installedBuild = app.appInfo.appBuildNumber {
                return Text(verbatim: "\(app.appInfo.appVersion) (\(installedBuild))")
            }
            return Text(verbatim: app.appInfo.appVersion)
        }

        let displayInstalledVersion = app.source == .homebrew ?
            app.appInfo.appVersion.stripBrewRevisionSuffix() : app.appInfo.appVersion
        let displayAvailableVersion = app.source == .homebrew ?
            availableVersion.stripBrewRevisionSuffix() : availableVersion

        // Full version display with build numbers for detail view
        if app.source == .sparkle {
            let installedBuild = app.appInfo.appBuildNumber
            let availableBuild = app.availableBuildNumber

            if !displayInstalledVersion.isEmpty && !displayAvailableVersion.isEmpty &&
               displayInstalledVersion == displayAvailableVersion {
                var result = Text(verbatim: displayInstalledVersion).foregroundColor(.orange)
                if let build = installedBuild {
                    result = result + Text(verbatim: " (\(build))").foregroundColor(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                result = result + Text(verbatim: " → ")
                result = result + Text(verbatim: displayAvailableVersion).foregroundColor(.green)
                result = result + Text(verbatim: " (")
                if let build = availableBuild {
                    result = result + Text(build).foregroundColor(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                result = result + Text(verbatim: ")")
                return result
            } else if displayAvailableVersion.isEmpty, let availableBuild = availableBuild {
                var result = Text(verbatim: displayInstalledVersion).foregroundColor(.orange)
                if let build = installedBuild {
                    result = result + Text(verbatim: " (\(build))").foregroundColor(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                result = result + Text(verbatim: " → build ")
                result = result + Text(availableBuild).foregroundColor(.green)
                return result
            } else {
                var result = Text(verbatim: displayInstalledVersion).foregroundColor(.orange)
                if let build = installedBuild {
                    result = result + Text(verbatim: " (\(build))").foregroundColor(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                result = result + Text(verbatim: " → ")
                result = result + Text(verbatim: displayAvailableVersion).foregroundColor(.green)
                if let build = availableBuild {
                    result = result + Text(verbatim: " (\(build))").foregroundColor(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                return result
            }
        } else {
            var result = Text(verbatim: displayInstalledVersion).foregroundColor(.orange)
            result = result + Text(verbatim: " → ")
            result = result + Text(verbatim: displayAvailableVersion).foregroundColor(.green)
            return result
        }
    }

    private func preprocessChangelogText(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var processed: [String] = []
        var currentLine = ""

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Empty line = paragraph break
            if trimmedLine.isEmpty {
                if !currentLine.isEmpty {
                    processed.append(currentLine)
                    currentLine = ""
                }
                processed.append("")  // Preserve paragraph break
                continue
            }

            // Check if this is a continuation line (starts with spaces in original)
            let isContinuation = line.hasPrefix("  ") || line.hasPrefix("\t")

            // Check if this starts a new item (bullet, number, or header)
            let startsNewItem = trimmedLine.hasPrefix("-") ||
                               trimmedLine.hasPrefix("•") ||
                               trimmedLine.hasPrefix("*") ||
                               trimmedLine.first?.isNumber == true ||
                               trimmedLine.hasSuffix(":")

            if isContinuation && !startsNewItem {
                // Join with previous line (add space if needed)
                if !currentLine.isEmpty && !currentLine.hasSuffix(" ") {
                    currentLine += " "
                }
                currentLine += trimmedLine
            } else {
                // Start new line
                if !currentLine.isEmpty {
                    processed.append(currentLine)
                }
                currentLine = trimmedLine
            }
        }

        // Don't forget the last line
        if !currentLine.isEmpty {
            processed.append(currentLine)
        }

        // Join with proper line breaks
        return processed.joined(separator: "\n")
    }

    private func preprocessHTML(_ html: String) -> String {
        var cleaned = html

        // Remove leading/trailing whitespace and newlines from the entire HTML
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // First pass: Remove empty list items before processing lists
        // Match <li> followed by only whitespace/br tags and then </li>
        cleaned = cleaned.replacingOccurrences(of: #"<li>(\s|<br\s*/?>)*</li>"#, with: "", options: .regularExpression)

        // Remove completely empty lists
        cleaned = cleaned.replacingOccurrences(of: #"<ul>(\s|<br\s*/?>)*</ul>"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"<ol>(\s|<br\s*/?>)*</ol>"#, with: "", options: .regularExpression)

        // Fix malformed structure: </ul><h3>...</h3><ul> → </ul>\n<h3>...</h3>\n<ul>
        // This pattern happens in Postico where lists are split by headers
        cleaned = cleaned.replacingOccurrences(of: #"</ul>\s*(<h[1-6]>)"#, with: "</ul>\n$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(</h[1-6]>)\s*<ul>"#, with: "$1\n<ul>", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"</ol>\s*(<h[1-6]>)"#, with: "</ol>\n$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"(</h[1-6]>)\s*<ol>"#, with: "$1\n<ol>", options: .regularExpression)

        // Second pass: After fixing structure, remove any newly created empty lists
        cleaned = cleaned.replacingOccurrences(of: #"<ul>(\s|<br\s*/?>)*</ul>"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"<ol>(\s|<br\s*/?>)*</ol>"#, with: "", options: .regularExpression)

        // Remove multiple consecutive <br> tags (more than 2)
        cleaned = cleaned.replacingOccurrences(of: #"(<br\s*/?>){3,}"#, with: "<br><br>", options: .regularExpression)

        // Remove excessive whitespace between block elements (more than 1 blank line)
        cleaned = cleaned.replacingOccurrences(of: #"\n\s*\n\s*\n+"#, with: "\n\n", options: .regularExpression)

        // Clean up whitespace around list tags
        cleaned = cleaned.replacingOccurrences(of: #"\s*<ul>\s*"#, with: "<ul>", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s*</ul>\s*"#, with: "</ul>", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s*<ol>\s*"#, with: "<ol>", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s*</ol>\s*"#, with: "</ol>", options: .regularExpression)

        return cleaned
    }

    private func formattedReleaseDescription(_ description: String, for app: UpdateableApp) -> String {
        if app.source == .appStore {
            return description.replacingOccurrences(of: "\n", with: "<br>")
        } else {
            return description
        }
    }

    private func formatDate(_ dateString: String) -> String {
        // RFC 2822 format (e.g., "Mon, 17 Nov 2025 18:53:41 -0800")
        let rfc2822Formatter = DateFormatter()
        rfc2822Formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        rfc2822Formatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = rfc2822Formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        // Sparkle format (e.g., "17 November 2025 18:53:41 +0000")
        let sparkleFormatter = DateFormatter()
        sparkleFormatter.dateFormat = "dd MMMM yyyy HH:mm:ss Z"
        sparkleFormatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = sparkleFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        // Common datetime format (e.g., "2021-11-18 17:06:23")
        let datetimeFormatter = DateFormatter()
        datetimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        datetimeFormatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = datetimeFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        // Date-only format (e.g., "2021-11-18")
        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = dateOnlyFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        // ISO 8601 format without separators (e.g., "2025-11-03T04:59:29Z")
        let compactISO8601Formatter = DateFormatter()
        compactISO8601Formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        compactISO8601Formatter.locale = Locale(identifier: "en_US_POSIX")
        compactISO8601Formatter.timeZone = TimeZone(secondsFromGMT: 0)

        if let date = compactISO8601Formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        // ISO 8601 format (flexible catch-all)
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        // If all parsing fails, return original string
        return dateString
    }

    private func standardizeFont(in nsAttributedString: NSAttributedString) -> AttributedString {
        let mutableString = NSMutableAttributedString(attributedString: nsAttributedString)
        let textRange = NSRange(location: 0, length: mutableString.length)
        let systemFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)

        // Convert SwiftUI colors to NSColor
        let bodyColor = NSColor(ThemeColors.shared(for: colorScheme).primaryText)
        let linkColor = NSColor(ThemeColors.shared(for: colorScheme).accent)

        // Remove all existing styling attributes
        mutableString.removeAttribute(.foregroundColor, range: textRange)
        mutableString.removeAttribute(.backgroundColor, range: textRange)
        mutableString.removeAttribute(.shadow, range: textRange)
        mutableString.removeAttribute(.font, range: textRange)

        // Apply base styling: system font + body text color
        mutableString.addAttribute(.font, value: systemFont, range: textRange)
        mutableString.addAttribute(.foregroundColor, value: bodyColor, range: textRange)

        // Preserve bold/italic traits from original HTML
        nsAttributedString.enumerateAttribute(.font, in: textRange, options: .reverse) { (fontObject, range, _) in
            guard let font = fontObject as? NSFont else { return }

            let traits = font.fontDescriptor.symbolicTraits
            let fontDescriptor = systemFont.fontDescriptor.withSymbolicTraits(traits)
            if let font = NSFont(descriptor: fontDescriptor, size: systemFont.pointSize) {
                mutableString.addAttribute(.font, value: font, range: range)
            }
        }

        // Apply accent color to links
        nsAttributedString.enumerateAttribute(.link, in: textRange, options: []) { (linkValue, range, _) in
            if linkValue != nil {
                mutableString.addAttribute(.foregroundColor, value: linkColor, range: range)
            }
        }

        return AttributedString(mutableString)
    }

    private func openInAppStore(urlString: String) {
        guard var urlComponents = URLComponents(string: urlString) else {
            return
        }
        urlComponents.scheme = "macappstore"
        if let url = urlComponents.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func processedReleaseNotes(for app: UpdateableApp) -> String? {
        // Priority: 1) Fetched external notes, 2) Inline description
        guard let description = (app.fetchedReleaseNotes ?? app.releaseDescription)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        let htmlDescription = formattedReleaseDescription(description, for: app)

        // Check if content is already HTML (contains tags)
        let isHTML = htmlDescription.contains("<") && htmlDescription.contains(">")

        if isHTML {
            // For HTML content: just clean up malformed tags
            return preprocessHTML(htmlDescription)
        } else {
            // For plain text: join continuation lines and convert newlines to <br>
            let cleaned = preprocessChangelogText(htmlDescription)
            return cleaned.replacingOccurrences(of: "\n", with: "<br>")
        }
    }
}
