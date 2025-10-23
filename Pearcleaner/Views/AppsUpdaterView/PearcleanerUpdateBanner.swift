//
//  PearcleanerUpdateBanner.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/22/25.
//

import SwiftUI
import AlinFoundation

struct PearcleanerUpdateBanner: View {
    @EnvironmentObject var updater: Updater
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false
    @State private var isExpanded: Bool = false

    var newVersion: String? {
        updater.releases.first?.tagName
    }

    var releaseNotes: String? {
        updater.releases.first?.body
    }

    // Computed properties for update state
    var isUpdating: Bool {
        updater.progressBar.1 > 0.0 && updater.progressBar.1 < 1.0
    }

    var isUpdateComplete: Bool {
        updater.progressBar.1 == 1.0
    }

    var hasError: Bool {
        let errorKeywords = ["failed", "error", "invalid", "no releases", "no downloadable"]
        return updater.progressBar.1 == 0.0 && errorKeywords.contains { updater.progressBar.0.lowercased().contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row (matching UpdateRowView exactly)
            HStack(alignment: .center, spacing: 12) {
                // App icon (Pearcleaner's icon)
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                }

                // App name and version
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pearcleaner")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    // Version info
                    if let newVersion = newVersion {
                        Text(verbatim: "\(updater.currentVersion) → \(newVersion)")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }

                Spacer()

                // Dynamic button based on update state
                if isUpdateComplete {
                    // Show Restart button after update completes
                    Button {
                        relaunchApp(afterDelay: 1)
                    } label: {
                        Text("Restart")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.green)
                } else if !isUpdating {
                    // Show Install Update button before update starts
                    Button {
                        updater.downloadUpdate()
                    } label: {
                        Text("Install Update")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(hasError ? .red : .orange)
                }

                // View Changes button (hidden during update)
                if releaseNotes != nil && !isUpdating {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "Close" : "View Changes")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(ThemeColors.shared(for: colorScheme).accent)
                }
            }
            .padding()

            // Progress indicator (shown during update or on error)
            if isUpdating || hasError {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        // Status message
                        Text(updater.progressBar.0)
                            .font(.callout)
                            .foregroundStyle(hasError ? .red : ThemeColors.shared(for: colorScheme).primaryText)

                        Spacer()

                        // Percentage (only show during active update)
                        if isUpdating {
                            Text(verbatim: "\(Int(updater.progressBar.1 * 100))%")
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                    }
                    .padding(.horizontal)

                    // Progress bar (only show during active update)
                    if isUpdating {
                        ProgressView(value: updater.progressBar.1, total: 1.0)
                            .progressViewStyle(.linear)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }

            // Expanded release notes (matching UpdateRowView)
            if isExpanded, let release = updater.releases.first {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        // Release title
                        Text(release.name)
                            .font(.headline)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                        // Release notes (HTML rendering with modifiedBody)
                        ScrollView {
                            if let modifiedBody = release.modifiedBody(owner: "alienator88", repo: "Pearcleaner") {
                                Text(AttributedString(modifiedBody))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            } else if let body = releaseNotes {
                                Text(body)
                                    .font(.body)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxHeight: 200)
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
}
