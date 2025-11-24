//
//  Interface.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/18/24.
//


import Foundation
import SwiftUI
import ServiceManagement
import AlinFoundation

struct InterfaceSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var updater: Updater
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var fsm: FolderSettingsManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.glassEffect") private var glassEffect: String = "Regular"
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.minimalist") private var minimalEnabled: Bool = true
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.interface.multiSelect") private var multiSelect: Bool = false
    @AppStorage("settings.interface.greetingEnabled") private var greetingEnabled: Bool = true
    @AppStorage("settings.interface.badgeOverlaysEnabled") private var badgeOverlaysEnabled: Bool = true
    @AppStorage("settings.interface.startupView") private var startupView: Int = CurrentPage.applications.rawValue
    @State private var showPagePopover: Bool = false
    @State private var hiddenPages: Set<Int> = AppState.loadHiddenPages()

    var body: some View {

        VStack(spacing: 20) {

            // === Appearance =================================================================================================
            PearGroupBox(header: { Text("Appearance").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2) },
                         content: {
                VStack {

                    if #unavailable(macOS 26.0) {
                        HStack(spacing: 0) {
                            Image(systemName: glass ? "cube.transparent" : "cube.transparent.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Transparent sidebar")
                                    .font(.callout)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            }
                            Spacer()
                            Toggle(isOn: $glass, label: {
                            })
                            .toggleStyle(SettingsToggle())
                        }
                        .padding(5)
                    } else {
                        HStack(spacing: 0) {
                            Image(systemName: "cube.transparent")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Glass Effect")
                                    .font(.callout)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            }
                            Spacer()
                            Picker(selection: $glassEffect) {
                                Text("Regular")
                                    .tag("Regular")
                                Text("Clear")
                                    .tag("Clear")
                            } label: { EmptyView() }
                                .buttonStyle(.borderless)
                        }
                        .padding(5)
                    }




                    HStack(spacing: 0) {
                        Image(systemName: animationEnabled ? "play" : "play.slash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(animationEnabled ? String(localized: "Transition animations enabled") : String(localized: "Transition animations disabled"))
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        Spacer()
                        Toggle(isOn: $animationEnabled, label: {
                        })
                        .toggleStyle(SettingsToggle())
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: scrollIndicators ? "computermouse.fill" : "computermouse")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(scrollIndicators ? String(localized: "Scrollbar is set to OS preference in lists") : String(localized: "Scrollbar is hidden in lists"))
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        Spacer()
                        Toggle(isOn: $scrollIndicators, label: {
                        })
                        .toggleStyle(SettingsToggle())
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: minimalEnabled ? "list.dash.header.rectangle" : "list.bullet.rectangle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(minimalEnabled ? String(localized: "Simple app list enabled") : String(localized: "Simple app list disabled"))
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        Spacer()
                        Toggle(isOn: $minimalEnabled, label: {
                        })
                        .toggleStyle(SettingsToggle())
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: multiSelect ? "checkmark.square.fill" : "square")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(multiSelect ? String(localized: "Multi-select enabled in sidebar app list") : String(localized: "Multi-select disabled in sidebar app list"))
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        Spacer()
                        Toggle(isOn: $multiSelect, label: {
                        })
                        .toggleStyle(SettingsToggle())
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: greetingEnabled ? "hand.raised.fill" : "hand.raised")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(greetingEnabled ? String(localized: "Greeting enabled on main page") : String(localized: "Greeting disabled on main page"))
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        Spacer()
                        Toggle(isOn: $greetingEnabled, label: {
                        })
                        .toggleStyle(SettingsToggle())
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: badgeOverlaysEnabled ? "bell.badge.fill" : "bell.badge")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(badgeOverlaysEnabled ? String(localized: "Badge notification overlays enabled") : String(localized: "Badge notification overlays disabled"))
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        Spacer()
                        Toggle(isOn: $badgeOverlaysEnabled, label: {
                        })
                        .toggleStyle(SettingsToggle())
                    }
                    .padding(5)


                    HStack(spacing: 0) {
                        Image(systemName: "arrow.uturn.forward")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        Text("Startup view & page visibility")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        Spacer()
                        Button(action: {
                            showPagePopover.toggle()
                        }) {
                            HStack(spacing: 6) {
                                if let currentPage = CurrentPage(rawValue: startupView) {
                                    Image(systemName: currentPage.icon)
                                    Text(currentPage.title)
                                }
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        }
                        .buttonStyle(.borderless)
                        .popover(isPresented: $showPagePopover, arrowEdge: .trailing) {
                            PageVisibilityPopover(
                                startupView: $startupView,
                                hiddenPages: $hiddenPages,
                                colorScheme: colorScheme
                            )
                        }
                    }
                    .padding(5)

                }
            })

            PearGroupBox(header: { Text("Theme").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2) }, content: {
                ThemeCustomizationView()
            })
        }

    }

}

// MARK: - Page Visibility Popover

struct PageVisibilityPopover: View {
    @Binding var startupView: Int
    @Binding var hiddenPages: Set<Int>
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(CurrentPage.allCases, id: \.rawValue) { page in
                let isHidden = hiddenPages.contains(page.rawValue)
                let isStartupPage = startupView == page.rawValue

                HStack(spacing: 12) {
                    // Radio button and label - clickable together
                    Button(action: {
                        // If trying to set a hidden page as startup, unhide it first
                        if isHidden {
                            hiddenPages.remove(page.rawValue)
                            AppState.saveHiddenPages(hiddenPages)
                        }
                        startupView = page.rawValue
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isStartupPage ? "circle.fill" : "circle")
                                .foregroundStyle(isStartupPage ? ThemeColors.shared(for: colorScheme).accent : ThemeColors.shared(for: colorScheme).secondaryText)

                            Image(systemName: page.icon)
                                .frame(width: 16)
                            Text(page.title)
                                .font(.body)
                        }
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Set as startup page")

                    Spacer()

                    // Eye toggle button
                    Button(action: {
                        if isHidden {
                            hiddenPages.remove(page.rawValue)
                        } else {
                            // If trying to hide current startup page, default to .applications
                            if isStartupPage {
                                startupView = CurrentPage.applications.rawValue
                            }
                            hiddenPages.insert(page.rawValue)
                        }
                        AppState.saveHiddenPages(hiddenPages)
                    }) {
                        Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(isHidden ? ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.5) : ThemeColors.shared(for: colorScheme).accent)
                    }
                    .buttonStyle(.plain)
                    .help(isHidden ? "Show page" : "Hide page")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .opacity(isHidden ? 0.5 : 1.0)
            }
        }
        .frame(width: 200)
        .padding(.vertical, 8)
    }
}

