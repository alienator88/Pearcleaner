//
//  LipoView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/20/25.
//

import SwiftUI
import AlinFoundation

struct LipoView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var selectAll: Bool = false
    @State private var selectedApps: Set<String> = []
    @State private var isProcessing: Bool = false
    @State private var savingsAllApps: UInt32 = 0
    @State private var binaryAllApps: UInt32 = 0
    @State private var sliceSizesByPath = [String:(binary: UInt32,savings:UInt32)]()
    @State private var totalSpaceSaved: UInt64 = 0
    @State private var infoSidebar: Bool = false
    @State private var selectedSort: LipoSortOption = .name
    @State private var sizeCalculationTask: Task<Void, Never>?
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.lipo.pruneTranslations") private var prune = false
    @AppStorage("settings.lipo.filterMinSavings") private var filterMinSavings = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.lipo.excludedApps") private var excludedAppsData: Data = Data()

    enum LipoSortOption: String, CaseIterable {
        case name = "Name"
        case savings = "Savings Size"
        case binary = "Binary Size"
        
        var systemImage: String {
            switch self {
            case .name: return "list.bullet"
            case .savings: return "arrow.down.circle"
            case .binary: return "doc.circle"
            }
        }
    }

    // Change to a computed property without setter
    private var excludedApps: Set<String> {
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: excludedAppsData) {
            return decoded
        }
        return Set<String>()
    }

    // Add helper methods for excluded apps management
    private func addToExcluded(_ apps: Set<String>) {
        var current = excludedApps
        current.formUnion(apps)
        if let encoded = try? JSONEncoder().encode(current) {
            excludedAppsData = encoded
        }
    }

    // Rename the helper method to avoid conflict
    private func removeAppFromExcluded(_ appPath: String) {
        var current = excludedApps
        current.remove(appPath)
        if let encoded = try? JSONEncoder().encode(current) {
            excludedAppsData = encoded
        }
        calculateAllSizes() // Recalculate after removal
    }

    // Filter and sort the apps
    var universalApps: [AppInfo] {
        let filtered = appState.sortedApps.filter { $0.arch == .universal && !excludedApps.contains($0.path.path) }
        
        var result = filtered
        if filterMinSavings {
            // Only apply the filter if we have size data calculated
            if !sliceSizesByPath.isEmpty {
                result = filtered.filter { app in
                    if let sizes = sliceSizesByPath[app.path.path] {
                        return sizes.savings >= 1024 * 1024 // 1MB in bytes
                    }
                    return false
                }
            } else {
                // Return all apps while sizes are being calculated
                result = filtered
            }
        }
        
        // Apply sorting
        return result.sorted { app1, app2 in
            switch selectedSort {
            case .name:
                return app1.appName.localizedCaseInsensitiveCompare(app2.appName) == .orderedAscending
            case .savings:
                let savings1 = sliceSizesByPath[app1.path.path]?.savings ?? 0
                let savings2 = sliceSizesByPath[app2.path.path]?.savings ?? 0
                return savings1 > savings2 // Descending order for savings
            case .binary:
                let binary1 = sliceSizesByPath[app1.path.path]?.binary ?? 0
                let binary2 = sliceSizesByPath[app2.path.path]?.binary ?? 0
                return binary1 > binary2 // Descending order for binary size
            }
        }
    }

    var body: some View {
        ZStack {

            VStack(alignment: .leading, spacing: 0) {

                HStack(alignment: .center, spacing: 15) {
                    VStack(alignment: .leading){
                        Text("Lipo").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title).fontWeight(.bold)
                        Text("Remove unused architectures from your app binaries to reduce app size")
                            .font(.callout).foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    Spacer()
                    
                    // Sort dropdown menu
                    Menu {
                        ForEach(LipoSortOption.allCases, id: \.self) { sortOption in
                            Button {
                                selectedSort = sortOption
                            } label: {
                                Label(sortOption.rawValue, systemImage: sortOption.systemImage)
                            }
                        }
                    } label: {
                        Label(selectedSort.rawValue, systemImage: selectedSort.systemImage)
                    }
                    .buttonStyle(ControlGroupButtonStyle(
                        foregroundColor: ThemeColors.shared(for: colorScheme).primaryText,
                        shape: Capsule(style: .continuous),
                        level: .secondary
                    ))
                }

                VStack(alignment: .leading, spacing: 0) {

                    // Add this section back - the main app list content
                    if universalApps.isEmpty {
                        VStack {
                            Spacer()
                            Text("No universal apps found")
                                .font(.title2)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        HStack {
                            Toggle(isOn: $selectAll) {}
                                .toggleStyle(SimpleCheckboxToggleStyle())
                                .padding()
                                .onChange(of: selectAll) { newValue in
                                    if newValue {
                                        selectedApps = Set(universalApps.map { $0.path.path })
                                    } else {
                                        selectedApps.removeAll()
                                    }
                                }

                            Spacer()

                            LipoLegend()
                                .padding()

                        }

                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(universalApps, id: \.path) { app in
                                    if let sizes = sliceSizesByPath[app.path.path] {
                                        AppRowView(
                                            app: app,
                                            selectedApps: $selectedApps,
                                            savingsSize: sizes.savings,
                                            binarySize: sizes.binary
                                        )
                                    }
                                }
                            }
                        }
                        .scrollIndicators(scrollIndicators ? .automatic : .never)
                        .padding(.bottom)
                    }

                    HStack(spacing: 10) {
                        // Left side - Total savings with fixed width
                        Text("\(selectedApps.count) / \(universalApps.count)")
                            .font(.footnote)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .frame(minWidth: 80, alignment: .leading)

                        Spacer()

                        // Center - Exclude and Start Lipo buttons
                        HStack(spacing: 8) {
                            Button {
                                excludeSelectedApps()
                            } label: {
                                Label {
                                    Text("Exclude")
                                } icon: {
                                    Image(systemName: "minus.circle")
                                }
                                .frame(minWidth: 80)
                            }
                            .disabled(selectedApps.isEmpty)
                            .buttonStyle(ControlGroupButtonStyle(
                                foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                shape: Capsule(style: .continuous),
                                skipControlGroup: true,
                                disabled: selectedApps.isEmpty
                            ))

                            Divider().frame(height: 10)

                            Button {
                                startLipo()
                            } label: {
                                if !isProcessing {
                                    Label {
                                        Text("Start Lipo")
                                    } icon: {
                                        Image(systemName: "scissors")
                                    }
                                    .frame(minWidth: 100)
                                }else {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .frame(minWidth: 100)
                                }
                            }
                            .disabled(selectedApps.isEmpty)
                            .buttonStyle(ControlGroupButtonStyle(
                                foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                shape: Capsule(style: .continuous),
                                skipControlGroup: true,
                                disabled: selectedApps.isEmpty
                            ))
                        }
                        .controlGroup(Capsule(style: .continuous), level: .secondary)

                        Spacer()

                        Button {
                            infoSidebar.toggle()
                        } label: {
                            Image(systemName: "sidebar.trailing")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                        }
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .buttonStyle(.borderless)
                        .transition(.move(edge: .trailing))
                        .help("See lipo details")
                    }
                }
            }
            .blur(radius: infoSidebar ? 2 : 0)

            // Add the sidebar view
            LipoSidebarView(infoSidebar: $infoSidebar, excludedApps: excludedApps, prune: $prune, filterMinSavings: $filterMinSavings, onRemoveExcluded: removeAppFromExcluded, totalSpaceSaved: totalSpaceSaved, savingsAllApps: savingsAllApps)
        }
        .animation(.easeInOut(duration: animationEnabled ? 0.35 : 0), value: infoSidebar)
        .frame(maxWidth: .infinity)
        .padding(20)
        .onAppear { 
            calculateAllSizes() 
        }
        .onDisappear {
            sizeCalculationTask?.cancel()
            sizeCalculationTask = nil
        }
    }

    private func excludeSelectedApps() {
        addToExcluded(selectedApps)
        selectedApps.removeAll()
        calculateAllSizes() // Recalculate after exclusion
    }

    private func startLipo() {
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            var totalPreSize: UInt64 = 0
            var totalPostSize: UInt64 = 0

            for app in universalApps where selectedApps.contains(app.path.path) {
                let (success, sizes) = thinAppBundleArchitecture(at: app.path, of: app.arch, multi: true)
                if success, let sizes = sizes {
                    totalPreSize += sizes["pre"] ?? 0
                    totalPostSize += sizes["post"] ?? 0
                    totalSpaceSaved += (sizes["pre"] ?? 0) - (sizes["post"] ?? 0)
                }
                // Prune languages if enabled
                if prune {
                    do {
                        try pruneLanguages(in: app.path.path)
                    } catch {
                        printOS("Translation prune error: \(error)")
                    }
                }
            }



            let overallSavings = totalPreSize > 0 ? Int((Double(totalPreSize - totalPostSize) / Double(totalPreSize)) * 100) : 0

            let titleFormat = NSLocalizedString("Space Savings: %d%%\nTotal Space Saved: %@", comment: "Lipo completion title")
            let messageFormat = NSLocalizedString("The total space savings between all the lipo'd apps\nSize Before: %@\nSize After: %@", comment: "Lipo completion message")

            let title = String(format: titleFormat, overallSavings, formatByte(size: Int64(totalSpaceSaved)).human)
            let message = String(format: messageFormat, formatByte(size: Int64(totalPreSize)).human, formatByte(size: Int64(totalPostSize)).human)


            DispatchQueue.main.async {
                showCustomAlert(title: title, message: message, style: .informational)
            }
            isProcessing = false
        }
    }

    private func calculateAllSizes() {
        // Cancel any existing task
        sizeCalculationTask?.cancel()
        
        sizeCalculationTask = Task {
            let apps = self.universalApps // Capture apps at start to avoid accessing changing state
            var temp = [String:(UInt32,UInt32)]()
            
            for app in apps {
                // Check for cancellation
                guard !Task.isCancelled else {
                    printOS("Size calculation task was cancelled")
                    return
                }
                
                // Add safety checks
                guard let execURL = app.executableURL else {
                    printOS("Warning: No executable URL for app: \(app.appName)")
                    continue
                }
                
                guard FileManager.default.fileExists(atPath: execURL.path) else {
                    printOS("Warning: Executable not found for app: \(app.appName) at path: \(execURL.path)")
                    continue
                }
                
                do {
                    if let sizes = try getArchitectureSliceSizes(from: execURL.path) {
                        temp[app.path.path] = (sizes.full, isOSArm() ? sizes.intel : sizes.arm)
                    }
                } catch {
                    printOS("Error calculating sizes for \(app.appName): \(error)")
                }
            }
            
            // Final cancellation check before updating UI
            guard !Task.isCancelled else {
                printOS("Size calculation task was cancelled before UI update")
                return
            }
            
            // Update UI on main thread
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.sliceSizesByPath = temp
                self.savingsAllApps = temp.values.reduce(0) { $0 + $1.1 }
                self.binaryAllApps = temp.values.reduce(0) { $0 + $1.0 }
            }
        }
    }
}



struct AppRowView: View {
    @Environment(\.colorScheme) var colorScheme
    let app: AppInfo
    @Binding var selectedApps: Set<String>
    let savingsSize: UInt32
    let binarySize: UInt32
    @State private var sizeLoading: Bool = true
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"

    var body: some View {
        HStack(spacing: 15) {
            Toggle(isOn: Binding(
                get: { selectedApps.contains(app.path.path) },
                set: { isSelected in
                    if isSelected {
                        selectedApps.insert(app.path.path)
                    } else {
                        selectedApps.remove(app.path.path)
                    }
                }
            )) {
                EmptyView()
            }
            .toggleStyle(SimpleCheckboxToggleStyle())

            VStack {
                HStack {

                    if let icon = app.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }

                    Text(app.appName).font(.title3)

                    Divider()

                    Text(verbatim: "\(formatByte(size: Int64(app.bundleSize)).human)")
                        .font(.caption)
                        .help("Full app size")

                    Divider()

                    if binarySize > 0 && savingsSize > 0 {
                        Text("**\(Int((Double(savingsSize) / Double(binarySize)) * 100))%** savings")
                            .font(.footnote)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    Spacer()

                    HStack {
                        Text(verbatim: "\(formatByte(size: Int64(savingsSize)).human)")
                            .foregroundStyle(.green)
                            .padding(.trailing, 30)
                            .frame(minWidth: 50, alignment: .leading)

                        Text(verbatim: "\(formatByte(size: Int64(binarySize)).human)")
                            .foregroundStyle(.orange)
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                    .font(.callout)


                }

                HorizontalSizeBarView(binarySize: binarySize, savingsSize: savingsSize)
                    .frame(maxWidth: .infinity)


            }

        }
        .padding()
        .background(ThemeColors.shared(for: colorScheme).secondaryBG.clipShape(RoundedRectangle(cornerRadius: 8)))
        .onTapGesture {
            NSWorkspace.shared.selectFile(app.path.path, inFileViewerRootedAtPath: app.path.deletingLastPathComponent().path)
        }
    }
}



struct HorizontalSizeBarView: View {
    let binarySize: UInt32
    let savingsSize: UInt32
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let binaryWidth = totalWidth * (Double(binarySize) / Double(binarySize))
            let savingsWidth = binaryWidth * (Double(savingsSize) / Double(binarySize))

            RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                .frame(width: .infinity, height: 4)
                .padding(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4).strokeBorder(ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.5), lineWidth: 1),
                    alignment: .center
                )
                .overlay (
                    RoundedRectangle(cornerRadius: 4).fill(Color.green)
                        .frame(width: savingsWidth, height: 4)
                        .padding(2),
                    alignment: .leading
                )
        }
    }
}



public func getArchitectureSliceSizes(from executablePath: String) throws -> (arm: UInt32, intel: UInt32, full: UInt32)? {
    guard !executablePath.isEmpty else {
        throw NSError(domain: "LipoError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty executable path"])
    }
    
    let fileURL = URL(fileURLWithPath: executablePath)
    let fileData = try Data(contentsOf: fileURL)
    
    guard fileData.count >= 8 else {
        throw NSError(domain: "LipoError", code: 2, userInfo: [NSLocalizedDescriptionKey: "File too small to contain valid header"])
    }
    
    let fullSize = UInt32(fileData.count)
    let FAT_MAGIC: UInt32 = 0xcafebabe
    
    let header = try fileData.subdata(in: 0..<8).withUnsafeBytes { ptr -> FatHeader in
        guard ptr.count >= 8 else {
            throw NSError(domain: "LipoError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Insufficient data for header"])
        }
        return FatHeader(
            magic: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
            numArchitectures: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian
        )
    }

    var armSize: UInt32 = 0
    var intelSize: UInt32 = 0

    if header.magic == FAT_MAGIC {
        guard header.numArchitectures > 0 && header.numArchitectures < 100 else {
            throw NSError(domain: "LipoError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid number of architectures"])
        }
        
        var offset = 8
        for _ in 0..<header.numArchitectures {
            let endOffset = offset + 20
            guard endOffset <= fileData.count else {
                throw NSError(domain: "LipoError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Architecture data extends beyond file"])
            }
            
            let arch = try fileData.subdata(in: offset..<endOffset).withUnsafeBytes { ptr -> FatArch in
                guard ptr.count >= 20 else {
                    throw NSError(domain: "LipoError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Insufficient data for architecture"])
                }
                return FatArch(
                    cpuType: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                    cpuSubtype: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian,
                    offset: ptr.load(fromByteOffset: 8, as: UInt32.self).bigEndian,
                    size: ptr.load(fromByteOffset: 12, as: UInt32.self).bigEndian,
                    align: ptr.load(fromByteOffset: 16, as: UInt32.self).bigEndian
                )
            }

            if arch.cpuType == 0x100000C {
                armSize = arch.size
            } else if arch.cpuType == 0x01000007 {
                intelSize = arch.size
            }
            offset += 20
        }
    } else {
        // For a lipo'd binary, assume the whole file is the slice.
        guard fileData.count >= 8 else {
            return (arm: 0, intel: 0, full: fullSize)
        }
        
        let cpuType = fileData.subdata(in: 4..<8).withUnsafeBytes { 
            $0.count >= 4 ? $0.load(as: UInt32.self).bigEndian : 0
        }
        if cpuType == 0x100000C {
            armSize = fullSize
        } else if cpuType == 0x01000007 {
            intelSize = fullSize
        }
    }

    return (arm: armSize, intel: intelSize, full: fullSize)
}
