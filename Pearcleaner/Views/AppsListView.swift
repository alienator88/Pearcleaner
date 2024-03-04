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
    var filteredUserApps: [AppInfo]
    var filteredSystemApps: [AppInfo]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if filteredUserApps.count > 0 {
                    SectionView(title: "User", count: filteredUserApps.count, apps: filteredUserApps, search: $search, showPopover: $showPopover)
                }

                if filteredSystemApps.count > 0 {
                    SectionView(title: "System", count: filteredSystemApps.count, apps: filteredSystemApps, search: $search, showPopover: $showPopover)
                }
            }
            .padding(.horizontal)
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
            ForEach(apps, id: \.self) { appInfo in
                AppListItems(search: $search, showPopover: $showPopover, appInfo: appInfo)
                    .padding(.vertical, 5)
                if appInfo != apps.last {
                    Divider().padding(.horizontal, 5)
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

