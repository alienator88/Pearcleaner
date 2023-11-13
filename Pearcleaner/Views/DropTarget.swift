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
    @ObservedObject var appState: AppState
    @State private var shouldFlash = false
    private var types: [UTType] = [.fileURL]
    @Environment(\.colorScheme) var colorScheme
    @State private var phase: CGFloat = 0
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    var body: some View {
        ZStack {
            
            FlashingBackground(shouldFlash: $shouldFlash)
            
            HStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [.pink, .orange]), startPoint: .leading, endPoint: .trailing)
                            .mask(Image("logo")
                                .resizable()
                                .scaledToFit())
                    }
                    .frame(width: 500, height: 200)
                    
                    Spacer()
                    
                    
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(LinearGradient(gradient: Gradient(colors: [.pink, .orange]), startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3, dash: [10], dashPhase: phase))
                    .onAppear {
                        withAnimation(.linear.speed(0.5).repeat(while: ants, autoreverses: false)) {
                            if ants {
                                phase -= 20
                            }
                        }
                    }
                    .onChange(of: ants) { newValue in
                        withAnimation(.linear.speed(0.5).repeat(while: newValue, autoreverses: false)) {
                            phase -= 20
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            }
            
            
        }
        .onDrop(of: types, delegate: self)
        .padding(20)
        
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
                        appState.currentView = .files
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
