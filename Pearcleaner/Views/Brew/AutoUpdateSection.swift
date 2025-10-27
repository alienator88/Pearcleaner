//
//  AutoUpdateSection.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/25/25.
//

import SwiftUI
import AlinFoundation

struct AutoUpdateSection: View {
    @ObservedObject private var manager = HomebrewAutoUpdateManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var logSheetWindow: NSWindow?
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text("Status")
                                            .font(.headline)
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                                        if manager.isAgentLoaded {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                                .font(.callout)
                                                .help("LaunchAgent is active")
                                        } else {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red)
                                                .font(.callout)
                                                .help("LaunchAgent is inactive")
                                        }
                                    }

                                    let enabledCount = manager.schedules.filter { $0.isEnabled }.count
                                    Text(manager.isAgentLoaded ? "\(enabledCount) schedule\(enabledCount == 1 ? "" : "s") active" : "Inactive")
                                        .font(.callout)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                }

                                Spacer()

                                // Master enable/disable toggle
                                Toggle("", isOn: Binding(
                                    get: { manager.isEnabled },
                                    set: { newValue in
                                        do {
                                            try manager.toggleEnabled(newValue)
                                        } catch {
                                            errorMessage = error.localizedDescription
                                            showError = true
                                        }
                                    }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.large)
                                .help(manager.isEnabled ? "Disable automatic updates (preserves schedule)" : "Enable automatic updates")
                            }

                            Divider()

                            // Actions Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Actions (applied to all schedules)")
                                    .font(.subheadline)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                                HStack(spacing: 20) {
                                    Toggle("Update Homebrew", isOn: $manager.runUpdate)
                                        .toggleStyle(CircleCheckboxToggleStyle())
                                        .help("Update Homebrew itself")
                                        .disabled(!manager.isEnabled)
                                        .onChange(of: manager.runUpdate) { _ in
                                            if manager.isEnabled && !manager.schedules.isEmpty {
                                                Task {
                                                    do {
                                                        try manager.applySchedule()
                                                        manager.originalRunUpdate = manager.runUpdate
                                                    } catch {
                                                        errorMessage = error.localizedDescription
                                                        showError = true
                                                    }
                                                }
                                            }
                                        }

                                    Toggle("Upgrade Packages", isOn: $manager.runUpgrade)
                                        .toggleStyle(CircleCheckboxToggleStyle())
                                        .help("Upgrade currently installed packages")
                                        .disabled(!manager.isEnabled)
                                        .onChange(of: manager.runUpgrade) { _ in
                                            if manager.isEnabled && !manager.schedules.isEmpty {
                                                Task {
                                                    do {
                                                        try manager.applySchedule()
                                                        manager.originalRunUpgrade = manager.runUpgrade
                                                    } catch {
                                                        errorMessage = error.localizedDescription
                                                        showError = true
                                                    }
                                                }
                                            }
                                        }

                                    Toggle("Cleanup", isOn: $manager.runCleanup)
                                        .toggleStyle(CircleCheckboxToggleStyle())
                                        .help("Remove orphaned dependencies, old package versions and scrub download cache")
                                        .disabled(!manager.isEnabled)
                                        .onChange(of: manager.runCleanup) { _ in
                                            if manager.isEnabled && !manager.schedules.isEmpty {
                                                Task {
                                                    do {
                                                        try manager.applySchedule()
                                                        manager.originalRunCleanup = manager.runCleanup
                                                    } catch {
                                                        errorMessage = error.localizedDescription
                                                        showError = true
                                                    }
                                                }
                                            }
                                        }
                                }
                            }
                        }
                        .padding()
                    }

                    // Schedule Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Schedule")
                                    .font(.headline)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                                Spacer()

                                // View Log button
                                if manager.logFileExists {
                                    Button {
                                        showLogSheet()
                                    } label: {
                                        Label("View Log", systemImage: "doc.text")
                                    }
                                    .buttonStyle(.bordered)
                                    .help("View homebrew-autoupdate.log")
                                }

                                Button {
                                    manager.schedules.append(ScheduleOccurrence())
                                } label: {
                                    Label("Add Schedule", systemImage: "plus")
                                        .font(.callout)
                                }
                                .help("Add a new schedule occurrence")
                                .disabled(!manager.isEnabled)
                            }

                            if manager.schedules.isEmpty {
                                Text("No schedules configured")
                                    .font(.callout)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            } else {
                                Divider()

                                LazyVStack(spacing: 8) {
                                    ForEach($manager.schedules) { $schedule in
                                        ScheduleRow(
                                            schedule: $schedule,
                                            isDisabled: !manager.isEnabled,
                                            isInEditMode: manager.isInEditMode(schedule),
                                            isNewSchedule: !manager.originalSchedules.contains(where: { $0.id == schedule.id })
                                        )
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .scrollIndicators(scrollIndicators ? .automatic : .never)
        }
        .alert("Error", isPresented: $showError) {
            Button("Okay", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HomebrewViewShouldRefresh"))) { _ in
            manager.refreshState()
        }
        .onDisappear {
            manager.removeUnsavedSchedules()
        }
    }

    // MARK: - Log Viewer Sheet

    private func showLogSheet() {
        // Read log file
        guard let logContent = try? String(contentsOfFile: manager.logPath, encoding: .utf8) else {
            errorMessage = "Could not read log file"
            showError = true
            return
        }

        guard let parentWindow = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            return
        }

        // Create SwiftUI view
        let contentView = LogViewerSheet(
            logContent: logContent,
            onClose: {
                if let sheetWindow = self.logSheetWindow {
                    parentWindow.endSheet(sheetWindow)
                }
                self.logSheetWindow = nil
            }
        )

        // Create sheet window
        let hostingController = NSHostingController(rootView: contentView)

        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        sheetWindow.title = "Log Viewer"
        sheetWindow.contentViewController = hostingController
        sheetWindow.isReleasedWhenClosed = false

        // Present as sheet
        parentWindow.beginSheet(sheetWindow)
        self.logSheetWindow = sheetWindow
    }
}

// MARK: - Schedule Row Component

struct ScheduleRow: View {
    @Binding var schedule: ScheduleOccurrence
    let isDisabled: Bool
    let isInEditMode: Bool
    let isNewSchedule: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var errorMessage: String?
    @State private var showError: Bool = false

    private let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    // Convert 24-hour to 12-hour format
    private var hour12: Int {
        let h = schedule.hour
        if h == 0 { return 12 }
        if h > 12 { return h - 12 }
        return h
    }

    private var isPM: Bool {
        schedule.hour >= 12
    }

    var body: some View {
        HStack(spacing: 8) {

            // Toggle - outside background
            Toggle("", isOn: $schedule.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .help(schedule.isEnabled ? "Schedule is enabled" : "Schedule is disabled")
                .onChange(of: schedule.isEnabled) { _ in
                    // Instant save for toggle changes (don't trigger edit mode)
                    Task {
                        do {
                            try HomebrewAutoUpdateManager.shared.applySchedule()
                        } catch {
                            await MainActor.run {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }
                }

            // Rest of row - with background
            HStack(spacing: 5) {

                // Weekday picker
                Picker("", selection: $schedule.weekday) {
                    ForEach(0..<7) { day in
                        Text(weekdayNames[day]).tag(day)
                    }
                }
                .labelsHidden()
                .minimalistPicker()
                .frame(width: 60, alignment: .center)

                Divider()
                    .padding(.trailing, 12)

                HStack(spacing: 2) {
                    // Hour picker (12-hour format)
                    Picker("", selection: Binding(
                        get: { hour12 },
                        set: { newHour in
                            // Convert back to 24-hour
                            if isPM {
                                schedule.hour = newHour == 12 ? 12 : newHour + 12
                            } else {
                                schedule.hour = newHour == 12 ? 0 : newHour
                            }
                        }
                    )) {
                        ForEach(1...12, id: \.self) { hour in
                            Text(verbatim: String(format: "%02d", hour)).tag(hour)
                                .monospacedDigit()
                        }
                    }
                    .labelsHidden()
                    .minimalistPicker()
                    .frame(alignment: .center)
                    .fixedSize()

                    Text(verbatim: ":")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .font(.title3)

                    // Minute picker
                    Picker("", selection: $schedule.minute) {
                        ForEach(0..<60) { minute in
                            Text(verbatim: String(format: "%02d", minute)).tag(minute)
                                .monospacedDigit()
                        }
                    }
                    .labelsHidden()
                    .minimalistPicker()
                    .frame(alignment: .center)
                    .fixedSize()
                }


                // AM/PM picker
                Picker("", selection: Binding(
                    get: { isPM },
                    set: { newIsPM in
                        if newIsPM && !isPM {
                            // Switch to PM
                            schedule.hour = schedule.hour == 0 ? 12 : schedule.hour + 12
                        } else if !newIsPM && isPM {
                            // Switch to AM
                            schedule.hour = schedule.hour == 12 ? 0 : schedule.hour - 12
                        }
                    }
                )) {
                    Text(verbatim: "AM").tag(false)
                    Text(verbatim: "PM").tag(true)
                }
                .labelsHidden()
                .minimalistPicker()
                .frame(alignment: .center)
                .fixedSize()


                Spacer()

                // Save button (conditional, only in edit mode)
                if isInEditMode {
                    Button {
                        Task {
                            do {
                                try HomebrewAutoUpdateManager.shared.saveSchedule(schedule)
                            } catch {
                                await MainActor.run {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.3))
                                .frame(width: 16, height: 16)

                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(.green)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Save this schedule")
                }

                // Revert button (conditional, only for existing schedules in edit mode)
                if isInEditMode && !isNewSchedule {
                    Button {
                        HomebrewAutoUpdateManager.shared.revertSchedule(schedule)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 16, height: 16)

                            Image(systemName: "arrow.counterclockwise.circle")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Revert to original schedule")
                }

                // Delete button
                Button {
                    Task {
                        do {
                            try HomebrewAutoUpdateManager.shared.deleteSchedule(schedule)
                        } catch {
                            await MainActor.run {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 16, height: 16)

                        Image(systemName: "xmark.circle")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(.red)
                    }
                }
                .buttonStyle(.plain)
                .help("Delete this schedule")
            }
            .padding(.horizontal, 5)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ThemeColors.shared(for: colorScheme).primaryBG)
            )
            .padding(6)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isInEditMode ? ThemeColors.shared(for: colorScheme).accent : Color.clear,
                        style: StrokeStyle(lineWidth: 1.0, dash: [5, 3])
                    )
            )
        }
        .opacity(isDisabled ? 0.4 : 1.0)
        .disabled(isDisabled)
        .alert("Error", isPresented: $showError) {
            Button("Okay", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }
}
