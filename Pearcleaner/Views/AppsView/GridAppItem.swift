//
//  GridAppItem.swift
//  Pearcleaner
//
//  Created for grid layout mode
//

import AlinFoundation
import Foundation
import SwiftUI

struct GridAppItem: View {
    @EnvironmentObject var appState: AppState
    @Binding var search: String
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.multiSelect") private var multiSelect: Bool = false
    @EnvironmentObject var locations: Locations
    let itemId = UUID()
    let appInfo: AppInfo
    var isSelected: Bool { appState.appInfo.path == appInfo.path }
    @State private var hoveredItemPath: URL? = nil
    @Namespace var appItemNamespace

    var body: some View {
        VStack(spacing: 8) {

            if multiSelect {
                HStack {
                    Button {
                        let isChecked = self.appState.externalPaths.contains(self.appInfo.path)

                        if !isChecked {
                            if !self.appState.externalPaths.contains(self.appInfo.path) {
                                let wasEmpty = self.appState.externalPaths.isEmpty
                                self.appState.externalPaths.append(self.appInfo.path)

                                if wasEmpty && appState.currentView != .files {
                                    appState.multiMode = true
                                    showAppInFiles(
                                        appInfo: appInfo, appState: appState,
                                        locations: locations)
                                }
                            }
                        } else {
                            self.appState.externalPaths.removeAll {
                                $0 == self.appInfo.path
                            }

                            if self.appState.externalPaths.isEmpty {
                                appState.multiMode = false
                            }
                        }
                    } label: {
                        EmptyView()
                    }
                    .buttonStyle(CircleCheckboxButtonStyle(isSelected: self.appState.externalPaths.contains(self.appInfo.path)))

                    Spacer()
                }
            }

            Button(action: {
                if !isSelected {
                    updateOnMain {
                        appState.appInfo = .empty
                        appState.selectedItems = []
                        appState.currentView = .empty
                    }
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        showAppInFiles(appInfo: appInfo, appState: appState, locations: locations)
                    }
                } else {
                    // Closing the same item
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        updateOnMain {
                            appState.appInfo = .empty
                            appState.selectedItems = []
                            appState.currentView = .empty
                        }
                    }
                }
            }) {
                VStack(spacing: 6) {

                    // App Icon
                    if let appIcon = appInfo.appIcon {
                        ZStack {
                            Image(nsImage: appIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .matchedGeometryEffect(
                                    id: "icon-\(appInfo.path.path)", in: appItemNamespace)
                        }
                    }

                    // App Name
                    Text(appInfo.appName)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    // Size info
                    Text(
                        appInfo.bundleSize == 0 ? "..." : formatByte(size: appInfo.bundleSize).human
                    )
                    .font(.system(size: 9))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.6))
                    .lineLimit(1)
                    .frame(minWidth: 50, alignment: .center)
                }
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onHover { hovering in
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.20 : 0)) {
                    self.isHovered = hovering
                    self.hoveredItemPath = isHovered ? appInfo.path : nil
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected && !glass ? ThemeColors.shared(for: colorScheme).secondaryBG : .clear
                )
        }
        .overlay {
            if isSelected && isHovered {
                // Dimmed background with centered X when selected and hovered
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ThemeColors.shared(for: colorScheme).primaryBG.opacity(0.8))

                    ZStack {
                        Circle()
                            .fill(ThemeColors.shared(for: colorScheme).secondaryBG.opacity(0.9))
                            .frame(width: 32, height: 32)

                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    }
                }
                .allowsHitTesting(false)
            } else if isSelected {
                // Just selected, no hover - show subtle selection indicator
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(ThemeColors.shared(for: colorScheme).accent, lineWidth: 2)
                    .allowsHitTesting(false)
            } else if isHovered {
                // Just hovered, not selected
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        ThemeColors.shared(for: colorScheme).primaryText.opacity(0.3), lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            if appInfo.bundleSize == 0 {
                appState.getBundleSize(for: appInfo) { size in
                    //                    printOS("Getting size for: \(appInfo.appName)")
                    //                    appInfo.bundleSize = size
                }
            }
        }
    }
}
