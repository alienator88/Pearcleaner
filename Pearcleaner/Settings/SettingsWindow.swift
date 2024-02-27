//
//  SettingsWindow.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/31/23.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        
        TabView() {
            GeneralSettingsTab()
                .tabItem {
                    Label(CurrentTabView.general.title, systemImage: "gear")
                }
                .tag(CurrentTabView.general)
            
            PermissionsSettingsTab()
                .tabItem {
                    Label(CurrentTabView.permissions.title, systemImage: "lock")
                }
                .tag(CurrentTabView.permissions)
            
            SentinelSettingsTab()
                .tabItem {
                    Label(CurrentTabView.sentinel.title, systemImage: "eye.circle")
                }
                .tag(CurrentTabView.sentinel)
            
            UpdateSettingsTab()
                .tabItem {
                    Label(CurrentTabView.update.title, systemImage: "tray.and.arrow.down")
                }
                .tag(CurrentTabView.update)
            
            AboutSettingsTab()
                .tabItem {
                    Label(CurrentTabView.about.title, systemImage: "info.circle")
                }
                .tag(CurrentTabView.about)
             
        }
        
    }
    
}







