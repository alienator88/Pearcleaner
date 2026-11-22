//
//  VMContainerView.swift
//  Pearcleaner
//
//  Development view section: lists images, containers, volumes, build cache
//  and VM disks per runtime with real names and sizes. Deleting runs the
//  tool's own CLI (after confirmation), or trashes UTM bundles; file paths
//  reuse the app's FileManagerUndo trash flow.
//

import SwiftUI

struct VMContainerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var consoleManager = GlobalConsoleManager.shared
    @State private var inventory: VMContainerInventory?
    @State private var isScanning = false
    @State private var lastScan: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shippingbox.and.arrow.backward")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("VM and Container Storage")
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    Text("Images, containers, volumes and VM disks from Docker, Colima, Lima, OrbStack, UTM and minikube")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

                Spacer()

                if let total = inventory?.totalBytes, total > 0 {
                    Text("\(formatBytes(total)) on disk")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

                Button(action: scan) {
                    HStack(spacing: 6) {
                        if isScanning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isScanning ? "Scanning..." : "Scan")
                    }
                }
                .disabled(isScanning)
                .controlSize(.small)
                .buttonStyle(.plain)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .controlGroup(Capsule(style: .continuous), level: .primary)
                .help("List VM and container storage")
            }

            if let inventory {
                if inventory.groups.isEmpty {
                    Text("No VM or container tools detected")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .italic()
                } else {
                    ForEach(inventory.groups) { group in
                        if group.items.isEmpty {
                            if let note = group.note {
                                Text("\(group.tool): \(note)")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    .italic()
                            }
                        } else {
                            VMContainerGroupView(group: group) {
                                Task { scanInBackground() }
                            }
                        }
                    }
                }
            } else if isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Scanning runtimes...")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            } else {
                Text("Scan to list images, containers, volumes and VMs")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .italic()
            }
        }
        .padding()
        .background(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.05))
        .cornerRadius(10)
        .task {
            if inventory == nil {
                scan()
            }
        }
    }

    private func scan() {
        guard !isScanning else { return }
        isScanning = true
        scanInBackground()
    }

    private func scanInBackground() {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = VMContainerScanner.scan()
            DispatchQueue.main.async {
                self.inventory = result
                self.isScanning = false
                self.lastScan = Date()
                if !result.groups.isEmpty {
                    GlobalConsoleManager.shared.appendOutput("✓ Scanned VM and container runtimes (\(result.groups.count) tool\(result.groups.count == 1 ? "" : "s") detected)\n", source: CurrentPage.development.title)
                }
            }
        }
    }
}

private struct VMContainerGroupView: View {
    @Environment(\.colorScheme) var colorScheme
    let group: VMContainerGroup
    let onItemDeleted: () -> Void
    @State private var isCollapsed = false

    var body: some View {
        GroupBox {
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(VMContainerGroup.Section.allCases) { section in
                        let sectionItems = group.items.filter { $0.kind == section }
                        if !sectionItems.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.rawValue)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                ForEach(sectionItems) { item in
                                    VMContainerItemRow(item: item) {
                                        onItemDeleted()
                                    }
                                }
                            }
                        }
                    }

                    Text("Deleting a VM disk or volume is irreversible and removes everything inside it. Cleaning docker from inside a VM does not shrink the VM disk file.")
                        .font(.caption2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
                .transition(.opacity)
            }
        }
        .groupBoxStyle(.collapsible(
            icon: group.toolIcon,
            title: group.tool,
            count: group.items.count,
            isCollapsed: isCollapsed,
            onToggle: {
                isCollapsed.toggle()
            }
        ))
    }
}

private struct VMContainerItemRow: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var consoleManager = GlobalConsoleManager.shared
    let item: VMContainerGroup.Item
    let onDeleted: () -> Void
    @State private var confirming = false
    @State private var working = false

    var body: some View {
        HStack(spacing: 10) {
            Text(item.badge)
                .font(.caption2.weight(.medium).monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                .help(item.kind.rawValue)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    if item.isRunning {
                        Text("running")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if item.sizeBytes > 0 {
                Text(formatBytes(item.sizeBytes))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            if let provisioned = item.provisionedBytes, provisioned > item.sizeBytes {
                Text("limit \(formatBytes(provisioned))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }

            if let stopCommand = item.stopCommand, item.isRunning {
                Button("Stop") {
                    runStop(stopCommand)
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .foregroundStyle(.orange)
                .disabled(working)
                .help("Stop \(item.name) through \(item.tool); nothing is deleted")
            }

            if item.hostPath != nil, item.deleteCommand == nil {
                Button("Trash") {
                    trashHostArtifact()
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .foregroundStyle(.red)
                .disabled(item.isRunning)
                .help(item.isRunning ? "Stop the VM before deleting" : "Move the VM disk or bundle to Trash")
            } else if let command = item.deleteCommand {
                Button(item.safety == .cache ? "Clean" : "Delete") {
                    confirming = true
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .foregroundStyle(.red)
                .disabled(item.isRunning)
                .help(deleteHelp)
                .confirmationDialog(
                    item.safety == .cache
                        ? "Remove \(item.name)? It can be re-downloaded later."
                        : "Delete \(item.name)? This is irreversible and everything inside will be lost.",
                    isPresented: $confirming,
                    titleVisibility: .visible
                ) {
                    Button(item.safety == .cache ? "Remove" : "Delete", role: .destructive) {
                        runDelete(command)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    if item.safety == .destructive {
                        Text("VM disks and volumes hold your data (databases, files inside the VM). This cannot be undone.")
                    }
                }
            }

            if working {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var deleteHelp: String {
        switch item.safety {
        case .cache:
            return "Remove \(item.name) through \(item.tool); it can be re-pulled later"
        case .destructive:
            return "Delete \(item.name) through \(item.tool); irreversible"
        }
    }

    private func runStop(_ command: [String]) {
        guard !command.isEmpty else { return }
        working = true
        let itemName = item.name
        let tool = item.tool
        DispatchQueue.global(qos: .userInitiated).async {
            let cli = command[0]
            let args = Array(command.dropFirst())
            // Stopping a VM can take a while to unmount and shut down cleanly.
            let ok = DevEnvProcess.run(cli, args, timeout: 120) != nil
            DispatchQueue.main.async {
                self.working = false
                if ok {
                    GlobalConsoleManager.shared.appendOutput("✓ Stopped \(itemName) via \(tool)\n", source: CurrentPage.development.title)
                    onDeleted()
                } else {
                    GlobalConsoleManager.shared.appendOutput("Failed to stop \(itemName) via \(tool); the CLI exited non-zero or timed out\n", source: CurrentPage.development.title)
                }
            }
        }
    }

    private func runDelete(_ command: [String]) {
        guard !command.isEmpty else { return }
        working = true
        let itemName = item.name
        let tool = item.tool
        DispatchQueue.global(qos: .userInitiated).async {
            let cli = command[0]
            let args = Array(command.dropFirst())
            let ok = DevEnvProcess.run(cli, args, timeout: 60) != nil
            DispatchQueue.main.async {
                self.working = false
                if ok {
                    GlobalConsoleManager.shared.appendOutput("✓ Removed \(itemName) via \(tool)\n", source: CurrentPage.development.title)
                    onDeleted()
                } else {
                    GlobalConsoleManager.shared.appendOutput("Failed to remove \(itemName) via \(tool); the CLI exited non-zero or timed out\n", source: CurrentPage.development.title)
                }
            }
        }
    }

    private func trashHostArtifact() {
        guard let path = item.hostPath else { return }
        let url = URL(fileURLWithPath: path)
        let bundleName = "Development - VM Disk (\(item.name))"
        let result = FileManagerUndo.shared.deleteFiles(at: [url], bundleName: bundleName)
        if result {
            GlobalConsoleManager.shared.appendOutput("✓ Trashed \(path)\n", source: CurrentPage.development.title)
            onDeleted()
        } else {
            GlobalConsoleManager.shared.appendOutput("Failed to trash \(path)\n", source: CurrentPage.development.title)
        }
    }
}