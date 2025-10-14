//
//  Searchbar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/26/24.
//

import AlinFoundation
import Ifrit
import SwiftUI

struct AppSearchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @EnvironmentObject var updater: Updater
    @EnvironmentObject var permissionManager: PermissionManager
    @Environment(\.colorScheme) var colorScheme
    @State private var search: String = ""
    @AppStorage("settings.general.selectedSortAppsList") var selectedSortOption: SortOption =
        .alphabetical
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.multiSelect") private var multiSelect: Bool = false
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 265
    @State private var dimensionStart: Double?

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

                SearchBarSidebar(search: $search)
                    .padding()
                    .padding(.top, 20)

                AppsListView(
                    search: $search, filteredApps: filteredApps, isGridMode: appState.isGridMode
                )
                .padding([.bottom, .horizontal], 5)

            }
        }
        .onAppear {
            // Initialize grid mode based on current sidebar width
            appState.isGridMode = sidebarWidth > 316
        }
        .onChange(of: sidebarWidth) { newWidth in
            // Update grid mode when sidebar width changes programmatically
            let newGridMode = newWidth > 316
            if newGridMode != appState.isGridMode {
                withAnimation(.easeInOut(duration: animationEnabled ? 0.3 : 0)) {
                    appState.isGridMode = newGridMode
                }
            }
        }

        .overlay(alignment: .trailing) {
            // Invisible resize handle on the trailing edge
            Rectangle()
                .fill(Color.clear)
                .frame(width: 10)
                .contentShape(Rectangle())
                .offset(x: 5)  // Center on the edge
                .onHover { inside in
                    if inside {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .contextMenu {
                    Button("Reset Size") {
                        sidebarWidth = 265
                        appState.isGridMode = false
                    }
                }
                .gesture(sidebarDragGesture)
                .help("Right click to reset size")
        }

    }

    private var sidebarDragGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { val in
                if dimensionStart == nil {
                    dimensionStart = sidebarWidth
                }
                let delta = val.location.x - val.startLocation.x
                let newDimension = dimensionStart! + Double(delta)

                // Calculate dynamic max width based on available items
                let filteredUserApps = filteredApps.filter { !$0.system }
                let filteredSystemApps = filteredApps.filter { $0.system }
                let maxItemsInSection = max(filteredUserApps.count, filteredSystemApps.count)
                let optimalColumns = min(5, max(1, maxItemsInSection))

                // Calculate ideal width for optimal columns (item width + spacing + padding)
                let idealMaxWidth = Double(optimalColumns * 120 + (optimalColumns - 1) * 5 + 50)

                // Extended range with dynamic max, but always allow grid mode at 316+
                let minWidth: Double = 240
                let maxWidth: Double = max(400, min(640, idealMaxWidth)) // Always allow at least 400px for grid mode
                let newWidth = max(minWidth, min(maxWidth, newDimension))

                sidebarWidth = newWidth

                // Toggle grid mode at 316px threshold (around 3 columns)
                let newGridMode = newWidth > 316
                if newGridMode != appState.isGridMode {
                    withAnimation(.easeInOut(duration: animationEnabled ? 0.3 : 0)) {
                        appState.isGridMode = newGridMode
                    }
                }

                NSCursor.closedHand.set()
            }
            .onEnded { val in
                dimensionStart = nil
                NSCursor.arrow.set()
            }
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
                return result?.score ?? 1.0 < 0.4  // Adjust threshold as needed (lower = stricter)
            }
        }

        // Sort based on the selected option
        switch selectedSortOption {
        case .alphabetical:
            return apps.sorted {
                $0.appName.replacingOccurrences(of: ".", with: "").lowercased()
                    < $1.appName.replacingOccurrences(of: ".", with: "").lowercased()
            }
        case .size:
            return apps.sorted { $0.bundleSize > $1.bundleSize }
        case .creationDate:
            return apps.sorted {
                ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast)
            }
        case .contentChangeDate:
            return apps.sorted {
                ($0.contentChangeDate ?? Date.distantPast)
                    > ($1.contentChangeDate ?? Date.distantPast)
            }
        case .lastUsedDate:
            return apps.sorted {
                ($0.lastUsedDate ?? Date.distantPast) > ($1.lastUsedDate ?? Date.distantPast)
            }
        }

    }

}

struct SimpleSearchStyle: TextFieldStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @State var trash: Bool = false
    @Binding var text: String
    @State var glass: Bool = false
    @State var padding: CGFloat = 5
    @EnvironmentObject var appState: AppState
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    func _body(configuration: TextField<Self._Label>) -> some View {

        ZStack {

            ZStack {
                if text.isEmpty {
                    HStack {
                        Spacer()
                        Text(
                            isFocused
                                ? String(localized: "Type to search")
                                : String(localized: "Hover to search")
                        )
                        .font(.subheadline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
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
                        } label: {
                            EmptyView()
                        }
                        .buttonStyle(
                            SimpleButtonStyle(
                                icon: "delete.left.fill", help: String(localized: "Clear text"),
                                size: 16, padding: 0))
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

struct SimpleSearchStyleSidebar: TextFieldStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @State var trash: Bool = false
    @Binding var text: String
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fsm: FolderSettingsManager
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.general.selectedSortAppsList") var selectedSortOption: SortOption =
        .alphabetical
    @AppStorage("settings.interface.multiSelect") private var multiSelect: Bool = false
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 265

    func _body(configuration: TextField<Self._Label>) -> some View {

        HStack {
            configuration
                .font(.title3)
                .textFieldStyle(PlainTextFieldStyle())

            Spacer()

            if trash && text != "" {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "delete.left.fill")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }

            Menu {
                Section(header: Text("Sorting")) {
                    ForEach(SortOption.allCases) { option in
                        Button {
                            withAnimation(
                                Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)
                            ) {
                                selectedSortOption = option
                            }
                        } label: {
                            HStack {
                                Image(
                                    systemName: selectedSortOption == option
                                        ? "circle.inset.filled" : "circle")
                                Text(option.title)
                            }
                        }
                    }
                }

                Section(header: Text("Layout")) {
                    Button(action: {
                        withAnimation(.spring(duration: animationEnabled ? 0.3 : 0)) {
                            sidebarWidth = 265
                        }
                    }) {
                        HStack {
                            Image(systemName: sidebarWidth < 316 ? "circle.inset.filled" : "circle")
                            Text("List View")
                        }

                    }

                    Button(action: {
                        withAnimation(.spring(duration: animationEnabled ? 0.3 : 0)) {
                            sidebarWidth = 375
                        }
                    }) {
                        HStack {
                            Image(systemName: sidebarWidth > 316 ? "circle.inset.filled" : "circle")
                            Text("Grid View")
                        }

                    }
                }

                Section(header: Text("Options")) {
                    Button("Refresh List") {
                        // Use loadAndUpdateApps with forceRefresh to bypass cache
                        Task { @MainActor in
                            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                AppCachePlist.loadAndUpdateApps(folderPaths: fsm.folderPaths, forceRefresh: true)
                            }
                        }
                    }

                    Button(multiSelect ? "Hide multi-select" : "Show multi-select") {
                        withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                            multiSelect.toggle()
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .padding(2)
                    .contentShape(Rectangle())
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .menuIndicator(.hidden)
            .frame(width: 16)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .controlGroup(Capsule(style: .continuous), level: .primary)
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
            insertionPointColor = NSColor(.primary.opacity(0.2))  //.clear
        }
    }
}

struct SearchBarSidebar: View {
    @Binding var search: String
    @State var padding: CGFloat = 5
    @State var sidebar: Bool = true
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            TextField("Search...", text: $search)
                .textFieldStyle(SimpleSearchStyleSidebar(trash: true, text: $search))
        }
    }
}
