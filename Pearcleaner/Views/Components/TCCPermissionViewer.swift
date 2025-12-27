//
//  TCCPermissionViewer.swift
//  Pearcleaner
//
//  Sheet view for displaying TCC (privacy) permissions for an application
//

import SwiftUI

struct TCCPermissionViewer: View {
    let bundleIdentifier: String
    let appName: String
    let onClose: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isLoading: Bool = true
    @State private var result: TCCQueryResult = TCCQueryResult()

    var body: some View {
        StandardSheetView(
            title: "Permissions for \(appName)",
            width: 700,
            height: 500,
            onClose: onClose,
            content: {
                // Content area - no tabs
                if isLoading {
                    loadingView
                } else if !result.hasAnyPermissions {
                    emptyStateView(message: "No permissions found")
                } else {
                    permissionListView(permissions: result.allPermissions)
                }
            },
            actionButtons: {
                HStack(spacing: 12) {
                    Button("Refresh") {
                        loadPermissions()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)

                    Button("Close") {
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        )
        .onAppear {
            loadPermissions()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading permissions...")
                .font(.body)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                .padding(.top, 12)
            Spacer()
        }
    }

    // MARK: - Permission List View

    private func permissionListView(
        permissions: [TCCPermission]
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(permissions) { permission in
                    permissionRow(permission)

                    if permission.id != permissions.last?.id {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Permission Row

    private func permissionRow(_ permission: TCCPermission) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Permission name
                Text(permission.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                // Source badge (USER or SYSTEM)
                Text(permission.source.rawValue)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(permission.sourceColor.opacity(0.15))
                    .foregroundStyle(permission.sourceColor)
                    .cornerRadius(4)

                Spacer()

                // Status badge
                Text(permission.statusText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(permission.statusColor.opacity(0.2))
                    .foregroundStyle(permission.statusColor)
                    .cornerRadius(6)
            }

            // Optional details
            if permission.reasonText != nil || permission.lastModified != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let reasonText = permission.reasonText {
                        Text("Previous action: \(reasonText)")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    if let date = permission.lastModified {
                        Text("Last modified: \(formattedDate(date))")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 48))
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.5))

            Text(message)
                .font(.body)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load Permissions

    private func loadPermissions() {
        isLoading = true

        Task {
            let queryResult = await TCCQueryHelper.queryAllDatabases(
                bundleIdentifier: bundleIdentifier
            )

            await MainActor.run {
                self.result = queryResult
                self.isLoading = false
            }
        }
    }

    // MARK: - Formatting

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
