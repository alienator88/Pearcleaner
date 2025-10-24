//
//  HelperToolManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/14/25.
//

import ServiceManagement
import AlinFoundation

extension Notification.Name {
    static let helperRequired = Notification.Name("helperRequired")
}

@objc(HelperToolProtocol)
public protocol HelperToolProtocol {
    func runCommand(command: String, withReply reply: @escaping (Bool, String) -> Void)
    func runThinning(atPath: String, withReply reply: @escaping (Bool, String) -> Void)
    func runBundleThinning(bundlePath: String, withReply reply: @escaping (Bool, String, [String: UInt64]) -> Void)
}

enum HelperToolAction {
    case none      // Only check status
    case install   // Install the helper tool
    case uninstall // Uninstall the helper tool
    case reinstall // Uninstall then reinstall (fixes desync)
}

class HelperToolManager: ObservableObject {
    static let shared = HelperToolManager()
    private var helperConnection: NSXPCConnection?
    let helperToolIdentifier = "com.alienator88.Pearcleaner.PearcleanerHelper"
    @Published var isHelperToolInstalled: Bool = false
    @Published var message: String = String(localized: "Checking...")
    @Published var isInitialCheckComplete: Bool = false
    var status: String {
        return isHelperToolInstalled ? String(localized:"Enabled") : String(localized:"Disabled")
    }

    var shouldShowHelperBadge: Bool {
        return isInitialCheckComplete && !isHelperToolInstalled
    }

    // Trigger overlay when operation fails due to missing helper
    func triggerHelperRequiredAlert() {
        NotificationCenter.default.post(name: .helperRequired, object: nil)
    }

    init() {
        Task {
            await manageHelperTool()
        }
    }

    // Function to manage the helper tool installation/uninstallation
    func manageHelperTool(action: HelperToolAction = .none) async {
        let plistName = "\(helperToolIdentifier).plist"
        let service = SMAppService.daemon(plistName: plistName)
        var occurredError: NSError?

        // Perform install/uninstall actions if specified
        switch action {
        case .install:
            // Pre-check before registering
            switch service.status {
            case .requiresApproval:
                updateOnMain {
                    self.message = String(localized: "Registered but requires enabling in System Settings > Login Items.")
                }
                SMAppService.openSystemSettingsLoginItems()
            case .enabled:
                // Verify the helper actually works (same desync check as .none action)
                let whoamiResult = await runCommand("whoami", skipHelperCheck: true)
                let isRoot = whoamiResult.0 && whoamiResult.1.trimmingCharacters(in: .whitespacesAndNewlines) == "root"

                if !isRoot {
                    // Desync detected - helper claims enabled but doesn't work
                    printOS("Helper desync detected during install attempt, attempting auto-recovery...")
                    updateOnMain {
                        self.message = String(localized: "Service desynced, attempting recovery...")
                    }

                    // Recursively call with reinstall action
                    await manageHelperTool(action: .reinstall)
                    return // Exit early, reinstall will handle status updates
                }

                // Helper verified working
                updateOnMain {
                    self.message = String(localized: "Service is already enabled.")
                }
            default:
                do {
                    try service.register()
                    if service.status == .requiresApproval {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                } catch let nsError as NSError {
                    occurredError = nsError
                    if nsError.code == 1 { // Operation not permitted
                        updateOnMain {
                            self.message = String(localized: "Permission required. Enable in System Settings > Login Items.")
                        }
                        SMAppService.openSystemSettingsLoginItems()
                    } else {
                        updateOnMain {
                            self.message = String(localized: "Installation failed: \(nsError.localizedDescription)")
                        }
                        printOS("Failed to register helper: \(nsError.localizedDescription)")
                    }

                }
            }

        case .uninstall:
            do {
                try await service.unregister()
                // Close any existing connection
                helperConnection?.invalidate()
                helperConnection = nil
            } catch let nsError as NSError {
                occurredError = nsError
                printOS("Failed to unregister helper: \(nsError.localizedDescription)")
            }

        case .reinstall:
            // Uninstall first
            do {
                try await service.unregister()
                helperConnection?.invalidate()
                helperConnection = nil
            } catch let nsError as NSError {
                printOS("Reinstall: Failed to unregister: \(nsError.localizedDescription)")
            }

            // Small delay to ensure launchd processes the unregister
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Then install
            do {
                try service.register()
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            } catch let nsError as NSError {
                occurredError = nsError
                printOS("Reinstall: Failed to register: \(nsError.localizedDescription)")
            }

        case .none:
            break
        }

        await updateStatusMessages(with: service, occurredError: occurredError)
        let isEnabled = (service.status == .enabled)
        //        let whoamiResult = await runCommand("whoami", skipHelperCheck: true)
        //        let isRoot = whoamiResult.0 && whoamiResult.1.trimmingCharacters(in: .whitespacesAndNewlines) == "root"
        updateOnMain {
            self.isHelperToolInstalled = isEnabled// && isRoot
            self.isInitialCheckComplete = true
        }
    }

    // Function to open Settings > Login Items
    func openSMSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // Function to run privileged commands
    func runCommand(_ command: String, skipHelperCheck: Bool = false) async -> (Bool, String) {
        if !skipHelperCheck && !isHelperToolInstalled {
            return (false, "XPC: Helper tool is not installed")
        }

        guard let connection = getConnection() else {
            return (false, "XPC: Connection not available")
        }

        return await withCheckedContinuation { continuation in
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                continuation.resume(returning: (false, "XPC: Connection error: \(error.localizedDescription)"))
            }) as? HelperToolProtocol else {
                continuation.resume(returning: (false, "XPC: Failed to get remote object"))
                return
            }

            proxy.runCommand(command: command, withReply: { success, output in
                continuation.resume(returning: (success, output))
            })
        }
    }

    // Function to run privileged thinning on apps owned by root
    func runThinning(atPath path: String) async -> (Bool, String) {
        guard let connection = getConnection() else {
            return (false, "XPC: No helper connection")
        }

        return await withCheckedContinuation { continuation in
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                continuation.resume(returning: (false, "XPC: Error: \(error.localizedDescription)"))
            }) as? HelperToolProtocol else {
                continuation.resume(returning: (false, "XPC: Proxy failure"))
                return
            }

            proxy.runThinning(atPath: path) { success, output in
                continuation.resume(returning: (success, output))
            }
        }
    }
    
    // Function to run privileged bundle thinning on entire app bundles
    func runBundleThinning(bundlePath path: String) async -> (Bool, String, [String: UInt64]) {
        guard let connection = getConnection() else {
            return (false, "XPC: No helper connection", [:])
        }

        return await withCheckedContinuation { continuation in
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                continuation.resume(returning: (false, "XPC: Error: \(error.localizedDescription)", [:]))
            }) as? HelperToolProtocol else {
                continuation.resume(returning: (false, "XPC: Proxy failure", [:]))
                return
            }

            proxy.runBundleThinning(bundlePath: path) { success, output, sizes in
                continuation.resume(returning: (success, output, sizes))
            }
        }
    }


    // Create/reuse XPC connection
    private func getConnection() -> NSXPCConnection? {
        if let connection = helperConnection {
            return connection
        }
        let connection = NSXPCConnection(machServiceName: helperToolIdentifier, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)
        connection.invalidationHandler = { [weak self] in
            self?.helperConnection = nil
        }
        connection.resume()
        helperConnection = connection
        return connection
    }



    // Helper to update helper status messages
    func updateStatusMessages(with service: SMAppService, occurredError: NSError?) async {
        if let nsError = occurredError {
            switch nsError.code {
            case kSMErrorAlreadyRegistered:
                updateOnMain {
                    self.message = String(localized: "Service is already registered and enabled.")
                }
            case kSMErrorLaunchDeniedByUser:
                updateOnMain {
                    self.message = String(localized: "User denied permission. Enable in System Settings > Login Items.")
                }
            case kSMErrorInvalidSignature:
                updateOnMain {
                    self.message = String(localized: "Invalid signature, ensure proper signing on the application and helper tool.")
                }
            case 1:
                updateOnMain {
                    self.message = String(localized: "Authorization required in Settings > Login Items > \(Bundle.main.name).app.")
                }
            default:
                updateOnMain {
                    self.message = String(localized: "Operation failed: \(nsError.localizedDescription)")
                }
            }
        } else {
            switch service.status {
            case .notRegistered:
                updateOnMain {
                    self.message = String(localized: "Service hasn’t been registered. You may register it now.")
                }
            case .enabled:
                let whoamiResult = await runCommand("whoami", skipHelperCheck: true)
                let isRoot = whoamiResult.0 && whoamiResult.1.trimmingCharacters(in: .whitespacesAndNewlines) == "root"

                if !isRoot {
                    // Desync detected - automatically attempt to fix
                    printOS("Helper desync detected, attempting auto-recovery...")
                    updateOnMain {
                        self.message = String(localized: "Service desynced, attempting recovery...")
                    }

                    // Recursively call with reinstall action
                    await manageHelperTool(action: .reinstall)
                    return // Exit early, reinstall will handle status updates
                }

                updateOnMain {
                    self.message = String(localized: "Service successfully registered and eligible to run.")
                }
            case .requiresApproval:
                updateOnMain {
                    self.message = String(localized: "Service registered but requires user approval in Settings > Login Items > \(Bundle.main.name).app.")
                }
            case .notFound:
                updateOnMain {
                    self.message = String(localized: "Service is not installed.")
                }
            @unknown default:
                updateOnMain {
                    self.message = String(localized: "Unknown service status (\(service.status.rawValue)).")
                }
            }
        }
    }
}
