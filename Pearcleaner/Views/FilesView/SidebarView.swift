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
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
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
                .frame(width: 350)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
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
    let displaySizeTotal: String

    var body: some View {
        VStack(spacing: 0) {

            headerMain()

            headerDetailRow(label: "Version", value: appState.appInfo.appVersion)
            headerDetailRow(label: "Bundle", value: appState.appInfo.bundleIdentifier)
            headerDetailRow(label: "Total size of all files", value: displaySizeTotal)
        }

    }

    @ViewBuilder
    private func headerMain() -> some View {
        VStack {
            if let appIcon = appState.appInfo.appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .padding(5)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(appState.appInfo.appIcon?.averageColor ?? .clear))
                    }
            }

            Text(appState.appInfo.appName)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(2)
                .padding(.bottom)
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func headerDetailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 5)
    }
}


struct AppDetails: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {

            //MARK: Badges
            HStack(alignment: .center, spacing: 10) {
                Spacer()
                if appState.appInfo.webApp {
                    Text("web")
                        .font(.footnote)
                        .foregroundStyle(.primary.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.primary.opacity(0.1))
                        .clipShape(Capsule())
                }

                if appState.appInfo.wrapped {
                    Text("iOS")
                        .font(.footnote)
                        .foregroundStyle(.primary.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.primary.opacity(0.1))
                        .clipShape(Capsule())
                }

                if appState.appInfo.arch != .empty {
                    Text(appState.appInfo.arch.type)
                        .font(.footnote)
                        .foregroundStyle(.primary.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.primary.opacity(0.1))
                        .clipShape(Capsule())
                }

                Text(appState.appInfo.system ? "system" : "user")
                    .font(.footnote)
                    .foregroundStyle(.primary.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.primary.opacity(0.1))
                    .clipShape(Capsule())

                if appState.appInfo.cask != nil {
                    Text("homebrew")
                        .font(.footnote)
                        .foregroundStyle(.primary.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.primary.opacity(0.1))
                        .clipShape(Capsule())
                }

                Spacer()
            }

            detailRow(label: "Location", value: appState.appInfo.path.deletingLastPathComponent().path)
            detailRow(label: "Installed Date", value: appState.appInfo.creationDate.map { formattedMDDate(from: $0) })
            detailRow(label: "Modified Date", value: appState.appInfo.contentChangeDate.map { formattedMDDate(from: $0) })
            detailRow(label: "Last Used Date", value: appState.appInfo.lastUsedDate.map { formattedMDDate(from: $0) })
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String?) -> some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value ?? "Not available")
        }
        .padding(.bottom, 5)
    }
}



struct ExtraOptions: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack() {
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
