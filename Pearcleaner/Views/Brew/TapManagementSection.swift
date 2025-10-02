//
//  TapManagementSection.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import SwiftUI
import AlinFoundation

struct TapManagementSection: View {
    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @State private var newTapName: String = ""
    @State private var isAddingTap: Bool = false
    @State private var showAddTapSheet: Bool = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with add button
            HStack {
                Text(verbatim: "\(brewManager.availableTaps.count) tap\(brewManager.availableTaps.count == 1 ? "" : "s")")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                if brewManager.isLoadingTaps {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

                Spacer()

                Button {
                    showAddTapSheet = true
                } label: {
                    Label("Add Tap", systemImage: "plus")
                }
                .buttonStyle(ControlGroupButtonStyle(
                    foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                    shape: Capsule(style: .continuous),
                    level: .primary,
                    skipControlGroup: true
                ))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if brewManager.isLoadingTaps {
                VStack(alignment: .center, spacing: 10) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading taps...")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if brewManager.availableTaps.isEmpty {
                VStack(alignment: .center, spacing: 15) {
                    Spacer()
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .font(.system(size: 50))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text("No taps found")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Text("Add a tap to get started")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(brewManager.availableTaps) { tap in
                            TapRowView(tap: tap)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(scrollIndicators ? .automatic : .never)
            }
        }
        .sheet(isPresented: $showAddTapSheet) {
            AddTapSheet(isPresented: $showAddTapSheet)
        }
    }
}

// MARK: - Tap Row View

struct TapRowView: View {
    let tap: HomebrewTapInfo
    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered: Bool = false
    @State private var isRemoving: Bool = false
    @State private var showRemoveAlert: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Tap icon
            ZStack {
                Circle()
                    .fill((tap.isOfficial ? Color.blue : Color.orange).opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: tap.isOfficial ? "homebrew" : "point.3.filled.connected.trianglepath.dotted")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tap.isOfficial ? .blue : .orange)
            }

            // Tap name and details
            VStack(alignment: .leading, spacing: 4) {
                Text(tap.name)
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                HStack(spacing: 6) {
                    if tap.isOfficial {
                        Label("Official", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else {
                        Text("Third-party")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    Text(verbatim: "•")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    Text(verbatim: "\(HomebrewController.shared.getBrewPrefix())/Library/Taps/\(tap.name.replacingOccurrences(of: "/", with: "/homebrew-"))")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Remove button
            if isRemoving {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Removing...")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            } else if !tap.isOfficial {
                Button {
                    showRemoveAlert = true
                } label: {
                    Label("Remove", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Remove tap")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ?
                    ThemeColors.shared(for: colorScheme).secondaryBG.opacity(0.8) :
                    ThemeColors.shared(for: colorScheme).secondaryBG
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .alert("Remove \(tap.name)?", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    isRemoving = true
                    do {
                        try await HomebrewController.shared.removeTap(name: tap.name)
                        await brewManager.loadTaps()
                    } catch {
                        printOS("Error removing tap: \(error)")
                    }
                    isRemoving = false
                }
            }
        } message: {
            Text("Are you sure you want to remove this tap?")
        }
    }
}

// MARK: - Add Tap Sheet

struct AddTapSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @State private var tapName: String = ""
    @State private var isAdding: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add Tap")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                .buttonStyle(.plain)
            }

            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter the tap name to add")
                    .font(.subheadline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                Text("Examples:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "• homebrew/cask-versions")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .monospaced()

                    Text(verbatim: "• user/tap")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .monospaced()

                    Text(verbatim: "• organization/repository")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .monospaced()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ThemeColors.shared(for: colorScheme).secondaryBG)
            )

            // Input field
            TextField("user/tap", text: $tapName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ThemeColors.shared(for: colorScheme).secondaryBG)
                )

            // Error message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(ControlGroupButtonStyle(
                    foregroundColor: ThemeColors.shared(for: colorScheme).secondaryText,
                    shape: Capsule(style: .continuous),
                    level: .secondary,
                    skipControlGroup: true
                ))

                Button(isAdding ? "Adding..." : "Add Tap") {
                    addTap()
                }
                .buttonStyle(ControlGroupButtonStyle(
                    foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                    shape: Capsule(style: .continuous),
                    level: .primary,
                    skipControlGroup: true
                ))
                .disabled(tapName.isEmpty || isAdding)
            }
        }
        .padding(20)
        .frame(width: 450, height: 400)
    }

    private func addTap() {
        errorMessage = ""
        Task {
            isAdding = true
            do {
                try await HomebrewController.shared.addTap(name: tapName)
                await brewManager.loadTaps()
                isPresented = false
            } catch {
                errorMessage = "Failed to add tap: \(error.localizedDescription)"
            }
            isAdding = false
        }
    }
}
