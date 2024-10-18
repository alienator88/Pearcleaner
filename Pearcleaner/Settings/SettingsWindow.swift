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
    @EnvironmentObject var windowSettings: WindowSettings
    @Binding var showPopover: Bool
    @Binding var search: String
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.selectedTab") private var selectedTab: CurrentTabView = .general
    @State private var isResetting = false

    var body: some View {

        NavigationStack {
            HStack(spacing: 0) {
                sidebarView
                detailView
            }
        }
        .navigationTitle(Text(verbatim: ""))
        .frame(width: 750, height: 620)
    }


    /// Sidebar view for navigation items
    @ViewBuilder
    private var sidebarView: some View {
        VStack(alignment: .center, spacing: 4) {
            PearDropViewSmall()
                .padding(.leading, 4)

            Divider()
                .padding(.bottom, 8)
                .padding(.horizontal, 9)

            SidebarItemView(title: CurrentTabView.general.title, systemImage: "gear", isSelected: selectedTab == .general) {
                selectedTab = .general
            }
            SidebarItemView(title: CurrentTabView.interface.title, systemImage: "macwindow", isSelected: selectedTab == .interface) {
                selectedTab = .interface
            }
            SidebarItemView(title: CurrentTabView.folders.title, systemImage: "folder", isSelected: selectedTab == .folders) {
                selectedTab = .folders
            }
            SidebarItemView(title: CurrentTabView.update.title, systemImage: "cloud", isSelected: selectedTab == .update) {
                selectedTab = .update
            }
            // SidebarItemView(title: CurrentTabView.tips.title, systemImage: "star", isSelected: selectedTab == .tips) {
            //     selectedTab = .tips
            // }
            SidebarItemView(title: CurrentTabView.about.title, systemImage: "info.circle", isSelected: selectedTab == .about) {
                selectedTab = .about
            }

            Spacer()

            Text("v\(Bundle.main.version)").foregroundStyle(.secondary)
                .padding(.bottom, 4)

            Button("") {
                resetUserDefaults()
            }
            .buttonStyle(ResetSettingsButtonStyle(isResetting: $isResetting, label: String(localized: "Reset Settings"), help: String(localized: "Reset all settings to default")))
            .disabled(isResetting)


 
        }
        .padding(.bottom)
        .padding(.horizontal, 8)
        .frame(width: 200)
        .background(backgroundView(themeManager: themeManager, darker: true, glass: glass))
    }

    /// Detail view content based on the selected tab
    @ViewBuilder
    private var detailView: some View {
        ScrollView() {
            // The actual detail views wrapped inside the VStack
            switch selectedTab {
            case .general:
                GeneralSettingsTab()
                    .environmentObject(appState)
            case .interface:
                InterfaceSettingsTab(showPopover: $showPopover, search: $search)
                    .environmentObject(themeManager)
                    .environmentObject(windowSettings)
            case .folders:
                FolderSettingsTab()
                    .environmentObject(themeManager)
            case .update:
                UpdateSettingsTab()
                    .environmentObject(updater)
//            case .tips:
//                TipsSettingsTab()
            case .about:
                AboutSettingsTab()
            }
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .offset(y: -22)
        .background(backgroundView(themeManager: themeManager, glass: false))

    }

    private func resetUserDefaults() {
        isResetting = true
        DispatchQueue.global(qos: .background).async {
            UserDefaults.standard.dictionaryRepresentation().keys.forEach(UserDefaults.standard.removeObject(forKey:))
            DispatchQueue.main.async {
                isResetting = false
            }
        }
    }

}


struct SidebarItemView: View {
    var title: String
    var systemImage: String
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(isSelected ? .accentColor : .primary)
                .frame(width: 20, height: 20)
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(isSelected ? .accentColor : .primary)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? .primary.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}







//        NavigationStack {
//            HStack(spacing: 0) {
//                // Custom Sidebar with buttons for each tab
//                List(selection: $selectedTab) {
//                    SidebarItemView(title: CurrentTabView.general.title,
//                                    systemImage: "gear",
//                                    isSelected: selectedTab == .general) {
//                        selectedTab = .general
//                    }
//
//                    SidebarItemView(title: CurrentTabView.interface.title,
//                                    systemImage: "macwindow",
//                                    isSelected: selectedTab == .interface) {
//                        selectedTab = .interface
//                    }
//
//                    SidebarItemView(title: CurrentTabView.folders.title,
//                                    systemImage: "folder",
//                                    isSelected: selectedTab == .folders) {
//                        selectedTab = .folders
//                    }
//
//                    SidebarItemView(title: CurrentTabView.update.title,
//                                    systemImage: "cloud",
//                                    isSelected: selectedTab == .update) {
//                        selectedTab = .update
//                    }
//
//                    SidebarItemView(title: CurrentTabView.tips.title,
//                                    systemImage: "star",
//                                    isSelected: selectedTab == .tips) {
//                        selectedTab = .tips
//                    }
//
//                    SidebarItemView(title: CurrentTabView.about.title,
//                                    systemImage: "info.circle",
//                                    isSelected: selectedTab == .about) {
//                        selectedTab = .about
//                    }
//
//                    Spacer() // Pushes items to the top
//                }
//                .removeSidebarToggle()
//                .frame(width: 200) // Fixed width for sidebar
//                .padding(.top, 20) // Top padding to space out items
//                .background(backgroundView(themeManager: themeManager, glass: true))
//
//                ZStack(alignment: .top) {
//                    // Custom Toolbar View at the top
//                    HStack {
//                        Text(selectedTab.title)
//                            .font(.headline)
//                            .padding(.leading)
//
//                        Spacer()
//
//                        // Add more toolbar buttons as needed
//                        Button(action: {
//                            print("Toolbar Button Tapped")
//                        }) {
//                            Image(systemName: "gearshape")
//                                .padding()
//                        }
//                    }
//                    .frame(height: 40) // Set fixed height for toolbar
//                    .background(backgroundView(themeManager: themeManager, glass: true))
//                    .zIndex(1) // Ensure this is on top
//                    .offset(y: -30)
//
//                    // The actual detail view content
//                    Group {
//                        switch selectedTab {
//                        case .general:
//                            GeneralSettingsTab()
//                        case .interface:
//                            InterfaceSettingsTab(showPopover: $showPopover, search: $search)
//                                .environmentObject(themeManager)
//                        case .folders:
//                            FolderSettingsTab()
//                                .environmentObject(themeManager)
//                        case .update:
//                            UpdateSettingsTab()
//                                .environmentObject(themeManager)
//                        case .tips:
//                            TipsSettingsTab()
//                        case .about:
//                            AboutSettingsTab()
//                        }
//                    }
//                    .padding(.top, 40) // Add padding below the custom toolbar
//                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill remaining space
//                    .background(backgroundView(themeManager: themeManager, glass: false))
//                }
//
//            }
//            .navigationTitle("")
//        }

//        TabView(selection: $selectedTab) {
//            GeneralSettingsTab()
//                .tabItem {
//                    Label(CurrentTabView.general.title, systemImage: "gear")
//                }
//                .tag(CurrentTabView.general)
//
//            InterfaceSettingsTab(showPopover: $showPopover, search: $search)
//                .tabItem {
//                    Label(CurrentTabView.interface.title, systemImage: "macwindow")
//                }
//                .tag(CurrentTabView.interface)
//                .environmentObject(themeManager)
//
//            FolderSettingsTab()
//                .tabItem {
//                    Label(CurrentTabView.folders.title, systemImage: "folder")
//                }
//                .tag(CurrentTabView.folders)
//                .environmentObject(themeManager)
//
//            UpdateSettingsTab()
//                .tabItem {
//                    Label(CurrentTabView.update.title, systemImage: "cloud")
//                }
//                .tag(CurrentTabView.update)
//                .environmentObject(themeManager)
//
//            TipsSettingsTab()
//                .tabItem {
//                    Label(CurrentTabView.tips.title, systemImage: "star")
//                }
//                .tag(CurrentTabView.tips)
//
//            AboutSettingsTab()
//                .tabItem {
//                    Label(CurrentTabView.about.title, systemImage: "info.circle")
//                }
//                .tag(CurrentTabView.about)
//        }
//        .background(backgroundView(themeManager: themeManager, glass: glass))
