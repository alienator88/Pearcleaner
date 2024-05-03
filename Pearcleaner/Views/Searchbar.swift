//
//  Searchbar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/26/24.
//

import SwiftUI

struct Searchbar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeSettings: ThemeSettings
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    var glass: Bool
    var sidebarWidth: Double
    var menubarEnabled: Bool
    var mini: Bool
    @Binding var search: String
    @Binding var showPopover: Bool
    @State private var showMenu = false
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Spacer()
                .frame(height: 10)

            AppsListView(search: $search, showPopover: $showPopover, filteredApps: filteredApps)
                .padding(.top, 25)

            Divider()

            HStack(spacing: 10) {


                SearchBar(search: $search, darker: (mini || menubarEnabled) ? false : true, glass: glass)


                if search.isEmpty {
                    Button("More") {
                        self.showMenu.toggle()
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "ellipsis.circle", help: "More"))
                    .popover(isPresented: $showMenu) {
                        VStack(alignment: .leading) {

                            if mini && !menubarEnabled {
                                Button("") {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        appState.currentView = .empty
                                        appState.appInfo = AppInfo.empty
                                        showPopover = false
                                    }
                                }
                                .buttonStyle(SimpleButtonStyle(icon: "circle.fill", label: "Drop Target", help: "Drop Target", size: 5))
                            }


                            Button("Leftover Files") {
                                showMenu = false
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showPopover = false
                                    appState.appInfo = .empty
                                    if appState.zombieFile.fileSize.keys.isEmpty {
                                        appState.currentView = .zombie
                                        appState.showProgress.toggle()
                                        showPopover.toggle()
                                        reversePreloader(allApps: appState.sortedApps, appState: appState, locations: locations, fsm: fsm, reverseAddon: true)
                                    } else {
                                        appState.currentView = .zombie
                                        showPopover.toggle()
                                    }
                                }
                            }
                            .buttonStyle(SimpleButtonStyle(icon: "circle.fill", label: "Leftover Files", help: "Leftover Files", size: 5))


                            if #available(macOS 14.0, *) {
                                SettingsLink {}
                                    .buttonStyle(SimpleButtonStyle(icon: "circle.fill", label: "Settings", help: "Settings", size: 5))
                            } else {
                                Button("Settings") {
                                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: NSApp.delegate, from: nil)
                                    showMenu = false
                                }
                                .buttonStyle(SimpleButtonStyle(icon: "circle.fill", label: "Settings", help: "Settings", size: 5))
                            }

                            if menubarEnabled {
                                Button("Quit") {
                                    NSApp.terminate(nil)
                                }
                                .buttonStyle(SimpleButtonStyle(icon: "circle.fill", label: "Quit Pearcleaner", help: "Quit Pearcleaner", size: 5))
                            }

                        }
                        .padding()
                        .background(backgroundView(themeSettings: themeSettings, glass: glass).padding(-80))

                    }
                }



            }
            .padding(.horizontal, search.isEmpty ? 10 : 5)
            .padding(.vertical, 5)
        }
    }

    private var filteredApps: [AppInfo] {
        if search.isEmpty {
            return appState.sortedApps
        } else {
            return appState.sortedApps.filter { $0.appName.localizedCaseInsensitiveContains(search) }
        }
    }
}




struct SimpleSearchStyle: TextFieldStyle {
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @State var trash: Bool = false
    @Binding var text: String
    @State var darker: Bool = false
    @State var glass: Bool = false
    @State var padding: CGFloat = 5
    @State var sidebar: Bool = true
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeSettings: ThemeSettings
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false

    func _body(configuration: TextField<Self._Label>) -> some View {

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(darker ? themeSettings.themeColor.darker(by: 5) : themeSettings.themeColor)
                .allowsHitTesting(false)
                .frame(height: 30)
                .opacity((glass && (sidebar || !mini && !menubarEnabled)) || mini || menubarEnabled ? 0.0 : 1.0)


            ZStack {
                if text.isEmpty {
                    HStack {
                        Spacer()
                        Text(isFocused ? "Type to search" : "Click to search")
                            .font(.subheadline)
                            .foregroundColor(Color("mode").opacity(0.2))
                        Spacer()
                    }
                }
                HStack {
                    configuration
                        .font(.title3)
                        .textFieldStyle(PlainTextFieldStyle())

                    Spacer()

                    if trash && text != "" {
                        Button("") {
                            text = ""
                        }
                        .buttonStyle(SimpleButtonStyle(icon: "delete.left.fill", help: "Clear text", size: 14, padding: padding))
                    }
                }

            }
            .padding(.horizontal, 8)

        }
        .onHover { hovering in
            withAnimation(Animation.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
                self.isFocused = true
            }
        }
        .focused($isFocused)
        .onAppear {
            updateOnMain {
                self.isFocused = true
            }
        }
    }
}

// Hide blinking textfield caret
extension NSTextView {
    open override var frame: CGRect {
        didSet {
            insertionPointColor = .clear
        }
    }
}

struct SearchBar: View {
    @Binding var search: String
    @State var darker: Bool = false
    @State var glass: Bool = false
    @State var padding: CGFloat = 5
    @State var sidebar: Bool = true
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            TextField("", text: $search)
                .textFieldStyle(SimpleSearchStyle(trash: true, text: $search, darker: darker, glass: glass, padding: padding, sidebar: sidebar))
        }
    }
}
