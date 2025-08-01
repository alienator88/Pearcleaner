import SwiftUI

// MARK: - ThemeColors Struct

// MARK: - Example Usage
// Use this anywhere in your SwiftUI views:
//
// struct ExampleView: View {
//     var body: some View {
//         Text("App Name")
//             .foregroundColor(theme(for: colorScheme).textPrimary)
//             .padding()
//             .background(theme(for: colorScheme).backgroundPanel)
//     }
// }


struct ThemeColors {
    static func shared(for colorScheme: ColorScheme) -> ThemeColors {
        ThemeColors(colorScheme: colorScheme)
    }

    private let colorScheme: ColorScheme
    private var isDark: Bool { colorScheme == .dark }

    // Main window background (overall background of the app)
    var backgroundMain: Color {
        isDark ? Color(hex: "#1a1b1f") : Color(hex: "#fdfcfa")
    }

    // Sidebar or secondary panel background
    var backgroundPanel: Color {
        isDark ? Color(hex: "#2d2e33") : Color(hex: "#f6f5f2")
    }

    // Main text color (titles, app names)
    var textPrimary: Color {
        isDark ? Color(hex: "#ffffff") : Color(hex: "#1e1e1e")
    }

    // Secondary text (dates, file sizes, subtle info)
    var textSecondary: Color {
        isDark ? Color(hex: "#8f9093") : Color(hex: "#92a0b5")
    }

    // Primary accent (e.g. branding highlight, app icon pink)
    var accentPrimary: Color {
        isDark ? Color(hex: "#f755a3") : Color(hex: "#f756a2")
    }

    // Highlight color (checkbox, selection glow, hover)
    var accentSelection: Color {
        isDark ? Color(hex: "#58c5ff") : Color(hex: "#3983fc")
    }

    // Folder or file icons (system-style color)
    var iconFolder: Color {
        isDark ? Color(hex: "#1e90ff") : Color(hex: "#3983fc")
    }

    // Row/card background (app rows, list items, file path background)
    var surfaceCard: Color {
        isDark ? Color(hex: "#3a3b3f") : Color(hex: "#e8e6e3")
    }
}


// MARK: - View Extension for Easy Access

extension View {
    func theme(for colorScheme: ColorScheme) -> ThemeColors {
        return ThemeColors.shared(for: colorScheme)
    }
}


// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Theme Color Demo Views

struct ColorSquare: View {
    let color: Color
    let name: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 30, height: 30)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
            Text(name)
                .font(.caption2)
                .foregroundColor(ThemeColors.shared(for: colorScheme).textSecondary)
        }
    }
}

struct ThemeColorDemo: View {
    @Environment(\.colorScheme) var colorScheme
    
    private var theme: ThemeColors {
        ThemeColors.shared(for: colorScheme)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ColorSquare(color: theme.backgroundMain, name: "Main BG")
            ColorSquare(color: theme.backgroundPanel, name: "Panel BG")
            ColorSquare(color: theme.textPrimary, name: "Primary")
            ColorSquare(color: theme.textSecondary, name: "Secondary")
            ColorSquare(color: theme.accentPrimary, name: "Accent")
            ColorSquare(color: theme.accentSelection, name: "Selection")
            ColorSquare(color: theme.iconFolder, name: "Folder")
            ColorSquare(color: theme.surfaceCard, name: "Surface")
        }
    }
}
