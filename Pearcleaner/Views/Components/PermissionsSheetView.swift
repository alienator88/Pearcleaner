//
//  PermissionsSheetView.swift
//  Pearcleaner
//
//  Custom permissions view with ThemeColors integration
//

import SwiftUI
import AlinFoundation

struct PermissionsSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var permissionManager = PermissionManager.shared

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            // Title
            HStack {
                Spacer()
                Text(LocalizedStringKey("Permission Status"))
                    .font(.title2)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                Spacer()
            }

            Divider()

            // Permission list
            if let results = permissionManager.results {
                ForEach(results.checkedPermissions, id: \.self) { permission in
                    HStack {
                        // Status icon (keep green/red for universal recognition)
                        Image(systemName: results.grantedPermissions.contains(permission) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(results.grantedPermissions.contains(permission) ? .green : .red)

                        // Permission name
                        Text(permissionName(for: permission))
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                        Spacer()

                        // View button
                        Button {
                            openSettingsForPermission(permission)
                        } label: {
                            Text(LocalizedStringKey("View"))
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                        }
                    }
                    .padding(5)
                }
            }

            Divider()

            // Restart notice - use secondaryText instead of opacity
            Text("Restart \(Bundle.main.name) for changes to take effect")
                .font(.footnote)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

            // Action buttons
            HStack {
                Button("Restart") {
                    relaunchApp()
                }
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                Button("Close") {
                    dismiss()
                }
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            }
        }
        .padding()
        .frame(width: 300)
        .background(ThemeColors.shared(for: colorScheme).primaryBG)
        .cornerRadius(12)
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

    private func openSettingsForPermission(_ permission: PermissionManager.PermissionType) {
        let urlString: String
        switch permission {
        case .fullDiskAccess:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .automation:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
