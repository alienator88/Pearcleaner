//
//  PermissionsSheetView.swift
//  Pearcleaner
//
//  Custom permissions view with ThemeColors integration
//

import SwiftUI
import AlinFoundation

// MARK: - Local PermissionManager (replaces AlinFoundation version)

class PermissionManagerLocal: ObservableObject {
    static let shared = PermissionManagerLocal()

    @Published var results: PermissionsCheckResults?

    private init() {}

    var allPermissionsGranted: Bool {
        return results?.fullDiskAccess ?? false
    }

    /// Returns true when permission check is complete AND permissions are denied
    /// Use this for UI warnings/badges to avoid showing false positives before check completes
    var shouldShowPermissionWarning: Bool {
        guard let results = results else {
            return false  // Don't show warning until check completes
        }
        return results.fullDiskAccess == false
    }

    enum PermissionType {
        case fullDiskAccess
    }

    struct PermissionsCheckResults {
        var fullDiskAccess: Bool?

        var checkedPermissions: [PermissionType] {
            return fullDiskAccess != nil ? [.fullDiskAccess] : []
        }

        var grantedPermissions: [PermissionType] {
            return fullDiskAccess == true ? [.fullDiskAccess] : []
        }
    }

    func checkPermissions(types: [PermissionType] = [.fullDiskAccess], completion: @escaping (PermissionsCheckResults) -> Void) {
        checkFullDiskAccess { hasAccess in
            let results = PermissionsCheckResults(fullDiskAccess: hasAccess)
            completion(results)
        }
    }

    /// Check Full Disk Access permission with retry logic
    /// Uses higher priority QoS and faster syscall for better reliability
    private func checkFullDiskAccess(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {  // Higher priority than .background
            let result = self.attemptFDACheck(maxAttempts: 2, delayMs: 100)
            DispatchQueue.main.async {
                if !result {
                    printOS("Full Disk Permission: ❌")
                }
                completion(result)
            }
        }
    }

    /// Attempt FDA check with retries
    /// First tries fast access() syscall, then falls back to directory listing
    private func attemptFDACheck(maxAttempts: Int, delayMs: Int) -> Bool {
        let checkPath = "~/Library/Containers/com.apple.stocks"
        let expandedPath = NSString(string: checkPath).expandingTildeInPath

        for attempt in 1...maxAttempts {
            // Method 1: Try using access() syscall (fastest)
            if let cPath = expandedPath.cString(using: .utf8) {
                if access(cPath, R_OK) == 0 {
                    return true  // Success - have FDA
                }
            }

            // Method 2: Fallback to directory listing (more reliable but slower)
            let fileManager = FileManager.default
            if let _ = try? fileManager.contentsOfDirectory(atPath: expandedPath) {
                return true
            }

            // If not last attempt, wait before retry
            if attempt < maxAttempts {
                Thread.sleep(forTimeInterval: Double(delayMs) / 1000.0)
            }
        }

        return false  // All attempts failed
    }
}

// MARK: - PermissionsSheetView

struct PermissionsSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var permissionManager = PermissionManagerLocal.shared

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

    private func permissionName(for permission: PermissionManagerLocal.PermissionType) -> String {
        switch permission {
        case .fullDiskAccess:
            return "Full Disk Access".localized()
        }
    }

    func openSettingsForPermission(_ permission: PermissionManagerLocal.PermissionType) {
        let urlString: String
        switch permission {
        case .fullDiskAccess:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }

    }
}
