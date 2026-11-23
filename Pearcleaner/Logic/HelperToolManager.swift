//
//  HelperToolManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/14/25.
//

import Foundation
import ServiceManagement

// The installed privileged helper is gone. HelperToolManager remains as the
// app-wide facade so existing call sites keep their shape, but every operation
// now routes through SessionPrivilegeManager: AuthorizationExecuteWithPrivileges
// runs an Apple-signed /bin/sh with a session-held credential, one password
// prompt per app session, nothing installed, nothing left behind.
extension Notification.Name {
    static let helperRequired = Notification.Name("helperRequired")
}

enum HelperToolAction {
    case none      // Only check status
    case install   // Historically installed the daemon; now a no-op stub
    case uninstall // Historically unregistered the daemon
    case reinstall // Historically reinstall; now a no-op stub
}

class HelperToolManager: ObservableObject {
    static let shared = HelperToolManager()
    let helperToolIdentifier = "com.alienator88.Pearcleaner.PearcleanerHelper"
    @Published var isHelperToolInstalled: Bool = false
    @Published var message: String = String(localized: "Checking...")
    @Published var isInitialCheckComplete: Bool = false
    var status: String {
        return isHelperToolInstalled ? String(localized:"Enabled") : String(localized:"Disabled")
    }

    var shouldShowHelperBadge: Bool {
        return false
    }

    // Kept for compatibility: privileged features no longer need the badge.
    func triggerHelperRequiredAlert() {
        NotificationCenter.default.post(name: .helperRequired, object: nil)
    }

    init() {
        Task {
            await manageHelperTool()
        }
    }

    // The old install/uninstall/reinstall lifecycle no longer exists. The
    // daemon is unregistered if a previous Pearcleaner version installed it,
    // then the status settles at "not installed" for good.
    func manageHelperTool(action: HelperToolAction = .none) async {
        await SessionPrivilegeManager.removeInstalledHelper()
        await MainActor.run {
            self.isHelperToolInstalled = false
            self.isInitialCheckComplete = true
            self.message = String(localized: "Privileged tasks ask for your password once per session.")
        }
    }

    // Kept for call sites that still call it from the CLI paths.
    func openSMSettings() {}

    // Function to run privileged commands through the session credential
    func runCommand(_ command: String, skipHelperCheck: Bool = false) async -> (Bool, String) {
        await Task.detached(priority: .userInitiated) {
            SessionPrivilegeManager.shared.run(command: command)
        }.value
    }

    // Function to run privileged thinning on apps owned by root
    func runThinning(atPath path: String) async -> (Bool, String) {
        await Task.detached(priority: .userInitiated) {
            SessionPrivilegeManager.shared.thin(binaryAt: path)
        }.value
    }

    // Function to run privileged bundle thinning on entire app bundles
    func runBundleThinning(bundlePath path: String) async -> (Bool, String, [String: UInt64]) {
        await Task.detached(priority: .userInitiated) {
            SessionPrivilegeManager.shared.thinBundle(at: path)
        }.value
    }
}