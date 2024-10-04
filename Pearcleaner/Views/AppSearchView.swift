//
//  Searchbar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/26/24.
//

import SwiftUI
import AlinFoundation

struct AppSearchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @EnvironmentObject var updater: Updater
    @EnvironmentObject var permissionManager: PermissionManager
    var glass: Bool
    var menubarEnabled: Bool
    var mini: Bool
    @Binding var search: String
    @Binding var showPopover: Bool
    @State private var showMenu = false
    @Binding var isMenuBar: Bool
    @AppStorage("settings.general.selectedSortAppsList") var selectedSortAlpha: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true


    var body: some View {
        VStack(alignment: .center, spacing: 0) {

            Spacer()
                .frame(height: !isMenuBar ? 30 : 10)


            searchBarComponent
                .padding(.horizontal, search.isEmpty ? 10 : 5)
                .padding(.bottom, 5)

            Divider()

#if DEBUG
            Rectangle()
                .fill(.orange)
                .frame(height: 2)

#endif

            AppsListView(search: $search, showPopover: $showPopover, filteredApps: filteredApps)
                .padding(.vertical, 4)

            if updater.updateAvailable {
                Divider()
                UpdateBadge(updater: updater)
                    .padding(8)
            } else if let _ = permissionManager.results, !permissionManager.allPermissionsGranted {
                Divider()
                PermissionsBadge()
                    .padding(8)
            } else if updater.announcementAvailable {
                Divider()
                FeatureBadge(updater: updater)
                    .padding(8)
            }

        }

    }


    private var searchBarComponent: some View {
        HStack(spacing: 10) {

            if search.isEmpty {
                Button("Refresh") {
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        showPopover = false
                        reloadAppsList(appState: appState, fsm: fsm)
                    }
                }
                .buttonStyle(SimpleButtonStyle(icon: "arrow.counterclockwise.circle", help: "Refresh apps (⌘+R)", size: 16))
            }

            SearchBar(search: $search, darker: (mini || menubarEnabled) ? false : true, glass: glass)


            if search.isEmpty {
                Button("More") {
                    self.showMenu.toggle()
                }
                .buttonStyle(SimpleButtonStyle(icon: "ellipsis.circle", help: "More", size: 16, rotate: true))
                .popover(isPresented: $showMenu) {
                    VStack(alignment: .leading) {

                        Button("") {
                            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                selectedSortAlpha.toggle()
                            }
                        }
                        .buttonStyle(SimpleButtonStyle(icon: "circle.fill", label: "Sorting: \(selectedSortAlpha ? "ABC" : "123")", help: "Can also click on User/System headers to toggle this", size: 5))

                        if mini && !menubarEnabled {
                            Button("") {
                                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                    appState.currentView = .empty
                                    appState.appInfo = AppInfo.empty
                                    showPopover = false
                                }
                            }
                            .buttonStyle(SimpleButtonStyle(icon: "circle.fill", label: "Drop Target", help: "Drop Target", size: 5))
                        }


                        Button("Leftover Files") {
                            showMenu = false
                            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                showPopover = false
                                appState.appInfo = .empty
                                if appState.zombieFile.fileSize.keys.isEmpty {
                                    appState.currentView = .zombie
                                    appState.showProgress.toggle()
                                    showPopover.toggle()
                                    reversePreloader(allApps: appState.sortedApps, appState: appState, locations: locations, fsm: fsm)
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
                                if #available(macOS 13.0, *) {
                                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                                } else {
                                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                                }
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
                    .background(backgroundView(themeManager: themeManager, glass: glass).padding(-80))

                }
            }



        }
    }


    private var filteredApps: [AppInfo] {
        let apps: [AppInfo]
        if search.isEmpty {
            apps = appState.sortedApps
        } else {
            apps = appState.sortedApps.filter { $0.appName.localizedCaseInsensitiveContains(search) }
        }

        switch selectedSortAlpha {
        case true:
            return apps.sorted { $0.appName.replacingOccurrences(of: ".", with: "").lowercased() < $1.appName.replacingOccurrences(of: ".", with: "").lowercased() }
        case false:
            return apps.sorted { $0.bundleSize > $1.bundleSize }
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
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    func _body(configuration: TextField<Self._Label>) -> some View {

        ZStack {
//            RoundedRectangle(cornerRadius: 8)
//                .fill(darker ? themeManager.pickerColor.adjustBrightness(5) : themeManager.pickerColor)
//                .allowsHitTesting(false)
//                .frame(height: 30)
//                .opacity((glass && (sidebar || !mini && !menubarEnabled)) || mini || menubarEnabled ? 0.0 : 1.0)


            ZStack {
                if text.isEmpty {
                    HStack {
                        Spacer()
                        Text(isFocused ? "Type to search" : "Click to search")
                            .font(.subheadline)
                            .foregroundColor(.primary.opacity(0.2))
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
            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
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
            insertionPointColor = NSColor(.primary.opacity(0.2))//.clear
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
