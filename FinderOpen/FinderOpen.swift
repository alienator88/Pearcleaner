//
//  FinderSync.swift
//  FinderOpen
//
//  Created by Alin Lupascu on 4/11/24.
//

import Cocoa
import FinderSync

class FinderOpen: FIFinderSync {

    override init() {
        super.init()
        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath as NSString)
        // Set the directory URLs that the Finder Sync extension observes
        FIFinderSyncController.default().directoryURLs = Set([URL(fileURLWithPath: "/")])
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")

        // Ensure we are dealing with the contextual menu for items
        if menuKind == .contextualMenuForItems {
            // Get the selected items
            if let selectedItemURLs = FIFinderSyncController.default().selectedItemURLs(),
               selectedItemURLs.count == 1, selectedItemURLs.first?.pathExtension == "app" {
                // Add menu item if the selected item is a .app file
                let menuItem = NSMenuItem(title: "Pearcleaner Uninstall", action: #selector(openInMyApp), keyEquivalent: "")
                if let appIcon = NSImage(named: "Icon") {
                    menuItem.image = appIcon
                } else {
                    menuItem.image = NSImage(named: NSImage.trashFullName)
                }
                menu.addItem(menuItem)
            }
        }

        // Return the menu (which may be empty if the conditions are not met)
        return menu

    }

    @objc func openInMyApp(_ sender: AnyObject?) {
        // Get the selected items (files/folders) in Finder
        guard let selectedItems = FIFinderSyncController.default().selectedItemURLs(), !selectedItems.isEmpty else {
            return
        }

        // Consider only the first selected item
        let firstSelectedItem = selectedItems[0]
        let path = firstSelectedItem.path
        NSWorkspace.shared.open(URL(string: "pear://com.alienator88.Pearcleaner?path=\(path)")!)

    }


}
