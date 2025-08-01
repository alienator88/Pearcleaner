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

    private let sidebarWidth: CGFloat = 80

    var body: some View {
        VStack(spacing: 12) {

            Spacer()
                .frame(height: 20)

            ForEach(CurrentPage.allCases, id: \.self) { page in
                NavigationItem(
                    page: page,
                    isSelected: appState.currentPage == page,
                    isHovered: hoveredItem == page
                ) {
                    selectPage(page)
                }
                .onHover { isHovering in
                    withAnimation(.easeInOut(duration: animationEnabled ? 0.2 : 0)) {
                        hoveredItem = isHovering ? page : nil
                    }
                }
            }

            Spacer()

        }
        .frame(width: sidebarWidth)
        .background(backgroundView(color: theme(for: colorScheme).backgroundMain, glass: glass))
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.1))
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
        Button(action: action) {
            VStack(spacing: 6) {

                // Icon
                Image(systemName: page.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
                    .frame(width: 28, height: 28)
                    .foregroundColor(iconColor)

                // Label
                Text(page.title)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 60)

            }
            .frame(width: 64, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var iconColor: Color {
        if isSelected {
            return theme(for: colorScheme).iconFolder
        } else if isHovered {
            return theme(for: colorScheme).iconFolder.opacity(0.8)
        } else {
            return theme(for: colorScheme).iconFolder.opacity(0.6)
        }
    }

    private var textColor: Color {
        if isSelected {
            return theme(for: colorScheme).textPrimary
        } else if isHovered {
            return theme(for: colorScheme).textPrimary.opacity(0.8)
        } else {
            return theme(for: colorScheme).textPrimary.opacity(0.6)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return theme(for: colorScheme).backgroundPanel.opacity(0.8)
        } else if isHovered {
            return theme(for: colorScheme).backgroundPanel.opacity(0.4)
        } else {
            return Color.clear
        }
    }
}
