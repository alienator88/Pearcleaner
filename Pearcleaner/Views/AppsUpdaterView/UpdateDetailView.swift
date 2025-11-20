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
                .offset(x: -5)

                // Action buttons in header
                HStack(spacing: 8) {
                    if app.source != .unsupported {
                        actionButton(for: app)
                    }

                    if app.source != .unsupported {
                        Button("Skip Version") {
                            // TODO: Implement skip version
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        .clipShape(Capsule())

                        Button("Ignore") {
                            updateManager.hideApp(app)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
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
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                        .disabled(isLoadingCasks)
                        .opacity(isLoadingCasks ? 0.5 : 1.0)
                    }
                }
            }

            Divider()

            // Info section (SOURCE, RELEASED, CHECKED)
            HStack(spacing: 40) {

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
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

                Divider().frame(height: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text("RELEASED")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    if let date = app.releaseDate {
                        Text(formatDate(date))
                            .font(.body)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    } else {
                        Text("Unknown")
                            .font(.body)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }

                Divider().frame(height: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text("PLACEHOLDER")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text("Test")
                        .font(.body)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                }

                Spacer()
            }

            // Release details (if available)
            if app.source == .sparkle || app.source == .appStore {
                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    Text("What's New")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    // Release title
                    if let title = app.releaseTitle {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }

                    // Release date
                    if let date = app.releaseDate {
                        Text("Released: \(formatDate(date))")
                            .font(.subheadline)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    // Release description (HTML formatted) - scrollable section
                    if let description = app.releaseDescription {
                        ScrollView {
                            let htmlDescription = formattedReleaseDescription(description, for: app)

                            if let nsAttributedString = try? NSAttributedString(
                                data: Data(htmlDescription.utf8),
                                options: [.documentType: NSAttributedString.DocumentType.html,
                                         .characterEncoding: String.Encoding.utf8.rawValue],
                                documentAttributes: nil
                            ) {
                                let standardizedString = standardizeFont(in: nsAttributedString)

                                Text(standardizedString)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            } else {
                                Text(description)
                                    .font(.body)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                        .scrollIndicators(scrollIndicators ? .visible : .hidden)
                        .frame(maxHeight: 200)
                    }

                    // Release notes link
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

    private func formattedReleaseDescription(_ description: String, for app: UpdateableApp) -> String {
        if app.source == .appStore {
            return description.replacingOccurrences(of: "\n", with: "<br>")
        } else {
            return description
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let sparkleFormatter = DateFormatter()
        sparkleFormatter.dateFormat = "dd MMMM yyyy HH:mm:ss Z"
        sparkleFormatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = sparkleFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        return dateString
    }

    private func standardizeFont(in nsAttributedString: NSAttributedString) -> AttributedString {
        let mutableString = NSMutableAttributedString(attributedString: nsAttributedString)
        let systemFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let range = NSRange(location: 0, length: mutableString.length)
        mutableString.addAttribute(.font, value: systemFont, range: range)
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
}
