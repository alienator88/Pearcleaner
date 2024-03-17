//
//  SettingsWindow.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPopover: Bool
    @Binding var search: String
    @Binding var showFeature: Bool
    @AppStorage("settings.general.glass") private var glass: Bool = true

    var body: some View {
        
        TabView() {
            GeneralSettingsTab(showPopover: $showPopover, search: $search)
                .tabItem {
                    Label(CurrentTabView.general.title, systemImage: "gear")
                }
                .tag(CurrentTabView.general)

            MenuBarSettingsTab(showPopover: $showPopover, search: $search)
                .tabItem {
                    Label(CurrentTabView.menubar.title, systemImage: "menubar.rectangle")
                }
                .tag(CurrentTabView.menubar)

            UpdateSettingsTab(showFeature: $showFeature)
                .tabItem {
                    Label(CurrentTabView.update.title, systemImage: "cloud")
                }
                .tag(CurrentTabView.update)

            AboutSettingsTab()
                .tabItem {
                    Label(CurrentTabView.about.title, systemImage: "info.circle")
                }
                .tag(CurrentTabView.about)

        }
        .background(glass ? GlassEffect(material: .sidebar, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all) : nil)


    }
    
}









