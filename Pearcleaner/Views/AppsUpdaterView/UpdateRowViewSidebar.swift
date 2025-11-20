//
//  UpdateRowViewSidebar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/19/25.
//

import SwiftUI
import AlinFoundation

struct UpdateRowViewSidebar: View {
    let app: UpdateableApp
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @State private var isHovered: Bool = false
    @StateObject private var updateManager = UpdateManager.shared

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
        case .current:
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
        case .current:
            return "app"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                // App icon
                if let appIcon = app.appInfo.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Fallback to source icon with colored background
                    ZStack {
                        Circle()
                            .fill(sourceColor.opacity(0.2))
                            .frame(width: 30, height: 30)

                        Image(systemName: sourceIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(sourceColor)
                    }
                }

                // App name and version
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: app.appInfo.appName)
                        .font(.system(size: isSelected ? 14 : 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Version info
                    buildVersionText(for: app, colorScheme: colorScheme)
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 35)
            .background(Color.white.opacity(0.000000001))
            .padding(.trailing)
            .padding(.vertical, 5)
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
        .padding(.leading, 10)
        .onHover { hovering in
            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.20 : 0)) {
                isHovered = hovering
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected && !glass ? ThemeColors.shared(for: colorScheme).secondaryBG : .clear
                )
        }
        .overlay {
            if isHovered || isSelected {
                HStack {
                    Spacer()
                    ZStack {
                        // Morphing shape that animates between rectangle and square
                        RoundedRectangle(cornerRadius: isSelected ? 6 : 50)
                            .fill(
                                isSelected
                                    ? ThemeColors.shared(for: colorScheme).accent
                                    : ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5)
                            )
                            .frame(width: isSelected ? 20 : 2, height: isSelected ? 20 : 25)

                        if isSelected {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .opacity(isSelected ? 1 : 0)
                        }
                    }
                    .padding(.trailing, 7)
                }
                .allowsHitTesting(false)
            }
        }
        .task(id: app.id) {
            // Fetch external release notes if we have a link but no content yet
            guard let notesLink = app.releaseNotesLink,
                  let notesURL = URL(string: notesLink),
                  app.fetchedReleaseNotes == nil else {
                return
            }

            await fetchReleaseNotes(for: app.id, from: notesURL)
        }
    }

    private func buildVersionText(for app: UpdateableApp, colorScheme: ColorScheme) -> Text {
        // For unsupported and current apps, just show the installed version (no arrow)
        if app.source == .unsupported || app.source == .current {
            return Text(verbatim: app.appInfo.appVersion)
                .foregroundColor(ThemeColors.shared(for: colorScheme).secondaryText)
        }

        guard let availableVersion = app.availableVersion else {
            // No available version (shouldn't happen, but handle gracefully)
            return Text(verbatim: app.appInfo.appVersion)
        }

        // Clean Homebrew versions for display (strip commit hash)
        let displayInstalledVersion = app.source == .homebrew ?
            app.appInfo.appVersion.stripBrewRevisionSuffix() : app.appInfo.appVersion
        let displayAvailableVersion = app.source == .homebrew ?
            availableVersion.stripBrewRevisionSuffix() : availableVersion

        // Simple version display without build numbers
        var result = Text(verbatim: displayInstalledVersion).foregroundColor(.orange)
        result = result + Text(verbatim: " → ").foregroundColor(ThemeColors.shared(for: colorScheme).secondaryText)
        result = result + Text(verbatim: displayAvailableVersion).foregroundColor(.green)
        return result
    }

    private func fetchReleaseNotes(for appId: UUID, from url: URL) async {
        do {
            var request = URLRequest(url: url, timeoutInterval: 3)
            request.httpMethod = "GET"

            // This runs on a background thread automatically
            let (data, _) = try await URLSession.shared.data(for: request)

            guard let content = String(data: data, encoding: .utf8) else { return }

            // Update the app's fetchedReleaseNotes in the UpdateManager (must be on main thread)
            await MainActor.run {
                updateManager.updateFetchedReleaseNotes(for: appId, content: content)
            }
        } catch {
            // Silent failure - will fall back to inline description
        }
    }
}
