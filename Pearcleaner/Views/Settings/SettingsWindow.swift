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
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var updater: Updater
    @Binding var search: String
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.selectedTab") private var selectedTab: CurrentTabView = .general
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @State private var showPerms = false

    var body: some View {

        NavigationStack {
            HStack(spacing: 0) {
                sidebarView
                Divider().edgesIgnoringSafeArea(.top)
                detailView
            }
        }
        .navigationTitle(Text(verbatim: ""))
        .frame(width: 800, height: 720)
    }


    /// Sidebar view for navigation items
    @ViewBuilder
    private var sidebarView: some View {
        VStack(alignment: .center, spacing: 4) {

            Spacer().frame(height: 10)

            VStack(alignment: .leading, spacing: 0) {
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
                SidebarItemView(title: CurrentTabView.helper.title, systemImage: "key", isSelected: selectedTab == .helper) {
                    selectedTab = .helper
                }
                SidebarItemView(title: CurrentTabView.about.title, systemImage: "info.circle", isSelected: selectedTab == .about) {
                    selectedTab = .about
                }
            }



            Spacer()

            HStack {
                Button() {
                    updateOnMain {
                        selectedTab = .about
                    }
                } label: {
                    Text(verbatim: "v\(Bundle.main.version)".uppercased())
                        .font(.footnote)
                }

                Divider().frame(height: 10)

                Button() {
                    showPerms.toggle()
                } label: {
                    Text(String(localized: "Permissions").uppercased())
                        .font(.footnote)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                .sheet(isPresented: $showPerms, content: {
                    PermissionsListView()
                })
            }
            .controlSize(.small)
            .buttonStyle(.plain)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .controlGroup(Capsule(style: .continuous), level: .secondary)

        }
        .padding(.bottom)
        .padding(.horizontal)
        .frame(width: 180)
        .background(.ultraThickMaterial)
        .background {
            MetalView()
                .frame(width: 180)
                .ignoresSafeArea(.all)
        }
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
                InterfaceSettingsTab(search: $search)
            case .folders:
                FolderSettingsTab()
            case .update:
                UpdateSettingsTab()
                    .environmentObject(updater)
            case .helper:
                HelperSettingsTab()
            case .about:
                AboutSettingsTab()
            }
        }
        .scrollIndicators(scrollIndicators ? .automatic : .never)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .offset(y: -22)
        .background(backgroundView(color: ThemeColors.shared(for: colorScheme).primaryBG))

    }

}


struct SidebarItemView: View {
    @Environment(\.colorScheme) var colorScheme
    var title: String
    var systemImage: String
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                .frame(width: 20, height: 20)
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(isSelected ? ThemeColors.shared(for: colorScheme).primaryText : ThemeColors.shared(for: colorScheme).secondaryText)
            if !HelperToolManager.shared.isHelperToolInstalled && title.lowercased().contains("helper") {
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.orange)
                    .frame(width: 14, height: 14)
                    .help("Please install the helper service")
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? ThemeColors.shared(for: colorScheme).primaryText.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
