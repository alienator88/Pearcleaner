//
//  SettingsWindow.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import SwiftUI
import AlinFoundation

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fsm: FolderSettingsManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var updater: Updater
    @Binding var showPopover: Bool
    @Binding var search: String
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.selectedTab") private var selectedTab: CurrentTabView = .general

    var body: some View {
        
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(showPopover: $showPopover, search: $search)
                .tabItem {
                    Label(CurrentTabView.general.title, systemImage: "gear")
                }
                .tag(CurrentTabView.general)

            InterfaceSettingsTab(showPopover: $showPopover, search: $search)
                .tabItem {
                    Label(CurrentTabView.interface.title, systemImage: "macwindow")
                }
                .tag(CurrentTabView.interface)

            FolderSettingsTab()
                .tabItem {
                    Label(CurrentTabView.folders.title, systemImage: "folder")
                }
                .tag(CurrentTabView.folders)

            UpdateSettingsTab()
                .tabItem {
                    Label(CurrentTabView.update.title, systemImage: "cloud")
                }
                .tag(CurrentTabView.update)
                .environmentObject(themeManager)

            TipsSettingsTab()
                .tabItem {
                    Label(CurrentTabView.tips.title, systemImage: "star")
                }
                .tag(CurrentTabView.tips)

            AboutSettingsTab()
                .tabItem {
                    Label(CurrentTabView.about.title, systemImage: "info.circle")
                }
                .tag(CurrentTabView.about)
        }
        .background(backgroundView(themeManager: themeManager, glass: glass))

    }

}









