//
//  Styles.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI
import AlinFoundation

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
                .frame(width: 18, height: 18)
                .overlay {
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.primary)
                            .scaleEffect(isHovered ? 0.8 : 1.0)
                    }
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
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: !hovered ? "trash" : "trash.fill")
                .foregroundColor(isEnabled ? .white.opacity(1) : .white.opacity(0.3))
                .scaleEffect(hovered ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: hovered)

            Divider()
                .frame(height: 24)
                .opacity(0.5)

            configuration.label
                .foregroundColor(isEnabled ? .white.opacity(1) : .white.opacity(0.3))

        }
        .frame(height: 24)
        .frame(minWidth: 75)
        .padding(.horizontal)
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
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: !hovered ? "arrow.counterclockwise.circle" : "arrow.counterclockwise.circle.fill")
                .foregroundColor(.white)
                .scaleEffect(hovered ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: hovered)

            Divider()
                .frame(height: 24)
                .foregroundColor(.white)
                .opacity(0.5)

            configuration.label
                .foregroundColor(.white)

        }
        .frame(height: 24)
        .frame(minWidth: 75)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(configuration.isPressed ? Color("button").opacity(0.8) : Color("button"))
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
            .foregroundStyle(.primary.opacity(0.0))
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
                    dimension = 280
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
                let minWidth: Double = 250
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
                    .frame(width: 220 * multiplier) // Adjust the width based on the multiplier
                LinearGradient(gradient: Gradient(colors: [.orange, .primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 10 * multiplier) // Adjust the width based on the multiplier
                LinearGradient(gradient: Gradient(colors: [.primary.opacity(0.5), .primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 300 * multiplier) // Adjust the width based on the multiplier
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
                    .frame(width: 260)
                LinearGradient(gradient: Gradient(colors: [.orange, .primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 10)
                LinearGradient(gradient: Gradient(colors: [.primary.opacity(0.5), .primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 300)
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
    // Selected option binding to allow external state management
    @Binding var selectedOption: CurrentPage
    @Binding var isExpanded: Bool
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    // Options array with names and icons
    let options: [CurrentPage]

    // Action callback when an option is selected
    var onSelect: ((String) -> Void)?

//    @State private var isExpanded: Bool = false

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
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(options, id: \.title) { option in
                                Button(action: {
                                    selectedOption = option // Update selected option
                                    onSelect?(option.title) // Call the selection handler
                                    withAnimation {
                                        isExpanded = false
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: option.icon)
                                        Text(option.title)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        // Display the selected option when collapsed
                        HStack {
                            Image(systemName: selectedOption.icon)
                            Text(selectedOption.title)
                        }
                    }
                }
                .padding(isExpanded ? 10 : 8)
//                .background(
//                    ZStack {
//                        LinearGradient(
//                            colors: [Color.green, Color.orange],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        ) // Gradient layer
//                        .clipShape(RoundedRectangle(cornerRadius: 8)) // Match shape to material
//                        .overlay(.ultraThinMaterial) // Translucent material over gradient
//                    }
//                )
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 0.6)
                )
                .transition(.scale)
            }
        }
        .buttonStyle(.plain)
    }
}
