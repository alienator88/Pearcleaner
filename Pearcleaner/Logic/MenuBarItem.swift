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

    func addMenuBarExtra<V: View>(withView view: @escaping () -> V) {
        guard statusItem == nil else { return }

        // Initialize the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set up the status item's button
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: "Pearcleaner")
            button.action = #selector(togglePopover(_:))
            button.target = self
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

    func getStatus() -> Bool {
        if let item = statusItem {
            return true
        } else {
            return false
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
