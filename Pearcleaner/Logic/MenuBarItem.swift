//
//  MenuBarItem.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/16/24.
//

import AppKit
import SwiftUI

class MenuBarExtraManager {
    static let shared = MenuBarExtraManager()
    private var statusItem: NSStatusItem?
    private var popover = NSPopover()
    private var lastView: (() -> AnyView)?
    @AppStorage("settings.interface.selectedMenubarIcon") var selectedMenubarIcon: String = "bubbles.and.sparkles.fill"

    func addMenuBarExtra<V: View>(withView view: @escaping () -> V) {
        guard statusItem == nil else { return }

        // Remember the last view
        lastView = { AnyView(view()) }

        // Initialize the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set up the status item's button
        if let button = statusItem?.button{
            button.image = NSImage(systemSymbolName: selectedMenubarIcon, accessibilityDescription: "Pearcleaner")
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        // Set up the popover
        popover.contentSize = NSSize(width: 300, height: 370)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: view())
    }


    func removeMenuBarExtra() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func swapMenuBarIcon(icon: String) {
        guard let button = statusItem?.button else { return }
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            button.image = image
        }
    }

    func restartMenuBarExtra() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.removeMenuBarExtra()

            // Ensure the last view and icon are available before re-adding
            if let lastView = self.lastView {
                self.addMenuBarExtra(withView: lastView)
            }
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }

    // Method to programmatically show the popover (for deep link handling)
    func showPopover() {
        if let button = statusItem?.button, !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }

}

