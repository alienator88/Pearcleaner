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
    @StateObject private var updateManager = UpdateManager.shared
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        if hiddenSidebar {
            HStack {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    UpdaterHiddenHeaderSection(hiddenCount: updateManager.hiddenUpdates.count)
                    Divider()
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

// Header info component
struct UpdaterHiddenHeaderSection: View {
    let hiddenCount: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "eye.slash")
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)

                Text("Hidden Updates")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            }

            HStack(spacing: 0) {
                Text("Hidden Apps:")
                Spacer()
                Text(verbatim: "\(hiddenCount)")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .font(.caption)
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
        case .appStore: return "storefront.fill"
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
