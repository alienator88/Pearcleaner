//
//  Styles.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import Foundation
import SwiftUI

struct SimpleButtonStyle: ButtonStyle {
    @State private var hovered = false
    let icon: String
    let label: String
    let help: String
    let color: Color
    let size: CGFloat

    init(icon: String, label: String = "", help: String, color: Color = Color("mode"), size: CGFloat = 20) {
        self.icon = icon
        self.label = label
        self.help = help
        self.color = color
        self.size = size
    }
    
    func makeBody(configuration: Self.Configuration) -> some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
            if !label.isEmpty {
                Text(label)
            }
        }
        .foregroundColor(hovered ? color : color.opacity(0.5))
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


struct RegularButtonStyle: ButtonStyle {
    let icon: String
    let label: String
    let help: String
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {

        HStack(alignment: .center) {
            Image(systemName: icon).foregroundColor(Color("mode")).padding(.leading, 2).padding(.trailing, 0)
            Text(label).textCase(.uppercase).foregroundColor(Color("mode")).fontWeight(.bold).padding(.trailing, 2)

        }
        .padding(8)
        .background(!configuration.isPressed ? hovered ? Color("mode").opacity(0.4) : Color("mode").opacity(0) : Color("mode").opacity(0.5))
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
                .strokeBorder(Color("mode").opacity(0.5), lineWidth: 1)
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
        )
        .help(help)

    }
}


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
                    .foregroundColor(Color("mode")).padding(.leading, 2).padding(.trailing, 0)
            }
            Text(label)
                .textCase(.uppercase).foregroundColor(Color("mode")).fontWeight(.bold).padding(.trailing, 2)
        }
        .padding(8)
        .background(!configuration.isPressed ? hovered ? Color("mode").opacity(0.4) : Color("mode").opacity(0) : Color("mode").opacity(0.5))
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
                .strokeBorder(Color("mode").opacity(0.5), lineWidth: 1)
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
        )
        .help(help)
    }
}



struct InfoButton: View {
    @State private var isPopoverPresented: Bool = false
    let text: String
    let color: Color?
    let label: String?

    var body: some View {
        Button(action: {
            self.isPopoverPresented.toggle()
        }) {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: "info.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundColor(color?.opacity(0.7) ?? Color("mode").opacity(0.7))
                    .frame(height: 16)
                if !label!.isEmpty {
                    Text(label!)
                        .font(.callout)
                        .foregroundColor(color?.opacity(0.7) ?? Color("mode").opacity(0.7))

                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VStack {
                Spacer()
                Text(text)
                    .font(.callout)
                    .frame(maxWidth: .infinity)
                    .padding()
                Spacer()
            }
            .frame(width: 300)
        }
        .padding(.horizontal, 5)
    }
}


struct UninstallButton: ButtonStyle {
    var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "trash")
                .foregroundColor(isEnabled ? .white.opacity(1) : .white.opacity(0.3))

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
//        .background(
//            configuration.isPressed ? Color("uninstall").opacity(0.8) :
//                (isEnabled ? Color("uninstall") : Color.gray)
//        )
        .cornerRadius(8)
        .onHover { over in
            if over {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}



struct WarningPopoverView: View {
    var label: String
    var bodyText: String

    @Binding var isPresented: Bool

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .popover(isPresented: $isPresented, arrowEdge: .top) {
                    VStack {
                        Spacer()
                        Text(bodyText)
                            .font(.callout)
                            .frame(maxWidth: .infinity)
                            .padding()
                        Spacer()
                    }
                    .frame(width: 300)
                }

            Text(label)
                .foregroundStyle(Color.red)

            Spacer()
        }
        .onTapGesture {
            isPresented.toggle()
        }
    }
}


public struct NewFeatureView: View {
    var text: String
    var mini: Bool
    @Binding var showFeature: Bool

    public var body: some View {
        VStack {
            HStack {
                Image(systemName: "star")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text("New features for v\((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)!)!")
                    .font(.headline).bold()
                Spacer()
                Button("") {
                    withAnimation(Animation.easeInOut(duration: 0.5)) {
                        showFeature = false
                    }
                }
                .buttonStyle(SimpleButtonStyle(icon: "x.circle.fill", help: "Close", color: (Color("mode").opacity(0.5))))
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding()

            ScrollView() {
                Text(text)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                    .padding(.trailing)
            }
            .padding(.horizontal)
            .padding(.bottom)

        }
        .frame(maxWidth: mini ? 200 : 400, maxHeight: mini ? 300 : 250)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color("mode").opacity(0.2), lineWidth: 0.6)
        )
        .padding()
    }
}


public struct SlideableDivider: View {
    @EnvironmentObject private var themeSettings: ThemeSettings
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
            .foregroundStyle(Color("mode").opacity(0.0))
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


struct LabeledDivider: View {
    let label: String
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color("mode").opacity(0.2))

            Text(label)
                .textCase(.uppercase)
                .font(.title2)
                .foregroundColor(Color("mode").opacity(0.6))
                .padding(.horizontal, 10)
                .frame(minWidth: 80)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color("mode").opacity(0.2))
        }
        .frame(minHeight: 35)
    }
}


struct AnimatedSearchStyle: TextFieldStyle {
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Binding var text: String
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fsm: FolderSettingsManager

    func _body(configuration: TextField<Self._Label>) -> some View {
        
        HStack(spacing: 5) {
            
            if isHovered || !text.isEmpty {
                
                configuration
                    .frame(height: 15)
                    .font(.title3)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.leading, 50)

                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 15, height: 15)
                    .padding(.trailing, 5)
                    .foregroundStyle(isHovered ? Color("mode").opacity(0.8) : Color("mode").opacity(0.5))
                    .onTapGesture {
                        withAnimation {
                            // Refresh Apps list
                            appState.reload.toggle()
                            let sortedApps = getSortedApps(paths: fsm.folderPaths, appState: appState)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                appState.sortedApps = sortedApps
                                appState.reload.toggle()
                            }
                        }
                        
                    }
                    .help("Refresh app list")


                if text != "" {
                    Image(systemName: "xmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 10, height: 10)
                        .padding(.trailing, 5)
                        .foregroundStyle(isHovered ? Color("mode").opacity(0.8) : Color("mode").opacity(0.5))
                        .onTapGesture {
                            withAnimation {
                                text = ""
                            }
                        }
                        .help("Clear search")
                }


            } else {
                HStack {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundColor(isHovered ? Color("mode") : Color("mode").opacity(0.5))
                }
                .frame(width: 150)

            }
        }
        .padding(8)
        .overlay(
            Group {
                if isHovered || !text.isEmpty {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color("mode").opacity(0.4), lineWidth: 1)
                        .allowsHitTesting(false)
                        .padding(.leading, 50)
                }
            }
        )
        .onHover { hovering in
            withAnimation(Animation.easeInOut(duration: 0.4)) {
                self.isHovered = hovering
                self.isFocused = hovering
            }
        }
        .focused($isFocused)
    }
}




struct SimpleSearchStyle: TextFieldStyle {
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @State var icon: Image?
    @State var trash: Bool = false
    @Binding var text: String
    @EnvironmentObject var appState: AppState
    @AppStorage("settings.general.mini") private var mini: Bool = false

    func _body(configuration: TextField<Self._Label>) -> some View {
        
        HStack(spacing: 5) {
            
            HStack(spacing: 5) {
                if icon != nil {
                    icon
                        .foregroundColor(Color("mode").opacity(0.5))
                }
                
                configuration
                    .font(.title3)
                    .textFieldStyle(PlainTextFieldStyle())

                
                if trash && text != "" {
                    Image(systemName: "xmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 10, height: 10)
                        .padding(.trailing, 5)
                        .foregroundStyle(isHovered ? Color("mode").opacity(0.8) : Color("mode").opacity(0.5))
                        .onTapGesture {
                            text = ""
                        }
                        .help("Clear search")
                }
            }
            
        }
        .padding(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color("mode").opacity(0.2), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .onHover { hovering in
            withAnimation(Animation.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
                self.isFocused = true
            }
        }
        .focused($isFocused)
        .onAppear {
            updateOnMain {
                self.isFocused = false
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



struct VerticalDivider: View {
    
    var color: Color = Color("AccentColor")
    var width: CGFloat = 1
    var height: CGFloat = 20
    var opacity: Double = 1
    
    var body: some View {
        Divider()
            .foregroundColor(color)
            .frame(width: width, height: height)
            .opacity(opacity)
            .ignoresSafeArea(.all)
    }
}




struct WindowActionButton: ButtonStyle {
    enum UserAction {
        case accept
        case cancel
    }
    @State private var hovered = false
    let action: UserAction
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 100)
            .padding(10)
            .background(
                !configuration.isPressed ?
                !hovered ?
                action == .accept ? Color("button") : Color.red :
                    action == .accept ? Color("button").opacity(0.8) : Color.red.opacity(0.8) :
                    action == .accept ? Color("button").opacity(0.5) : Color.red.opacity(0.5)
            )
            .foregroundColor(.white)
            .cornerRadius(8)
            .onHover { hovering in
                withAnimation(Animation.easeIn(duration: 0.15)) {
                    hovered = hovering
                }
            }
    }
}


struct SimpleButtonBrightStyle: ButtonStyle {
    @State private var hovered = false
    let icon: String
    let help: String
    let color: Color
    let shield: Bool?

    init(icon: String, help: String, color: Color, shield: Bool? = nil) {
        self.icon = icon
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



struct FilesViewActionButton: ButtonStyle {
    enum UserAction {
        case uninstall
        case close
    }
    @State private var hovered = false
    let action: UserAction

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 70)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        configuration.isPressed ?
                        Color("AccentColor").opacity(0.7) :
                            hovered ? Color("AccentColor").opacity(0.8) : Color("AccentColor").opacity(0.9), lineWidth: 2
                    )


            )
            .foregroundColor(
                action == .uninstall ? Color("AccentColor") : Color("mode")
            )
            .cornerRadius(6)
            .onHover { hovering in
                withAnimation(Animation.easeIn(duration: 0.15)) {
                    hovered = hovering
                }
            }
    }
}




struct SentinelToggleStyle: ToggleStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        
        HStack {
            
            ZStack{
                RoundedRectangle(cornerRadius: 50)
                    .fill(configuration.isOn ? greenBG : redBG)
                    .frame(width: 70, height: 40)
                HStack{
                    Image(systemName: "lock.shield")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .padding(.leading, 10)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "shield")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .padding(.trailing, 10)
                        .foregroundColor(.white)
                }
                
            }
            .frame(width: 70, height: 40, alignment: .center)
            .overlay(
                Circle()
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 0)
                    .padding(.all, 4)
                    .offset(x: configuration.isOn ? 15 : -15, y: 0)
            )
            .overlay(
                Image(systemName: "power")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.black.opacity(0.3))
                    .offset(x: configuration.isOn ? 15 : -15, y: 0)
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.5)) {
                    configuration.isOn.toggle()
                }
            }
            .animation(.default, value: configuration.isOn)
        }
        
        
    }
    
}



private let greenBG: AnyShapeStyle = AnyShapeStyle(
    .green.shadow(.inner(radius: 2, x: 0, y: 1))
)

private let redBG: AnyShapeStyle = AnyShapeStyle(
    .red.shadow(.inner(radius: 2, x: 0, y: 1))
)



struct PillPicker: View {
    @Binding var index: Int
    var onTapAction: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ForEach(0..<3) { i in
                ZStack {
                    Capsule()
                        .fill(Color.white)
                        .offset(x: (CGFloat(index - i) * 100))
                        .animation(.default, value: index)
                        .opacity(index == i ? 1 : 0)
                        .scaleEffect(index == i ? 1 : 0.70)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)

                    HStack(spacing: 0) {
                        
                        Text(i == 0 ? "Apps" : (i == 1 ? "Widgets" : "Plugins"))
                            .font(.system(size: 12))
                            .foregroundColor(index == i ? (colorScheme == .dark ? .black : Color("AccentColor")) : Color("mode"))
                    }
                    .padding(5)
                    .frame(height: 25)
                    .background(.white.opacity(0.0001))
                }
                .onTapGesture {
                    withAnimation {
                        index = i
                        onTapAction()
                    }
                }
            }
        }
        .frame(height: 25)
        .padding(5)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.8 : 0.2), lineWidth: 1)
                        .blur(radius: 1)
                        .offset(y: 1)
                )
        )
        .clipShape(Capsule())
    }
}




struct PearDropView: View {

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                LinearGradient(gradient: Gradient(colors: [.green, .orange]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 220)
                LinearGradient(gradient: Gradient(colors: [.orange, Color("mode").opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
                    .frame(width: 10)
                LinearGradient(gradient: Gradient(colors: [Color("mode").opacity(0.5), Color("mode").opacity(0.5)]), startPoint: .leading, endPoint: .trailing)
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



// Used for testing UI bounds
extension View {
    func bounds() -> some View {
        self.border(Color.red, width: 1)
    }
}


@ViewBuilder
func backgroundView(themeSettings: ThemeSettings, darker: Bool = false, glass: Bool = false) -> some View {
    if glass {
        GlassEffect(material: .sidebar, blendingMode: .behindWindow)
            .edgesIgnoringSafeArea(.all)
    } else {
        darker ? themeSettings.themeColor.darker(by: 5).edgesIgnoringSafeArea(.all) : themeSettings.themeColor.edgesIgnoringSafeArea(.all)
    }
}


struct PresetColor: ButtonStyle {
    var fillColor: Color
    var label: String

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .frame(width: 20, height: 20)
                .fixedSize(horizontal: true, vertical: true)
                .foregroundColor(fillColor)
                .background(fillColor)
                .clipShape(Circle())
                .help(label)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .strokeBorder(Color("mode").opacity(0.8), lineWidth: 1.5))
//            Text(label)
        }
        .onHover { inside in inside ? NSCursor.pointingHand.push() : NSCursor.pop() }

    }
}
