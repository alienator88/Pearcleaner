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
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.selectedTab") private var selectedTab: CurrentTabView = .general
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @State private var showPerms = false
    @State private var toolbarRefreshTrigger = false
    @ObservedObject private var helperToolManager = HelperToolManager.shared

    var body: some View {

        HStack(spacing: 0) {
            sidebarView
                .padding(8)
            detailView
                .padding(.top)
        }
        .ignoresSafeArea(edges: .top)
        .background(backgroundView(color: ThemeColors.shared(for: colorScheme).primaryBG))
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onAppear {
            // Force toolbar refresh by toggling state
            DispatchQueue.main.async {
                toolbarRefreshTrigger.toggle()
            }
        }
        .toolbar {
            ToolbarItem { Spacer() }

            // Conditional toolbar items based on selected tab
            ToolbarItemGroup {
                Group {
                    switch selectedTab {
                    case .helper:
                        // Helper tab toolbar items
                        Button {
                            helperToolManager.openSMSettings()
                        } label: {
                            Label("Login Items", systemImage: "gear")
                                .labelStyle(.iconOnly)
                                .help("Login Items")
                        }

                        Button {
                            Task {
                                await helperToolManager.manageHelperTool(action: .uninstall)
                            }
                        } label: {
                            Label("Unregister Service", systemImage: "scissors")
                                .labelStyle(.iconOnly)
                                .help("Unregister Service")
                        }

                        Button {
                            Task {
                                await helperToolManager.manageHelperTool(action: .reinstall)
                            }
                        } label: {
                            Label("Reinstall Service", systemImage: "arrow.clockwise")
                                .labelStyle(.iconOnly)
                                .help("Force Reinstall Service (fixes desync)")
                        }

                    case .about:
                        // About tab toolbar item
                        Button(action: {
                            NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/alienator88")!)
                        }, label: {
                            Label {
                                Text("Sponsor")
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                    .font(.body)
                                    .bold()
                            } icon: {
                                Image(systemName: "heart")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(.pink)
                            }
                            .labelStyle(.titleAndIcon)
                        })

                    default:
                        // No toolbar items for other tabs
                        EmptyView()
                    }
                }
                .id(toolbarRefreshTrigger)
            }
        }
    }


    /// Sidebar view for navigation items
    @ViewBuilder
    private var sidebarView: some View {
        VStack(alignment: .center, spacing: 4) {

            Spacer().frame(height: 35)

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
                    PermissionsSheetView()
                })
            }
            .controlSize(.small)
            .buttonStyle(.plain)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .controlGroup(Capsule(style: .continuous), level: .primary)

        }
        .padding(.bottom)
        .padding(.horizontal)
        .frame(width: 180)
        .ifGlassMain()
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
                InterfaceSettingsTab()
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
                Image(systemName: "exclamationmark.triangle")
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
