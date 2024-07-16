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
            withAnimation(Animation.easeIn(duration: 0.15)) {
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
                    withAnimation(.smooth()) {
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
            withAnimation() {
                hovered = hovering
            }
        }
        .scaleEffect(configuration.isPressed ? 0.95 : 1)
        .help(help)
    }
}



struct PearDropView: View {

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                LinearGradient(gradient: Gradient(colors: [.green, .orange]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 220)
                LinearGradient(gradient: Gradient(colors: [.orange, .primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 10)
                LinearGradient(gradient: Gradient(colors: [.primary.opacity(0.5), .primary.opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 300)
            }
            .mask(
                Image("logo_text_small")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 500)
                    .padding()
            )

        }
        .frame(height: 120)

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

