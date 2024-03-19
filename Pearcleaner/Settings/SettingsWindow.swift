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

            InterfaceSettingsTab(showPopover: $showPopover, search: $search)
                .tabItem {
                    Label(CurrentTabView.interface.title, systemImage: "macwindow")
                }
                .tag(CurrentTabView.interface)

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









