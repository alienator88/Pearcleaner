//
//  HomebrewView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import SwiftUI
import AlinFoundation

enum HomebrewViewSection: String, CaseIterable {
    case installed = "Installed"
    case search = "Browse"
    case taps = "Taps"
    case maintenance = "Maintenance"

    var icon: String {
        switch self {
        case .installed:
            return "shippingbox.fill"
        case .search:
            return "magnifyingglass"
        case .taps:
            return "point.3.filled.connected.trianglepath.dotted"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        }
    }
}

struct HomebrewView: View {
    @StateObject private var brewManager = HomebrewManager()
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedSection: HomebrewViewSection = .installed
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Section Picker
            Picker("", selection: $selectedSection) {
                ForEach(HomebrewViewSection.allCases, id: \.self) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 5)

            // Section Content
            Group {
                switch selectedSection {
                case .installed:
                    InstalledPackagesSection()
                case .search:
                    SearchInstallSection()
                case .taps:
                    TapManagementSection()
                case .maintenance:
                    MaintenanceSection()
                }
            }
            .transition(.opacity)
            .animation(animationEnabled ? .easeInOut(duration: 0.2) : .none, value: selectedSection)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environmentObject(brewManager)
        .task {
            await brewManager.refreshAll()
        }
        .toolbar {
            TahoeToolbarItem(placement: .navigation) {
                VStack(alignment: .leading) {
                    Text("Homebrew Manager")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Manage Homebrew packages, taps, and maintenance")
                        .font(.callout)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }

            ToolbarItem { Spacer() }

            TahoeToolbarItem(isGroup: true) {
                Button {
                    Task {
                        await brewManager.refreshAll()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.counterclockwise")
                }
                .help("Refresh all data")
            }
        }
    }
}
