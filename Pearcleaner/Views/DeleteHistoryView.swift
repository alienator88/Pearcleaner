//
//  DeleteHistoryView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/10/25.
//

import SwiftUI
import AlinFoundation

struct DeleteHistoryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @StateObject private var historyManager = UndoHistoryManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedRecords = Set<UUID>()
    @State private var isRestoring = false

    var body: some View {
        StandardSheetView(
            title: "Delete History",
            width: 700,
            height: 500,
            onClose: {
                appState.showDeleteHistory = false
            },
            content: {
                if historyManager.history.isEmpty {
                    VStack {
                        Spacer()
                        Text("No delete history")
                            .font(.title2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        Text("Deleted files will appear here")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        // Info text
                        Text("Restore previously deleted files from trash (last 10 operations)")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .padding(.bottom, 5)

                        // List of history records
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(historyManager.history.enumerated()), id: \.element.id) { index, record in
                                    HistoryRecordRow(
                                        record: record,
                                        isSelected: selectedRecords.contains(record.id),
                                        isValid: historyManager.isRecordValid(record),
                                        onToggle: {
                                            if selectedRecords.contains(record.id) {
                                                selectedRecords.remove(record.id)
                                            } else {
                                                selectedRecords.insert(record.id)
                                            }
                                        }
                                    )

                                    if index < historyManager.history.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .background(ThemeColors.shared(for: colorScheme).secondaryBG)
                        .cornerRadius(8)
                    }
                }
            },
            selectionControls: {
                if !historyManager.history.isEmpty {
                    Button(selectedRecords.count == historyManager.history.count ? "Deselect All" : "Select All") {
                        if selectedRecords.count == historyManager.history.count {
                            selectedRecords.removeAll()
                        } else {
                            selectedRecords = Set(historyManager.history.map { $0.id })
                        }
                    }
                    .buttonStyle(ControlGroupButtonStyle(
                        foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                        shape: Capsule(style: .continuous),
                        level: .primary,
                        skipControlGroup: true
                    ))
                    .disabled(isRestoring)
                }
            },
            actionButtons: {
                HStack(spacing: 10) {
                    Button("Cancel") {
                        appState.showDeleteHistory = false
                    }
                    .buttonStyle(ControlGroupButtonStyle(
                        foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                        shape: Capsule(style: .continuous),
                        level: .primary,
                        skipControlGroup: true
                    ))
                    .disabled(isRestoring)

                    if !selectedRecords.isEmpty {
                        Divider().frame(height: 10)
                        
                        Button {
                            restoreSelectedRecords()
                        } label: {
                            if isRestoring {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Restoring...")
                                }
                            } else {
                                Label("Restore \(selectedRecords.count)", systemImage: "arrow.uturn.backward")
                            }
                        }
                        .buttonStyle(ControlGroupButtonStyle(
                            foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                            shape: Capsule(style: .continuous),
                            level: .primary,
                            skipControlGroup: true
                        ))
                        .disabled(isRestoring)
                    }
                }
                .controlGroup(Capsule(style: .continuous), level: .primary)
            }
        )
    }

    private func restoreSelectedRecords() {
        isRestoring = true

        let recordsToRestore = historyManager.history.filter { selectedRecords.contains($0.id) }

        Task {
            do {
                try await historyManager.restoreRecords(recordsToRestore)
                selectedRecords.removeAll()
                isRestoring = false

                // Refresh app list and file view (same as Undo Removal in AppCommands)
                await MainActor.run {
                    if appState.currentPage == .plugins {
                        NotificationCenter.default.post(name: NSNotification.Name("PluginsViewShouldRefresh"), object: nil)
                    } else if appState.currentPage == .fileSearch {
                        NotificationCenter.default.post(name: NSNotification.Name("FileSearchViewShouldUndo"), object: nil)
                    } else if appState.currentPage == .orphans {
                        NotificationCenter.default.post(name: NSNotification.Name("ZombieViewShouldRefresh"), object: nil)
                    } else if appState.currentPage == .packages {
                        NotificationCenter.default.post(name: NSNotification.Name("PackagesViewShouldRefresh"), object: nil)
                    } else if appState.currentPage == .development {
                        NotificationCenter.default.post(name: NSNotification.Name("DevelopmentViewShouldRefresh"), object: nil)
                    } else {
                        // Use default non-streaming mode for undo (needs full AppInfo)
                        loadApps(folderPaths: fsm.folderPaths)
                        // After reload, if we're viewing files, refresh the file view
                        if appState.currentView == .files {
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                showAppInFiles(appInfo: appState.appInfo, appState: appState, locations: locations)
                            }
                        }
                    }
                }

                // Close sheet if no history remains
                if historyManager.history.isEmpty {
                    await MainActor.run {
                        appState.showDeleteHistory = false
                    }
                }
            } catch {
                printOS("❌ Failed to restore records: \(error.localizedDescription)")
                isRestoring = false
            }
        }
    }
}

// MARK: - History Record Row

struct HistoryRecordRow: View {
    let record: UndoHistoryRecord
    let isSelected: Bool
    let isValid: Bool
    let onToggle: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox button
            Button {
                onToggle()
            } label: {
                EmptyView()
            }
            .buttonStyle(CircleCheckboxButtonStyle(isSelected: isSelected))
            .disabled(!isValid)

            VStack(alignment: .leading, spacing: 4) {
                // App name and timestamp
                HStack {
                    Text(record.appName)
                        .font(.headline)
                        .foregroundStyle(isValid ? ThemeColors.shared(for: colorScheme).primaryText : ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.5))

                    Spacer()

                    Text(formatRelativeTime(record.timestamp))
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

                // File count
                HStack {
                    Text("\(record.fileCount) file\(record.fileCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    if !isValid {
                        Text(verbatim: "•")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        Text("Files no longer in trash")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? ThemeColors.shared(for: colorScheme).accent.opacity(0.1) : Color.clear)
    }
}
