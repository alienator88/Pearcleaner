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
    
    // MARK: - Default Color Values - Made accessible
    static let defaultDarkColors = [
        "#1a1b1f", // backgroundMain
        "#2d2e33", // backgroundPanel
        "#ffffff", // textPrimary
        "#8f9093", // textSecondary
        "#419cff"  // accentPrimary
    ]
    
    static let defaultLightColors = [
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


struct CustomColorPicker: View {
    @Binding var selectedColor: Color
    @State private var hue: Double = 0.0
    @State private var saturation: Double = 1.0
    @State private var brightness: Double = 1.0
    
    let pickerSize: CGSize = CGSize(width: 280, height: 200)
    let sliderHeight: CGFloat = 20
    
    // Pre-compute the hue gradient colors to avoid recalculation
    private let hueGradientColors = [
        Color(hue: 0, saturation: 1, brightness: 1),
        Color(hue: 0.16, saturation: 1, brightness: 1),
        Color(hue: 0.33, saturation: 1, brightness: 1),
        Color(hue: 0.5, saturation: 1, brightness: 1),
        Color(hue: 0.66, saturation: 1, brightness: 1),
        Color(hue: 0.83, saturation: 1, brightness: 1),
        Color(hue: 1, saturation: 1, brightness: 1)
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Color Gradient with better corner handling
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hue: hue, saturation: 0, brightness: 1),
                        Color(hue: hue, saturation: 1, brightness: 1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.black
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.multiply) // This should help with corner blending
                
                // Scope image
                Image(systemName: "scope")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .shadow(color: Color.black, radius: 2)
                    .position(
                        x: CGFloat(saturation) * pickerSize.width - 1,
                        y: CGFloat(1 - brightness) * pickerSize.height - 1
                    )
                    .allowsHitTesting(false)
            }
            .frame(width: pickerSize.width, height: pickerSize.height)
            .drawingGroup() // This can help with rendering artifacts
            .clipShape(RoundedRectangle(cornerRadius: 8))
//            .overlay(
//                RoundedRectangle(cornerRadius: 8)
//                    .stroke(Color.white, lineWidth: 0.8)
//            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSaturationBrightness(from: value.location)
                    }
            )

            // Hue gradient
            ZStack(alignment: .leading) {
                LinearGradient(
                    gradient: Gradient(colors: hueGradientColors),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: pickerSize.width, height: sliderHeight)
                
                // Vertical rounded rectangle thumb
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: 2, height: sliderHeight - 2)
                    .shadow(color: Color.black, radius: 2)
                    .offset(x: CGFloat(hue) * pickerSize.width - 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
//            .overlay(
//                RoundedRectangle(cornerRadius: 8)
//                    .stroke(Color.white, lineWidth: 0.8)
//            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateHue(from: value.location)
                    }
            )
        }
        .onAppear {
            initializeFromColor()
        }
    }
    
    private func updateSaturationBrightness(from location: CGPoint) {
        // Ensure the values are properly bounded and mapped
        saturation = Double(min(max(location.x / pickerSize.width, 0), 1))
        brightness = Double(min(max(1 - (location.y / pickerSize.height), 0), 1))
        updateSelectedColor()
    }
    
    private func updateHue(from location: CGPoint) {
        hue = Double(min(max(location.x / pickerSize.width, 0), 1))
        updateSelectedColor()
    }
    
    private func updateSelectedColor() {
        selectedColor = Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    private func initializeFromColor() {
        let uiColor = NSColor(selectedColor)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        hue = Double(h)
        saturation = Double(s)
        brightness = Double(b)
    }
}

struct ClickableColorSquare: View {
    let name: String
    let colorIndex: Int
    @Binding var colorsText: String
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showingColorPicker = false
    @State private var selectedColor: Color = .clear
    
    // Computed property to get the current color from theme (no local override)
    private var currentColor: Color {
        let theme = ThemeColors.shared(for: colorScheme)
        switch colorIndex {
        case 0: return theme.primaryBG
        case 1: return theme.secondaryBG
        case 2: return theme.primaryText
        case 3: return theme.secondaryText
        case 4: return theme.accent
        default: return .clear
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(currentColor) // Always uses theme color, no local override
                .frame(width: 30, height: 30)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ThemeColors.shared(for: colorScheme).secondaryText, lineWidth: 1)
                )
                .onTapGesture {
                    selectedColor = currentColor
                    showingColorPicker = true
                }
                .popover(isPresented: $showingColorPicker, arrowEdge: .top) {
                    VStack(spacing: 16) {
                        // Large color preview background - this updates dynamically
//                        RoundedRectangle(cornerRadius: 12)
//                            .fill(selectedColor)
//                            .frame(height: 60)
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 12)
//                                    .stroke(ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.3), lineWidth: 1)
//                            )
//                            .padding(.horizontal)

                        CustomColorPicker(selectedColor: $selectedColor)
                            // No onChange needed since we're not updating anything locally
                        
                        Button("Save") {
                            // Save to theme when closing
                            updateColorInTheme()
                            showingColorPicker = false
                        }
                        .controlSize(.small)
                        .buttonStyle(.plain)
                        .foregroundStyle(theme(for: colorScheme).accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .controlGroup(Capsule(style: .continuous), level: .secondary)
                    }
                    .padding()
                    .background(selectedColor.padding(-80))
                    .frame(width: 340)
                }
            
            Text(name)
                .font(.caption2)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
        }
        .frame(width: 80)
        .onChange(of: colorsText) { _ in
            selectedColor = currentColor
        }
        .onChange(of: colorScheme) { _ in
            selectedColor = currentColor
        }
        .onAppear {
            selectedColor = currentColor
        }
    }
    
    private func updateColorInTheme() {
        var colors = colorsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        while colors.count < 5 {
            let defaults = colorScheme == .dark ? ThemeColors.defaultDarkColors : ThemeColors.defaultLightColors
            colors.append(defaults[colors.count])
        }
        
        colors[colorIndex] = selectedColor.hexString
        
        colorsText = colors.joined(separator: ", ")
        
        if colorScheme == .dark {
            ThemeColors.saveCustomColors(dark: colorsText, light: ThemeColors.getCurrentColorsString(for: .light))
        } else {
            ThemeColors.saveCustomColors(dark: ThemeColors.getCurrentColorsString(for: .dark), light: colorsText)
        }
    }
}

struct InteractiveThemeColorDemo: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var colorsText: String
    
    var body: some View {
        HStack(spacing: 8) {
            ClickableColorSquare(name: "Primary BG", colorIndex: 0, colorsText: $colorsText)
            ClickableColorSquare(name: "Secondary BG", colorIndex: 1, colorsText: $colorsText)
            ClickableColorSquare(name: "Primary Text", colorIndex: 2, colorsText: $colorsText)
            ClickableColorSquare(name: "Secondary Text", colorIndex: 3, colorsText: $colorsText)
            ClickableColorSquare(name: "Accent", colorIndex: 4, colorsText: $colorsText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

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

            InteractiveThemeColorDemo(colorsText: $colorsText)

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
        let colors = colorsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        if colors.count != 5 {
            showError("Please provide exactly 5 hex colors separated by commas.")
            return
        }
        
        for (index, color) in colors.enumerated() {
            if !isValidHexColor(color) {
                showError("Color #\(index + 1) '\(color)' is not a valid hex color. Use format #rrggbb")
                return
            }
        }
        
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
