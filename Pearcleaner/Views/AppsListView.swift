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
    @Binding var showPopover: Bool
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.selectedSort") var selectedSortAlpha: Bool = true

    var filteredApps: [AppInfo]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let filteredUserApps = filteredApps.filter { !$0.system }
                let filteredSystemApps = filteredApps.filter { $0.system }

                if !filteredUserApps.isEmpty {
                    SectionView(title: "User", count: filteredUserApps.count, apps: filteredUserApps, search: $search, showPopover: $showPopover)
                }


                if !filteredSystemApps.isEmpty {
                    SectionView(title: "System", count: filteredSystemApps.count, apps: filteredSystemApps, search: $search, showPopover: $showPopover)
                }
            }
            .padding(.top, !mini ? 4 : 0)
        }
        .scrollIndicators(.never)
    }
}


struct SectionView: View {
    var title: String
    var count: Int
    var apps: [AppInfo]
    @Binding var search: String
    @Binding var showPopover: Bool
    @State private var showItems: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            Header(title: title, count: count, showPopover: $showPopover)
                .padding(.leading, 5)
                .onTapGesture {
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        showItems.toggle()
                    }
                }
            
            if showItems {
                ForEach(apps, id: \.self) { appInfo in
                    AppListItems(search: $search, showPopover: $showPopover, appInfo: appInfo)
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
    @Binding var showPopover: Bool
    @AppStorage("settings.general.glass") private var glass: Bool = true
//    @AppStorage("settings.general.selectedSortAppsList") var selectedSortAlpha: Bool = true


    var body: some View {
        HStack {
            Text("\(title)").foregroundStyle(.primary).opacity(0.5)

            Text("\(count)")
                .font(.system(size: 10))
                .monospacedDigit()
                .frame(minWidth: count > 99 ? 30 : 24, minHeight: 17)
                .background(.primary.opacity(0.1))
                .clipShape(.capsule)
                .padding(.leading, 2)

            Spacer()

        }
        .frame(minHeight: 20)
        .padding(5)
        .help("Click header to change sorting order")
//        .onTapGesture {
//            selectedSortAlpha.toggle()
//        }
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

