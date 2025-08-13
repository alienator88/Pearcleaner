//
//  LeftNavigation.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 8/1/25.
//

import SwiftUI
import AlinFoundation

struct LeftNavigationSidebar: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @State private var hoveredItem: CurrentPage?
    @Binding var isFullscreen: Bool

    private let sidebarWidth: CGFloat = 80

    var body: some View {
        VStack(spacing: 12) {

            Spacer()
                .frame(height: isFullscreen ? 0 : 20)

            ForEach(CurrentPage.allCases, id: \.self) { page in
                NavigationItem(
                    page: page,
                    isSelected: appState.currentPage == page,
                    isHovered: hoveredItem == page
                ) {
                    // Clear appInfo selection on tab switch
                    if appState.currentPage != .applications {
                        updateOnMain{
                            appState.appInfo = .empty
                        }
                    }
                    selectPage(page)
                }
                .onHover { isHovering in
                    withAnimation(.easeInOut(duration: animationEnabled ? 0.2 : 0)) {
                        hoveredItem = isHovering ? page : nil
                    }
                }
            }


            Spacer()

#if DEBUG
            VStack(alignment: .center, spacing: 5) {
                Image(systemName: "ladybug.fill")
                Text(verbatim: "\(Bundle.main.version) (\(Bundle.main.buildVersion))")
                    .font(.footnote)
            }
            .foregroundStyle(.orange)
            .padding(.bottom)
#endif

        }
        .frame(width: sidebarWidth)
        .background(backgroundView(color: ThemeColors.shared(for: colorScheme).secondaryBG, glass: glass))
        .overlay(
            Rectangle()
                .fill(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.1))
                .frame(width: 1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        )
    }

    private func selectPage(_ page: CurrentPage) {
        withAnimation(.easeInOut(duration: animationEnabled ? 0.3 : 0)) {
            appState.currentPage = page

            // Reset view state when changing pages
            if page == .applications {
                appState.currentView = .empty
            }
        }
    }
}

struct NavigationItem: View {
    @Environment(\.colorScheme) var colorScheme
    let page: CurrentPage
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
                .frame(width: 28, height: 28)
                .foregroundStyle(iconColor)

            // Label
            Text(page.title)
                .font(.system(size: 9, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 60)
        }
        .frame(width: 64, height: 56)
        .contentShape(Rectangle())  // Makes entire frame clickable
        .onTapGesture {
            action()
        }
    }

    private var iconColor: Color {
        if isSelected {
            return ThemeColors.shared(for: colorScheme).accent
        } else if isHovered {
            return ThemeColors.shared(for: colorScheme).accent.opacity(0.8)
        } else {
            return ThemeColors.shared(for: colorScheme).accent.opacity(0.6)
        }
    }

    private var textColor: Color {
        if isSelected {
            return ThemeColors.shared(for: colorScheme).primaryText
        } else if isHovered {
            return ThemeColors.shared(for: colorScheme).primaryText.opacity(0.8)
        } else {
            return ThemeColors.shared(for: colorScheme).secondaryText
        }
    }

//    private var backgroundColor: Color {
//        if isSelected {
//            return ThemeColors.shared(for: colorScheme).backgroundPanel.opacity(0.8)
//        } else if isHovered {
//            return ThemeColors.shared(for: colorScheme).backgroundPanel.opacity(0.4)
//        } else {
//            return Color.clear
//        }
//    }
}

struct NavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())  // Ensures full area is clickable
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
