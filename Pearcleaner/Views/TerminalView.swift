//
//  TerminalView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 2/12/25.
//

import SwiftUI
import SwiftTerm
import AlinFoundation

struct TerminalSheetView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @Binding var showPopover: Bool
    let title: String
    let command: String

    init(showPopover: Binding<Bool>, title: String = "Terminal", command: String) {
        self._showPopover = showPopover
        self.title = title
        self.command = command
    }

    var body: some View {
        VStack(spacing: 0) {

            Text(title)
                .font(.title2)
                .padding()

            Divider()

            TerminalWrapper(command: command)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()

            Divider()

            Button("Close") {

                if mini || menubarEnabled {
                    appState.currentView = .apps
                    self.showPopover = false
                } else {
                    appState.currentView = .empty
                }
                appState.appInfo = AppInfo.empty

            }
            .buttonStyle(SimpleButtonStyle(icon: "x.circle", iconFlip: "x.circle.fill", help: String(localized: "Close")))
            .padding(5)
        }
        .ignoresSafeArea(.all)
        .background(Color.black)
    }
}


struct TerminalWrapper: NSViewRepresentable {
    let command: String
    @State private var terminalDelegate = TerminalDelegate() // Retain delegate

    func makeNSView(context: Context) -> NoScrollTerminalView {
        let terminalView = NoScrollTerminalView(frame: .zero)
        terminalView.processDelegate = terminalDelegate

        let shell = getShell()
        let shellIdiom = "-" + (shell as NSString).lastPathComponent

        terminalView.startProcess(executable: shell, execName: shellIdiom)

        // Run the given command after shell initializes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            terminalView.send(txt: "clear;\(self.command)\n")
        }

        return terminalView
    }

    func updateNSView(_ nsView: NoScrollTerminalView, context: Context) {}
}


class TerminalDelegate: NSObject, LocalProcessTerminalViewDelegate {
    func sizeChanged(source: SwiftTerm.LocalProcessTerminalView, newCols: Int, newRows: Int) {

    }
    
    func setTerminalTitle(source: SwiftTerm.LocalProcessTerminalView, title: String) {

    }
    
    func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {

    }
    
    func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
        print("Process terminated with code: \(exitCode ?? -1)")
    }

}


class NoScrollTerminalView: LocalProcessTerminalView {
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        // Remove any NSScroller subviews
        DispatchQueue.main.async {
            for subview in self.subviews {
                if subview is NSScroller {
                    subview.removeFromSuperview()
                }
            }
        }

        // Set Nerd Font if available
        self.font = getNerdFont()
    }
}

func getShell () -> String
{
    let bufsize = sysconf(_SC_GETPW_R_SIZE_MAX)
    guard bufsize != -1 else {
        return "/bin/bash"
    }
    let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufsize)
    defer {
        buffer.deallocate()
    }
    var pwd = passwd()
    var result: UnsafeMutablePointer<passwd>? = UnsafeMutablePointer<passwd>.allocate(capacity: 1)

    if getpwuid_r(getuid(), &pwd, buffer, bufsize, &result) != 0 {
        return "/bin/bash"
    }
    return String (cString: pwd.pw_shell)
}

func getNerdFont() -> NSFont {
    let preferredNerdFonts = [
        "Hack Nerd Font", "FiraCode Nerd Font", "JetBrainsMono Nerd Font",
        "SourceCodePro Nerd Font", "MesloLGS NF", "Cascadia Code PL"
    ]

    for fontName in preferredNerdFonts {
        if let font = NSFont(name: fontName, size: 14) {
            return font
        }
    }

    // Fallback to system monospaced font if no Nerd Font is found
    return NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
}
