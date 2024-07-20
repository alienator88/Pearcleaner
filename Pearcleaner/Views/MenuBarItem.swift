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
    private var lastIcon: String?

    func addMenuBarExtra<V: View>(withView view: @escaping () -> V, icon: String) {
        guard statusItem == nil else { return }

        // Remember the last view and icon
        lastView = { AnyView(view()) }
        lastIcon = icon

        // Initialize the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set up the status item's button
        if let button = statusItem?.button{
            button.image = NSImage(systemSymbolName: icon, accessibilityDescription: "Pearcleaner")
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
        } else {
            button.image = NSImage(named: icon)
        }
    }

    func restartMenuBarExtra() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.removeMenuBarExtra()

            // Ensure the last view and icon are available before re-adding
            if let lastView = self.lastView, let lastIcon = self.lastIcon {
                self.addMenuBarExtra(withView: lastView, icon: lastIcon)
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


}
