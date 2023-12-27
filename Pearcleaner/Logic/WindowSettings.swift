//
//  WindowSettings.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 12/26/23.
//

import SwiftUI

class WindowSettings {
    private let windowWidthKey = "windowWidthKey"
    private let windowHeightKey = "windowHeightKey"
    private let windowXKey = "windowXKey"
    private let windowYKey = "windowYKey"

    func saveWindowSettings(frame: NSRect) {
        UserDefaults.standard.set(Float(frame.size.width), forKey: windowWidthKey)
        UserDefaults.standard.set(Float(frame.size.height), forKey: windowHeightKey)
        UserDefaults.standard.set(Float(frame.origin.x), forKey: windowXKey)
        UserDefaults.standard.set(Float(frame.origin.y), forKey: windowYKey)
    }

    func loadWindowSettings() -> NSRect {
        let width = CGFloat(UserDefaults.standard.float(forKey: windowWidthKey))
        let height = CGFloat(UserDefaults.standard.float(forKey: windowHeightKey))
        let x = CGFloat(UserDefaults.standard.float(forKey: windowXKey))
        let y = CGFloat(UserDefaults.standard.float(forKey: windowYKey))

        return NSRect(x: x, y: y, width: width, height: height)
    }
}
