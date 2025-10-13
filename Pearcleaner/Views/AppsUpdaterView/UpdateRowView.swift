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
    @StateObject private var updateManager = UpdateManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false

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
            Button(app.source == .sparkle ? "Open" : "Update") {
                Task { await updateManager.updateApp(app) }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var secondaryActionButtons: some View {
        // Info button for App Store apps
        if app.source == .appStore, let appStoreURL = app.appStoreURL {
            Button {
                openInAppStore(urlString: appStoreURL)
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
            }
            .buttonStyle(.plain)
            .help("View in App Store")
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Source icon (circular background)
            ZStack {
                Circle()
                    .fill(sourceColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: sourceIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(sourceColor)
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
}
