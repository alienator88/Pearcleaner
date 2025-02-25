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
    @EnvironmentObject var locations: Locations
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    var showPopover: Binding<Bool>?
    let command: String?
    let homebrew: Bool

    init(showPopover: Binding<Bool>? = nil, command: String? = nil, homebrew: Bool = false, caskName: String? = nil) {
        self.showPopover = showPopover
        self.command = homebrew ? getBrewCleanupCommand(for: caskName ?? "") : command
        self.homebrew = homebrew
    }

    var body: some View {
        VStack(spacing: 0) {

            Text(homebrew ? "Homebrew Cleanup: \(appState.appInfo.appName)" : "Terminal")
                .font(.title2)
                .padding()

            Divider()

            if let command = command {
                TerminalWrapper(command: command)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                Text("No command provided")
                    .foregroundColor(.gray)
                    .padding()
            }

            Divider()

            Button("Close") {

                // Handle close logic based on the presence of showPopover
                if let showPopover = showPopover {
                    // If popover is present
                    if mini || menubarEnabled {
                        appState.currentView = .apps
                        showPopover.wrappedValue = false
                    } else {
                        appState.currentView = .empty
                    }
                } else {
                    // No popover, so just clear the current view and app info
                    appState.currentView = .empty
                }
                
                appState.appInfo = AppInfo.empty

                // Check if there are more paths to process
                if !appState.externalPaths.isEmpty {
                    // Get the next path
                    if let nextPath = appState.externalPaths.first {
                        // Load the next app's info
                        if let nextApp = AppInfoFetcher.getAppInfo(atPath: nextPath) {
                            updateOnMain {
                                appState.appInfo = nextApp
                            }
                            showAppInFiles(appInfo: nextApp, appState: appState, locations: locations, showPopover: showPopover ?? .constant(false))
                        }
                    }
                }

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
            terminalView.send(txt: "clear;echo 'Please wait..';\(self.command)\n")
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
