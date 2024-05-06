//
//  PermissionChecker.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 5/3/24.
//

import SwiftUI
//import EventKit

struct PermissionsCheckResults {
    var fullDiskAccess: Bool
    var accessibility: Bool
    var automation: Bool

    // Computed property to check if all permissions are granted
    var allPermissionsGranted: Bool {
        return fullDiskAccess && accessibility && automation
    }
}

func checkAllPermissions(appState: AppState, completion: @escaping (PermissionsCheckResults) -> Void) {
    let dispatchGroup = DispatchGroup()

    // Check Full Disk Access
    var fullDiskAccess = false
    @AppStorage("settings.permissions.hasLaunched") var hasLaunched: Bool = false

    let process = Process()
    process.launchPath = "/usr/bin/sqlite3"
    process.arguments = ["/Library/Application Support/com.apple.TCC/TCC.db", "select client from access where auth_value and service = 'kTCCServiceSystemPolicyAllFiles' and client = 'com.alienator88.Pearcleaner'"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.launch()
    process.waitUntilExit() // Ensure process completes

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)
    fullDiskAccess = (output?.contains("com.alienator88.Pearcleaner") ?? false)

    // Check Accessibility
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

    // Check Automation Permission
    var automationAccess = false
    dispatchGroup.enter()
    checkAutomationPermission(appState: appState) { success in
        automationAccess = success
        dispatchGroup.leave()
    }


    // Wait for all async checks to complete
    dispatchGroup.notify(queue: .main) {
        let results = PermissionsCheckResults(
            fullDiskAccess: fullDiskAccess,
            accessibility: accessibilityEnabled,
            automation: automationAccess
        )

        // Check if any permission is denied and show window
        if !(results.fullDiskAccess && results.accessibility && results.automation) {
            updateOnMain {
                appState.permissionsOkay = false
            }
        }

        completion(results)
    }
}



// Check Finder Automation permission
func checkAutomationPermission(appState: AppState, completion: @escaping (Bool) -> Void) {
    DispatchQueue.global(qos: .background).async {
        let scriptText = "tell application \"Finder\" to return name of home"
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptText) {
            let _ = script.executeAndReturnError(&error)
            DispatchQueue.main.async {
                completion(error == nil)
            }
        } else {
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
}



struct PermissionsNotificationView: View {
    let appState: AppState
    @State private var hovered: Bool = false

    var body: some View {
        HStack {
            Text("Missing Permissions!")
                .font(.callout)
                .opacity(0.5)
                .padding(.leading, 7)

            Spacer()

            settingsLinkButton
        }
        .frame(height: 30)
        .padding(5)
        .background(Color("mode").opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal)
        .padding(.bottom)
    }

    @ViewBuilder
    private var settingsLinkButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                labelContent
            }
            .buttonStyle(PlainButtonStyle())
            .padding(4)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hover in
                withAnimation {
                    hovered = hover
                }
            }
            .help("Check all permissions")
        } else {
            Button(action: {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }) {
                labelContent
            }
            .buttonStyle(PlainButtonStyle())
            .padding(4)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hover in
                withAnimation {
                    hovered = hover
                }
            }
            .help("Check all permissions")
        }

    }

    @ViewBuilder
    private var labelContent: some View {
        HStack(alignment: .center) {
            Image(systemName: !hovered ? "lock" : "lock.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(.white)
            Text("Check")
                .foregroundStyle(.white)
        }
        .padding(3)
    }
}




