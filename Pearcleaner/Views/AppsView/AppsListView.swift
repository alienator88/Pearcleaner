//
//  AppsListView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/4/24.
//

import Foundation
import SwiftUI

struct AppsListView: View {
    @Binding var search: String
    @AppStorage("settings.general.selectedSort") var selectedSortAlpha: Bool = true
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    var filteredApps: [AppInfo]
    var isGridMode: Bool

    var body: some View {
        ScrollView {
            if isGridMode {
                LazyVStack(alignment: .leading, spacing: 10) {
                    let filteredUserApps = filteredApps.filter { !$0.system }
                    let filteredSystemApps = filteredApps.filter { $0.system }

                    let maxColumns = 5 // Maximum columns allowed
                    let maxItemsInSection = max(filteredUserApps.count, filteredSystemApps.count)
                    let optimalColumns = min(maxColumns, max(1, maxItemsInSection))

                    if !filteredUserApps.isEmpty {
                        GridSectionView(
                            title: String(localized: "User"), count: filteredUserApps.count,
                            apps: filteredUserApps, search: $search,
                            maxColumns: min(optimalColumns, filteredUserApps.count))
                    }

                    if !filteredSystemApps.isEmpty {
                        GridSectionView(
                            title: String(localized: "System"), count: filteredSystemApps.count,
                            apps: filteredSystemApps, search: $search,
                            maxColumns: min(optimalColumns, filteredSystemApps.count))
                    }
                }
                .padding(.horizontal, 5)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    let filteredUserApps = filteredApps.filter { !$0.system }
                    let filteredSystemApps = filteredApps.filter { $0.system }

                    if !filteredUserApps.isEmpty {
                        SectionView(
                            title: String(localized: "User"), count: filteredUserApps.count,
                            apps: filteredUserApps, search: $search)
                    }

                    if !filteredSystemApps.isEmpty {
                        SectionView(
                            title: String(localized: "System"), count: filteredSystemApps.count,
                            apps: filteredSystemApps, search: $search
                        )
                        .padding(.top, 5)
                    }
                }
            }
        }
        .scrollIndicators(scrollIndicators ? .automatic : .never)
    }
}

struct SectionView: View {
    var title: String
    var count: Int
    var apps: [AppInfo]
    @Binding var search: String
    @State private var showItems: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            Header(title: title, count: count)
                .padding(.leading, 5)
                .onTapGesture {
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        showItems.toggle()
                    }
                }

            if showItems {
                ForEach(apps, id: \.self) { appInfo in
                    AppListItems(search: $search, appInfo: appInfo)
                        .transition(.opacity)
                }
            }

        }
    }
}

struct Header: View {
    let title: String
    let count: Int
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.glass") private var glass: Bool = true

    var body: some View {
        HStack {
            Text(verbatim: "\(title)").foregroundStyle(
                ThemeColors.shared(for: colorScheme).primaryText
            ).opacity(0.5)

            Text(verbatim: "\(count)")
                .font(.system(size: 10))
                .monospacedDigit()
                .frame(minWidth: count > 99 ? 30 : 24, minHeight: 17)
                .background(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.1))
                .clipShape(.capsule)
                .padding(.leading, 2)

            Spacer()

        }
        .background(.black.opacity(0.0000000001))
        .frame(minHeight: 20)
        .padding([.horizontal, .bottom], 5)
        //        .help("Click header to change sorting order")
        //        .onTapGesture {
        //            selectedSortAlpha.toggle()
        //        }
    }
}

struct GridSectionView: View {
    var title: String
    var count: Int
    var apps: [AppInfo]
    @Binding var search: String
    var maxColumns: Int
    @State private var showItems: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        VStack(spacing: 5) {
            Header(title: title, count: count)
                .padding(.leading, 5)
                .onTapGesture {
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        showItems.toggle()
                    }
                }

            if showItems {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 120, maximum: 120), spacing: 5)
                    ], spacing: 5
                ) {
                    ForEach(apps, id: \.self) { appInfo in
                        GridAppItem(search: $search, appInfo: appInfo)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: CGFloat(maxColumns * 120 + (maxColumns - 1) * 5 + 10))
            }
        }
    }
}

//List {
//    Section {
//        ForEach(filteredUserApps, id:\.self) { element in
//            Text(element.appName)
//        }
//        .listRowBackground(Color.clear)
//    } header: {
//        Text("User Apps")
//    }
//
//    Section {
//        ForEach(filteredSystemApps, id:\.self) { element in
//            Text(element.appName)
//        }
//        .listRowBackground(Color.clear)
//    } header: {
//        Text("System Apps")
//    }
//
//}
//.scrollContentBackground(.hidden)
//.background(.clear)
//.scrollIndicators(.never)
