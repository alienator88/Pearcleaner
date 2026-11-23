//
//  SnapshotsView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/22/26.
//

import SwiftUI
import AlinFoundation

struct TMSnapshot: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let volume: String
    let date: Date?
    let purgeable: Bool
    let sizeBytes: UInt64?

    var isSystemOwned: Bool {
        return name.hasPrefix("com.apple.os.update")
            || name.hasPrefix("com.apple.TimeMachine")
            || name.hasPrefix("com.apple.update")
    }
}

struct SnapshotsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var consoleManager = GlobalConsoleManager.shared
    @ObservedObject private var helperManager = HelperToolManager.shared
    @State private var snapshots: [TMSnapshot] = []
    @State private var selectedSnapshot: TMSnapshot?
    @State private var isLoading: Bool = false
    @State private var isDeleting: Bool = false
    @State private var lastRefreshDate: Date?
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    private var deletableSnapshots: [TMSnapshot] {
        snapshots.filter { !$0.isSystemOwned }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                content
            }
            .frame(minWidth: 680, minHeight: 380)
        }
        .onAppear {
            if snapshots.isEmpty && !isLoading {
                refreshSnapshots()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SnapshotsViewShouldRefresh"))) { _ in
            refreshSnapshots()
        }
        .confirmationDialog(
            String(localized: "Delete the selected snapshot?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete Snapshot"), role: .destructive) {
                if let snapshot = selectedSnapshot {
                    deleteSnapshot(snapshot)
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "The system may recreate snapshots automatically. Deleting the last snapshot on a volume is not possible."))
        }
        .alert(
            String(localized: "Snapshot Error"),
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Text(String(localized: "Time Machine local snapshots"))
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    consoleManager.showConsole.toggle()
                }
            } label: {
                Image(systemName: consoleManager.showConsole ? "terminal.fill" : "terminal")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
            }
            .buttonStyle(.borderless)
            .help(String(localized: "Toggle console output"))
            .padding(.trailing, 10)

            Button {
                refreshSnapshots()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
            }
            .buttonStyle(.borderless)
            .disabled(isLoading || isDeleting)
            .help(String(localized: "Refresh snapshots"))
            .padding(.trailing, 10)

            Button {
                selectedSnapshot = deletableSnapshots.min { a, b in
                    (a.date ?? .distantPast) < (b.date ?? .distantPast)
                }
                if selectedSnapshot != nil {
                    showDeleteConfirm = true
                }
            } label: {
                HStack(spacing: 4) {
                    if isDeleting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text(String(localized: "Delete"))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || isDeleting || deletableSnapshots.isEmpty)
            .help(String(localized: "Delete the oldest non-system snapshot"))
        }
        .padding()
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(alignment: .center, spacing: 10) {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Text(String(localized: "Loading snapshots..."))
                    .font(.title2)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if snapshots.isEmpty {
            VStack(alignment: .center, spacing: 12) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                Text(String(localized: "No local snapshots found"))
                    .font(.title2)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                Text(String(localized: "Time Machine keeps local snapshots only when a backup destination is configured or right after an OS update."))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            snapshotList
        }
    }

    private var snapshotList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(snapshots.count) snapshot\(snapshots.count == 1 ? "" : "s")")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                Spacer()

                if let lastRefresh = lastRefreshDate {
                    TimelineView(.periodic(from: lastRefresh, by: 1.0)) { _ in
                        Text("Updated \(formatRelativeTime(lastRefresh))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(snapshots) { snapshot in
                        SnapshotRowView(
                            snapshot: snapshot,
                            onDelete: {
                                selectedSnapshot = snapshot
                                showDeleteConfirm = true
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .scrollIndicators(scrollIndicators ? .automatic : .never)
        }
    }

    // MARK: Actions

    private func refreshSnapshots() {
        GlobalConsoleManager.shared.appendOutput("Refreshing local snapshots...\n", source: CurrentPage.snapshots.title)
        isLoading = true

        Task {
            let (success, output) = await HelperToolManager.shared.runCommand("diskutil apfs listSnapshots /")

            let parsed = success ? parseSnapshots(output: output) : []

            await MainActor.run {
                self.snapshots = parsed
                self.isLoading = false
                self.lastRefreshDate = Date()

                if success {
                    GlobalConsoleManager.shared.appendOutput("✓ Found \(parsed.count) snapshot\(parsed.count == 1 ? "" : "s")\n", source: CurrentPage.snapshots.title)
                } else {
                    GlobalConsoleManager.shared.appendOutput("✗ Failed to list snapshots: \(output)\n", source: CurrentPage.snapshots.title)
                }
            }
        }
    }

    private func deleteSnapshot(_ snapshot: TMSnapshot) {
        isDeleting = true
        GlobalConsoleManager.shared.appendOutput("Deleting snapshot \(snapshot.name)...\n", source: CurrentPage.snapshots.title)

        Task {
            let (success, output) = await HelperToolManager.shared.runCommand("diskutil apfs deleteSnapshot / -name \(quoted(snapshot.name))")

            await MainActor.run {
                self.isDeleting = false

                if success {
                    GlobalConsoleManager.shared.appendOutput("✓ Deleted snapshot \(snapshot.name)\n", source: CurrentPage.snapshots.title)
                    self.refreshSnapshots()
                } else {
                    self.deleteError = output.isEmpty ? String(localized: "The snapshot could not be deleted.") : output
                    GlobalConsoleManager.shared.appendOutput("✗ Failed to delete snapshot: \(output)\n", source: CurrentPage.snapshots.title)
                }
            }
        }
    }

    private func quoted(_ value: String) -> String {
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: Parsing

    private func parseSnapshots(output: String) -> [TMSnapshot] {
        var result: [TMSnapshot] = []
        var currentName: String?
        var currentPurgeable = false

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Name:") {
                currentName = trimmed.dropFirst("Name:".count).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Purgeable:") {
                currentPurgeable = trimmed.contains("Yes")
            } else if trimmed.hasPrefix("XID:"), let name = currentName {
                let date = parseSnapshotDate(name: name)
                result.append(TMSnapshot(
                    name: name,
                    volume: "/",
                    date: date,
                    purgeable: currentPurgeable,
                    sizeBytes: nil
                ))
                currentName = nil
                currentPurgeable = false
            }
        }
        return result
    }

    private func parseSnapshotDate(name: String) -> Date? {
        // Time Machine snapshots embed the date: com.apple.TimeMachine.2026-11-20-123456.local
        let pattern = "\\.?(\\d{4})-(\\d{2})-(\\d{2})-(\\d{6})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(name.startIndex..., in: name)
        guard let match = regex.firstMatch(in: name, range: range),
              let r1 = Range(match.range(at: 1), in: name),
              let r2 = Range(match.range(at: 2), in: name),
              let r3 = Range(match.range(at: 3), in: name),
              let r4 = Range(match.range(at: 4), in: name) else { return nil }

        let year = Int(name[r1]) ?? 0
        let month = Int(name[r2]) ?? 0
        let day = Int(name[r3]) ?? 0
        let timeDigits = name[r4]
        let hour = Int(timeDigits.prefix(2)) ?? 0
        let minute = Int(timeDigits.dropFirst(2).prefix(2)) ?? 0
        let second = Int(timeDigits.suffix(2)) ?? 0

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return Calendar.current.date(from: components)
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: Row view

struct SnapshotRowView: View {
    let snapshot: TMSnapshot
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(snapshot.isSystemOwned
                    ? ThemeColors.shared(for: colorScheme).secondaryText
                    : ThemeColors.shared(for: colorScheme).accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.name)
                    .font(.callout)
                    .monospaced()
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    if let date = snapshot.date {
                        Text(date.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    if snapshot.purgeable {
                        Text(String(localized: "Purgeable"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.2)))
                            .foregroundStyle(.blue)
                    }

                    if snapshot.isSystemOwned {
                        Text(String(localized: "System"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(snapshot.isSystemOwned
                        ? ThemeColors.shared(for: colorScheme).secondaryText
                        : .red)
            }
            .buttonStyle(.borderless)
            .disabled(snapshot.isSystemOwned)
            .help(snapshot.isSystemOwned
                ? String(localized: "System snapshots cannot be deleted while in use")
                : String(localized: "Delete this snapshot"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ThemeColors.shared(for: colorScheme).secondaryBG)
        )
        .contentShape(Rectangle())
    }
}