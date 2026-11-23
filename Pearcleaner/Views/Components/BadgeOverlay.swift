//
//  BadgeOverlay.swift
//  Pearcleaner
//
//  Unified overlay component for all toolbar badge notifications
//  Created by Alin Lupascu on 10/23/25.
//

import SwiftUI
import AlinFoundation

enum OverlayType {
    case permissions
    case update
    case announcement
}

struct BadgeOverlay: View {
    @EnvironmentObject var updater: Updater
    @ObservedObject var permissionManager = PermissionManagerLocal.shared
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.badgeOverlaysEnabled") private var badgeOverlaysEnabled: Bool = true
    @State private var isVisible: Bool = false
    @State private var isExpanded: Bool = false
    @State private var showPermissionList: Bool = false
    @State private var showUpdateView: Bool = false
    @State private var showFeatureView: Bool = false
    @State private var dismissedOverlays: Set<OverlayType> = []

    // Determine which overlay to show based on priority (permissions → update → announcement)
    private var currentOverlay: OverlayType? {
        // Permissions: highest priority
        if permissionManager.shouldShowPermissionWarning {
            if !dismissedOverlays.contains(.permissions) {
                return .permissions
            }
        }

        // Update: third priority
        if updater.updateAvailable && !dismissedOverlays.contains(.update) {
            return .update
        }

        // Announcement: lowest priority
        if updater.announcementAvailable && !dismissedOverlays.contains(.announcement) {
            return .announcement
        }

        return nil
    }

    private var shouldShowOverlay: Bool {
        badgeOverlaysEnabled && currentOverlay != nil
    }

    var body: some View {
        if shouldShowOverlay {
            VStack {
                Spacer()
                HStack {
                    Spacer()

                    VStack(alignment: .leading, spacing: 12) {
                        // Header + Content determined by enum switch
                        if let overlay = currentOverlay {
                            switch overlay {
                            case .permissions:
                                permissionsContent
                            case .update:
                                updateContent
                            case .announcement:
                                announcementContent
                            }
                        }
                    }
                    .padding(10)
                    .frame(width: 410)
                    .ifGlassSidebar()
//                    .background(
//                        RoundedRectangle(cornerRadius: 12)
//                            .fill(ThemeColors.shared(for: colorScheme).secondaryBG)
//                            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)
//                    )
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 20)
                }
            }
            .onAppear {
                withAnimation(animationEnabled ? .spring(response: 0.4, dampingFraction: 0.8) : .none) {
                    isVisible = true
                }
            }
            .onDisappear {
            }
            .onChange(of: currentOverlay) { newValue in
                // Animate when switching between overlay types or showing/hiding
                withAnimation(animationEnabled ? .spring(response: 0.4, dampingFraction: 0.8) : .none) {
                    isVisible = newValue != nil
                }
                // Reset expansion when switching between overlay types
                if newValue != nil {
                    isExpanded = false
                }
            }
        }
    }

    // MARK: - Permissions Content

    @ViewBuilder
    private var permissionsContent: some View {
        HStack(alignment: .top) {
            Image(systemName: "lock.slash.fill")
                .foregroundColor(.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions Missing!")
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        Text("Pearcleaner requires permissions to search all system locations comprehensively.")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if let results = permissionManager.results {
                            Text("Missing permissions:")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                            ForEach(results.checkedPermissions, id: \.self) { permission in
                                if !results.grantedPermissions.contains(permission) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                        Text(permissionName(for: permission))
                                            .font(.caption)
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    }
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            Spacer()

            Button {
                dismissOverlay()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }

        Divider()

        HStack {
            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Open System Settings")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ThemeColors.shared(for: colorScheme).accent)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Open System Settings to grant permissions")

            Button {
                permissionManager.checkPermissions(types: [.fullDiskAccess]) { results in
                    permissionManager.results = results
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ThemeColors.shared(for: colorScheme).secondaryText)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Retry permission check")

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(isExpanded ? "See less" : "See more")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Update Content

    @ViewBuilder
    private var updateContent: some View {
        HStack(alignment: .top) {
            Image(systemName: "icloud.and.arrow.down.fill")
                .foregroundColor(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 8) {
                Text("Update Available!")
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        Text("A new version of Pearcleaner is available for download.")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            Spacer()

            Button {
                dismissOverlay()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }

        Divider()

        HStack {
            Button {
                showUpdateView.toggle()
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("View Update")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ThemeColors.shared(for: colorScheme).accent)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("View update details and download")
            .sheet(isPresented: $showUpdateView) {
                updater.getUpdateView()
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(isExpanded ? "See less" : "See more")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Announcement Content

    @ViewBuilder
    private var announcementContent: some View {
        HStack(alignment: .top) {
            Image(systemName: "sparkles")
                .foregroundColor(.purple)
                .font(.title3)

            VStack(alignment: .leading, spacing: 8) {
                Text("New Feature!")
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        Text("Check out the latest additions to Pearcleaner.")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            Spacer()

            Button {
                dismissOverlay()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }

        Divider()

        HStack {
            Button {
                showFeatureView.toggle()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Learn More")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ThemeColors.shared(for: colorScheme).accent)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("View announcement details")
            .sheet(isPresented: $showFeatureView) {
                updater.getAnnouncementView()
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(isExpanded ? "See less" : "See more")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helper Functions

    private func dismissOverlay() {
        withAnimation(animationEnabled ? .easeOut(duration: 0.2) : .none) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let overlay = currentOverlay else { return }

            // Add any dismissed overlay to the set (dismissed for this session)
            // Helper can be re-shown by removing from set via notification
            dismissedOverlays.insert(overlay)
        }
    }

    private func permissionName(for permission: PermissionManagerLocal.PermissionType) -> String {
        switch permission {
        case .fullDiskAccess:
            return "Full Disk Access".localized()
        }
    }
}
