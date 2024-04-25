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

    var filteredApps: [AppInfo]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                let filteredUserApps = filteredApps.filter { !$0.system }
                let filteredSystemApps = filteredApps.filter { $0.system }

                if !filteredUserApps.isEmpty {
                    SectionView(title: "User", count: filteredUserApps.count, apps: filteredUserApps, search: $search, showPopover: $showPopover)
                }


                if !filteredSystemApps.isEmpty {
                    SectionView(title: "System", count: filteredSystemApps.count, apps: filteredSystemApps, search: $search, showPopover: $showPopover)
                }
            }
//            .padding(.horizontal)
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

    var body: some View {
        VStack(spacing: 0) {
            Header(title: title, count: count, showPopover: $showPopover)
                .padding(.leading, 5)
            ForEach(apps, id: \.self) { appInfo in
                AppListItems(search: $search, showPopover: $showPopover, appInfo: appInfo)
                if appInfo != apps.last {
//                    Divider().padding(.horizontal, 5)
                }
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

