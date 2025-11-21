//
//  AdoptionSheetView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/18/25.
//

import SwiftUI

enum AdoptionContext {
    case updaterView
    case filesView
}

struct AdoptionSheetView: View {
    let appInfo: AppInfo
    let context: AdoptionContext
    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var isPresented: Bool
    @State private var matchingCasks: [AdoptableCask] = []
    @State private var selectedCaskToken: String? = nil
    @State private var manualEntry: String = ""
    @State private var manualEntryValidation: AdoptableCask? = nil
    @State private var isAdopting: Bool = false
    @State private var adoptionError: String? = nil
    @State private var isSearching: Bool = true

    var body: some View {
        StandardSheetView(
            title: "Adopt \(appInfo.appName) with Homebrew",
            width: 700,
            height: 600,
            onClose: {
                isPresented = false
            },
            content: {
                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    Text("Select a Homebrew cask to manage this app. Homebrew will adopt the existing installation without moving or duplicating files.")
                        .font(.body)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    // Matching casks section
                    if isSearching {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Searching for matching casks...")
                                    .font(.body)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }
                            Spacer()
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        CaskAdoptionContentView(
                            matchingCasks: $matchingCasks,
                            selectedCaskToken: $selectedCaskToken,
                            manualEntry: $manualEntry,
                            manualEntryValidation: $manualEntryValidation,
                            adoptionError: $adoptionError,
                            onManualEntryChange: validateManualEntry,
                            limitCaskListHeight: true
                        )
                    }
                }
            },
            actionButtons: {
                HStack(spacing: 12) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdopting)

                    Button(isAdopting ? "Adopting..." : "Adopt") {
                        performAdoption()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAdopting || !canAdopt)
                }
            }
        )
        .onAppear {
            searchForMatchingCasks()
        }
    }

    // MARK: - Computed Properties

    private var canAdopt: Bool {
        if isSearching { return false }
        if isAdopting { return false }

        // Either a cask is selected from the list, or manual entry is valid
        if let selected = selectedCaskToken, !selected.isEmpty {
            return true
        }

        if manualEntryValidation != nil, !manualEntry.isEmpty {
            return true
        }

        return false
    }

    private var selectedCask: AdoptableCask? {
        if let token = selectedCaskToken {
            return matchingCasks.first(where: { $0.token == token })
        }
        return manualEntryValidation
    }

    // MARK: - Methods

    private func searchForMatchingCasks() {
        isSearching = true

        Task {
            // Small delay to show loading state
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

            let matches = findMatchingCasks(for: appInfo, from: brewManager.allAvailableCasks)

            await MainActor.run {
                matchingCasks = matches
                isSearching = false

                // Auto-select first compatible cask if there's only one
                if matches.count == 1, matches[0].isVersionCompatible {
                    selectedCaskToken = matches[0].token
                }
            }
        }
    }

    private func validateManualEntry(_ token: String) {
        guard !token.isEmpty, token.count >= 2 else {
            manualEntryValidation = nil
            return
        }

        // Validate against loaded casks
        let validated = validateManualCaskEntry(token, for: appInfo, from: brewManager.allAvailableCasks)
        if validated != nil {
            manualEntryValidation = validated
            selectedCaskToken = nil  // Clear list selection when manual entry is valid
        } else {
            manualEntryValidation = nil
        }
    }

    private func performAdoption() {
        guard let cask = selectedCask else { return }

        isAdopting = true
        adoptionError = nil

        Task {
            do {
                try await HomebrewController.shared.adoptCask(token: cask.token)

                // Success - reload installed packages
                await brewManager.loadInstalledPackages()

                // Clear cask cache to pick up new adoption
                invalidateCaskLookupCache()

                // Reload apps to get updated cask metadata (non-streaming for full AppInfo)
                let folderPaths = await MainActor.run {
                    FolderSettingsManager.shared.folderPaths
                }
                await loadAppsAsync(folderPaths: folderPaths, useStreaming: false)

                // Trigger Updater refresh to recategorize and check for updates
                await MainActor.run {
                    // Only update AppState.appInfo when adopting from FilesView
                    if context == .filesView {
                        // Create updated AppInfo copy with new cask token
                        let updatedAppInfo = AppInfo(
                            id: appInfo.id,
                            path: appInfo.path,
                            bundleIdentifier: appInfo.bundleIdentifier,
                            appName: appInfo.appName,
                            appVersion: appInfo.appVersion,
                            appBuildNumber: appInfo.appBuildNumber,
                            appIcon: appInfo.appIcon,
                            webApp: appInfo.webApp,
                            wrapped: appInfo.wrapped,
                            system: appInfo.system,
                            arch: appInfo.arch,
                            cask: cask.token,
                            steam: appInfo.steam,
                            hasSparkle: appInfo.hasSparkle,
                            isAppStore: appInfo.isAppStore,
                            adamID: appInfo.adamID,
                            autoUpdates: cask.autoUpdates,
                            bundleSize: appInfo.bundleSize,
                            lipoSavings: appInfo.lipoSavings,
                            fileSize: appInfo.fileSize,
                            fileIcon: appInfo.fileIcon,
                            creationDate: appInfo.creationDate,
                            contentChangeDate: appInfo.contentChangeDate,
                            lastUsedDate: appInfo.lastUsedDate,
                            dateAdded: appInfo.dateAdded,
                            entitlements: appInfo.entitlements,
                            teamIdentifier: appInfo.teamIdentifier
                        )

                        // Update AppState.appInfo immediately for UI feedback
                        AppState.shared.appInfo = updatedAppInfo

                        // Also update in sortedApps array
                        if let index = AppState.shared.sortedApps.firstIndex(where: { $0.path == appInfo.path }) {
                            AppState.shared.sortedApps[index] = updatedAppInfo
                        }
                    }

                    // Always trigger Updater refresh (for both contexts)
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UpdaterViewShouldRefresh"),
                        object: nil
                    )
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isAdopting = false
                    adoptionError = "Failed to adopt: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Cask Row View

struct CaskRowView: View {
    let cask: AdoptableCask
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                // Radio button indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? ThemeColors.shared(for: colorScheme).accent : ThemeColors.shared(for: colorScheme).secondaryText)

                VStack(alignment: .leading, spacing: 6) {
                    // Cask name and token
                    HStack(spacing: 8) {
                        Text(cask.displayName)
                            .font(.headline)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                        if cask.displayName != cask.token {
                            Text(verbatim: "(\(cask.token))")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        }
                    }

                    // Version info
                    HStack(spacing: 4) {
                        Text("Version:")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        Text(cask.version)
                            .font(.caption)
                            .foregroundStyle(cask.isVersionCompatible ? .green : .orange)

                        if cask.autoUpdates {
                            Text("• Auto-updates")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if !cask.isVersionCompatible {
                            Text("• Version mismatch")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    // Description
                    if let description = cask.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .lineLimit(2)
                    }

                    // Homepage link
                    if let homepage = cask.homepage, let url = URL(string: homepage) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.caption2)
                                Text(homepage)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    // Match score (debug info)
                    #if DEBUG
                    Text("Match score: \(cask.matchScore)")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    #endif
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ?
                          ThemeColors.shared(for: colorScheme).accent.opacity(0.1) :
                          ThemeColors.shared(for: colorScheme).secondaryBG
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ?
                                  ThemeColors.shared(for: colorScheme).accent :
                                  Color.clear,
                                  lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
