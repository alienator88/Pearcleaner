//
//  ThemeManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/12/24.
//

import Foundation
import SwiftUI
import AppKit

class ThemeSettings: ObservableObject {
    static let shared = ThemeSettings()
    private let userDefaults = UserDefaults.standard
    private let colorKey = "themeColor"

    @Published var themeColor: Color {
        didSet {
            saveThemeColor()
        }
    }

    // light - Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 1)
    // dark  - Color(.sRGB, red: 0.149, green: 0.149, blue: 0.149, opacity: 1)

    init() {
        // Initialize color from UserDefaults or use a default value
        if let components = UserDefaults.standard.object(forKey: colorKey) as? [CGFloat], components.count >= 4 {
            themeColor = Color(.sRGB, red: components[0], green: components[1], blue: components[2], opacity: components[3])
        } else {
            themeColor = Color.clear
        }
    }

    func saveThemeColor() {
        let nsColor = NSColor(themeColor)
        if let components = nsColor.cgColor.components {
            UserDefaults.standard.set(components, forKey: colorKey)
        }
    }

    func resetToDefault(dark: Bool = true) {
        themeColor = dark ? Color(.sRGB, red: 0.149, green: 0.149, blue: 0.149, opacity: 1) : Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 1)
        saveThemeColor()
    }
}

extension Color {
    func darker(by percentage: CGFloat = 30.0) -> Color {
        var hsb = (hue: CGFloat(0), saturation: CGFloat(0), brightness: CGFloat(0), alpha: CGFloat(0))
        NSColor(self).getHue(&hsb.hue, saturation: &hsb.saturation, brightness: &hsb.brightness, alpha: &hsb.alpha)
        return Color(hue: hsb.hue, saturation: hsb.saturation, brightness: max(hsb.brightness - percentage/100, 0), opacity: hsb.alpha)
    }
    func lighter(by percentage: CGFloat = 30.0) -> Color {
        var hsb = (hue: CGFloat(0), saturation: CGFloat(0), brightness: CGFloat(0), alpha: CGFloat(0))
        NSColor(self).getHue(&hsb.hue, saturation: &hsb.saturation, brightness: &hsb.brightness, alpha: &hsb.alpha)
        return Color(hue: hsb.hue, saturation: hsb.saturation, brightness: min(hsb.brightness + percentage / 100, 1.0), opacity: hsb.alpha)
    }
}
