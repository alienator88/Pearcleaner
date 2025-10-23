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
    case helper
    case permissions
    case update
    case announcement
}

struct BadgeOverlay: View {
    @EnvironmentObject var updater: Updater
    @ObservedObject var helperManager = HelperToolManager.shared
    @ObservedObject var permissionManager = PermissionManager.shared
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @State private var isVisible: Bool = false
    @State private var isExpanded: Bool = false
    @State private var showPermissionList: Bool = false
    @State private var showUpdateView: Bool = false
    @State private var showFeatureView: Bool = false
    @State private var dismissedOverlays: Set<OverlayType> = []

    // Determine which overlay to show based on priority (helper → permissions → update → announcement)
    private var currentOverlay: OverlayType? {
        // Helper: highest priority
        if !helperManager.isHelperToolInstalled {
            if !dismissedOverlays.contains(.helper) {
                return .helper
            }
        }

        // Permissions: second priority
        if permissionManager.results != nil && !permissionManager.allPermissionsGranted {
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
        currentOverlay != nil
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
                            case .helper:
                                helperContent
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
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeColors.shared(for: colorScheme).secondaryBG)
                            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)
                    )
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

                // Listen for helper required notifications to re-show helper overlay
                NotificationCenter.default.addObserver(
                    forName: .helperRequired,
                    object: nil,
                    queue: .main
                ) { [self] _ in
                    dismissedOverlays.remove(.helper)
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: .helperRequired, object: nil)
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

    // MARK: - Helper Content

    @ViewBuilder
    private var helperContent: some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 8) {
                Text("Privileged Helper Not Installed!")
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                // Expanded content
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        Text("When the helper tool was introduced March 2025, it was said that AuthorizationExecuteWithPrivileges (granting authentication via password prompt popup) would eventually be removed as it has already been deprecated by Apple. Some functionality will stop working in Pearcleaner if the helper isn't enabled going forward.")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Some of the features that require the helper:")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 6) {
                                Text(verbatim: "•")
                                Text("Delete system-protected files and folders")
                            }
                            HStack(alignment: .top, spacing: 6) {
                                Text(verbatim: "•")
                                Text("Unload launch daemons and agents")
                            }
                            HStack(alignment: .top, spacing: 6) {
                                Text(verbatim: "•")
                                Text("Manage PKG receipts and installations")
                            }
                            HStack(alignment: .top, spacing: 6) {
                                Text(verbatim: "•")
                                Text("Perform updates on 3rd party apps, and more")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
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
                openAppSettingsWindow(tab: .helper, updater: updater)
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Enable Helper")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ThemeColors.shared(for: colorScheme).accent)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Open Settings to enable the Privileged Helper")

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

    private func permissionName(for permission: PermissionManager.PermissionType) -> String {
        switch permission {
        case .fullDiskAccess:
            return "Full Disk Access".localized()
        case .accessibility:
            return "Accessibility".localized()
        case .automation:
            return "Automation".localized()
        }
    }
}
