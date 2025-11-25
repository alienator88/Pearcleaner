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
    @EnvironmentObject var updateManager: UpdateManager
    @EnvironmentObject var brewManager: HomebrewManager
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @State private var showAdoptionSheet: Bool = false
    @State private var isLoadingCasks: Bool = false

    // Inline adoption state for unsupported apps
    @State private var matchingCasks: [AdoptableCask] = []
    @State private var selectedCaskToken: String? = nil
    @State private var manualEntry: String = ""
    @State private var manualEntryValidation: AdoptableCask? = nil
    @State private var isAdopting: Bool = false
    @State private var adoptionError: String? = nil
    @State private var isSearchingCasks: Bool = false

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
                        HStack(spacing: 8) {
                            Text(app.appInfo.appName)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                            // Pre-release indicator (Sparkle only)
                            if app.source == .sparkle && app.isPreRelease {
                                if #available(macOS 14.0, *) {
                                    Image(systemName: "flask.fill")
                                        .font(.title3)
                                        .foregroundStyle(.green)
                                        .help("Pre-release")
                                } else {
                                    Image(systemName: "testtube.2")
                                        .font(.title3)
                                        .foregroundStyle(.green)
                                        .help("Pre-release")
                                }
                            }

                            // App Store button (App Store only)
                            if app.source == .appStore, let appStoreURL = app.appStoreURL {
                                Button {
                                    openInAppStore(urlString: appStoreURL)
                                } label: {
                                    Image(systemName: ifOSBelow(macOS: 14) ? "cart.fill" : "storefront.fill")
                                        .font(.title3)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                                }
                                .buttonStyle(.plain)
                                .help("View in App Store")
                            }

                            // Unsupported indicator
                            if app.source == .unsupported {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                                    .help("Unsupported")
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                // Status view (leading edge of button)
                                statusView(for: app)

                                // Action button (right edge)
                                buildExpandableActionButton(for: app)
                            }
                        }

                        // Version info with build numbers
                        buildVersionText(for: app, colorScheme: colorScheme)
                            .font(.title3)
                            .help(buildNumberTooltip(for: app) ?? "")

                        // Non-primary region warning
                        if isNonPrimaryRegion, let region = app.foundInRegion {
                            Text("Found in \(region) App Store. Open in App Store to update.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Divider()

            // Unsupported apps: Show inline adoption view
            if app.source == .unsupported {
                unsupportedContentView(for: app)
            }
            // Current apps: Show simple "up to date" message
            else if app.source == .current {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("App is up to date")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // All other apps: Show normal info and release notes
            else {
                // Release details (only for apps with updates)
                VStack(alignment: .leading, spacing: 16) {

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
                .padding(.horizontal, 5)

                // Metadata row at bottom
                Divider()

                metadataRow(for: app)
            }

            Spacer()
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAdoptionSheet) {
            AdoptionSheetView(
                appInfo: app.appInfo,
                context: .updaterView,
                isPresented: $showAdoptionSheet
            )
        }
        .onAppear {
            loadCasksForAdoption()
        }
        .onChange(of: appId) { newAppId in
            // Clear cask search state when switching apps
            matchingCasks = []
            selectedCaskToken = nil
            manualEntry = ""
            manualEntryValidation = nil
            isAdopting = false
            adoptionError = nil
            isSearchingCasks = false

            // Re-trigger cask search for new unsupported app
            // Use Task to allow SwiftUI to update with new app first
            Task {
                // Look up the new app directly from updateManager
                if let newApp = updateManager.updatesBySource.values
                    .flatMap({ $0 })
                    .first(where: { $0.id == newAppId }),
                   newApp.source == .unsupported {
                    await MainActor.run {
                        searchForMatchingCasks(for: newApp)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metadataRow(for app: UpdateableApp) -> some View {
        HStack(spacing: 0) {
            // Released date
            HStack(spacing: 0) {
                Spacer()
                if let date = app.releaseDate {
                    Text(formatDate(date))
                        .font(.subheadline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
                Spacer()
            }

            // Source
            HStack(spacing: 0) {
                Spacer()
                HStack(spacing: 4) {
                    Text(app.source.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    if app.isIOSApp {
                        Text(verbatim: "(iOS)")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                Spacer()
            }

            // Changelog
            HStack(spacing: 0) {
                Spacer()
                if let link = app.releaseNotesLink, let url = URL(string: link) {
                    Link(destination: url) {
                        Text("View Changelog")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("No Changelog")
                        .font(.subheadline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }
                Spacer()
            }
        }
        .padding(.vertical, 5)
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

    private func buildExpandableActionButton(for app: UpdateableApp) -> ExpandableActionButton {
        // Current apps: Hide (primary) + Adopt (secondary, if applicable)
        if app.source == .current {
            let primaryAction = ActionButtonItem(
                title: "Hide",
                foregroundColor: .red,
                backgroundColor: ThemeColors.shared(for: colorScheme).secondaryBG,
                action: {
                    updateManager.hideApp(app, skipVersion: nil)
                }
            )

            var secondaryActions: [ActionButtonItem] = []

            // Add Adopt button for non-Homebrew current apps
            if app.appInfo.cask == nil {
                secondaryActions.append(ActionButtonItem(
                    title: "Adopt",
                    foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                    backgroundColor: ThemeColors.shared(for: colorScheme).secondaryBG,
                    isDisabled: isLoadingCasks,
                    action: {
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
                    }
                ))
            }

            return ExpandableActionButton(
                primaryAction: primaryAction,
                secondaryActions: secondaryActions
            )
        }
        // Unsupported apps: Hide only (no dropdown)
        else if app.source == .unsupported {
            let primaryAction = ActionButtonItem(
                title: "Hide",
                foregroundColor: .red,
                backgroundColor: ThemeColors.shared(for: colorScheme).secondaryBG,
                action: {
                    updateManager.hideApp(app, skipVersion: nil)
                }
            )

            return ExpandableActionButton(
                primaryAction: primaryAction,
                secondaryActions: []
            )
        }
        // Apps with updates: Update (primary) + Skip + Hide + Adopt (secondary)
        else {
            let primaryAction = ActionButtonItem(
                title: app.isIOSApp || isNonPrimaryRegion ? "Update in App Store" : "Update",
                foregroundColor: .white,
                backgroundColor: .green,
                isDisabled: app.status != .idle,
                action: {
                    if app.isIOSApp, let appStoreURL = app.appStoreURL {
                        openInAppStore(urlString: appStoreURL)
                    } else if isNonPrimaryRegion, let appStoreURL = app.appStoreURL {
                        openInAppStore(urlString: appStoreURL)
                    } else {
                        Task { await updateManager.updateApp(app) }
                    }
                }
            )

            var secondaryActions: [ActionButtonItem] = []

            // Skip button
            if let availableVersion = app.availableVersion {
                let displayVersion = app.source == .homebrew ?
                    availableVersion.stripBrewRevisionSuffix() : availableVersion
                secondaryActions.append(ActionButtonItem(
                    title: "Skip \(displayVersion)",
                    foregroundColor: .orange,
                    backgroundColor: ThemeColors.shared(for: colorScheme).secondaryBG,
                    action: {
                        updateManager.hideApp(app, skipVersion: availableVersion)
                    }
                ))
            }

            // Hide button
            secondaryActions.append(ActionButtonItem(
                title: "Hide",
                foregroundColor: .red,
                backgroundColor: ThemeColors.shared(for: colorScheme).secondaryBG,
                action: {
                    updateManager.hideApp(app, skipVersion: nil)
                }
            ))

            // Adopt button for non-Homebrew apps
            if app.source != .homebrew && app.appInfo.cask == nil {
                secondaryActions.append(ActionButtonItem(
                    title: "Adopt",
                    foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                    backgroundColor: ThemeColors.shared(for: colorScheme).secondaryBG,
                    isDisabled: isLoadingCasks,
                    action: {
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
                    }
                ))
            }

            return ExpandableActionButton(
                primaryAction: primaryAction,
                secondaryActions: secondaryActions
            )
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

    private func buildVersionText(for app: UpdateableApp, colorScheme: ColorScheme) -> Text {
        // Current apps: Show only installed version (no arrow)
        if app.source == .current {
            if app.source == .sparkle, let installedBuild = app.appInfo.appBuildNumber {
                let displayBuild = installedBuild.count > 5 ? String(installedBuild.prefix(5)) + "..." : installedBuild
                return Text(verbatim: "\(app.appInfo.appVersion) (\(displayBuild))")
            }
            return Text(verbatim: app.appInfo.appVersion)
        }

        guard let availableVersion = app.availableVersion else {
            if app.source == .sparkle, let installedBuild = app.appInfo.appBuildNumber {
                let displayBuild = installedBuild.count > 5 ? String(installedBuild.prefix(5)) + "..." : installedBuild
                return Text(verbatim: "\(app.appInfo.appVersion) (\(displayBuild))")
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

            // Truncate build numbers to 6 characters
            let displayInstalledBuild = installedBuild.map { $0.count > 6 ? String($0.prefix(6)) + "..." : $0 }
            let displayAvailableBuild = availableBuild.map { $0.count > 6 ? String($0.prefix(6)) + "..." : $0 }

            if !displayInstalledVersion.isEmpty && !displayAvailableVersion.isEmpty &&
               displayInstalledVersion == displayAvailableVersion {
                var result = Text(verbatim: displayInstalledVersion).foregroundColor(.orange)
                if let build = displayInstalledBuild {
                    result = result + Text(verbatim: " (\(build))").foregroundColor(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                result = result + Text(verbatim: " → ")
                result = result + Text(verbatim: displayAvailableVersion).foregroundColor(.green)
                result = result + Text(verbatim: " (")
                if let build = displayAvailableBuild {
                    result = result + Text(build).foregroundColor(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                result = result + Text(verbatim: ")")
                return result
            } else if displayAvailableVersion.isEmpty, let availableBuild = displayAvailableBuild {
                var result = Text(verbatim: displayInstalledVersion).foregroundColor(.orange)
                if let build = displayInstalledBuild {
                    result = result + Text(verbatim: " (\(build))").foregroundColor(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                result = result + Text(verbatim: " → build ")
                result = result + Text(availableBuild).foregroundColor(.green)
                return result
            } else {
                var result = Text(verbatim: displayInstalledVersion).foregroundColor(.orange)
                if let build = displayInstalledBuild {
                    result = result + Text(verbatim: " (\(build))").foregroundColor(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                result = result + Text(verbatim: " → ")
                result = result + Text(verbatim: displayAvailableVersion).foregroundColor(.green)
                if let build = displayAvailableBuild {
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

    private func buildNumberTooltip(for app: UpdateableApp) -> String? {
        let installedBuild = app.appInfo.appBuildNumber
        let availableBuild = app.availableBuildNumber

        // Only show tooltip if at least one build number exists and is > 6 chars
        guard (installedBuild?.count ?? 0) > 6 || (availableBuild?.count ?? 0) > 6 else {
            return nil
        }

        if app.source == .current {
            if let build = installedBuild {
                return "Build: \(build)"
            }
        } else {
            // Apps with updates
            var parts: [String] = []
            if let installed = installedBuild {
                parts.append("Installed: \(installed)")
            }
            if let available = availableBuild {
                parts.append("Available: \(available)")
            }
            return parts.joined(separator: " → ")
        }

        return nil
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

    // MARK: - Unsupported App Content View

    @ViewBuilder
    private func unsupportedContentView(for app: UpdateableApp) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("This application does not have a supported installer. You may try to adopt it into Homebrew if it exists in the Cask repo.")
                .font(.body)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                .padding(.horizontal)

            // Inline adoption view
            if isSearchingCasks || brewManager.allAvailableCasks.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Searching for matching casks...")
                            .font(.body)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Scrollable matching casks section
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            CaskAdoptionContentView(
                                matchingCasks: $matchingCasks,
                                selectedCaskToken: $selectedCaskToken,
                                manualEntry: $manualEntry,
                                manualEntryValidation: $manualEntryValidation,
                                adoptionError: $adoptionError,
                                onManualEntryChange: validateManualEntry,
                                limitCaskListHeight: false,
                                showManualEntry: false
                            )
                        }
                        .padding(.horizontal)
                    }
                    .scrollIndicators(scrollIndicators ? .visible : .hidden)

                    // Bottom-pinned manual entry and button section
                    VStack(alignment: .leading, spacing: 12) {
//                        Divider()

                        // Manual entry section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Manual Entry")
                                .font(.headline)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                            Text("If the correct cask isn't listed above, enter the cask token manually:")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                            HStack(spacing: 8) {
                                TextField("e.g., firefox", text: $manualEntry)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: manualEntry) { newValue in
                                        validateManualEntry(newValue)
                                    }

                                if !manualEntry.isEmpty {
                                    if let validation = manualEntryValidation {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .help("Valid cask: \(validation.displayName)")
                                    } else if manualEntry.count >= 2 {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                            .help("Cask not found")
                                    }
                                }
                            }
                        }

                        // Adopt button
                        HStack {
                            Spacer()
                            Button(isAdopting ? "Adopting..." : "Adopt with Homebrew") {
                                performAdoption(for: app)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isAdopting || !canAdopt)
                        }
                    }
                    .padding([.horizontal, .top])
                    .background(ThemeColors.shared(for: colorScheme).primaryBG)
                }
            }
        }
    }

    // MARK: - Adoption Support Methods

    private var canAdopt: Bool {
        if isSearchingCasks || isAdopting { return false }

        if let selected = selectedCaskToken, !selected.isEmpty {
            return true
        }

        if manualEntryValidation != nil, !manualEntry.isEmpty {
            return true
        }

        return false
    }

    private var selectedCask: AdoptableCask? {
        if let token = selectedCaskToken {
            return matchingCasks.first(where: { $0.token == token })
        }
        return manualEntryValidation
    }

    private func loadCasksForAdoption() {
        guard let app = app else { return }

        // Load casks if not already loaded
        if brewManager.allAvailableCasks.isEmpty {
            isSearchingCasks = true
            Task {
                await brewManager.loadAvailablePackages(appState: appState)
                await MainActor.run {
                    searchForMatchingCasks(for: app)
                }
            }
        } else {
            searchForMatchingCasks(for: app)
        }
    }

    private func searchForMatchingCasks(for app: UpdateableApp) {
        isSearchingCasks = true

        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

            let matches = findMatchingCasks(for: app.appInfo, from: brewManager.allAvailableCasks)

            await MainActor.run {
                matchingCasks = matches
                isSearchingCasks = false

                // Auto-select first compatible cask if there's only one
                if matches.count == 1, matches[0].isVersionCompatible {
                    selectedCaskToken = matches[0].token
                }
            }
        }
    }

    private func validateManualEntry(_ token: String) {
        guard let app = app else { return }
        guard !token.isEmpty, token.count >= 2 else {
            manualEntryValidation = nil
            return
        }

        let validated = validateManualCaskEntry(token, for: app.appInfo, from: brewManager.allAvailableCasks)
        if validated != nil {
            manualEntryValidation = validated
            selectedCaskToken = nil
        } else {
            manualEntryValidation = nil
        }
    }

    private func performAdoption(for app: UpdateableApp) {
        guard let cask = selectedCask else { return }

        isAdopting = true
        adoptionError = nil

        Task {
            do {
                try await HomebrewController.shared.adoptCask(token: cask.token)

                await brewManager.loadInstalledPackages()
                invalidateCaskLookupCache()

                let folderPaths = await MainActor.run {
                    FolderSettingsManager.shared.folderPaths
                }
                await loadAppsAsync(folderPaths: folderPaths, useStreaming: false)

                await MainActor.run {
                    isAdopting = false
                }

                // Trigger update scan to recategorize the app
                await UpdateManager.shared.scanIfNeeded(forceReload: true, sources: [.homebrew])
            } catch {
                await MainActor.run {
                    adoptionError = "Failed to adopt: \(error.localizedDescription)"
                    isAdopting = false
                }
            }
        }
    }

    // MARK: - Helper Methods

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
