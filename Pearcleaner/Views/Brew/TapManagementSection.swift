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
    @State private var isExpanded: Bool = false
    @State private var isLoadingPackages: Bool = false
    @State private var tapFormulae: [String] = []
    @State private var tapCasks: [String] = []

    var body: some View {
        VStack(spacing: 0) {
        HStack(alignment: .center, spacing: 12) {
            // Tap icon
            ZStack {
                Circle()
                    .fill((tap.isOfficial ? Color.blue : Color.orange).opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: tap.isOfficial ? "mug" : "point.3.filled.connected.trianglepath.dotted")
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

            // See Packages button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }

                if isExpanded {
                    // Load packages after expanding
                    Task {
                        await loadTapPackages()
                    }
                }
            } label: {
                Label(isExpanded ? "Hide Packages" : "See Packages",
                      systemImage: isExpanded ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.borderless)
            .help("View packages in this tap")

            // Remove button
            if isRemoving {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Removing...")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            } else { //if !tap.isOfficial {
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

            // Expanded packages section
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal)

                    if isLoadingPackages {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading packages...")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else if tapFormulae.isEmpty && tapCasks.isEmpty {
                        HStack {
                            Spacer()
                            Text("No packages found in this tap")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            // Show formulae
                            if !tapFormulae.isEmpty {
                                Text("Formulae (\(tapFormulae.count))")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    .padding(.horizontal)

                                ForEach(tapFormulae, id: \.self) { formulaName in
                                    TapPackageRowView(tapName: tap.name, packageName: formulaName, isCask: false)
                                }
                            }

                            // Show casks
                            if !tapCasks.isEmpty {
                                Text("Casks (\(tapCasks.count))")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    .padding(.horizontal)
                                    .padding(.top, tapFormulae.isEmpty ? 0 : 8)

                                ForEach(tapCasks, id: \.self) { caskName in
                                    TapPackageRowView(tapName: tap.name, packageName: caskName, isCask: true)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal)
            }
        }
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
                Task { @MainActor in
                    isRemoving = true
                    defer { isRemoving = false }

                    do {
                        // Always use force flag - leaves packages installed
                        try await HomebrewController.shared.removeTap(name: tap.name, force: true)
                        // Just remove from list instead of reloading all taps
                        brewManager.removeTapFromList(name: tap.name)
                        // Don't reload installed packages - they're still there
                    } catch {
                        printOS("Error removing tap: \(error)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to remove this tap?")
        }
    }

    private func loadTapPackages() async {
        isLoadingPackages = true
        defer { isLoadingPackages = false }

        do {
            let result = try await HomebrewController.shared.getPackagesFromTap(tap.name)
            tapFormulae = result.formulae
            tapCasks = result.casks
        } catch {
            printOS("Error loading packages from tap: \(error)")
            tapFormulae = []
            tapCasks = []
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
        StandardSheetView(
            title: "Add Tap",
            width: 450,
            height: 400,
            onClose: { isPresented = false }
        ) {
            // Content
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

            TextField("user/tap", text: $tapName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ThemeColors.shared(for: colorScheme).secondaryBG)
                )

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } actionButtons: {
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
    }

    private func addTap() {
        errorMessage = ""
        Task {
            isAdding = true
            do {
                try await HomebrewController.shared.addTap(name: tapName)
                await brewManager.loadTaps()

                // Note: No need to update Browse cache - we load names dynamically now

                isPresented = false
            } catch {
                errorMessage = "Failed to add tap: \(error.localizedDescription)"
            }
            isAdding = false
        }
    }
}

// MARK: - Tap Package Row View

struct TapPackageRowView: View {
    let tapName: String
    let packageName: String
    let isCask: Bool
    @EnvironmentObject var brewManager: HomebrewManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isInstalling: Bool = false
    @State private var isUninstalling: Bool = false
    @State private var showInstallAlert: Bool = false
    @State private var showUninstallAlert: Bool = false
    @State private var isHovered: Bool = false

    // Fully-qualified name for installation (e.g., "powershell/tap/powershell")
    private var fullPackageName: String {
        "\(tapName)/\(packageName)"
    }

    private var isAlreadyInstalled: Bool {
        if isCask {
            return brewManager.installedCasks.contains { installedPackage in
                installedPackage.name == packageName
            }
        } else {
            return brewManager.installedFormulae.contains { installedPackage in
                installedPackage.name == packageName
            }
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Package icon (smaller)
            ZStack {
                Circle()
                    .fill((isCask ? Color.purple : Color.green).opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: isCask ? "shippingbox.fill" : "cube.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isCask ? .purple : .green)
            }

            // Package info
            VStack(alignment: .leading, spacing: 2) {
                Text(packageName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            }

            Spacer()

            // Install status/button
            if isInstalling {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Installing...")
                        .font(.caption2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            } else if isUninstalling {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Uninstalling...")
                        .font(.caption2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            } else if isAlreadyInstalled {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("Installed")
                            .font(.caption2)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    // Uninstall button
                    Button {
                        showUninstallAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Uninstall package")
                }
            } else {
                Button("Install") {
                    showInstallAlert = true
                }
                .font(.caption2)
                .buttonStyle(ControlGroupButtonStyle(
                    foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                    shape: Capsule(style: .continuous),
                    level: .primary,
                    skipControlGroup: true
                ))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ?
                    ThemeColors.shared(for: colorScheme).secondaryBG.opacity(0.5) :
                    Color.clear
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .alert("Install \(packageName)?", isPresented: $showInstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Install") {
                Task { @MainActor in
                    isInstalling = true
                    defer { isInstalling = false }

                    do {
                        try await HomebrewController.shared.installPackage(name: fullPackageName, cask: isCask)
                        if isCask {
                            invalidateCaskLookupCache()
                        }
                        await brewManager.loadInstalledPackages()
                    } catch {
                        printOS("Error installing package \(fullPackageName): \(error)")
                    }
                }
            }
        } message: {
            Text("This will install \(packageName) from the tapped repository.")
        }
        .alert("Uninstall \(packageName)?", isPresented: $showUninstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                Task { @MainActor in
                    isUninstalling = true
                    defer { isUninstalling = false }

                    do {
                        try await HomebrewUninstaller.shared.uninstallPackage(name: packageName, cask: isCask)
                        if isCask {
                            invalidateCaskLookupCache()
                        }
                        await brewManager.loadInstalledPackages()
                    } catch {
                        printOS("Error uninstalling package \(packageName): \(error)")
                    }
                }
            }
        } message: {
            Text("This will remove \(packageName) from your system.")
        }
    }
}
