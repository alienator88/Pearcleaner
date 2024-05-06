//
//  WindowSettings.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 12/26/23.
//

import SwiftUI

class WindowSettings {
    private let windowWidthKey = "windowWidthKey"
    private let windowHeightKey = "windowHeightKey"
    private let windowWidthKeyMini = "windowWidthKeyMini"
    private let windowHeightKeyMini = "windowHeightKeyMini"
    private let windowXKey = "windowXKey"
    private let windowYKey = "windowYKey"
    @AppStorage("settings.general.mini") private var mini: Bool = false
    var windows: [NSWindow] = []

    func registerDefaultWindowSettings(completion: @escaping () -> Void = {}) {

        let defaults = UserDefaults.standard

        // Get primary screen
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        // Calculate default window sizes and x/y coordinates
        let defaultWidth = Float(900)  // Default width for regular window
        let defaultHeight = Float(600) // Default height for regular window
        let defaultWidthMini = Float(300) // Default width for mini window
        let defaultHeightMini = Float(370)  // Default height for mini window
        let defaultX = Float((screenFrame.width - CGFloat(defaultWidth)) / 2 + screenFrame.origin.x) // Default X coordinate
        let defaultY = Float((screenFrame.height - CGFloat(defaultHeight)) / 2 + screenFrame.origin.y) // Default Y coordinate

        // Set defaults only if they are not already set
        if defaults.object(forKey: windowWidthKey) == nil {
            defaults.set(defaultWidth, forKey: windowWidthKey)
        }
        if defaults.object(forKey: windowHeightKey) == nil {
            defaults.set(defaultHeight, forKey: windowHeightKey)
        }
        if defaults.object(forKey: windowWidthKeyMini) == nil {
            defaults.set(defaultWidthMini, forKey: windowWidthKeyMini)
        }
        if defaults.object(forKey: windowHeightKeyMini) == nil {
            defaults.set(defaultHeightMini, forKey: windowHeightKeyMini)
        }
        if defaults.object(forKey: windowXKey) == nil {
            defaults.set(defaultX, forKey: windowXKey)
        }
        if defaults.object(forKey: windowYKey) == nil {
            defaults.set(defaultY, forKey: windowYKey)
        }

        completion()

    }

    // Save user window settings
    func saveWindowSettings(frame: NSRect) {
        UserDefaults.standard.set(Float(frame.size.width), forKey: mini ? windowWidthKeyMini : windowWidthKey)
        UserDefaults.standard.set(Float(frame.size.height), forKey: mini ? windowHeightKeyMini : windowHeightKey)
        UserDefaults.standard.set(Float(frame.origin.x), forKey: windowXKey)
        UserDefaults.standard.set(Float(frame.origin.y), forKey: windowYKey)
    }

    // Load default window settings or user defined settings
    func loadWindowSettings() -> NSRect {
        let width = CGFloat(UserDefaults.standard.float(forKey: mini ? windowWidthKeyMini : windowWidthKey))
        let height = CGFloat(UserDefaults.standard.float(forKey: mini ? windowHeightKeyMini : windowHeightKey))
        let x = CGFloat(UserDefaults.standard.float(forKey: windowXKey))
        let y = CGFloat(UserDefaults.standard.float(forKey: windowYKey))

        return NSRect(x: x, y: y, width: width, height: height)
    }

    // Launch new app windows on demand
    func newWindow<V: View>(withView view: @escaping () -> V, completion: @escaping () -> Void = {}) {
        findAndHideWindows(named: ["Pearcleaner"])
        let contentView = view
        let frame = self.loadWindowSettings()
        let newWindow = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        newWindow.titlebarAppearsTransparent = true
        newWindow.isMovableByWindowBackground = true
        newWindow.center()
        newWindow.title = "Pearcleaner"
        newWindow.isRestorable = false
        newWindow.titleVisibility = .hidden
        newWindow.setFrameAutosaveName("Pearcleaner")
        newWindow.contentView = NSHostingView(rootView: contentView())
        self.windows.append(newWindow)
        newWindow.makeKeyAndOrderFront(nil)
        completion()
    }
}



//struct WillRestore: ViewModifier {
//    let restore: Bool
//
//    func body(content: Content) -> some View {
//        content
//            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification), perform: { output in
//                let window = output.object as! NSWindow
//                window.isRestorable = false
//            })
//    }
//}
//
//extension View {
//    func willRestore(_ restoreState: Bool = true) -> some View {
//        modifier(WillRestore(restore: restoreState))
//    }
//}
