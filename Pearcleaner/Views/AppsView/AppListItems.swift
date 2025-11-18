//
//  AppListDetails.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/10/23.
//

import AlinFoundation
import Foundation
import SwiftUI

struct AppListItems: View {
    @EnvironmentObject var appState: AppState
    @Binding var search: String
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.minimalist") private var minimalEnabled: Bool = true
    @AppStorage("settings.interface.multiSelect") private var multiSelect: Bool = false
    @EnvironmentObject var locations: Locations
    let itemId = UUID()
    let appInfo: AppInfo
    var isSelected: Bool { appState.appInfo.path == appInfo.path }
    @State private var hoveredItemPath: URL? = nil
    @Namespace var appItemNamespace

    var body: some View {

        HStack {

            if multiSelect {
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
                        self.appState.externalPaths.removeAll { $0 == self.appInfo.path }

                        if self.appState.externalPaths.isEmpty {
                            appState.multiMode = false
                        }
                    }
                } label: {
                    EmptyView()
                }
                .buttonStyle(CircleCheckboxButtonStyle(isSelected: self.appState.externalPaths.contains(self.appInfo.path)))
                .padding(.leading)
            }

            Button(action: {
                if !isSelected {
                    showAppInFiles(appInfo: appInfo, appState: appState, locations: locations)
                } else {
                    // Closing the same item
                    updateOnMain {
                        appState.appInfo = .empty
                        appState.selectedItems = []
                        appState.currentView = .empty
                    }
                }

            }) {
                VStack {

                    HStack(alignment: .center) {

                        if let appIcon = appInfo.appIcon {
                            ZStack {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .matchedGeometryEffect(
                                        id: "icon-\(appInfo.path.path)", in: appItemNamespace)
                            }

                        }

                        if minimalEnabled {
                            Text(appInfo.appName)
                                .font(.system(size: (isSelected) ? 14 : 12))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            VStack(alignment: .center, spacing: 2) {
                                HStack {
                                    Text(appInfo.appName)
                                        .font(.system(size: (isSelected) ? 14 : 12))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Spacer()
                                }

                                HStack(spacing: 5) {
                                    Text(verbatim: "v\(appInfo.appVersion)")
                                        .font(.footnote)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .opacity(0.5)
                                    Text(verbatim: "•").font(.footnote).opacity(0.5)

                                    Text(
                                        appInfo.bundleSize == 0
                                            ? String(localized: "calculating")
                                            : "\(formatByte(size: appInfo.bundleSize).human)"
                                    )
                                    .font(.footnote)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .opacity(0.5)
                                    .frame(minWidth: 60, alignment: .leading)
                                    Spacer()
                                }

                            }
                        }

                        if minimalEnabled {
                            Spacer()
                        }

                        if minimalEnabled && !isSelected {
                            Text(
                                appInfo.bundleSize == 0
                                    ? ""
                                    : formatByte(size: appInfo.bundleSize).human
                            )
                            .font(.system(size: 10))
                            .foregroundStyle(
                                ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
                            .frame(minWidth: 60, alignment: .trailing)
                        }
                    }

                }
                .frame(height: 35)
                .padding(.trailing)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            .padding(.leading, multiSelect ? 0 : 10)
            .onHover { hovering in
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.20 : 0)) {
                    self.isHovered = hovering
                    self.hoveredItemPath = isHovered ? appInfo.path : nil
                }
            }

        }
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected && !glass ? ThemeColors.shared(for: colorScheme).secondaryBG : .clear
                )
        }
        .overlay {
            if isHovered || isSelected {
                HStack {
                    Spacer()
                    ZStack {
                        // Morphing shape that animates between rectangle and square
                        RoundedRectangle(cornerRadius: isSelected ? 6 : 50)
                            .fill(
                                isSelected
                                    ? ThemeColors.shared(for: colorScheme).accent
                                    : ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5)
                            )
                            .frame(width: isSelected ? 20 : 2, height: isSelected ? 20 : 25)

                        if isSelected {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .opacity(isSelected ? 1 : 0)
                        }
                    }
                    //                    .animation(animationEnabled ? .spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0) : .linear(duration: 0), value: isSelected)
                    .padding(.trailing, 7)
                }
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
