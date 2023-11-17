//
//  NewWin.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/16/23.
//


import AppKit
import SwiftUI

class NewWin: NSWindowController {
    
    static var shared = NewWin()
    
    static func show(appState: AppState, width: CGFloat, height: CGFloat, newWin: NewWindow) {
        shared = NewWin(appState: appState, width: width, height: height, newWin: newWin)
        shared.window?.makeKeyAndOrderFront(nil)
    }
    
    static func close() {
        shared.window?.close()
    }
    
    convenience init(appState: AppState, width: CGFloat, height: CGFloat, newWin: NewWindow) {
        
        let window = Self.makeWindow(width: width, height: height)
        
        window.backgroundColor = NSColor.controlBackgroundColor
        
        self.init(window: window)
        
        // Using Visual Effect to make titlebar fully transparent
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .underWindowBackground
        
        let contentView = makeNewView(appState: appState, newWin: newWin)
        
        let hostView = NSHostingView(rootView: contentView)
        
        window.contentView = visualEffect
        
        visualEffect.addSubview(hostView)
        hostView.frame = visualEffect.frame
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.center()
        window.title = "Support Admin"
        
    }
    
    private static func makeWindow(width: CGFloat, height: CGFloat) -> NSWindow {
        let contentRect = NSRect(x: 0, y: 0, width: width, height: height)
        let styleMask: NSWindow.StyleMask = [
            .titled,
            .fullSizeContentView,
            //            .closable,
        ]
        return NSWindow(contentRect: contentRect,
                        styleMask: styleMask,
                        backing: .buffered,
                        defer: false)
    }
    
    private func makeNewView(appState: AppState, newWin: NewWindow) -> some View {
        switch newWin {
        case .update:
            return AnyView(UpdateView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(appState))
        case .no_update:
            return AnyView(NoUpdateView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(appState))
        case .perm:
            return AnyView(PermView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(appState))
            //        case .restart:
            //            return AnyView(RestartView()
            //                .frame(maxWidth: .infinity, maxHeight: .infinity)
            //                .environmentObject(appState))
        }
    }
}


