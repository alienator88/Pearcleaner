//
//  MaintenanceSection.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import SwiftUI
import AlinFoundation

struct MaintenanceSection: View {
    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isUpdatingBrew: Bool = false
    @State private var isRunningDoctor: Bool = false
    @State private var isPurgingCache: Bool = false
    @State private var doctorOutput: String = ""
    @State private var showDoctorSheet: Bool = false
    @State private var doctorHealthy: Bool? = nil // nil = not run, true = healthy, false = unhealthy
    @State private var isCheckingHealthOnAppear: Bool = false
    @State private var isCheckingVersionOnAppear: Bool = false
    @State private var isCheckingCacheSize: Bool = false
    @State private var refreshID = UUID()
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Homebrew Version Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("Homebrew Version")
                                        .font(.headline)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                                    if isCheckingVersionOnAppear {
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 14, height: 14)
                                    } else if !brewManager.brewVersion.isEmpty {
                                        if brewManager.updateAvailable {
                                            Image(systemName: "arrow.up.circle.fill")
                                                .foregroundStyle(.orange)
                                                .font(.callout)
                                                .help("Homebrew update available")
                                        } else {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.green)
                                                .font(.callout)
                                                .help("Homebrew is up to date")
                                        }
                                    }
                                }

                                if !brewManager.brewVersion.isEmpty {
                                    if brewManager.updateAvailable && !brewManager.latestBrewVersion.isEmpty {
                                        // Show current → latest when update available
                                        Text("\(brewManager.brewVersion) → \(brewManager.latestBrewVersion)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                                    } else {
                                        // Show just current version when up to date
                                        Text(brewManager.brewVersion)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                                    }
                                } else {
                                    Text("Unknown")
                                        .font(.title3)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                }
                            }

                            Spacer()

                            Button {
                                Task {
                                    isUpdatingBrew = true
                                    do {
                                        try await HomebrewController.shared.updateBrew()
                                        await brewManager.checkForUpdate()
                                    } catch {
                                        printOS("Error updating Homebrew: \(error)")
                                    }
                                    isUpdatingBrew = false
                                }
                            } label: {
                                if isUpdatingBrew {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Updating...")
                                    }
                                } else {
                                    Label("Update Homebrew", systemImage: "arrow.triangle.2.circlepath")
                                }
                            }
                            .buttonStyle(ControlGroupButtonStyle(
                                foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                shape: Capsule(style: .continuous),
                                level: .primary,
                                skipControlGroup: true
                            ))
                            .disabled(isUpdatingBrew)
                        }

                        Text("Update Homebrew to the latest version using brew update")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .padding()
                }
                .groupBoxStyle(TransparentGroupBox())

                // Doctor Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("Homebrew Doctor")
                                        .font(.headline)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                                    if isCheckingHealthOnAppear {
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 14, height: 14)
                                    } else if let isHealthy = doctorHealthy {
                                        Button {
                                            if !isHealthy {
                                                showDoctorSheet = true
                                            }
                                        } label: {
                                            Image(systemName: isHealthy ? "checkmark" : "exclamationmark.octagon")
                                                .foregroundStyle(isHealthy ? .green : .red)
                                                .font(.callout)
                                        }
                                        .buttonStyle(.plain)
                                        .help(isHealthy ? "Your Homebrew installation is healthy" : "Click to view issues")
//                                        .disabled(isHealthy)
                                    }
                                }

                                Text("Check for potential issues")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }

                            Spacer()

                            Button {
                                Task {
                                    isRunningDoctor = true
                                    do {
                                        doctorOutput = try await HomebrewController.shared.runDoctor()
                                        doctorHealthy = doctorOutput.contains("Your system is ready to brew")
                                        if !doctorHealthy! {
                                            showDoctorSheet = true
                                        }
                                    } catch {
                                        printOS("Error running doctor: \(error)")
                                    }
                                    isRunningDoctor = false
                                }
                            } label: {
                                if isRunningDoctor {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Running...")
                                    }
                                } else {
                                    Label("Run Doctor", systemImage: "stethoscope")
                                }
                            }
                            .buttonStyle(ControlGroupButtonStyle(
                                foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                shape: Capsule(style: .continuous),
                                level: .primary,
                                skipControlGroup: true
                            ))
                            .disabled(isRunningDoctor)
                        }
                    }
                    .padding()
                }
                .groupBoxStyle(TransparentGroupBox())

                // Cleanup Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("Cleanup")
                                        .font(.headline)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                                    if isCheckingCacheSize {
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 14, height: 14)
                                    }
                                }

                                HStack(spacing: 6) {
                                    Text("Cache Size:")
                                        .font(.caption)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                                    if isCheckingCacheSize {
                                        Text("Calculating...")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    } else {
                                        Text(ByteCountFormatter.string(fromByteCount: brewManager.cacheSize, countStyle: .file))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                    }
                                }
                            }

                            Spacer()

                            Button {
                                Task {
                                    isPurgingCache = true
                                    do {
                                        try await HomebrewController.shared.performFullCleanup()
                                        await brewManager.loadCacheSize()
                                    } catch {
                                        printOS("Error performing cleanup: \(error)")
                                    }
                                    isPurgingCache = false
                                }
                            } label: {
                                if isPurgingCache {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Cleaning...")
                                    }
                                } else {
                                    Label("Run Cleanup", systemImage: "trash")
                                }
                            }
                            .buttonStyle(ControlGroupButtonStyle(
                                foregroundColor: .red,
                                shape: Capsule(style: .continuous),
                                level: .primary,
                                skipControlGroup: true
                            ))
                            .disabled(isPurgingCache || brewManager.cacheSize == 0)
                            .opacity((isPurgingCache || brewManager.cacheSize == 0) ? 0.5 : 1.0)
                        }

                        Text("Removes old versions, orphaned dependencies, and all cache files including latest versions")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .padding()
                }
                .groupBoxStyle(TransparentGroupBox())

                // Analytics Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Analytics")
                                    .font(.headline)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                                Text(brewManager.analyticsEnabled ? "Analytics are enabled" : "Analytics are disabled")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { brewManager.analyticsEnabled },
                                set: { newValue in
                                    // Update UI immediately for fluid experience
                                    brewManager.analyticsEnabled = newValue

                                    // Run command in background
                                    Task {
                                        do {
                                            try await HomebrewController.shared.setAnalyticsStatus(enabled: newValue)
                                        } catch {
                                            printOS("Error toggling analytics: \(error)")
                                            // Revert on error
                                            await MainActor.run {
                                                brewManager.analyticsEnabled = !newValue
                                            }
                                        }
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                        }

                        Text("Homebrew collects anonymous analytics to help improve the project")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .padding()
                }
                .groupBoxStyle(TransparentGroupBox())

                // Statistics Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statistics")
                            .font(.headline)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                        HStack(spacing: 0) {
                            // Formulae
                            VStack(spacing: 4) {
                                Text(verbatim: "\(brewManager.installedFormulae.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                Text("Formulae")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 40)

                            // Casks
                            VStack(spacing: 4) {
                                Text(verbatim: "\(brewManager.installedCasks.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                Text("Casks")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 40)

                            // Taps
                            VStack(spacing: 4) {
                                Text(verbatim: "\(brewManager.availableTaps.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                Text("Taps")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 40)

                            // Outdated
                            VStack(spacing: 4) {
                                Text(verbatim: "\(brewManager.outdatedPackages.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(brewManager.outdatedPackages.isEmpty ? ThemeColors.shared(for: colorScheme).primaryText : .orange)
                                Text("Outdated")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
                .groupBoxStyle(TransparentGroupBox())
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .scrollIndicators(scrollIndicators ? .automatic : .never)
        .sheet(isPresented: $showDoctorSheet) {
            DoctorOutputSheet(output: doctorOutput, isPresented: $showDoctorSheet)
        }
        .onAppear {
            runAllChecks()
        }
        .onChange(of: brewManager.maintenanceRefreshTrigger) { _ in
            runAllChecks()
        }
    }

    private func runAllChecks() {
        // Run health check, version check, and cache size check in parallel
        if !isCheckingHealthOnAppear && !isCheckingVersionOnAppear && !isCheckingCacheSize {
            // Check cache size (instant ~5-20ms with Swift calculation)
            Task {
                isCheckingCacheSize = true
                await brewManager.loadCacheSize()
                isCheckingCacheSize = false
            }
            // Run both checks in parallel
            Task {
                isCheckingVersionOnAppear = true
                await brewManager.checkForUpdate()
                isCheckingVersionOnAppear = false
            }

            Task {
                isCheckingHealthOnAppear = true
                do {
                    doctorOutput = try await HomebrewController.shared.runDoctor()
                    doctorHealthy = doctorOutput.contains("Your system is ready to brew")
                } catch {
                    printOS("Error running health check on appear: \(error)")
                    doctorHealthy = false
                }
                isCheckingHealthOnAppear = false
            }
        }
    }
}

// MARK: - Doctor Output Sheet

struct DoctorOutputSheet: View {
    let output: String
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme

    var isHealthy: Bool {
        return output.contains("Your system is ready to brew")
    }

    var body: some View {
        StandardSheetView(
            title: "Homebrew Doctor",
            width: 700,
            height: 500,
            onClose: { isPresented = false }
        ) {
            // Content
            ScrollView {
                if isHealthy {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)

                        Text("Your Homebrew installation is healthy!")
                            .font(.headline)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                        Text("No issues detected")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Issues detected:")
                            .font(.headline)
                            .foregroundStyle(.red)

                        Text(output)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ThemeColors.shared(for: colorScheme).secondaryBG)
                    )
                }
            }
        } actionButtons: {
            Button("Close") {
                isPresented = false
            }
            .buttonStyle(ControlGroupButtonStyle(
                foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                shape: Capsule(style: .continuous),
                level: .primary,
                skipControlGroup: true
            ))
        }
    }
}

// MARK: - Transparent GroupBox Style

struct TransparentGroupBox: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.content
        }
    }
}
