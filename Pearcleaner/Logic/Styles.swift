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
                .foregroundColor(hovered ? color : color.opacity(0.5))
        }
        .padding(8)
//        .background {
//            if hovered && !(shield ?? false) {
////                Circle()
////                    .strokeBorder(Color("AccentColor"), lineWidth: 1)
//                RoundedRectangle(cornerRadius: 8)
//                    .strokeBorder(Color("AccentColor"), lineWidth: 1)
//            }
//            
//        }
        .onHover { hovering in
            withAnimation() {
                hovered = hovering
            }
        }
        .help(help)
    }
}


struct LabeledDivider: View {
    let label: String
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color("AccentColor").opacity(0.2))
            
            Text(label)
                .textCase(.uppercase)
                .font(.title2)
                .foregroundColor(Color("AccentColor").opacity(0.6))
                .padding(.horizontal, 10)
                .frame(minWidth: 80)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color("AccentColor").opacity(0.2))
        }
        .frame(minHeight: 35)
    }
}


struct AnimatedSearchStyle: TextFieldStyle {
    @State private var isHovered = false
    @Binding var text: String
    @Binding var reload: Bool
    @EnvironmentObject var appState: AppState

    func _body(configuration: TextField<Self._Label>) -> some View {
        
        HStack(spacing: 5) {
            
            if isHovered || !text.isEmpty {
                
                configuration
//                    .frame(minWidth: 130)
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
                            reload.toggle()
                            let sortedApps = getSortedApps()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                appState.sortedApps.userApps = sortedApps.userApps
                                appState.sortedApps.systemApps = sortedApps.systemApps
                                reload.toggle()
                            }
                        }
                        
                    }
                
            } else {
                Image(systemName: "magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(isHovered ? Color("mode") : Color("mode").opacity(0.5))
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
            }
        }
    }
}




struct SimpleSearchStyle: TextFieldStyle {
    @State private var isHovered = false
    @State var icon: Image?
    @State var trash: Bool = false
    @Binding var reload: Bool
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
//                    .frame(minWidth: mini ? 80 : 300)
//                    .frame(maxWidth: mini ? 150 : 300)
                    .font(.title3)
                    .textFieldStyle(PlainTextFieldStyle())
                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 15, height: 15)
                    .padding(.trailing, 5)
                    .foregroundStyle(isHovered ? Color("mode").opacity(0.8) : Color("mode").opacity(0.5))
                    .onTapGesture {
                        withAnimation {
                            // Refresh Apps list
                            reload.toggle()
                            let sortedApps = getSortedApps()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                appState.sortedApps.userApps = sortedApps.userApps
                                appState.sortedApps.systemApps = sortedApps.systemApps
                                reload.toggle()
                            }
                        }
                        
                    }
                
//                if trash {
//                    Image(systemName: "xmark")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: 10, height: 10)
//                        .padding(.trailing, 5)
//                        .foregroundStyle(isHovered ? Color("mode").opacity(0.8) : Color("mode").opacity(0.5))
//                        .onTapGesture {
//                            text = ""
//                        }
//                        .opacity(text.isEmpty ? 0 : 1)
//                }
            }
            
        }
        .padding(6)
        .overlay(
            Group {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color("mode").opacity(0.2), lineWidth: 1)
                    .allowsHitTesting(false)
                
            }
        )
        .onHover { hovering in
            withAnimation(Animation.easeIn(duration: 0.15)) {
                self.isHovered = hovering
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



// Picker
//struct PillPicker: View {
//    @Binding var index: Int
//    var onTapAction: () -> Void
//    
//    var body: some View {
//        
//        HStack(alignment: .center, spacing: 20) {
//            ForEach(0..<3) { i in
//                HStack(spacing: 4) {
//                    Image(systemName: i == 0 ? "appclip" : "ellipsis.circle")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 16)
//                        .foregroundColor(index == i ? .black : .gray)
//                    
//                    Text(i == 0 ? "Apps" : (i == 1 ? "Widgets" : "Plugins"))
//                        .font(.system(size: 12))
//                        .foregroundColor(index == i ? .black : .gray)
//                }
//                .padding(8)
//                .background((Color.white).opacity(index == i ? 1 : 0))
//                .clipShape(Capsule())
//                .onTapGesture {
//                    withAnimation {
//                        index = i
//                        onTapAction()
//                    }
//                }
//            }
//        }
//        .background(Color.black.opacity(0.06))
//        .clipShape(Capsule())
//    }
//}

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
                        // Uncomment below for icon next to labels
//                        Image(systemName: i == 0 ? "appclip" : (i == 1 ? "macwindow" : "cube.box.fill"))
//                            .resizable()
//                            .scaledToFit()
//                            .frame(width: 16)
//                            .foregroundColor(index == i ? .black : .gray)
                        
                        Text(i == 0 ? "Apps" : (i == 1 ? "Widgets" : "Plugins"))
                            .font(.system(size: 12))
                            .foregroundColor(index == i ? (colorScheme == .dark ? .black : Color("AccentColor")) : .gray)
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
//        .background(Color.black.opacity(0.06))
        .clipShape(Capsule())
    }
}




        
        
        
        
        
        
//            .frame(height: 50)
        
//        HStack(spacing: 10) {
//            HStack(spacing: 2) {
//                Image(systemName: "appclip")
//                    .foregroundColor(index == 0 ? .black : .gray)
//                Text("Apps")
//                    .font(.footnote)
//                    .foregroundColor(index == 0 ? .black : .gray)
//            }
//            .padding(8)
//            .background((Color.white).opacity(index == 0 ? 1 : 0))
//            .clipShape(Capsule())
//            .onTapGesture {
//                withAnimation {
//                    index = 0
//                    onTapAction()
//                }
//            }
//            
//            HStack(spacing: 2) {
//                Image(systemName: "ellipsis.circle")
//                    .foregroundColor(index == 1 ? .black : .gray)
//                Text("Widgets")
//                    .foregroundColor(index == 1 ? .black : .gray)
//                
//                
//            }
//            .padding(8)
//            .background((Color.white).opacity(index == 1 ? 1 : 0))
//            .clipShape(Capsule())
//            .onTapGesture {
//                withAnimation {
//                    index = 1
//                    onTapAction()
//                }
//            }
//            
//            HStack(spacing: 2) {
//                Image(systemName: "ellipsis.circle")
//                    .foregroundColor(index == 2 ? .black : .gray)
//                Text("Plugins")
//                    .foregroundColor(index == 2 ? .black : .gray)
//                
//                
//            }
//            .padding(8)
//            .background((Color.white).opacity(index == 2 ? 2 : 0))
//            .clipShape(Capsule())
//            .onTapGesture {
//                withAnimation {
//                    index = 2
//                    onTapAction()
//                }
//            }
//        }
//        .background(Color.black.opacity(0.06))
//        .clipShape(Capsule())
//        .frame(height: 50)
