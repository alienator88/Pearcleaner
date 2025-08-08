//
//  AppListH.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI
import AlinFoundation
import FinderSync

struct MainWindow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 265
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @Binding var search: String
    @State private var showSys: Bool = true
    @State private var showUsr: Bool = true
    @State private var showMenu = false

    var body: some View {

        // Main App Window
        ZStack() {

            HStack(alignment: .center, spacing: 0) {
                LeftNavigationSidebar()
                    .zIndex(1)

                switch appState.currentPage {
                case .applications:
                    HStack(alignment: .center, spacing: 0) {

                        // App List
                        AppSearchView(glass: glass, search: $search)
                            .frame(width: sidebarWidth)
                            .transition(.opacity)

                        SlideableDivider(dimension: $sidebarWidth)
                            .zIndex(3)

                        // Details View
                        HStack(spacing: 0) {
                            Group {
                                switch appState.currentView {
                                case .empty:
                                    MountedVolumeView()
//                                    AppDetailsEmptyView()
                                case .files:
                                    FilesView(search: $search)
                                        .id(appState.appInfo.id)
                                case .zombie:
                                    ZombieView(search: $search)
                                        .id(appState.appInfo.id)
                                case .terminal:
                                    TerminalSheetView(homebrew: true, caskName: appState.appInfo.cask)
                                        .id(appState.appInfo.id)
                                }
                            }
                            .transition(.opacity)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .zIndex(2)
                    }

                case .orphans:
                    ZombieView(search: $search)
                        .onAppear {
                            if appState.zombieFile.fileSize.keys.isEmpty {
                                appState.showProgress.toggle()
                            }
                            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                if appState.zombieFile.fileSize.keys.isEmpty {
                                    reversePreloader(allApps: appState.sortedApps, appState: appState, locations: locations, fsm: fsm)
                                }
                            }
                        }

                case .development:
                    EnvironmentCleanerView()

                case .lipo:
                    LipoView()
                }
            }
        }
        .background(backgroundView(color: theme(for: colorScheme).backgroundMain))
        .frame(minWidth: appState.currentPage == .orphans ? 700 : 900, minHeight: 600)
        .edgesIgnoringSafeArea(.all)
    }
}



struct MountedVolumeView: View {
    struct Volume: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let icon: Image
        let totalSpace: Int64
        let usedSpace: Int64
    }
    @Environment(\.colorScheme) var colorScheme
    @State private var volume: Volume?
    @State private var initialSize: Int64 = 0

    var body: some View {
        ZStack(alignment: .center) {
            VStack {
                HStack {
                    Spacer()
                    if let username = NSFullUserName().components(separatedBy: " ").first {
                        Text("Welcome, \(username)!")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary.opacity(0.8))
                    }
                }
                Spacer()
            }

            Spacer()

            if let volume = volume {
                VStack(alignment: .center, spacing: 20) {

                    HStack {
                        volume.icon
                            .resizable()
                            .frame(width: 64, height: 64)

                        VStack(alignment: .leading) {

                            HStack {
                                Text(volume.name)
                                    .font(.title)
                                    .fontWeight(.bold)

                                Spacer()

                                let percentUsed = Double(volume.usedSpace) / Double(volume.totalSpace) * 100
                                Text(String(format: "%.0f%% full", percentUsed))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }


                            HStack {
                                Text("Size:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(ByteCountFormatter.string(fromByteCount: volume.totalSpace, countStyle: .file))
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)

                            }

                            HStack {
                                Text("Location:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(volume.path)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    HStack {
                        Text(ByteCountFormatter.string(fromByteCount: volume.usedSpace, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(ThemeColors.shared(for: colorScheme).backgroundMain)
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(ThemeColors.shared(for: colorScheme).iconFolder)
                                    .padding(3)
                                    .frame(width: geo.size.width * CGFloat(initialSize) / CGFloat(volume.totalSpace))
                                    .animation(.easeOut(duration: 1.0), value: initialSize)
                            }
                            .frame(height: 10)
                        }
                        Text(ByteCountFormatter.string(fromByteCount: volume.totalSpace, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 10)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ThemeColors.shared(for: colorScheme).backgroundPanel)
                )
                .padding()

            } else {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            let keys: [URLResourceKey] = [
                .volumeNameKey,
                .volumeAvailableCapacityKey,
                .volumeTotalCapacityKey
            ]
            let url = URL(fileURLWithPath: "/")

            guard let resource = try? url.resourceValues(forKeys: Set(keys)),
                  let total = resource.volumeTotalCapacity,
                  let available = resource.volumeAvailableCapacity else { return }

            let used = total - available
            let name = resource.volumeName ?? url.lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 32, height: 32)

            self.volume = Volume(
                name: name,
                path: url.path,
                icon: Image(nsImage: icon),
                totalSpace: Int64(total),
                usedSpace: Int64(used))

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.initialSize = Int64(used)
            }
        }
    }
}
