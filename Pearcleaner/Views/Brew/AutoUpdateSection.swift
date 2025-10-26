//
//  AutoUpdateSection.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/25/25.
//

import SwiftUI
import AlinFoundation

struct AutoUpdateSection: View {
    @StateObject private var manager = HomebrewAutoUpdateManager()
    @Environment(\.colorScheme) var colorScheme
    @State private var isApplying: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
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
                                        .help("Run 'brew update' to update Homebrew itself")
                                        .disabled(!manager.isEnabled)

                                    Toggle("Upgrade Packages", isOn: $manager.runUpgrade)
                                        .toggleStyle(CircleCheckboxToggleStyle())
                                        .help("Run 'brew upgrade --greedy' to upgrade installed packages")
                                        .disabled(!manager.isEnabled)

                                    Toggle("Cleanup", isOn: $manager.runCleanup)
                                        .toggleStyle(CircleCheckboxToggleStyle())
                                        .help("Run 'brew autoremove' and 'brew cleanup --prune=all' to remove old versions")
                                        .disabled(!manager.isEnabled)
                                }
                            }
                        }
                        .padding()
                    }

                    // Schedule Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Update Schedule")
                                    .font(.headline)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                                Spacer()

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
                                            onDelete: {
                                                manager.schedules.removeAll { $0.id == schedule.id }
                                            }
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

            // Bottom Toolbar
            if !manager.schedules.isEmpty {
                Divider()

                HStack(spacing: 12) {

                    // Log file button
                    if manager.logFileExists {
                        Button {
                            manager.openLogFile()
                        } label: {
                            Label("View Log", systemImage: "doc.text")
//                                .font(.callout)
                        }
                        .buttonStyle(.bordered)
                        .help("Open homebrew-autoupdate.log in text editor")
                    }
                    
                    Spacer()

                    if isApplying {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 8)
                    }

                    Button("Apply") {
                        applyChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isApplying)
                    .help("Save schedule and register LaunchAgent")
                }
                .padding()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func applyChanges() {
        isApplying = true

        Task {
            do {
                try manager.applySchedule()
                await MainActor.run {
                    isApplying = false
                    manager.checkLogFiles()  // Refresh log file status
                }
            } catch {
                await MainActor.run {
                    isApplying = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Schedule Row Component

struct ScheduleRow: View {
    @Binding var schedule: ScheduleOccurrence
    let isDisabled: Bool
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

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
        HStack(spacing: 12) {

            // Weekday picker
            Picker("", selection: $schedule.weekday) {
                ForEach(0..<7) { day in
                    Text(weekdayNames[day]).tag(day)
                }
            }
            .labelsHidden()
            .frame(width: 80)

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
                    Text("\(hour)").tag(hour)
                }
            }
            .labelsHidden()
            .frame(width: 60)

            Text(":")
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                .font(.title3)

            // Minute picker
            Picker("", selection: $schedule.minute) {
                ForEach(0..<60) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .labelsHidden()
            .frame(width: 60)

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
                Text("AM").tag(false)
                Text("PM").tag(true)
            }
            .labelsHidden()
            .frame(width: 60)

            Spacer()

            // Enabled toggle
            Toggle("", isOn: $schedule.isEnabled)
                .toggleStyle(.switch)
                .help(schedule.isEnabled ? "Schedule is enabled" : "Schedule is disabled")

            // Delete button
            Button {
                onDelete()
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
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
        )
        .opacity(isDisabled ? 0.4 : 1.0)
        .disabled(isDisabled)
    }
}
