//
//  DropTarget.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/11/23.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct DropTarget: View, DropDelegate {
    @AppStorage("settings.general.ants") private var ants: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @ObservedObject var appState: AppState
    @State private var shouldFlash = false
    private var types: [UTType] = [.fileURL]
    @Environment(\.colorScheme) var colorScheme
    @State private var phase: CGFloat = 4
    @Binding var showPopover: Bool

    public init(appState: AppState, showPopover: Binding<Bool>) {
        self.appState = appState
        _showPopover = showPopover
    }
    
    var body: some View {
        ZStack {
            
            FlashingBackground(shouldFlash: $shouldFlash)
            
            HStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    ZStack {
//                        Color("mode")
//                            .mask(
//                                Image(mini ? "pear" : "logo")
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(minWidth: mini ? 104 : 300)
//                                    .frame(maxWidth: mini ? 104 : 500)
//                                    .padding(mini ? 20 : 10)
//                            )
                        LinearGradient(gradient: Gradient(colors: [.pink, .orange]), startPoint: .leading, endPoint: .trailing)
                            .mask(
                                Image(mini ? "pear" : "logo")
                                .resizable()
                                .scaledToFit()
                                .frame(minWidth: mini ? 104 : 300)
                                .frame(maxWidth: mini ? 104 : 500)
                                .padding(mini ? 20 : 10)
                            )
                    }
                    
                    Spacer()
                    
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8)
//                    .fill(LinearGradient(gradient: Gradient(colors: [.pink, .orange]), startPoint: .leading, endPoint: .trailing))
                    .strokeBorder(LinearGradient(gradient: Gradient(colors: [.pink, .orange]), startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3, dash: [11.0], dashPhase: phase))
                    .onAppear {
                        withAnimation(.linear.speed(0.5).repeat(while: ants, autoreverses: false)) {
                            if ants {
                                phase -= 22
                            }
                        }
                    }
                    .onChange(of: ants) { newValue in
                        withAnimation(.linear.speed(0.5).repeat(while: newValue, autoreverses: false)) {
                            phase -= 22
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            }
            
            
        }
        .onDrop(of: types, delegate: self)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.5)) {
                appState.currentView = .apps
            }
        }
        .padding(20)
        .frame(maxWidth: mini ? 200 : .infinity)
        .frame(maxHeight: mini ? 200 : .infinity)
        
    }
    
    func dropEntered(info: DropInfo) {
        DispatchQueue.main.async {
            self.ants = true
        }
    }
    
    func dropExited(info: DropInfo) {
        DispatchQueue.main.async {
            self.ants = false
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        
        let itemProviders = info.itemProviders(for: [UTType.fileURL])
        
        guard itemProviders.count == 1 else {
            return false
        }
        for itemProvider in itemProviders {
            itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data else {
                    dump(error)
                    return
                }
                guard let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    print("Error: Not a valid URL.")
                    return
                }
                if url.pathExtension == "app" {
                    let appInfo = getAppInfo(atPath: url)
                    
                    DispatchQueue.main.async {
                        self.ants = false
                        appState.appInfo = appInfo!
                        findPathsForApp(appState: appState, appInfo: appState.appInfo)
                        if mini {
                            showPopover = true
                        } else {
                            appState.currentView = .files
                        }
                    }
                } else {
                    print("Error: Dropped file is not an application bundle")
                    DispatchQueue.main.async {
                        self.shouldFlash = true
                    }
                }
                
            }
        }
        DispatchQueue.main.async {
            self.ants = false
        }
        return true
    }
    
    
}


struct FlashingBackground: View {
    @Binding var shouldFlash: Bool
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(shouldFlash ? Color.red : Color.clear)
                .cornerRadius(8)
                .padding()
                .opacity(shouldFlash ? 0.5 : 0)
                .animation(.easeInOut(duration: 0.2).repeatCount(1, autoreverses: true), value: shouldFlash)
                .onChange(of: shouldFlash) { newValue in
                    if newValue {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            shouldFlash = false
                        }
                    }
                }
                .ignoresSafeArea()
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}



extension Animation {
    func `repeat`(while expression: Bool, autoreverses: Bool = true) -> Animation {
        if expression {
            return self.repeatForever(autoreverses: autoreverses)
        } else {
            return self
        }
    }
}
