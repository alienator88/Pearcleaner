//
//  UpdateManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation
import SwiftUI
import AlinFoundation

@MainActor
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var updatesBySource: [UpdateSource: [UpdateableApp]] = [:]
    @Published var isScanning: Bool = false
    @Published var lastScanDate: Date?

    private init() {}

    var hasUpdates: Bool {
        updatesBySource.values.contains { !$0.isEmpty }
    }

    func scanForUpdates() async {
        isScanning = true
        defer { isScanning = false }

        // Get apps from AppState
        let apps = AppState.shared.sortedApps

        // Scan for updates using coordinator
        updatesBySource = await UpdateCoordinator.scanForUpdates(apps: apps)
        lastScanDate = Date()
    }

    func updateApp(_ app: UpdateableApp) async {
        switch app.source {
        case .homebrew:
            if let cask = app.appInfo.cask {
                // Update the app status
                if var apps = updatesBySource[.homebrew],
                   let index = apps.firstIndex(where: { $0.id == app.id }) {
                    apps[index].status = .downloading
                    updatesBySource[.homebrew] = apps
                }

                // Perform upgrade
                try? await HomebrewController.shared.upgradePackage(name: cask)

                // Remove from list after upgrade
                updatesBySource[.homebrew]?.removeAll { $0.id == app.id }
            }

        case .appStore:
            if let adamID = app.adamID {
                // Update the app status
                if var apps = updatesBySource[.appStore],
                   let index = apps.firstIndex(where: { $0.id == app.id }) {
                    apps[index].status = .downloading
                    updatesBySource[.appStore] = apps
                }

                // Perform update
                await AppStoreUpdater.shared.updateApp(adamID: adamID) { [weak self] progress, status in
                    Task { @MainActor in
                        guard let self = self else { return }
                        if var apps = self.updatesBySource[.appStore],
                           let index = apps.firstIndex(where: { $0.id == app.id }) {
                            apps[index].progress = progress
                            self.updatesBySource[.appStore] = apps

                            // Remove from list when complete
                            if progress >= 1.0 {
                                self.updatesBySource[.appStore]?.removeAll { $0.id == app.id }
                            }
                        }
                    }
                }
            }

        case .sparkle:
            // Open the app so it can self-update
            NSWorkspace.shared.open(app.appInfo.path)
        }
    }

    func updateAll(source: UpdateSource) async {
        guard let apps = updatesBySource[source] else { return }

        for app in apps {
            await updateApp(app)
        }
    }
}
