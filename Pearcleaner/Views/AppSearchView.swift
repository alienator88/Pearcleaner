//
//  Searchbar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/26/24.
//

import SwiftUI
import AlinFoundation
import Ifrit

struct AppSearchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @EnvironmentObject var updater: Updater
    @EnvironmentObject var permissionManager: PermissionManager
    @Environment(\.colorScheme) var colorScheme
    var glass: Bool
    @Binding var search: String
    @State private var showMenu = false
    @AppStorage("settings.general.selectedSortAppsList") var selectedSortOption: SortOption = .alphabetical
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        
        VStack(alignment: .center, spacing: 0) {
            if appState.reload || appState.sortedApps.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {

                searchBarComponent
                    .padding(8)

                Divider()
                    .padding(.horizontal, 8)

                AppsListView(search: $search, filteredApps: filteredApps)
                    .padding(.vertical, 4)

                if updater.updateAvailable {
                    Divider()
                    UpdateBadge(updater: updater)
                        .padding()
                } else if updater.announcementAvailable {
                    Divider()
                    FeatureBadge(updater: updater)
                        .padding()
                } else if let _ = permissionManager.results, !permissionManager.allPermissionsGranted {
                    Divider()
                    PermissionsBadge()
                        .padding()
                } else if HelperToolManager.shared.shouldShowHelperBadge {
                    Divider()
                    HelperBadge()
                        .padding()
                }
            }


        }
        .padding(.top, 22)
#if DEBUG
        .overlay {
            VStack {
                HStack {
                    Text(verbatim: "DEBUG").foregroundStyle(.orange)
                        .help(Text(verbatim: "VERSION: \(Bundle.main.version) | BUILD: \(Bundle.main.buildVersion)"))
//                        .padding(.leading, 72)
//                        .padding(.top, 2)
                    Spacer()
                }

                Spacer()
            }
        }
#endif

        .padding(6)
        .padding(.top, 1)




    }


    private var searchBarComponent: some View {
        HStack(spacing: 10) {

            if search.isEmpty {
                Button("Refresh") {
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        reloadAppsList(appState: appState, fsm: fsm)
                    }
                }
                .buttonStyle(SimpleButtonStyle(icon: "arrow.counterclockwise.circle", help: String(localized: "Refresh apps (⌘+R)"), size: 16))
            }


            SearchBar(search: $search, darker: true, glass: glass, sidebar: false)


            if search.isEmpty {
                Button {
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        showMenu.toggle()
                    }
                } label: { EmptyView() }
                    .buttonStyle(SimpleButtonStyle(icon: "line.3.horizontal.decrease.circle", help: selectedSortOption.title, size: 16))
                    .popover(isPresented: $showMenu, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Spacer()
                                Text("Sorting Options").font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                            }
                            Divider()
                            ForEach(SortOption.allCases) { option in
                                Button {
                                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                        selectedSortOption = option
                                        showMenu = false
                                    }
                                } label: { EmptyView() }
                                    .buttonStyle(SimpleButtonStyle(icon: selectedSortOption == option ? "circle.inset.filled" : "circle", label: option.title, help: "", size: 5))
                            }
                        }
                        .padding()
                        .background(backgroundView(color: theme(for: colorScheme).backgroundMain, glass: glass).padding(-80))
                    }

            }

        }
        .frame(minHeight: 30)

    }


    private var filteredApps: [AppInfo] {
        let apps: [AppInfo]
        if search.isEmpty {
            apps = appState.sortedApps
        } else {
            let fuse = Fuse()
            apps = appState.sortedApps.filter { app in
                if app.appName.localizedCaseInsensitiveContains(search) {
                    return true
                }
                let result = fuse.searchSync(search, in: app.appName)
                return result?.score ?? 1.0 < 0.4 // Adjust threshold as needed (lower = stricter)
            }
        }

        // Sort based on the selected option
        switch selectedSortOption {
        case .alphabetical:
            return apps.sorted {
                $0.appName.replacingOccurrences(of: ".", with: "").lowercased() < $1.appName.replacingOccurrences(of: ".", with: "").lowercased()
            }
        case .size:
            return apps.sorted { $0.bundleSize > $1.bundleSize }
        case .creationDate:
            return apps.sorted { ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast) }
        case .contentChangeDate:
            return apps.sorted { ($0.contentChangeDate ?? Date.distantPast) > ($1.contentChangeDate ?? Date.distantPast) }
        case .lastUsedDate:
            return apps.sorted { ($0.lastUsedDate ?? Date.distantPast) > ($1.lastUsedDate ?? Date.distantPast) }
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
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    func _body(configuration: TextField<Self._Label>) -> some View {

        ZStack {

            ZStack {
                if text.isEmpty {
                    HStack {
                        Spacer()
                        Text(isFocused ? String(localized: "Type to search") : String(localized: "Hover to search"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                HStack {
                    configuration
                        .font(.title3)
                        .textFieldStyle(PlainTextFieldStyle())

                    Spacer()

                    if trash && text != "" {
                        Button {
                            text = ""
                        } label: { EmptyView() }
                        .buttonStyle(SimpleButtonStyle(icon: "delete.left.fill", help: String(localized: "Clear text"), size: 16, padding: 0))
                    }
                }

            }
            .padding(.horizontal, 5)

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
            TextField(text: $search) { EmptyView() }
                .textFieldStyle(SimpleSearchStyle(trash: true, text: $search, darker: darker, glass: glass, padding: padding, sidebar: sidebar))
        }
    }
}
