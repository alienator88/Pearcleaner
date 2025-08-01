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

//struct LadderTopRoundedRectangle: InsettableShape {
//    var cornerRadius: CGFloat
//    var ladderHeight: CGFloat
//    var ladderPosition: CGFloat
//    var insetAmount: CGFloat = 0
//
//    func inset(by amount: CGFloat) -> some InsettableShape {
//        var shape = self
//        shape.insetAmount += amount
//        return shape
//    }
//
//    func path(in rect: CGRect) -> Path {
//        var path = Path()
//
//        // Calculate the middle x position for the vertical section
//        //        let ladderStartX = rect.maxX - cornerRadius - (rect.width / ladderPosition)
//        let ladderStartX = rect.minX + cornerRadius + ladderPosition
//
//        // Start at the top-right corner
//        path.move(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
//
//        // 1. Top-right rounded corner
//        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
//                          control: CGPoint(x: rect.maxX, y: rect.minY))
//
//        // 2. Right side straight line down
//        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
//
//        // 3. Bottom-right rounded corner
//        path.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
//                          control: CGPoint(x: rect.maxX, y: rect.maxY))
//
//        // 4. Straight line across bottom
//        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
//
//        // 5. Bottom-left rounded corner
//        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
//                          control: CGPoint(x: rect.minX, y: rect.maxY))
//
//        // 6. Left side straight line going up
//        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + ladderHeight + cornerRadius))
//
//        // 7. Top-left rounded corner
//        path.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + ladderHeight),
//                          control: CGPoint(x: rect.minX, y: rect.minY + ladderHeight))
//
//        // 8. Straight line right to the start of the vertical section
//        path.addLine(to: CGPoint(x: ladderStartX - cornerRadius, y: rect.minY + ladderHeight))
//
//        // 9. Curved transition into the vertical section (left side)
//        path.addQuadCurve(
//            to: CGPoint(x: ladderStartX, y: rect.minY + ladderHeight - cornerRadius),
//            control: CGPoint(x: ladderStartX, y: rect.minY + ladderHeight)
//        )
//
//        // 10. Vertical line
//        path.addLine(to: CGPoint(x: ladderStartX, y: rect.minY + cornerRadius))
//
//        // 11. Curved transition from vertical to top (right side)
//        path.addQuadCurve(
//            to: CGPoint(x: ladderStartX + cornerRadius, y: rect.minY),
//            control: CGPoint(x: ladderStartX, y: rect.minY)
//        )
//
//        // 12. Final line to close the shape
//        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
//
//        path.closeSubpath()
//        return path
//    }
//}

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

struct SettingsControlButtonGroup: View {
    @Binding var isResetting: Bool
    let resetAction: () -> Void
    let exportAction: () -> Void
    let importAction: () -> Void

    @State private var hoveredIndex: Int? = nil
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if isResetting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .controlSize(.small)
                        .frame(width: 20)
                } else {
                    Image(systemName: "gear")
                        .frame(width: 20)
                }
            }
            .padding(.horizontal, 4)

            Divider().frame(height: 16).padding(.horizontal, 4)

            ForEach(0..<3) { index in
                let (label, action): (String, () -> Void) = switch index {
                case 0: ("Reset", resetAction)
                case 1: ("Export", exportAction)
                default: ("Import", importAction)
                }

                Button(action: action) {
                    Text(label)
                        .textCase(.uppercase)
                        .foregroundColor(.primary)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
                .disabled(isResetting)
                .padding(4)
                .background(hoveredIndex == index ? Color.primary.opacity(0.4) : Color.clear)
                .cornerRadius(4)
                .onHover { hovering in
                    withAnimation(animationEnabled ? .easeInOut(duration: 0.3) : nil) {
                        hoveredIndex = hovering ? index : nil
                    }
                }

                if index < 2 {
                    Divider().frame(height: 16).padding(.horizontal, 4)
                }
            }
        }
        .padding(8)
        // .background(hoveredIndex != nil ? Color.primary.opacity(0.4) : Color.clear) // removed as highlight is now per button
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.primary.opacity(0.5), lineWidth: 1)
        )
    }
}




struct SimpleCheckboxToggleStyle: ToggleStyle {
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
                            .foregroundStyle(!isHovered ? .primary : .secondary)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.secondary.opacity(0.5), lineWidth: 2)
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


//struct CircleCheckboxToggleStyle: ToggleStyle {
//    @State private var isHovered: Bool = false
//    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
//
//    func makeBody(configuration: Configuration) -> some View {
//        HStack {
//            Circle()
//                .fill(themeManager.pickerColor.adjustBrightness(5))
//                .frame(width: 18, height: 18)
//                .overlay {
//                    if configuration.isOn {
//                        ZStack {
//                            //                            Circle()
//                            //                                .fill(themeManager.pickerColor.adjustBrightness(-15))
//                            //                                .frame(width: 18, height: 18)
//                            Image(systemName: "checkmark")
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 8, height: 8)
//                                .foregroundStyle(.primary)
//                        }
//
//                    }
//                }
//                .overlay {
//                    Circle()
//                        .strokeBorder(themeManager.pickerColor.adjustBrightness(isHovered ? -10 : -5.0), lineWidth: 1)
//                }
//                .onTapGesture {
//                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
//                        configuration.isOn.toggle()
//                    }
//                }
//            configuration.label
//        }
//        .onHover(perform: { hovering in
//            self.isHovered = hovering
//        })
//    }
//}



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
                .frame(width: 20, alignment: .center)
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
                .frame(width: 20, alignment: .center)
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
                .frame(width: 20, alignment: .center)
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


struct LipoButton: ButtonStyle {
    @State private var hovered: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Image(systemName: hovered ? "square.split.1x2.fill" : "square.split.1x2")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .frame(width: 20, alignment: .center)
                .foregroundColor(.white.opacity(1))
                .animation(.easeInOut(duration: 0.1), value: hovered)
            Divider()
                .frame(height: 24)
                .foregroundColor(.white)
                .opacity(0.5)
                .padding(.horizontal, 8)

            configuration.label
                .foregroundColor(.white.opacity(1))

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
    @Binding var dimension: Double
    @State private var dimensionStart: Double?
    @State private var handleWidth: Double = 4
    @State private var handleHeight: Double = 30
    @State private var isHovered: Bool = false
    public init(dimension: Binding<Double>) {
        self._dimension = dimension
    }

    public var body: some View {
        Divider()
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


public struct SimpleButtonStyleFlipped: ButtonStyle {
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
        .foregroundColor(hovered ? color.opacity(0.5) : color)
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


//struct PearDropView: View {
//    @ObservedObject private var theme = ThemeManager.shared
//
//    var body: some View {
//
//        ZStack() {
//            let shadow = theme.displayMode == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.3)
//            let mainColor = theme.pickerColor.adjustBrightness(theme.displayMode == .dark ? 3 : 7)
//
//            shadow
//                .mask(
//                    Image("pearLogo")
//                        .resizable()
//                        .scaledToFit()
//                )
//                .offset(y: theme.displayMode == .dark ? 1 : -1)
//
//            mainColor
//                .mask(
//                    Image("pearLogo")
//                        .resizable()
//                        .scaledToFit()
//                )
//        }
//        //            AnimatedGradientView(colors: [.orange, .green, .yellow], direction: .horizontal)
//    }
//}

//struct PearDropViewSmall: View {
//
//    var body: some View {
//        VStack(alignment: .center, spacing: 0) {
//            HStack(spacing: 0) {
//                LinearGradient(gradient: Gradient(colors: [.green, .orange]), startPoint: .leading, endPoint: .trailing)
//                    .frame(width: 60)
//                LinearGradient(gradient: Gradient(colors: [.orange, .primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
//                    .frame(width: 10)
//                LinearGradient(gradient: Gradient(colors: [.primary.opacity(0.5), .primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
//                    .frame(width: 100)
//            }
//            .mask(
//                Image("logo_text_small")
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 180)
//            )
//        }
//        .frame(height: 50)
//    }
//}


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




//struct CustomPickerButton: View {
//    @EnvironmentObject var themeManager: ThemeManager
//
//    // Selected option binding to allow external state management
//    @Binding var selectedOption: CurrentPage
//    @Binding var isExpanded: Bool
//    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
//
//    // Options array with names and icons
//    let options: [CurrentPage]
//
//    // Action callback when an option is selected
//    var onSelect: ((String) -> Void)?
//
//    @State private var hoveredItem: String? // Tracks the currently hovered option
//
//    var body: some View {
//        Button(action: {
//            withAnimation(Animation.spring(duration: animationEnabled ? 0.35 : 0)) {
//                isExpanded.toggle()
//            }
//        }) {
//            ZStack {
//                // Background and overlay styling
//                VStack {
//                    if isExpanded {
//                        // Expanded menu with selectable options
//                        VStack(alignment: .leading, spacing: 0) {
//                            ForEach(Array(options.enumerated()), id: \.element.title) { index, option in
//                                Button(action: {
//                                    selectedOption = option
//                                    onSelect?(option.title)
//                                    withAnimation {
//                                        isExpanded = false
//                                    }
//                                }) {
//                                    HStack {
//                                        Image(systemName: option.icon)
//                                        Text(option.title)
//                                        if option.title == "Lipo" {
//                                            BetaBadge()
//                                        }
//                                        Spacer()
//                                        switch option.title {
//                                        case "Applications":
//                                            Text(verbatim: "⌘1").font(.footnote).opacity(0.3)
//                                        case "Development":
//                                            Text(verbatim: "⌘2").font(.footnote).opacity(0.3)
//                                        case "Lipo":
//                                            Text(verbatim: "⌘3").font(.footnote).opacity(0.3)
//                                        case "Orphaned Files":
//                                            Text(verbatim: "⌘4").font(.footnote).opacity(0.3)
//
//                                        default:
//                                            EmptyView()
//                                        }
//
//                                    }
//                                    .contentShape(Rectangle())
//                                    .opacity(hoveredItem == option.title ? 0.7 : 1.0)
//                                }
//                                .buttonStyle(.borderless)
//                                .foregroundStyle(.primary)
//                                .onHover { isHovering in
//                                    hoveredItem = isHovering ? option.title : nil
//                                }
//
//                                if index < options.count - 1 {
//                                    Divider()
//                                        .padding(.vertical, 8)
//                                        .opacity(0.3)
//                                }
//
//                            }
//                        }
//                        .frame(maxWidth: 140, alignment: .leading)
//                    } else {
//                        // Display the selected option when collapsed
//                        HStack {
//                            Image(systemName: selectedOption.icon)
//                            Text(selectedOption.title)
//                        }
//                        .padding(8)
//                        .contentShape(Rectangle())
//                        .opacity(hoveredItem == selectedOption.title ? 0.7 : 1.0) // Change opacity on hover
//                        .onHover { isHovering in
//                            // Update hoveredItem based on whether this HStack is hovered
//                            hoveredItem = isHovering ? selectedOption.title : nil
//                        }
//                    }
//                }
//                .padding(isExpanded ? 10 : 0)
//                .background(backgroundView(color: .blue, glass: false))
//                .cornerRadius(8)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 8)
//                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
//                )
//                .transition(.scale)
//            }
//        }
//        .buttonStyle(.plain)
//    }
//}


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
                    .fill(configuration.isOn ? ThemeColors.shared(for: colorScheme).textPrimary : ThemeColors.shared(for: colorScheme).textSecondary)
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
        AlertNotification(label: "Helper Not Installed".localized(), icon: "key", buttonAction: {
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
        Text("BETA").font(.system(size: fontSize)).foregroundColor(.orange)
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
                        .foregroundStyle(.secondary.opacity(0.5))
                        .matchedGeometryEffect(id: "previous", in: animation)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            HStack(spacing: 8) {
                Text("Searching:")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text((currentStep == 0 || !spotlight) ? "File System" : "Spotlight Index")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .matchedGeometryEffect(id: "current", in: animation)
                    .transition(.opacity)

                ProgressView().controlSize(.small)
            }
            .animation(.easeInOut(duration: animationEnabled ? 0.3 : 0), value: currentStep)
        }
        .frame(height: 48)
    }
}
