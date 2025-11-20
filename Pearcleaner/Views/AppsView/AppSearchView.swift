//
//  Searchbar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/26/24.
//

import AlinFoundation
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
            if appState.sortedApps.isEmpty {
                VStack {
                    Spacer()
                    Text("No apps found")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .font(.callout)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {

                SearchBarSidebar(search: $search)
                    .padding()
                    .padding(.top, 20)

                if !filteredApps.isEmpty {
                    AppsListView(
                        search: $search, filteredApps: filteredApps, isGridMode: appState.isGridMode
                    )
                    .padding([.bottom, .horizontal], 5)
                } else {
                    VStack {
                        Spacer()
                        Text("No results")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.title2)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }


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
            // Use custom fuzzy search algorithm
            let searchResults = appState.sortedApps.fuzzySearch(query: search)
            apps = searchResults.map { $0.item }
        }

        // Sort based on the selected option
        switch selectedSortOption {
        case .alphabetical:
            return apps.sorted {
                $0.appName.replacingOccurrences(of: ".", with: "").sortKey
                    < $1.appName.replacingOccurrences(of: ".", with: "").sortKey
            }
        case .size:
            return apps.sorted { $0.bundleSize > $1.bundleSize }
        case .creationDate:
            return apps.sorted {
                ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast)
            }
        case .dateAdded:
            return apps.sorted {
                ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast)
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


struct SearchBarSidebar: View {
    @Binding var search: String
    @State var menu: Bool = true
    @State var padding: CGFloat = 5
    @State var sidebar: Bool = true
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            TextField("Search...", text: $search)
                .textFieldStyle(SimpleSearchStyleSidebar(menu: menu, trash: true, text: $search))
        }
    }
}
