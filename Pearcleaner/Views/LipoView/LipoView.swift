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
    @State private var savingsAllApps: UInt64 = 0
    @State private var bundleAllApps: UInt64 = 0
    @State private var sliceSizesByPath = [String:(bundle: UInt64,savings:UInt64)]()
    @State private var totalSpaceSaved: UInt64 = 0
    @State private var infoSidebar: Bool = false
    @State private var selectedSort: LipoSortOption = .name
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.lipo.pruneTranslations") private var prune = false
    @AppStorage("settings.lipo.filterMinSavings") private var filterMinSavings = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.lipo.excludedApps") private var excludedAppsData: Data = Data()

    enum LipoSortOption: String, CaseIterable {
        case name = "Name"
        case savings = "Savings Size"
        case binary = "Bundle Size"
        
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
        // Sizes will be recalculated per-app on-demand
    }

    // Filter and sort the apps (Note: "universalApps" name is legacy - now includes all apps)
    var universalApps: [AppInfo] {
        // Show all apps since our new bundle thinning can find savings even in apps
        // whose main executable isn't universal (frameworks, plugins, etc. might be)
        let filtered = appState.sortedApps.filter { !excludedApps.contains($0.path.path) }
        
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
                let bundle1 = UInt64(app1.bundleSize)
                let bundle2 = UInt64(app2.bundleSize)
                return bundle1 > bundle2 // Descending order for bundle size
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
                            Text("No apps available for thinning")
                                .font(.title2)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        HStack {
                            Toggle(isOn: $selectAll) {}
                                .toggleStyle(SimpleCheckboxToggleStyle())
                                .padding(.vertical)
                                .onChange(of: selectAll) { newValue in
                                    if newValue {
                                        selectedApps = Set(universalApps.map { $0.path.path })
                                    } else {
                                        selectedApps.removeAll()
                                    }
                                }

                            Spacer()

                            LipoLegend()
                                .padding(.vertical)

                        }

                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(universalApps, id: \.path) { app in
                                    LipoAppRowView(
                                        app: app,
                                        selectedApps: $selectedApps,
                                        sliceSizesByPath: $sliceSizesByPath,
                                        savingsAllApps: $savingsAllApps,
                                        bundleAllApps: $bundleAllApps
                                    )
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
        .animation(animationEnabled ? .spring(response: 0.35, dampingFraction: 0.8) : .none, value: infoSidebar)
        .frame(maxWidth: .infinity)
        .padding(20)
        .onAppear { 
            // Sizes will be calculated per-app on-demand
        }
        .onDisappear {
            // No background tasks to cancel with per-app calculation
        }
    }

    private func excludeSelectedApps() {
        addToExcluded(selectedApps)
        selectedApps.removeAll()
        // Sizes will be recalculated per-app on-demand
    }

    private func startLipo() {
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            var totalPreSize: UInt64 = 0
            var totalPostSize: UInt64 = 0

            for app in universalApps where selectedApps.contains(app.path.path) {
                // Use the updated thinAppBundleArchitecture function with multi=true
                let (success, sizes) = thinAppBundleArchitecture(at: app.path, of: app.arch, multi: true)
                if success, let sizes = sizes {
                    totalPreSize += sizes["pre"] ?? 0
                    totalPostSize += sizes["post"] ?? 0
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

            let actualSpaceSaved = totalPreSize - totalPostSize
            let title = String(format: titleFormat, overallSavings, formatByte(size: Int64(actualSpaceSaved)).human)
            let message = String(format: messageFormat, formatByte(size: Int64(totalPreSize)).human, formatByte(size: Int64(totalPostSize)).human)

            DispatchQueue.main.async {
                self.totalSpaceSaved += actualSpaceSaved
                showCustomAlert(title: title, message: message, style: .informational)
                self.isProcessing = false
            }
        }
    }

    // Old bulk calculation function removed - now using per-app calculation
}



// New per-app row view that calculates bundle savings on-demand
struct LipoAppRowView: View {
    @Environment(\.colorScheme) var colorScheme
    let app: AppInfo
    @Binding var selectedApps: Set<String>
    @Binding var sliceSizesByPath: [String:(bundle: UInt64,savings:UInt64)]
    @Binding var savingsAllApps: UInt64
    @Binding var bundleAllApps: UInt64
    @State private var isCalculating: Bool = false
    @State private var calculatedSavings: UInt64?
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"

    var body: some View {
        HStack(spacing: 15) {
            appToggle
            appContentView
        }
        .onAppear {
            // Check if we already have savings calculated
            if let existingSizes = sliceSizesByPath[app.path.path] {
                calculatedSavings = existingSizes.savings
            } else if !isCalculating {
                // Automatically calculate when row appears in view
                calculateBundleSavings()
            }
        }
    }
    
    private var appToggle: some View {
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
    }
    
    private var appContentView: some View {
        VStack {
            HStack {
                appIconAndName
                Divider()
                appSizeInfo
                Divider()
                savingsPercentage
                Spacer()
                sizesDisplay
            }
            .padding()
        }
        .background(ThemeColors.shared(for: colorScheme).secondaryBG)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var appIconAndName: some View {
        HStack {
            if let icon = app.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
            Text(app.appName).font(.title3)
        }
    }
    
    private var appSizeInfo: some View {
        Text(verbatim: "\(formatByte(size: Int64(app.bundleSize)).human)")
            .font(.caption)
            .help("Full app size")
    }
    
    @ViewBuilder
    private var savingsPercentage: some View {
        if let savings = calculatedSavings {
            if app.bundleSize > 0 && savings > 0 {
                Text("**\(Int((Double(savings) / Double(app.bundleSize)) * 100))%** savings")
                    .font(.footnote)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
        }
    }
    
    @ViewBuilder
    private var sizesDisplay: some View {
        HStack {
            if let savings = calculatedSavings {
                Text(verbatim: "\(formatByte(size: Int64(savings)).human)")
                    .foregroundStyle(.green)
//                    .frame(minWidth: 100, alignment: .leading)
                    .help("Potential savings from bundle thinning")
            } else if isCalculating {
                Text("Calculating...")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
//                    .frame(minWidth: 100, alignment: .leading)
            } else {
                Text("0 bytes")
                    .foregroundStyle(.green)
//                    .frame(minWidth: 100, alignment: .leading)
                    .help("No savings available from bundle thinning")
            }
        }
    }
    
    private func calculateBundleSavings() {
        isCalculating = true
        
        Task {
            // Use our new bundle thinning approach to calculate potential savings
            let bundlePath = app.path
            let savings = await calculateBundleSavings(at: bundlePath)
            
            await MainActor.run {
                let wasAlreadyCalculated = calculatedSavings != nil
                calculatedSavings = savings
                
                // Update the shared state (always, even for 0 savings)
                sliceSizesByPath[app.path.path] = (bundle: UInt64(app.bundleSize), savings: savings)
                
                // Update totals (only add if not already counted)
                if !wasAlreadyCalculated {
                    savingsAllApps += savings
                    bundleAllApps += UInt64(app.bundleSize)
                }
                
                isCalculating = false
            }
        }
    }
    
    private func calculateBundleSavings(at bundlePath: URL) async -> UInt64 {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                // Use the same function as actual lipo operation, but in dry-run mode
                let (success, sizes) = thinAppBundleArchitecture(at: bundlePath, of: app.arch, multi: true, dryRun: true)

                if success, let sizes = sizes {
                    let preSize = sizes["pre"] ?? 0
                    let postSize = sizes["post"] ?? 0
                    let savings = preSize > postSize ? preSize - postSize : 0
                    continuation.resume(returning: savings)
                } else {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
}






