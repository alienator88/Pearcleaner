import SwiftUI
import AlinFoundation

// MARK: - Observable Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("settings.interface.customDarkColors") var customDarkColorsString: String = ""
    @AppStorage("settings.interface.customLightColors") var customLightColorsString: String = ""
    
    private init() {}
    
    func saveCustomColors(dark: String, light: String) {
        customDarkColorsString = dark
        customLightColorsString = light
    }
    
    func resetToDefaults() {
        customDarkColorsString = ""
        customLightColorsString = ""
    }
}

// MARK: - ThemeColors Struct

// MARK: - Example Usage
// Use this anywhere in your SwiftUI views:
//
// struct ExampleView: View {
//     var body: some View {
//         Text("App Name")
//             .foregroundStyle(theme(for: colorScheme).textPrimary)
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
    
    // MARK: - Default Color Values
    private static let defaultDarkColors = [
        "#1a1b1f", // backgroundMain
        "#2d2e33", // backgroundPanel
        "#ffffff", // textPrimary
        "#8f9093", // textSecondary
        "#419cff"  // accentPrimary
    ]
    
    private static let defaultLightColors = [
        "#fdfcfa", // backgroundMain
        "#f6f5f2", // backgroundPanel
        "#1e1e1e", // textPrimary
        "#92a0b5", // textSecondary
        "#0068da"  // accentPrimary
    ]
    
    // MARK: - Custom Color Loading (now uses ThemeManager)
    private var currentColors: [String] {
        let themeManager = ThemeManager.shared
        let customString = isDark ? themeManager.customDarkColorsString : themeManager.customLightColorsString
        let defaultColors = isDark ? Self.defaultDarkColors : Self.defaultLightColors
        
        if customString.isEmpty {
            return defaultColors
        }
        
        let customColors = customString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Ensure we have exactly 5 colors, fall back to defaults for missing ones
        var colors: [String] = []
        for i in 0..<5 {
            if i < customColors.count && !customColors[i].isEmpty {
                colors.append(customColors[i])
            } else {
                colors.append(defaultColors[i])
            }
        }
        return colors
    }

    // Main window background (overall background of the app)
    var primaryBG: Color {
        Color(hex: currentColors[0])
    }

    // Sidebar or secondary panel background
    var secondaryBG: Color {
        Color(hex: currentColors[1])
    }

    // Main text color (titles, app names)
    var primaryText: Color {
        Color(hex: currentColors[2])
    }

    // Secondary text (dates, file sizes, subtle info)
    var secondaryText: Color {
        Color(hex: currentColors[3])
    }

    // Primary accent (e.g. branding highlight, app icon pink)
    var accent: Color {
        Color(hex: currentColors[4])
    }
    
    // MARK: - Static Methods for Theme Management (now use ThemeManager)
    static func saveCustomColors(dark: String, light: String) {
        ThemeManager.shared.saveCustomColors(dark: dark, light: light)
    }
    
    static func resetToDefaults() {
        ThemeManager.shared.resetToDefaults()
    }
    
    static func getCurrentColorsString(for colorScheme: ColorScheme) -> String {
        let themeManager = ThemeManager.shared
        let isDark = colorScheme == .dark
        let customString = isDark ? themeManager.customDarkColorsString : themeManager.customLightColorsString
        let defaultColors = isDark ? defaultDarkColors : defaultLightColors
        
        if customString.isEmpty {
            return defaultColors.joined(separator: ", ")
        }
        return customString
    }
    
    static func getDefaultColorsString(for colorScheme: ColorScheme) -> String {
        let defaultColors = colorScheme == .dark ? defaultDarkColors : defaultLightColors
        return defaultColors.joined(separator: ", ")
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
    
    var hexString: String {
        let components = NSColor(self).cgColor.components ?? [0, 0, 0, 1]
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
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
                        .stroke(ThemeColors.shared(for: colorScheme).secondaryText, lineWidth: 1)
                )
            Text(name)
                .font(.caption2)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
        }
        .frame(width: 80)
    }
}

// Update ThemeColorDemo to observe ThemeManager
struct ThemeColorDemo: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var theme: ThemeColors {
        ThemeColors.shared(for: colorScheme)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ColorSquare(color: theme.primaryBG, name: "Primary BG")
            ColorSquare(color: theme.secondaryBG, name: "Secondary BG")
            ColorSquare(color: theme.primaryText, name: "Primary Text")
            ColorSquare(color: theme.secondaryText, name: "Secondary Text")
            ColorSquare(color: theme.accent, name: "Accent")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Expanded Theme Customization View

struct ThemeCustomizationView: View {
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var colorsText: String = ""
    @State private var showingSaved = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var isDark: Bool { colorScheme == .dark }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Current theme preview
            ThemeColorDemo()

            // Dynamic color section based on current color scheme
            VStack(alignment: .leading, spacing: 8) {
                Text("Color String")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    TextField("Enter exactly 5 hex colors separated by commas in the order above", text: $colorsText)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        .font(.system(.caption, design: .monospaced))

                    if showingSaved {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .transition(.opacity)
                            .padding(.leading, 5)
                    }
                }
            }
            
            // Action buttons
            HStack {
                Spacer()
                HStack(spacing: 10) {
                    Button("Save") {
                        withAnimation(.easeInOut(duration: animationEnabled ? 0.2 : 0)) {
                            saveColors()
                        }

                    }
                    Divider().frame(height: 10)
                    Button("Copy") {
                        withAnimation(.easeInOut(duration: animationEnabled ? 0.2 : 0)) {
                            copyToClipboard(colorsText)
                            showSuccess()
                        }
                    }
                    Divider().frame(height: 10)
                    Button("Reset") {
                        withAnimation(.easeInOut(duration: animationEnabled ? 0.2 : 0)) {
                            resetColors()
                        }

                    }
                }
                .controlSize(.small)
                .buttonStyle(.plain)
                .foregroundStyle(theme(for: colorScheme).accent)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .controlGroup(Capsule(style: .continuous), level: .secondary)
                Spacer()
            }

            if showingError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

        }
        .padding()
        .onAppear {
            loadCurrentColors()
        }
        .onChange(of: colorScheme) { _ in
            loadCurrentColors()
        }
    }
    
    private func loadCurrentColors() {
        colorsText = ThemeColors.getCurrentColorsString(for: colorScheme)
        clearMessages()
    }
    
    private func saveColors() {
        // Validate hex colors
        let colors = colorsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Check if we have exactly 5 colors
        if colors.count != 5 {
            showError("Please provide exactly 5 hex colors separated by commas.")
            return
        }
        
        // Validate each hex color
        for (index, color) in colors.enumerated() {
            if !isValidHexColor(color) {
                showError("Color #\(index + 1) '\(color)' is not a valid hex color. Use format #rrggbb")
                return
            }
        }
        
        // Save the colors
        if isDark {
            ThemeColors.saveCustomColors(dark: colorsText, light: ThemeColors.getCurrentColorsString(for: .light))
        } else {
            ThemeColors.saveCustomColors(dark: ThemeColors.getCurrentColorsString(for: .dark), light: colorsText)
        }
        
        showSuccess()
    }
    
    private func resetColors() {
        ThemeColors.resetToDefaults()
        loadCurrentColors()
        showSuccess()
    }
    
    private func isValidHexColor(_ hex: String) -> Bool {
        let trimmed = hex.trimmingCharacters(in: .whitespaces)
        
        // Check format: #rrggbb (7 characters total)
        guard trimmed.hasPrefix("#") && trimmed.count == 7 else {
            return false
        }
        
        // Validate hex characters
        let hexPart = String(trimmed.dropFirst())
        return hexPart.allSatisfy { $0.isHexDigit }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
        showingSaved = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            clearMessages()
        }
    }
    
    private func showSuccess() {
        showingSaved = true
        showingError = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            clearMessages()
        }
    }
    
    private func clearMessages() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingSaved = false
            showingError = false
        }
    }
}
