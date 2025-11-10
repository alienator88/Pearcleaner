//
//  PasswordRequestHandler.swift
//  Pearcleaner
//
//  Handles password requests from CLI via distributed notifications
//  Created by Alin Lupascu on 11/9/24.
//

import Foundation
import AppKit
import AlinFoundation

class PasswordRequestHandler {
    static let shared = PasswordRequestHandler()

    private init() {
        setupObserver()
    }


    private func setupObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handlePasswordRequest(_:)),
            name: NSNotification.Name("com.alienator88.Pearcleaner.passwordRequest"),
            object: nil
        )
    }

    @objc private func handlePasswordRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let requestId = userInfo["requestId"] as? String,
              let message = userInfo["message"] as? String else {
            return
        }

        // Show password dialog on main thread
        DispatchQueue.main.async {
            let password = self.showPasswordDialog(message: message)

            // Send response back
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("com.alienator88.Pearcleaner.passwordResponse"),
                object: nil,
                userInfo: [
                    "requestId": requestId,
                    "password": password ?? ""
                ],
                deliverImmediately: true
            )
        }
    }

    private func showPasswordDialog(message: String) -> String? {
        let alert = NSAlert()
        alert.messageText = "Pearcleaner"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let secureTextField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        secureTextField.placeholderString = "Password"
        alert.accessoryView = secureTextField
        alert.window.initialFirstResponder = secureTextField

        NSApp.activate(ignoringOtherApps: true)

        let response = alert.runModal()
        return response == .alertFirstButtonReturn ? secureTextField.stringValue : nil
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
