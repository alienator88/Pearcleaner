//
//  ZombieView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 2/26/24.
//

import Foundation
import SwiftUI
import AlinFoundation

struct ZombieView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @State private var showPop: Bool = false
    @State private var windowController = WindowManager()
    @AppStorage("settings.general.leftoverWarning") private var warning: Bool = false
    @State private var showAlert = false
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.general.selectedSort") var selectedSort: SortOptionList = .name
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @AppStorage("settings.general.confirmAlert") private var confirmAlert: Bool = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @Binding var search: String
    @State private var searchZ: String = ""
    @State private var selectedZombieItemsLocal: Set<URL> = []
    @State private var memoizedFiles: [URL] = []
    @State private var lastSearchTermUsed: String? = nil
    @State private var totalRealSize: Int64 = 0
    @State private var totalLogicalSize: Int64 = 0
    @State private var totalRealSizeUninstallBtn: String = ""
    @State private var totalLogicalSizeUninstallBtn: String = ""
    @State private var infoSidebar: Bool = false
    @State private var lastRefreshDate: Date?
    @State private var isRefreshing: Bool = false
    @State private var currentSearcher: ReversePathsSearcher?

    var body: some View {

        VStack(alignment: .center) {
            ZStack {
                    VStack(spacing: 0) {

                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                            TextField("Search...", text: $searchZ)
                                .onChange(of: searchZ) { newValue in
                                    updateMemoizedFiles(for: newValue, sizeType: sizeType, selectedSort: selectedSort)
                                }
                                .textFieldStyle(.plain)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                            if !searchZ.isEmpty {
                                Button {
                                    searchZ = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                        .controlGroup(Capsule(style: .continuous), level: .primary)
                        .padding(.top, 5)

                        // Stats header
                        HStack {
                            Text("\(memoizedFiles.count) file\(memoizedFiles.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                            if appState.showProgress {
                                Text("• Scanning...")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                ProgressView().controlSize(.mini)
                            }

                            Spacer()

                            if let lastRefresh = lastRefreshDate {
                                Text("Updated \(formatRelativeTime(lastRefresh))")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }
                        }
                        .padding(.vertical)

                        if !memoizedFiles.isEmpty {
                            ScrollView() {
                                LazyVStack(spacing: 8) {
                                    ForEach(memoizedFiles, id: \.self) { file in
                                        if let fileSize = appState.zombieFile.fileSize[file], let fileSizeL = appState.zombieFile.fileSizeLogical[file], let fileIcon = appState.zombieFile.fileIcon[file], let iconImage = fileIcon.map(Image.init(nsImage:)) {
                                            ZombieFileDetailsItem(size: fileSize, sizeL: fileSizeL, icon: iconImage, path: file, memoizedFiles: $memoizedFiles, isSelected: self.binding(for: file))
                                        }
                                    }

                                }
                            }
                            .scrollIndicators(scrollIndicators ? .automatic : .never)
                        } else if !appState.showProgress {
                            VStack {
                                Spacer()
                                Text("No orphaned files found")
                                    .font(.title2)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }

                        if appState.trashError {
                            InfoButton(text: "A trash error has occurred, please open the debug window(⌘+D) to see what went wrong or try again", color: .orange, label: "View Error", warning: true, extraView: {
                                Button("View Debug Window") {
                                    windowController.open(with: ConsoleView(), width: 600, height: 400)
                                }
                            })
                            .onDisappear {
                                appState.trashError = false
                            }
                            .padding(.bottom)
                        }
                    }
                    .opacity(infoSidebar ? 0.5 : 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, !selectedZombieItemsLocal.isEmpty ? 10 : 20)
                    .safeAreaInset(edge: .bottom) {
                        if !selectedZombieItemsLocal.isEmpty {
                            HStack {
                                Spacer()

                                HStack(spacing: 10) {
                                    Button(selectedZombieItemsLocal.count == memoizedFiles.count ? "Deselect All" : "Select All") {
                                        if selectedZombieItemsLocal.count == memoizedFiles.count {
                                            selectedZombieItemsLocal.removeAll()
                                        } else {
                                            selectedZombieItemsLocal = Set(memoizedFiles)
                                        }
                                        updateTotalSizes()
                                    }
                                    .buttonStyle(ControlGroupButtonStyle(
                                        foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                        shape: Capsule(style: .continuous),
                                        level: .primary,
                                        skipControlGroup: true
                                    ))

                                    Divider().frame(height: 10)

                                    Menu {
                                        Button("Exclude \(selectedZombieItemsLocal.count) Selected") {
                                            excludeAllSelectedItems()
                                        }
                                        .help("This will exclude selected items from future scans. Exclusion list can be edited from Settings > Folders tab or the sidebar in this view.")

                                        Menu("Link Selected to App") {
                                            ForEach(appState.sortedApps, id: \.id) { app in
                                                Button(app.appName) {
                                                    linkSelectedItemsToApp(app.path)
                                                }
                                            }
                                        }
                                        .help("Link all selected items to the chosen app and remove from orphan scans.")
                                    } label: {
                                        Text("Actions")
                                    }
                                    .buttonStyle(ControlGroupButtonStyle(
                                        foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                        shape: Capsule(style: .continuous),
                                        level: .primary,
                                        skipControlGroup: true
                                    ))

                                    Divider().frame(height: 10)

                                    Button {
                                        handleUninstallAction()
                                    } label: {
                                        Label {
                                            Text("Delete \(selectedZombieItemsLocal.count) Selected")
                                        } icon: {
                                            Image(systemName: "trash")
                                        }
                                    }
                                    .buttonStyle(ControlGroupButtonStyle(
                                        foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                        shape: Capsule(style: .continuous),
                                        level: .primary,
                                        skipControlGroup: true
                                    ))
                                }
                                .controlGroup(Capsule(style: .continuous), level: .primary)

                                Spacer()
                            }
                            .padding([.horizontal, .bottom])
                        }
                    }

                    ZombieSidebarView(
                        infoSidebar: $infoSidebar,
                        displaySizeTotal: displaySizeTotal,
                        selectedCount: selectedZombieItemsLocal.count,
                        totalCount: memoizedFiles.count,
                        fsm: fsm,
                        memoizedFiles: $memoizedFiles,
                        onRestoreFile: restoreFileToZombieList
                    )
            }
            .animation(animationEnabled ? .spring(response: 0.35, dampingFraction: 0.8) : .none, value: infoSidebar)
            .transition(.opacity)
            .onAppear {
                if lastRefreshDate == nil {
                    lastRefreshDate = Date()
                }
            }
            .onChange(of: appState.zombieFile.fileSize) { _ in
                // Update memoized files whenever new files are added
                updateMemoizedFiles(for: searchZ, sizeType: sizeType, selectedSort: selectedSort, force: true)
            }
            .sheet(isPresented: $showAlert, content: {
                    VStack(spacing: 10) {
                        Text("Important")
                            .font(.headline)
                        Divider()
                        Spacer()
                        Text("Orphaned file search is not 100% accurate as it doesn't have any uninstalled app bundles to check against for file exclusion. This does a best guess search for files/folders and excludes the ones that have overlap with your currently installed applications. Please confirm files marked for deletion really do belong to uninstalled applications.")
                            .font(.subheadline)
                        Spacer()
                        Button("Close") {
                            warning = true
                            showAlert = false
                            // Start the file scan after user acknowledges the warning
                            startFileScan()
                        }
                        .buttonStyle(SimpleButtonStyle(icon: "x.circle.fill", label: String(localized: "Close"), help: String(localized: "Dismiss")))
                        Spacer()
                    }
                    .padding(15)
                    .frame(width: 400, height: 250)
                    .background(GlassEffect(material: .hudWindow, blendingMode: .behindWindow))
                })
        }
        .onAppear {
            if !warning {
                showAlert = true
            } else {
                // Only trigger scan if warning has been acknowledged
                startFileScan()
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            TahoeToolbarItem(placement: .navigation) {
                VStack(alignment: .leading){
                    Text("Orphaned Files").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2).fontWeight(.bold)
                    Text("Remaining files and folders from previous applications")
                        .font(.callout).foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }


            ToolbarItem { Spacer() }

            TahoeToolbarItem(isGroup: true) {
                Menu {
                    ForEach(SortOptionList.allCases, id: \.self) { sortOption in
                        Button {
                            selectedSort = sortOption
                            updateMemoizedFiles(for: searchZ, sizeType: sizeType, selectedSort: selectedSort, force: true)
                        } label: {
                            Label(sortOption.title, systemImage: sortOption.systemImage)
                        }
                    }
                } label: {
                    Label(selectedSort.title, systemImage: selectedSort.systemImage)
                }
                .labelStyle(.titleAndIcon)

                if appState.showProgress {
                    Button {
                        stopSearch()
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                } else {
                    Button {
                        startSearch()
                    } label: {
                        Label("Refresh", systemImage: "arrow.counterclockwise")
                    }
                }

                Button {
                    infoSidebar.toggle()
                } label: {
                    Label("Info", systemImage: "sidebar.trailing")
                }
                .help("See details")
            }


        }

    }

    private func startSearch() {
        updateOnMain {
            appState.zombieFile = .empty
            appState.showProgress = true
            selectedZombieItemsLocal.removeAll()

            let searcher = ReversePathsSearcher(appState: appState, locations: locations, fsm: fsm, sortedApps: appState.sortedApps, streamingMode: true)
            currentSearcher = searcher

            searcher.reversePathsSearch {
                updateOnMain {
                    self.lastRefreshDate = Date()
                    self.currentSearcher = nil
                }
            }
        }
    }

    private func stopSearch() {
        currentSearcher?.stop()
        updateOnMain {
            appState.showProgress = false
            currentSearcher = nil
        }
    }

    private func startFileScan() {
        startSearch()
    }

    private func handleUninstallAction() {
        showCustomAlert(enabled: confirmAlert, title: String(localized: "Warning"), message: String(localized: "Are you sure you want to remove these files?"), style: .warning, onOk: {
            Task {

                let selectedItemsArray = Array(selectedZombieItemsLocal)

                let result = moveFilesToTrash(appState: appState, at: selectedItemsArray)
                if result {

                    if selectedZombieItemsLocal.count == appState.zombieFile.fileSize.keys.count {
                        updateOnMain {
                            appState.zombieFile = .empty
                            search = ""
                            searchZ = ""
                            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                appState.currentView = .empty
                            }

                        }
                    } else {
                        // Remove items from the list
                        appState.zombieFile.fileSize = appState.zombieFile.fileSize.filter { !selectedZombieItemsLocal.contains($0.key) }
                        appState.zombieFile.fileSizeLogical = appState.zombieFile.fileSizeLogical.filter { !selectedZombieItemsLocal.contains($0.key) }
                        appState.zombieFile.fileIcon = appState.zombieFile.fileIcon.filter { !selectedZombieItemsLocal.contains($0.key) }

                        // Clear the selection
                        selectedZombieItemsLocal.removeAll()

                        // Update memoized files and total sizes
                        updateMemoizedFiles(for: searchZ, sizeType: sizeType, selectedSort: selectedSort, force: true)
                    }
                }

            }

        })
    }

    private func binding(for file: URL) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                // Only return true if the file is both selected AND still in memoizedFiles
                self.selectedZombieItemsLocal.contains(file) && memoizedFiles.contains(file)
            },
            set: { isSelected in
                if isSelected {
                    // Only allow selection if the file is in memoizedFiles
                    if memoizedFiles.contains(file) {
                        self.selectedZombieItemsLocal.insert(file)
                    }
                } else {
                    self.selectedZombieItemsLocal.remove(file)
                }
                updateTotalSizes()
            }
        )
    }

    // The "Select All" toggle binding
    private var selectAllBinding: Binding<Bool> {
        Binding(
            get: {
                if searchZ.isEmpty {
                    return selectedZombieItemsLocal.count == appState.zombieFile.fileSize.count
                } else {
                    // Only consider files that are currently in memoizedFiles
                    let currentlyVisibleFiles = Set(memoizedFiles)
                    let selectedVisibleFiles = selectedZombieItemsLocal.intersection(currentlyVisibleFiles)
                    return !currentlyVisibleFiles.isEmpty && selectedVisibleFiles.count == currentlyVisibleFiles.count
                }
            },
            set: { newValue in
                if newValue {
                    // Only select files that are currently in memoizedFiles
                    selectedZombieItemsLocal = Set(memoizedFiles)
                } else {
                    // Only deselect files that are currently in memoizedFiles
                    let filesToDeselect = Set(memoizedFiles)
                    selectedZombieItemsLocal.subtract(filesToDeselect)
                }
                updateTotalSizes()
            }
        )
    }


    private func updateMemoizedFiles(for searchTerm: String, sizeType: String, selectedSort: SortOptionList, force: Bool = false) {
        if !force && searchTerm == lastSearchTermUsed && self.sizeType == sizeType && self.selectedSort == selectedSort {
            return
        }

        let results = filterAndSortFiles(for: searchTerm, sizeType: sizeType, selectedSort: selectedSort)
        memoizedFiles = results.files
        totalRealSize = results.totalRealSize
        totalLogicalSize = results.totalLogicalSize
        lastSearchTermUsed = searchTerm
        self.sizeType = sizeType
        self.selectedSort = selectedSort
        updateTotalSizes()
    }

    private func filterAndSortFiles(for searchTerm: String, sizeType: String, selectedSort: SortOptionList) -> (files: [URL], totalRealSize: Int64, totalLogicalSize: Int64) {
        let fileSizeReal = appState.zombieFile.fileSize
        let fileSizeLogical = appState.zombieFile.fileSizeLogical

        let filteredFilesReal = fileSizeReal.filter { url, _ in searchTerm.isEmpty || url.lastPathComponent.localizedCaseInsensitiveContains(searchTerm) }
        let filteredFilesLogical = fileSizeLogical.filter { url, _ in searchTerm.isEmpty || url.lastPathComponent.localizedCaseInsensitiveContains(searchTerm) }

        let filesToSort = sizeType == "Real" ? filteredFilesReal : filteredFilesLogical
        let sortedFilteredFiles = filesToSort.sorted { (left, right) -> Bool in
            switch selectedSort {
            case .name:
                return left.key.lastPathComponent.pearFormat() < right.key.lastPathComponent.pearFormat()
            case .size:
                return left.value > right.value
            case .path:
                return left.key.path.localizedCaseInsensitiveCompare(right.key.path) == .orderedAscending
            }
        }.map(\.key)

        let totalRealSize = filteredFilesReal.values.reduce(0, +)
        let totalLogicalSize = filteredFilesLogical.values.reduce(0, +)

        return (sortedFilteredFiles, totalRealSize, totalLogicalSize)
    }

    func calculateTotalSelectedZombieSize() -> (real: String, logical: String, finder: String) {
        var totalReal: Int64 = 0
        var totalLogical: Int64 = 0

        for url in selectedZombieItemsLocal {
            let realSize = appState.zombieFile.fileSize[url] ?? 0
            let logicalSize = appState.zombieFile.fileSizeLogical[url] ?? 0
            totalReal += realSize
            totalLogical += logicalSize
        }

        return (formatByte(size: totalReal).human,
                formatByte(size: totalLogical).human,
                "\(formatByte(size: totalLogicalSize).byte) (\(formatByte(size: totalReal).human))")
    }

    private func updateTotalSizes() {
        let sizes = calculateTotalSelectedZombieSize()
        totalRealSizeUninstallBtn = sizes.real
        totalLogicalSizeUninstallBtn = sizes.logical
    }

    private var displaySizeText: String {
        switch sizeType {
        case "Logical":
            return totalLogicalSizeUninstallBtn
        case "Real":
            return totalRealSizeUninstallBtn
        default:
            return totalRealSizeUninstallBtn
        }
    }


    private var displaySizeTotal: String {
        switch sizeType {
        case "Real":
            return formatByte(size: totalRealSize).human
        case "Logical":
            return formatByte(size: totalLogicalSize).human
        default:
            return "\(formatByte(size: totalLogicalSize).byte) (\(formatByte(size: totalRealSize).human))"
        }
    }

    private func excludeAllSelectedItems() {
        for path in selectedZombieItemsLocal {
            // Add to fsm path
            fsm.addPathZ(path.path)

            // Remove from memoizedFiles
            memoizedFiles.removeAll { $0 == path }

            // Remove from appState zombie file details
            appState.zombieFile.fileSize.removeValue(forKey: path)
            appState.zombieFile.fileSizeLogical.removeValue(forKey: path)
            appState.zombieFile.fileIcon.removeValue(forKey: path)
        }

        // Clear all selected items
        selectedZombieItemsLocal.removeAll()
    }
    
    private func linkSelectedItemsToApp(_ appPath: URL) {
        for path in selectedZombieItemsLocal {
            // Add association (same logic as individual file linking)
            ZombieFileStorage.shared.addAssociation(appPath: appPath, zombieFilePath: path)
            
            // Exclude from future scans (same as exclude button)
            fsm.addPathZ(path.path)
            
            // Remove from memoizedFiles
            memoizedFiles.removeAll { $0 == path }
            
            // Remove from appState zombie file details
            appState.zombieFile.fileSize.removeValue(forKey: path)
            appState.zombieFile.fileSizeLogical.removeValue(forKey: path)
            appState.zombieFile.fileIcon.removeValue(forKey: path)
        }
        
        // Clear all selected items
        selectedZombieItemsLocal.removeAll()
    }

    private func restoreFileToZombieList(_ fileURL: URL) {
        // Add back to zombie file data if it exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let fileSize = getFileSize(path: fileURL) {
                appState.zombieFile.fileSize[fileURL] = fileSize.real
                appState.zombieFile.fileSizeLogical[fileURL] = fileSize.logical
                appState.zombieFile.fileIcon[fileURL] = getFileIcon(for: fileURL)
            }
            
            // Add back to memoized files if it matches current search
            if (searchZ.isEmpty || fileURL.lastPathComponent.localizedCaseInsensitiveContains(searchZ)) && 
               !memoizedFiles.contains(fileURL) {
                memoizedFiles.append(fileURL)
                // Re-sort to maintain proper order
                updateMemoizedFiles(for: searchZ, sizeType: sizeType, selectedSort: selectedSort, force: true)
            }
        }
    }

    private func getFileSize(path: URL) -> (real: Int64, logical: Int64)? {
        do {
            let resourceValues = try path.resourceValues(forKeys: [.fileSizeKey, .fileAllocatedSizeKey])
            let logical = Int64(resourceValues.fileSize ?? 0)
            let real = Int64(resourceValues.fileAllocatedSize ?? 0)
            return (real: real, logical: logical)
        } catch {
            return nil
        }
    }

    private func getFileIcon(for url: URL) -> NSImage? {
        return NSWorkspace.shared.icon(forFile: url.path)
    }

}



struct ZombieFileDetailsItem: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fsm: FolderSettingsManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    let size: Int64?
    let sizeL: Int64?
    let icon: Image?
    let path: URL
    @Binding var memoizedFiles: [URL]

    @Binding var isSelected: Bool

    var body: some View {

        HStack(alignment: .center, spacing: 15) {
            Button(action: { isSelected.toggle() }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : ThemeColors.shared(for: colorScheme).secondaryText)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            if let appIcon = icon {
                appIcon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

            }

            VStack(alignment: .leading, spacing: 5) {

                HStack(alignment: .center) {
                    Text(showLocalized(url: path))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        .font(.title3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(path.lastPathComponent)
                        .overlay{
                            if (isHovered) {
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
                                        .frame(height: 1.5)
                                        .offset(y: 3)
                                }
                            }
                        }

                    if let imageView = folderImages(for: path.path) {
                        imageView
                    }

                }

                path.path.pathWithArrows(separatorColor: ThemeColors.shared(for: colorScheme).primaryText)
                    .font(.footnote)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .help(path.path)
            }
            .onHover { hovering in
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                    self.isHovered = hovering
                }
            }
            .onTapGesture {
                NSWorkspace.shared.selectFile(path.path, inFileViewerRootedAtPath: path.deletingLastPathComponent().path)
            }

            Spacer()

            let displaySize = sizeType == "Real" ? formatByte(size: size!).human :
            formatByte(size: sizeL!).human

            Text(verbatim: "\(displaySize)")
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ThemeColors.shared(for: colorScheme).secondaryBG)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            if path.pathExtension == "app" {
                Button("Open \(path.deletingPathExtension().lastPathComponent)") {
                    NSWorkspace.shared.open(path)
                }
                Divider()
            }
            Button("Copy Path") {
                copyToClipboard(text: path.path)
            }
            Button("View in Finder") {
                NSWorkspace.shared.selectFile(path.path, inFileViewerRootedAtPath: path.deletingLastPathComponent().path)
            }
            Divider()
            Menu("Link To") {
                ForEach(appState.sortedApps, id: \.id) { app in
                    let isAssociated = ZombieFileStorage.shared.getAssociatedFiles(for: app.path).contains(path)

                    Button {
                        if isAssociated {
                            // Unlinking - remove association and unexclude
                            ZombieFileStorage.shared.removeAssociation(appPath: app.path, zombieFilePath: path)
                            fsm.removePathZ(path.path)
                        } else {
                            // Linking - add association and exclude (same as exclude button)
                            ZombieFileStorage.shared.addAssociation(appPath: app.path, zombieFilePath: path)
                            
                            // Run the same exclude code
                            fsm.addPathZ(path.path)
                            memoizedFiles.removeAll { $0 == path }
                            appState.zombieFile.fileSize.removeValue(forKey: path)
                            appState.zombieFile.fileSizeLogical.removeValue(forKey: path)
                            appState.zombieFile.fileIcon.removeValue(forKey: path)
                            
                            if isSelected {
                                isSelected = false
                            }
                        }
                    } label: {
                        HStack {
                            Text(app.appName)
                            if isAssociated {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Button("Exclude") {
                fsm.addPathZ(path.path)
                // Remove from memoizedFiles
                memoizedFiles.removeAll { $0 == path }
                // Also remove from selectedZombieItemsLocal if it exists
                appState.zombieFile.fileSize.removeValue(forKey: path)
                appState.zombieFile.fileSizeLogical.removeValue(forKey: path)
                appState.zombieFile.fileIcon.removeValue(forKey: path)
                // Use @EnvironmentObject to access the parent's selectedZombieItemsLocal
                if isSelected {
                    isSelected = false
                }
            }
            .help("This adds the file/folder to the Exclusions list. Edit the exclusions list from Settings > Folders tab")
        }
    }
}

