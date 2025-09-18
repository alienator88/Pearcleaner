//
//  Styles.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI
import AlinFoundation


struct LadderTopRoundedRectangle: InsettableShape {
    var cornerRadius: CGFloat
    var ladderHeight: CGFloat
    var ladderPosition: CGFloat
    var isFlipped: Bool
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Calculate the ladder start position - always measured from left edge
        let ladderStartX = rect.minX + cornerRadius + ladderPosition

        // Start point changes based on flip
        let startPoint = isFlipped
        ? CGPoint(x: rect.minX + cornerRadius, y: rect.minY)
        : CGPoint(x: rect.maxX - cornerRadius, y: rect.minY)

        path.move(to: startPoint)

        if isFlipped {
            // Flipped version (ladder on right)

            // 1. Top-left rounded corner
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius),
                              control: CGPoint(x: rect.minX, y: rect.minY))

            // 2. Left side straight line down
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius))

            // 3. Bottom-left rounded corner
            path.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY),
                              control: CGPoint(x: rect.minX, y: rect.maxY))

            // 4. Straight line across bottom
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY))

            // 5. Bottom-right rounded corner
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius),
                              control: CGPoint(x: rect.maxX, y: rect.maxY))

            // 6. Right side straight line going up
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + ladderHeight + cornerRadius))

            // 7. Top-right rounded corner
            path.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + ladderHeight),
                              control: CGPoint(x: rect.maxX, y: rect.minY + ladderHeight))

            // 8. Straight line left to the start of the vertical section
            path.addLine(to: CGPoint(x: ladderStartX + cornerRadius, y: rect.minY + ladderHeight))

            // 9. Curved transition into the vertical section (right side)
            path.addQuadCurve(
                to: CGPoint(x: ladderStartX, y: rect.minY + ladderHeight - cornerRadius),
                control: CGPoint(x: ladderStartX, y: rect.minY + ladderHeight)
            )

            // 10. Vertical line
            path.addLine(to: CGPoint(x: ladderStartX, y: rect.minY + cornerRadius))

            // 11. Curved transition from vertical to top (left side)
            path.addQuadCurve(
                to: CGPoint(x: ladderStartX - cornerRadius, y: rect.minY),
                control: CGPoint(x: ladderStartX, y: rect.minY)
            )

            // 12. Final line to close the shape
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        } else {
            // Original version (ladder on left) - keeping your original code and comments

            // 1. Top-right rounded corner
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
                              control: CGPoint(x: rect.maxX, y: rect.minY))

            // 2. Right side straight line down
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))

            // 3. Bottom-right rounded corner
            path.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
                              control: CGPoint(x: rect.maxX, y: rect.maxY))

            // 4. Straight line across bottom
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))

            // 5. Bottom-left rounded corner
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
                              control: CGPoint(x: rect.minX, y: rect.maxY))

            // 6. Left side straight line going up
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + ladderHeight + cornerRadius))

            // 7. Top-left rounded corner
            path.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + ladderHeight),
                              control: CGPoint(x: rect.minX, y: rect.minY + ladderHeight))

            // 8. Straight line right to the start of the vertical section
            path.addLine(to: CGPoint(x: ladderStartX - cornerRadius, y: rect.minY + ladderHeight))

            // 9. Curved transition into the vertical section (left side)
            path.addQuadCurve(
                to: CGPoint(x: ladderStartX, y: rect.minY + ladderHeight - cornerRadius),
                control: CGPoint(x: ladderStartX, y: rect.minY + ladderHeight)
            )

            // 10. Vertical line
            path.addLine(to: CGPoint(x: ladderStartX, y: rect.minY + cornerRadius))

            // 11. Curved transition from vertical to top (right side)
            path.addQuadCurve(
                to: CGPoint(x: ladderStartX + cornerRadius, y: rect.minY),
                control: CGPoint(x: ladderStartX, y: rect.minY)
            )

            // 12. Final line to close the shape
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        }

        path.closeSubpath()
        return path
    }
}



struct ResetSettingsButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @Binding var isResetting: Bool
    let label: String
    let help: String
    @State private var hovered = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true


    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center) {
            if isResetting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .controlSize(.small)
                    .frame(width: 15)
            } else {
                Image(systemName: "gear")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).padding(.leading, 2).padding(.trailing, 0)
            }
            Text(label)
                .textCase(.uppercase).foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).fontWeight(.bold).padding(.trailing, 2)
        }
        .padding(8)
        .background(!configuration.isPressed ? hovered ? ThemeColors.shared(for: colorScheme).primaryText.opacity(0.4) : ThemeColors.shared(for: colorScheme).primaryText.opacity(0) : ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
        .cornerRadius(6)
        .scaleEffect(configuration.isPressed ? 0.95 : 1)
        .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
        .onHover { hovering in
            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                hovered = hovering
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5), lineWidth: 1)
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
        )
        .help(help)
    }
}

struct SettingsControlButtonGroup: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var isResetting: Bool
    let resetAction: () -> Void
    let exportAction: () -> Void
    let importAction: () -> Void

    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "gear")
                .resizable()
                .scaledToFit()
                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                .frame(width: 20)
                .rotationEffect(isResetting ? .degrees(360) : .degrees(0))
                .animation(isResetting ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                           value: isResetting)

            ForEach(0..<3) { index in
                let (label, action): (String, () -> Void) = switch index {
                case 0: ("Reset", resetAction)
                case 1: ("Export", exportAction)
                default: ("Import", importAction)
                }

                Button(action: action) {
                    Text(label)
                        .textCase(.uppercase)
                        .fontWeight(.bold)
                }

                if index < 2 {
                    Divider().frame(height: 10)
                }
            }
        }
        .disabled(isResetting)
        .controlSize(.small)
        .buttonStyle(.plain)
        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .controlGroup(Capsule(style: .continuous), level: .primary)
    }
}


struct ControlGroupButtonStyle<Shape: InsettableShape>: ButtonStyle {
    let foregroundColor: Color
    let shape: Shape
    let level: ControlGroupLevel
    let verticalPadding: CGFloat
    let horizontalPadding: CGFloat
    let skipControlGroup: Bool
    let disabled: Bool
    
    init(
        foregroundColor: Color,
        shape: Shape,
        level: ControlGroupLevel = .secondary,
        verticalPadding: CGFloat = 8,
        horizontalPadding: CGFloat = 14,
        skipControlGroup: Bool = false,
        disabled: Bool = false
    ) {
        self.foregroundColor = foregroundColor
        self.shape = shape
        self.level = level
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
        self.skipControlGroup = skipControlGroup
        self.disabled = disabled
    }
    
    func makeBody(configuration: Self.Configuration) -> some View {
        let styledContent = configuration.label
            .foregroundStyle(foregroundColor)
            .opacity(disabled ? 0.5 : 1.0)  // 50% opacity when disabled
            .controlSize(.small)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
//            .scaleEffect(configuration.isPressed && !disabled ? 0.98 : 1.0)  // Only scale if not disabled
//            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        
        if skipControlGroup {
            styledContent
        } else {
            styledContent.controlGroup(shape, level: level)
        }
    }
}

struct SimpleCheckboxToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.general.glass") private var glass: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.0000000001))
                .frame(width: 14, height: 14)
                .overlay {
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 8, height: 8)
                            .foregroundStyle(!isHovered ? ThemeColors.shared(for: colorScheme).primaryText : ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.5), lineWidth: 2)
                }
                .onTapGesture {
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        configuration.isOn.toggle()
                    }
                }
            configuration.label
        }
        .onHover(perform: { hovering in
            self.isHovered = hovering
        })
    }
}



public struct SlideableDivider: View {
    @Binding var dimension: Double
    @State private var color: Color
    @State private var dimensionStart: Double?
    @State private var handleWidth: Double = 4
    @State private var handleHeight: Double = 30
    @State private var isHovered: Bool = false
    public init(dimension: Binding<Double>, color: Color = .primary ) {
        self._dimension = dimension
        self.color = color
    }

    public var body: some View {
        Divider()
            .foregroundStyle(color)
            .background(
                // Invisible wider hover area
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 10) // 10pt wide hover area
                    .contentShape(Rectangle()) // Makes the clear area interactive
            )
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .contextMenu {
                Button("Reset Size") {
                    dimension = 265
                }
            }
            .gesture(drag)
            .help("Right click to reset size")
            .ignoresSafeArea(.all)
    }

    var drag: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: CoordinateSpace.global)
            .onChanged { val in
                if dimensionStart == nil {
                    dimensionStart = dimension
                }
                let delta = val.location.x - val.startLocation.x
                let newDimension = dimensionStart! + Double(delta)

                // Set minimum and maximum width
                let minWidth: Double = 240
                let maxWidth: Double = 300
                dimension = max(minWidth, min(maxWidth, newDimension))
                NSCursor.closedHand.set()
                handleWidth = 6
                handleHeight = 40
            }
            .onEnded { val in
                dimensionStart = nil
                NSCursor.arrow.set()
                handleWidth = 4
                handleHeight = 30
            }
    }
}



struct RoundedTextFieldStyle: TextFieldStyle {
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFocused

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(8)
            .cornerRadius(6)
            .textFieldStyle(.plain)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(ThemeColors.shared(for: colorScheme).secondaryText, lineWidth: 0.8)
            )
            .focused($isFocused)
            .onAppear {
                updateOnMain {
                    isFocused = false
                }
            }
    }
}



struct GlassEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material // Choose the material you want
    var blendingMode: NSVisualEffectView.BlendingMode // Choose the blending mode

    func makeNSView(context: Self.Context) -> NSView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        return visualEffectView
    }

    func updateNSView(_ nsView: NSView, context: Context) { }
}




struct SimpleButtonBrightStyle: ButtonStyle {
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @State private var hovered = false
    let icon: String
    let label: String
    let help: String
    let color: Color
    let shield: Bool?

    init(icon: String, label: String = "", help: String, color: Color, shield: Bool? = nil) {
        self.icon = icon
        self.label = label
        self.help = help
        self.color = color
        self.shield = shield
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20)
                .foregroundStyle(hovered ? color.opacity(0.5) : color)
            Text(label)
        }
        .padding(5)
        .onHover { hovering in
            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                hovered = hovering
            }
        }
        .scaleEffect(configuration.isPressed ? 0.95 : 1)
        .help(help)
    }
}


public struct SimpleButtonStyleFlipped: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var hovered = false
    let icon: String
    let iconFlip: String
    let label: String
    let help: String
    let color: Color
    let size: CGFloat
    let padding: CGFloat
    let rotate: Bool

    public init(icon: String, iconFlip: String = "", label: String = "", help: String, color: Color = .primary, size: CGFloat = 20, padding: CGFloat = 5, rotate: Bool = false) {
        self.icon = icon
        self.iconFlip = iconFlip
        self.label = label
        self.help = help
        self.color = color
        self.size = size
        self.padding = padding
        self.rotate = rotate
    }

    public func makeBody(configuration: Self.Configuration) -> some View {
        HStack(alignment: .center) {
            if !label.isEmpty {
                Text(label)
            }

            Image(systemName: (hovered && !iconFlip.isEmpty) ? iconFlip : icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotate ? (hovered ? 90 : 0) : 0))
                .animation(.easeInOut(duration: 0.2), value: hovered)
        }
        .foregroundStyle(hovered ? color.opacity(0.5) : color)
        .padding(padding)
        .onHover { hovering in
            withAnimation() {
                hovered = hovering
            }
        }
        .scaleEffect(configuration.isPressed ? 0.90 : 1)
        .help(help)
    }
}


// Background color/glass setter
@ViewBuilder
func backgroundView(color: Color, glass: Bool = false) -> some View {
    if glass {
        GlassEffect(material: .sidebar, blendingMode: .behindWindow)
            .edgesIgnoringSafeArea(.all)
    } else {
        color.edgesIgnoringSafeArea(.all)
    }
}


struct preTahoeSidebar: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.glass") private var glass: Bool = false

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background {
                    LinearGradient(colors: [ThemeColors.shared(for: colorScheme).secondaryBG, ThemeColors.shared(for: colorScheme).primaryBG], startPoint: .leading, endPoint: .trailing)
                }
        } else {
            content
                .background(backgroundView(color: ThemeColors.shared(for: colorScheme).secondaryBG, glass: glass))
                .overlay(
                    Rectangle()
                        .fill(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.1))
                        .frame(width: 1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                )
        }
    }
}

extension View {
    func preTahoeSidebarBG() -> some View {
        self.modifier(preTahoeSidebar())
    }
}


struct ifGlassAvailable: ViewModifier {
    @AppStorage("settings.general.glassEffect") private var glassEffect: String = "Regular"

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(glassEffect == "Regular" ? .regular : .clear, in: .rect(cornerRadius: 8))
        }
        else {
            content
        }
    }
}

extension View {
    func ifGlass() -> some View {
        self.modifier(ifGlassAvailable())
    }
}


struct ifGlassAvailableSidebar: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.glassEffect") private var glassEffect: String = "Regular"

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(.ultraThinMaterial.opacity(glassEffect == "Regular" ? 0 : 0.7))
                .glassEffect(glassEffect == "Regular" ? .regular : .clear, in: .rect(cornerRadius: 8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.2), lineWidth: colorScheme == .light ? 1 : 0)
                }
        }
        else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.2), lineWidth: 1)
                }
        }
    }
}

extension View {
    func ifGlassSidebar() -> some View {
        self.modifier(ifGlassAvailableSidebar())
    }
}


struct SettingsToggle: ToggleStyle {
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack {
                // Background Track
                Capsule()
                    .fill(.tertiary.opacity(0.5))
                    .frame(width: 40, height: 24)

                // Toggle Knob
                Circle()
                    .fill(configuration.isOn ? ThemeColors.shared(for: colorScheme).accent : ThemeColors.shared(for: colorScheme).secondaryText)
                    .frame(width: 18, height: 18)
                    .offset(x: configuration.isOn ? 8 : -8)
                    .animation(.spring(duration: 0.2), value: configuration.isOn)
            }
        }
        .buttonStyle(.plain)
    }
}


struct HelperBadge: View {
    @AppStorage("settings.general.selectedTab") private var selectedTab: CurrentTabView = .general

    var body: some View {
        AlertNotification(label: String(localized:"Helper Not Installed"), icon: "key", buttonAction: {
            selectedTab = .helper
            openAppSettings()
        }, btnColor: Color.orange, hideLabel: false)

    }
}


struct BetaBadge: View {
    let fontSize: CGFloat

    init(fontSize: CGFloat = 10) {
        self.fontSize = fontSize
    }

    var body: some View {
        Text("BETA").font(.system(size: fontSize)).foregroundStyle(.orange)
            .padding(1).padding(.horizontal, 2)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.orange, lineWidth: 1)
            }
    }
}


struct ProgressStepView: View {
    var currentStep: Int
    @Namespace private var animation
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") var animationEnabled: Bool = true
    @AppStorage("settings.general.spotlight") var spotlight = true

    var body: some View {
        VStack(spacing: 4) {
            if currentStep > 0 && spotlight {
                HStack(spacing: 8) {
                    Text("Searching:")
                        .font(.title2)
                        .opacity(0)
                    Text("File System")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.5))
                        .matchedGeometryEffect(id: "previous", in: animation)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            HStack(spacing: 8) {
                Text("Searching:")
                    .font(.title2)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                Text((currentStep == 0 || !spotlight) ? "File System" : "Spotlight Index")
                    .font(.title2)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .matchedGeometryEffect(id: "current", in: animation)
                    .transition(.opacity)

                ProgressView().controlSize(.small)
            }
            .animation(.easeInOut(duration: animationEnabled ? 0.3 : 0), value: currentStep)
        }
        .frame(height: 48)
    }
}
