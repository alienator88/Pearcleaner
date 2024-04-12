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
//                menuItem.image = NSImage(named: NSImage.trashEmptyName)
//                menu.addItem(withTitle: "Pearcleaner Uninstall", action: #selector(openInMyApp), keyEquivalent: "")
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


//class FinderSync: FIFinderSync {
//
//    var myFolderURL = URL(fileURLWithPath: "/Users/Shared/MySyncExtension Documents")
//    
//    override init() {
//        super.init()
//        
//        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath as NSString)
//        
//        // Set up the directory we are syncing.
//        FIFinderSyncController.default().directoryURLs = [self.myFolderURL]
//        
//        // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
//        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.colorPanelName)!, label: "Status One" , forBadgeIdentifier: "One")
//        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.cautionName)!, label: "Status Two", forBadgeIdentifier: "Two")
//    }
//    
//    // MARK: - Primary Finder Sync protocol methods
//    
//    override func beginObservingDirectory(at url: URL) {
//        // The user is now seeing the container's contents.
//        // If they see it in more than one view at a time, we're only told once.
//        NSLog("beginObservingDirectoryAtURL: %@", url.path as NSString)
//    }
//    
//    
//    override func endObservingDirectory(at url: URL) {
//        // The user is no longer seeing the container's contents.
//        NSLog("endObservingDirectoryAtURL: %@", url.path as NSString)
//    }
//    
//    override func requestBadgeIdentifier(for url: URL) {
//        NSLog("requestBadgeIdentifierForURL: %@", url.path as NSString)
//        
//        // For demonstration purposes, this picks one of our two badges, or no badge at all, based on the filename.
//        let whichBadge = abs(url.path.hash) % 3
//        let badgeIdentifier = ["", "One", "Two"][whichBadge]
//        FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
//    }
//    
//    // MARK: - Menu and toolbar item support
//    
//    override var toolbarItemName: String {
//        return "FinderSy"
//    }
//    
//    override var toolbarItemToolTip: String {
//        return "FinderSy: Click the toolbar item for a menu."
//    }
//    
//    override var toolbarItemImage: NSImage {
//        return NSImage(named: NSImage.cautionName)!
//    }
//    
//    override func menu(for menuKind: FIMenuKind) -> NSMenu {
//        // Produce a menu for the extension.
//        let menu = NSMenu(title: "")
//        menu.addItem(withTitle: "Example Menu Item", action: #selector(sampleAction(_:)), keyEquivalent: "")
//        return menu
//    }
//    
//    @IBAction func sampleAction(_ sender: AnyObject?) {
//        let target = FIFinderSyncController.default().targetedURL()
//        let items = FIFinderSyncController.default().selectedItemURLs()
//        
//        let item = sender as! NSMenuItem
//        NSLog("sampleAction: menu item: %@, target = %@, items = ", item.title as NSString, target!.path as NSString)
//        for obj in items! {
//            NSLog("    %@", obj.path as NSString)
//        }
//    }
//
//}

