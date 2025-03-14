//
//  Styles.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI
import AlinFoundation


struct LadderTopRoundedRectangle2: InsettableShape {
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

struct LadderTopRoundedRectangle: InsettableShape {
    var cornerRadius: CGFloat
    var ladderHeight: CGFloat
    var ladderPosition: CGFloat
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Calculate the middle x position for the vertical section
//        let ladderStartX = rect.maxX - cornerRadius - (rect.width / ladderPosition)
        let ladderStartX = rect.minX + cornerRadius + ladderPosition

        // Start at the top-right corner
        path.move(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))

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

        path.closeSubpath()
        return path
    }
}

struct ResetSettingsButtonStyle: ButtonStyle {
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
                    .foregroundColor(.primary).padding(.leading, 2).padding(.trailing, 0)
            }
            Text(label)
                .textCase(.uppercase).foregroundColor(.primary).fontWeight(.bold).padding(.trailing, 2)
        }
        .padding(8)
        .background(!configuration.isPressed ? hovered ? Color.primary.opacity(0.4) : Color.primary.opacity(0) : Color.primary.opacity(0.5))
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
                .strokeBorder(.primary.opacity(0.5), lineWidth: 1)
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
        )
        .help(help)
    }
}


struct SimpleCheckboxToggleStyle: ToggleStyle {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(themeManager.pickerColor.adjustBrightness(5))
                .frame(width: 14, height: 14)
                .overlay {
                    if configuration.isOn {
//                        RoundedRectangle(cornerRadius: 2)
//                            .fill(themeManager.pickerColor.adjustBrightness(-20))
//                            .frame(width: 8, height: 8)
                        Image(systemName: "checkmark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 8, height: 8)
                            .foregroundStyle(!isHovered ? .primary : .secondary)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(themeManager.pickerColor.adjustBrightness(isHovered ? -15 : -5.0), lineWidth: 1)
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


struct CircleCheckboxToggleStyle: ToggleStyle {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Circle()
                .fill(themeManager.pickerColor.adjustBrightness(5))
                .frame(width: 18, height: 18)
                .overlay {
                    if configuration.isOn {
                        ZStack {
//                            Circle()
//                                .fill(themeManager.pickerColor.adjustBrightness(-15))
//                                .frame(width: 18, height: 18)
                            Image(systemName: "checkmark")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 8, height: 8)
                                .foregroundStyle(.primary)
                        }

                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(themeManager.pickerColor.adjustBrightness(isHovered ? -10 : -5.0), lineWidth: 1)
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



struct UninstallButton: ButtonStyle {
    @State private var hovered: Bool = false
    var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Image(systemName: !hovered ? "trash" : "trash.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(isEnabled ? .white.opacity(1) : .white.opacity(0.3))
                .frame(width: 18, height: 18)
                .animation(.easeInOut(duration: 0.1), value: hovered)

            Divider()
                .frame(height: 24)
                .opacity(0.5)
                .padding(.horizontal, 8)

            configuration.label
                .frame(minWidth: 50)
                .foregroundColor(isEnabled ? .white.opacity(1) : .white.opacity(0.3))

        }
        .frame(height: 24)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(configuration.isPressed ? Color("uninstall").opacity(0.8) : Color("uninstall"))
        .cornerRadius(8)
        .onHover { over in
            hovered = over
        }
    }
}



struct RescanButton: ButtonStyle {
    @State private var hovered: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Image(systemName: !hovered ? "arrow.counterclockwise.circle" : "arrow.counterclockwise.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.1), value: hovered)

            Divider()
                .frame(height: 24)
                .foregroundColor(.white)
                .opacity(0.5)
                .padding(.horizontal, 8)

            configuration.label
                .foregroundColor(.white)

        }
        .frame(height: 24)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(configuration.isPressed ? Color("button").opacity(0.8) : Color("button"))
        .cornerRadius(8)
        .onHover { over in
            hovered = over
        }
    }
}

struct ExcludeButton: ButtonStyle {
    @State private var hovered: Bool = false
    var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Image(systemName: !hovered ? "minus.circle" : "minus.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundColor(isEnabled ? .white.opacity(1) : .white.opacity(0.3))
                .animation(.easeInOut(duration: 0.1), value: hovered)

            Divider()
                .frame(height: 24)
                .foregroundColor(.white)
                .opacity(0.5)
                .padding(.horizontal, 8)

            configuration.label
                .foregroundColor(isEnabled ? .white.opacity(1) : .white.opacity(0.3))

        }
        .frame(height: 24)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(configuration.isPressed ? Color("grayButton").opacity(0.8) : Color("grayButton"))
        .cornerRadius(8)
        .onHover { over in
            hovered = over
        }
    }
}



public struct SlideableDivider: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var dimension: Double
    @State private var dimensionStart: Double?
    @State private var handleWidth: Double = 4
    @State private var handleHeight: Double = 30
    @State private var isHovered: Bool = false
    public init(dimension: Binding<Double>) {
        self._dimension = dimension
    }

    public var body: some View {
        Rectangle()
            .opacity(0.0)
            .frame(width: 10)
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()

                } else {
                    NSCursor.pop()

                }
            }
            .contextMenu {
                Button("Reset Size") {
                    dimension = 300
                }
            }
            .gesture(drag)
            .help("Right click to reset size")
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
                let maxWidth: Double = 350
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
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(8)
            .cornerRadius(6)
            .textFieldStyle(.plain)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.primary.opacity(0.4), lineWidth: 0.8)
            )
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
                .foregroundColor(hovered ? color.opacity(0.5) : color)
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



struct PearDropView: View {
    var multiplier: CGFloat = 1.0 // Multiplier parameter with a default value

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                LinearGradient(gradient: Gradient(colors: [.green, .orange]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 175 * multiplier) // Adjust the width based on the multiplier
                LinearGradient(gradient: Gradient(colors: [.orange, .primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 10 * multiplier) // Adjust the width based on the multiplier
                LinearGradient(gradient: Gradient(colors: [.primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 250 * multiplier) // Adjust the width based on the multiplier
            }
            .mask(
                Image("logo_text_small")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 500 * multiplier) // Scale the mask image width
                    .padding()
            )
        }
        .frame(height: 120 * multiplier) // Adjust the height of the VStack based on the multiplier
    }
}

struct PearDropViewSmall: View {

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                LinearGradient(gradient: Gradient(colors: [.green, .orange]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 60)
                LinearGradient(gradient: Gradient(colors: [.orange, .primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 10)
                LinearGradient(gradient: Gradient(colors: [.primary.opacity(0.5), .primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 100)
            }
            .mask(
                Image("logo_text_small")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180)
            )
        }
        .frame(height: 50)
    }
}


// Background color/glass setter
@ViewBuilder
func backgroundView(themeManager: ThemeManager = ThemeManager.shared, darker: Bool = false, glass: Bool = false) -> some View {
    if glass {
        GlassEffect(material: .sidebar, blendingMode: .behindWindow)
            .edgesIgnoringSafeArea(.all)
    } else {
        darker ? themeManager.pickerColor.adjustBrightness(5).edgesIgnoringSafeArea(.all) : themeManager.pickerColor.edgesIgnoringSafeArea(.all)
    }
}



struct GlowGradientButton: View {
    // Define gradient colors for the button
    let gradientColors = Gradient(colors: [.blue,.purple,.pink,.red,.blue])

    // State variables to control animation and press state
    @State var isAnimating = false
    @State var isPressed = false

    var body: some View {
        ZStack{
            // Background of the button with stroke, blur, and offset effects
            RoundedRectangle(cornerRadius: 20)
                .stroke(AngularGradient(gradient: gradientColors, center: .center, angle: .degrees(isAnimating ? 360 : 0)), lineWidth: 10)
                .blur(radius: 30)
            //                .offset(y: 30) // Move the glow up or down
                .frame(width: 230, height: 30)

            // Text label for the button
            Text(verbatim: "Hello")
                .font(.system(size: 24))
                .frame(width: 280, height: 60)
                .background(.quinary.opacity(0.2), in: RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(.white)
                .overlay(
                    // Overlay to create glow effect
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AngularGradient(gradient: gradientColors, center: .center, angle: .degrees(isAnimating ? 360 : 0)), lineWidth: 2)
                )
        }
        // Scale effect when pressed
        .scaleEffect(isPressed ? 0.95 : 1)
        .animation(.easeInOut(duration: 0.2), value: isPressed)
        .onAppear() {
            // Animation to rotate gradient colors infinitely
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
        // Gesture to detect button press
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged({_ in isPressed = true})
                .onEnded({_ in isPressed = false})
        )
    }
}



struct CustomPickerButton: View {
    @EnvironmentObject var themeManager: ThemeManager

    // Selected option binding to allow external state management
    @Binding var selectedOption: CurrentPage
    @Binding var isExpanded: Bool
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    // Options array with names and icons
    let options: [CurrentPage]

    // Action callback when an option is selected
    var onSelect: ((String) -> Void)?

    @State private var hoveredItem: String? // Tracks the currently hovered option

    var body: some View {
        Button(action: {
            withAnimation(Animation.spring(duration: animationEnabled ? 0.35 : 0)) {
                isExpanded.toggle()
            }
        }) {
            ZStack {
                // Background and overlay styling
                VStack {
                    if isExpanded {
                        // Expanded menu with selectable options
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(options.enumerated()), id: \.element.title) { index, option in
                                Button(action: {
                                    selectedOption = option
                                    onSelect?(option.title)
                                    withAnimation {
                                        isExpanded = false
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: option.icon)
                                        Text(option.title)
                                        Spacer()
                                        switch option.title {
                                        case "Applications":
                                            Text(verbatim: "⌘1").font(.footnote).opacity(0.3)
                                        case "Development":
                                            Text(verbatim: "⌘2").font(.footnote).opacity(0.3)
                                        case "Orphaned Files":
                                            Text(verbatim: "⌘3").font(.footnote).opacity(0.3)
                                        default:
                                            EmptyView()
                                        }

                                    }
                                    .contentShape(Rectangle())
                                    .opacity(hoveredItem == option.title ? 0.7 : 1.0)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.primary)
                                .onHover { isHovering in
                                    hoveredItem = isHovering ? option.title : nil
                                }

                                if index < options.count - 1 {
                                    Divider()
                                        .padding(.vertical, 8)
                                        .opacity(0.3)
                                }

                            }
                        }
                        .frame(maxWidth: 140, alignment: .leading)
                    } else {
                        // Display the selected option when collapsed
                        HStack {
                            Image(systemName: selectedOption.icon)
                            Text(selectedOption.title)
                        }
                        .padding(8)
                        .contentShape(Rectangle())
                        .opacity(hoveredItem == selectedOption.title ? 0.7 : 1.0) // Change opacity on hover
                        .onHover { isHovering in
                            // Update hoveredItem based on whether this HStack is hovered
                            hoveredItem = isHovering ? selectedOption.title : nil
                        }
                    }
                }
                .padding(isExpanded ? 10 : 0)
                .background(backgroundView(themeManager: themeManager, darker: true, glass: false))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                )
                .transition(.scale)
            }
        }
        .buttonStyle(.plain)
    }
}


struct SettingsToggle: ToggleStyle {
    @EnvironmentObject var themeManager: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                ZStack {
                    // Background Track
                    Capsule()
                        .fill(themeManager.pickerColor.adjustBrightness(3))
                        .frame(width: 40, height: 24)
//                        .overlay {
//                            Capsule()
//                                .strokeBorder(configuration.isOn ? .green : .red, lineWidth: 1)
//                                .frame(width: 40, height: 24)
//                        }

                    // Toggle Knob
                    Circle()
                        .fill(configuration.isOn ? .primary : themeManager.pickerColor)
                        .frame(width: 18, height: 18)
                        .offset(x: configuration.isOn ? 9 : -9)
                        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                }
            }
        }
        .buttonStyle(.plain)
    }
}


struct HelperBadge: View {
    @AppStorage("settings.general.selectedTab") private var selectedTab: CurrentTabView = .general

    public var body: some View {
        AlertNotification(label: "Helper Not Installed".localized(), icon: "key", buttonAction: {
            selectedTab = .helper
            openAppSettings()
        }, btnColor: Color.orange, hideLabel: false)
    }
}
