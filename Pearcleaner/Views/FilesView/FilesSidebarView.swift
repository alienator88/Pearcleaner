//
//  SidebarView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 7/31/25.
//

import Foundation
import SwiftUI
import AlinFoundation

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Binding var infoSidebar: Bool
    let displaySizeTotal: String

    var body: some View {
        if infoSidebar {
            HStack {
                Spacer()

                VStack(spacing: 10) {
                    AppDetailsHeaderView(displaySizeTotal: displaySizeTotal)
                    Divider().padding(.vertical, 5)
                    AppDetails()
                    Spacer()
                    ExtraOptions()
                }
                .padding()
                .frame(width: 250)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.2), lineWidth: 1)
                }
            }
            .background(.black.opacity(0.00000000001))
            .transition(.move(edge: .trailing))
            .onTapGesture {
                infoSidebar = false
            }
        }
    }
}

struct AppDetailsHeaderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    let displaySizeTotal: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            headerMain()

            headerDetailRow(label: "Version", value: appState.appInfo.appVersion)
            headerDetailRow(label: "Bundle", value: appState.appInfo.bundleIdentifier)
            headerDetailRow(label: "Total size of all files", value: displaySizeTotal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func headerMain() -> some View {
        VStack(alignment: .center) {
            if let appIcon = appState.appInfo.appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .shadow(color: appState.appInfo.averageColor ?? .black, radius: 6)
            }

            Text(appState.appInfo.appName)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(2)
                .padding(4)
                .padding(.horizontal, 2)
//                .background {
//                    RoundedRectangle(cornerRadius: 8)
//                        .fill(appState.appInfo.averageColor ?? .clear)
//                }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func headerDetailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            Text(value)
        }
        .padding(.bottom, 5)
    }
}


struct AppDetails: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            //MARK: Badges
            HStack(alignment: .center, spacing: 5) {

                if appState.appInfo.webApp { badge("web") }
                if appState.appInfo.wrapped { badge("iOS") }
                if appState.appInfo.arch != .empty { badge(appState.appInfo.arch.type) }
                badge(appState.appInfo.system ? "system" : "user")
                if appState.appInfo.cask != nil { badge("brew") }
                if appState.appInfo.steam { badge("steam") }

            }
            .padding(.bottom, 8)

            detailRow(label: "Location", value: appState.appInfo.path.deletingLastPathComponent().path, location: true)
            detailRow(label: "Install Date", value: appState.appInfo.creationDate.map { formattedMDDate(from: $0) })
            detailRow(label: "Modified Date", value: appState.appInfo.contentChangeDate.map { formattedMDDate(from: $0) })
            detailRow(label: "Last Used Date".localized(), value: appState.appInfo.lastUsedDate.map { formattedMDDate(from: $0) })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.1))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func detailRow(label: String, value: String?, location: Bool = false) -> some View {
        VStack(alignment: .leading) {
            HStack(spacing: 2) {
                Text(label.localized())
                if location {
                    Button {
                        NSWorkspace.shared.selectFile(appState.appInfo.path.path, inFileViewerRootedAtPath: appState.appInfo.path.deletingLastPathComponent().path)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                }

            }
            .font(.subheadline)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

            Text(value ?? "Metadata not available")
        }
        .padding(.bottom, 5)
    }
}



struct ExtraOptions: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack() {
            Text("Click to dismiss").font(.caption).foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
            Spacer()
            Menu {
                if appState.appInfo.arch == .universal {
                    Button("Lipo Architectures") {
                        let title = NSLocalizedString("App Lipo", comment: "Lipo alert title")
                        let message = String(format: NSLocalizedString("Pearcleaner will strip the %@ architecture from %@'s executable file to save space. Would you like to proceed?", comment: "Lipo alert message"), isOSArm() ? "intel" : "arm64", appState.appInfo.appName)
                        showCustomAlert(title: title, message: message, style: .informational, onOk: {
                            let _ = thinAppBundleArchitecture(at: appState.appInfo.path, of: appState.appInfo.arch)
                        })
                    }
                }
                Button("Prune Translations") {
                    let title = NSLocalizedString("Prune Translations", comment: "Prune alert title")
                    let message = String(format: NSLocalizedString("This will remove all unused language translation files", comment: "Prune alert message"))
                    showCustomAlert(title: title, message: message, style: .warning, onOk: {
                        do {
                            try pruneLanguages(in: appState.appInfo.path.path)
                        } catch {
                            printOS("Translation prune error: \(error)")
                        }
                    })
                }
            } label: {
                Label("Options", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
