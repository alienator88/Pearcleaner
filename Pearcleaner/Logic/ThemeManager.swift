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

    func setPreset(preset: String, colorScheme: DisplayMode) {
        themeColor = getColorForPreset(preset: preset, colorScheme: colorScheme)
        saveThemeColor()
    }

    func getColorForPreset(preset: String, colorScheme: DisplayMode) -> Color {
        let slate = colorScheme.colorScheme == .light ? Color(.sRGB, red: 0.499549, green: 0.545169, blue: 0.682028, opacity: 1) : Color(.sRGB, red: 0.188143, green: 0.208556, blue: 0.262679, opacity: 1)
        let solarized = colorScheme.colorScheme == .light ? Color(.sRGB, red: 0.554372, green: 0.6557, blue: 0.734336, opacity: 1) : Color(.sRGB, red: 0.117257, green: 0.22506, blue: 0.249171, opacity: 1)
        let dracula = colorScheme.colorScheme == .light ? Color(.sRGB, red: 0.567094, green: 0.562125, blue: 0.81285, opacity: 1) : Color(.sRGB, red: 0.268614, green: 0.264737, blue: 0.383503, opacity: 1)

        switch preset {
        case "slate":
            return slate
        case "solarized":
            return solarized
        case "dracula":
            return dracula
        default:
            return themeColor
        }
    }

}

extension Color {
    /// Darkens the color by a percentage.
    func darker(by percentage: CGFloat = 30.0) -> Color {
        var hsb = (hue: CGFloat(0), saturation: CGFloat(0), brightness: CGFloat(0), alpha: CGFloat(0))
        NSColor(self).getHue(&hsb.hue, saturation: &hsb.saturation, brightness: &hsb.brightness, alpha: &hsb.alpha)
        return Color(hue: hsb.hue, saturation: hsb.saturation, brightness: max(hsb.brightness - percentage/100, 0), opacity: hsb.alpha)
    }

    /// Lightens the color by a percentage.
    func lighter(by percentage: CGFloat = 30.0) -> Color {
        var hsb = (hue: CGFloat(0), saturation: CGFloat(0), brightness: CGFloat(0), alpha: CGFloat(0))
        NSColor(self).getHue(&hsb.hue, saturation: &hsb.saturation, brightness: &hsb.brightness, alpha: &hsb.alpha)
        return Color(hue: hsb.hue, saturation: hsb.saturation, brightness: min(hsb.brightness + percentage / 100, 1.0), opacity: hsb.alpha)
    }
}

extension UserDefaults {
    func color(forKey key: String) -> Color? {
        guard let components = array(forKey: key) as? [CGFloat], components.count == 4 else {
            return nil
        }
        return Color(.sRGB, red: components[0], green: components[1], blue: components[2], opacity: components[3])
    }

    func setColor(_ color: Color, forKey key: String) {
        let nsColor = NSColor(color)
        if let components = nsColor.cgColor.components, components.count == 4 {
            set(components, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}
