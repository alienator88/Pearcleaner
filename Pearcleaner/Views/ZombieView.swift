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
    @AppStorage("settings.general.leftoverWarning") private var warning: Bool = false
    @State private var showAlert = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.general.selectedSort") var selectedSortAlpha: Bool = true
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @Environment(\.colorScheme) var colorScheme
    @Binding var showPopover: Bool
    @Binding var search: String
    @State private var searchZ: String = ""
    @State private var elapsedTime = 0
    @State private var timer: Timer? = nil
    @State private var selectedZombieItemsLocal: Set<URL> = []
    @State private var memoizedFiles: [URL] = []
    @State private var lastSearchTermUsed: String? = nil
    @State private var totalRealSize: Int64 = 0
    @State private var totalLogicalSize: Int64 = 0
    @State private var totalRealSizeUninstallBtn: String = ""
    @State private var totalLogicalSizeUninstallBtn: String = ""
    @State private var totalFinderSizeUninstallBtn: String = ""

    var body: some View {

        VStack(alignment: .center) {
            if appState.showProgress {
                VStack {
                    Group {
                        Spacer()

                        Text("Searching the file system").font(.title3)
                            .foregroundStyle(.primary.opacity(0.5))

                        ProgressView()
                            .progressViewStyle(.linear)
                            .frame(width: 400, height: 10)


                        Text("\(elapsedTime)")
                            .font(.title).monospacedDigit()
                            .foregroundStyle(.primary.opacity(0.5))
                            .opacity(elapsedTime == 0 ? 0 : 1)
                            .contentTransition(.numericText())


                        Spacer()
                    }
                    .transition(.opacity)

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        withAnimation {
                            self.elapsedTime += 1
                        }
                    }
                }
                .onDisappear {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.elapsedTime = 0
                }
            } else {
                // Titlebar
                HStack(spacing: 0) {
                    Spacer()

                    Button("Close") {
                        updateOnMain {
                            appState.appInfo = AppInfo.empty
                            search = ""
                            appState.currentView = .apps
                            showPopover = false
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "x.circle", iconFlip: "x.circle.fill", help: "Close"))
                }
                .padding(.top, 6)
                .padding(.trailing, (mini || menubarEnabled) ? 6 : 0)


                VStack() {
                    // Main Group
                    HStack() {

                        VStack(alignment: .center) {

                            HStack(alignment: .center) {
                                Image(systemName: "doc.badge.clock.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .symbolRenderingMode(.hierarchical)
                                    .padding(.trailing)

                                VStack(alignment: .leading, spacing: 10){
                                    HStack {
                                        Text("Leftover Files").font(.title).fontWeight(.bold)
                                        Spacer()
                                    }
                                    Text("Remaining files and folders from previous applications")
                                        .font(.callout).foregroundStyle(.primary.opacity(0.5))
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text("\(displaySizeTotal)").font(.title).fontWeight(.bold).help("Total size on disk")

                                    Text("\(selectedZombieItemsLocal.count) / \(searchZ.isEmpty ? appState.zombieFile.fileSize.count : memoizedFiles.count) \(appState.zombieFile.fileSize.count == 1 ? "item" : "items")")
                                        .font(.callout).foregroundStyle(.primary.opacity(0.5))
                                }

                            }

                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 0)
                    }

                    // Item selection and sorting toolbar
                    HStack {
                        Toggle("", isOn: Binding(
                            get: {
                                if searchZ.isEmpty {
                                    // All items are selected if no filter is applied and all items are selected
                                    return selectedZombieItemsLocal.count == appState.zombieFile.fileSize.count
                                } else {
                                    // All currently filtered files are selected when a filter is applied
                                    return Set(memoizedFiles).isSubset(of: selectedZombieItemsLocal) && selectedZombieItemsLocal.count == memoizedFiles.count
                                }
                            },
                            set: { newValue in
                                if newValue {
                                    if searchZ.isEmpty {
                                        // Select all files if no filter is applied
                                        selectedZombieItemsLocal = Set(appState.zombieFile.fileSize.keys)
                                    } else {
                                        // Select only filtered files if a filter is applied
                                        selectedZombieItemsLocal.formUnion(memoizedFiles)
                                    }
                                } else {
                                    if searchZ.isEmpty {
                                        // Deselect all files if no filter is applied
                                        selectedZombieItemsLocal.removeAll()
                                    } else {
                                        // Deselect only filtered files if a filter is applied
                                        selectedZombieItemsLocal.subtract(memoizedFiles)
                                    }
                                }

                                updateTotalSizes()
                            }
                        ))
                        .toggleStyle(SimpleCheckboxToggleStyle())
                        .help("All checkboxes")


                        SearchBar(search: $searchZ, darker: true, glass: glass, sidebar: false)
                            .padding(.horizontal)
                            .onChange(of: searchZ) { newValue in
                                updateMemoizedFiles(for: newValue, sizeType: sizeType, selectedSortAlpha: selectedSortAlpha)
                            }


                        Button("") {
                            selectedSortAlpha.toggle()
                            updateMemoizedFiles(for: searchZ, sizeType: sizeType, selectedSortAlpha: selectedSortAlpha, force: true)
                        }
                        .buttonStyle(SimpleButtonStyle(icon: selectedSortAlpha ? "textformat.abc" : "textformat.123", help: selectedSortAlpha ? "Sorted alphabetically" : "Sorted by size"))


                    }
                    .padding(.horizontal)
                    .padding(.vertical)


                    Divider()
                        .padding(.horizontal)

                    ScrollView() {
                        LazyVStack {
                            ForEach(memoizedFiles, id: \.self) { file in
                                if let fileSize = appState.zombieFile.fileSize[file], let fileSizeL = appState.zombieFile.fileSizeLogical[file], let fileIcon = appState.zombieFile.fileIcon[file] {
                                    let iconImage = fileIcon.map(Image.init(nsImage:))
                                    VStack {
                                        ZombieFileDetailsItem(size: fileSize, sizeL: fileSizeL, icon: iconImage, path: file, isSelected: self.binding(for: file))
                                            .padding(.vertical, 5)
                                    }
                                }
                            }

                        }
                        .padding()
                    }



                    Spacer()

                    HStack() {

                        Spacer()

                        InfoButton(text: "Leftover file search is not 100% accurate as it doesn't have any uninstalled app bundles to check against for file exclusion. This does a best guess search for files/folders and excludes the ones that have overlap with your currently installed applications. Please confirm files marked for deletion really do belong to uninstalled applications.", color: .orange, warning: true, edge: .top)

                        Button("Rescan") {
                            updateOnMain {
                                appState.zombieFile = .empty
                                appState.showProgress.toggle()
                                reversePreloader(allApps: appState.sortedApps, appState: appState, locations: locations, fsm: fsm, reverseAddon: true)
                            }
                        }
                        .buttonStyle(RescanButton())

                        Button("\(sizeType == "Logical" ? totalLogicalSizeUninstallBtn : sizeType == "Finder" ? totalFinderSizeUninstallBtn : totalRealSizeUninstallBtn)") {
                                Task {



                                    let selectedItemsArray = Array(selectedZombieItemsLocal)

                                    moveFilesToTrash(appState: appState, at: selectedItemsArray) { success in

                                        guard success else {
                                            return
                                        }

                                        if selectedZombieItemsLocal.count == appState.zombieFile.fileSize.keys.count {
                                            updateOnMain {
                                                appState.zombieFile = .empty
                                                search = ""
                                                searchZ = ""
                                                withAnimation {
                                                    if mini || menubarEnabled {
                                                        appState.currentView = .apps
                                                        showPopover = false
                                                    } else {
                                                        appState.currentView = .empty
                                                    }
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
                                            updateMemoizedFiles(for: searchZ, sizeType: sizeType, selectedSortAlpha: selectedSortAlpha, force: true)
                                        }

//                                        updateOnMain {
//                                            // Remove items from the list
//                                            appState.zombieFile.fileSize = appState.zombieFile.fileSize.filter { !selectedZombieItemsLocal.contains($0.key) }
//                                            // Update the selectedZombieFiles to remove references that are no longer present
//                                            selectedZombieItemsLocal.removeAll()
//                                            updateTotalSizes()
//
//                                        }

                                    }

//                                    updateMemoizedFiles(for: searchZ, sizeType: sizeType, selectedSortAlpha: selectedSortAlpha, force: true)

                                }

                            }
                            .buttonStyle(UninstallButton(isEnabled: !selectedZombieItemsLocal.isEmpty))
                            .disabled(selectedZombieItemsLocal.isEmpty)


                    }
                    .padding(.top)
                }
                .transition(.opacity)
                .padding([.horizontal, .bottom], 20)
                .padding(.top, !mini ? 10 : 0)
                .onAppear {
                    updateMemoizedFiles(for: searchZ, sizeType: sizeType, selectedSortAlpha: selectedSortAlpha, force: true)
                }
                .sheet(isPresented: $showAlert, content: {
                        VStack(spacing: 10) {
                            Text("Important")
                                .font(.headline)
                            Divider()
                            Spacer()
                            Text("Leftover file search is not 100% accurate as it doesn't have any uninstalled app bundles to check against for file exclusion. This does a best guess search for files/folders and excludes the ones that have overlap with your currently installed applications. Please confirm files marked for deletion really do belong to uninstalled applications.")
                                .font(.subheadline)
                            Spacer()
                            Button("Close") {
                                warning = true
                                showAlert = false
                            }
                            .buttonStyle(SimpleButtonStyle(icon: "x.circle.fill", label: "Close", help: "Dismiss"))
                            Spacer()
                        }
                        .padding(15)
                        .frame(width: 400, height: 250)
                        .background(GlassEffect(material: .hudWindow, blendingMode: .behindWindow))
                })

            }
        }
        .onAppear {
            if !warning {
                showAlert = true
            }
        }

    }

    private func binding(for file: URL) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.selectedZombieItemsLocal.contains(file) },
            set: { isSelected in
                if isSelected {
                    self.selectedZombieItemsLocal.insert(file)
                } else {
                    self.selectedZombieItemsLocal.remove(file)
                }
                updateTotalSizes()
            }
        )
    }


    private func updateMemoizedFiles(for searchTerm: String, sizeType: String, selectedSortAlpha: Bool, force: Bool = false) {
        if !force && searchTerm == lastSearchTermUsed && self.sizeType == sizeType && self.selectedSortAlpha == selectedSortAlpha {
            return
        }

        let results = filterAndSortFiles(for: searchTerm, sizeType: sizeType, selectedSortAlpha: selectedSortAlpha)
        memoizedFiles = results.files
        totalRealSize = results.totalRealSize
        totalLogicalSize = results.totalLogicalSize
        lastSearchTermUsed = searchTerm
        self.sizeType = sizeType
        self.selectedSortAlpha = selectedSortAlpha
        updateTotalSizes()
    }

    private func filterAndSortFiles(for searchTerm: String, sizeType: String, selectedSortAlpha: Bool) -> (files: [URL], totalRealSize: Int64, totalLogicalSize: Int64) {
        let fileSizeReal = appState.zombieFile.fileSize
        let fileSizeLogical = appState.zombieFile.fileSizeLogical

        let filteredFilesReal = fileSizeReal.filter { url, _ in searchTerm.isEmpty || url.lastPathComponent.localizedCaseInsensitiveContains(searchTerm) }
        let filteredFilesLogical = fileSizeLogical.filter { url, _ in searchTerm.isEmpty || url.lastPathComponent.localizedCaseInsensitiveContains(searchTerm) }

        let filesToSort = sizeType == "Real" || sizeType == "Finder" ? filteredFilesReal : filteredFilesLogical
        let sortedFilteredFiles = filesToSort.sorted { (left, right) -> Bool in
            if selectedSortAlpha {
                return left.key.lastPathComponent.pearFormat() < right.key.lastPathComponent.pearFormat()
            } else {
                return left.value > right.value
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
                "\(formatByte(size: totalLogical).byte) (\(formatByte(size: totalReal).human))")
    }

    private func updateTotalSizes() {
        let sizes = calculateTotalSelectedZombieSize()
        totalRealSizeUninstallBtn = sizes.real
        totalLogicalSizeUninstallBtn = sizes.logical
        totalFinderSizeUninstallBtn = "\(sizes.logical) (\(sizes.real))"
    }

    private var displaySizeText: String {
        switch sizeType {
        case "Logical":
            return totalLogicalSizeUninstallBtn
        case "Finder":
            return totalFinderSizeUninstallBtn
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

}



struct ZombieFileDetailsItem: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    let size: Int64?
    let sizeL: Int64?
    let icon: Image?
    let path: URL
    @Binding var isSelected: Bool

    var body: some View {

        HStack(alignment: .center, spacing: 20) {
            Toggle("", isOn: $isSelected)
            .toggleStyle(SimpleCheckboxToggleStyle())

//            Toggle("", isOn: Binding(
//                get: { self.selectedZombieItemsLocal.contains(self.path) },
//                set: { isChecked in
//                    if isChecked {
//                        self.selectedZombieItemsLocal.insert(self.path)
//                    } else {
//                        self.selectedZombieItemsLocal.remove(self.path)
//                    }
//                }
//            ))
//            .toggleStyle(SimpleCheckboxToggleStyle())

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
                        .font(.title3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(path.lastPathComponent)
                        .overlay{
                            if (isHovered) {
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.primary.opacity(0.5))
                                        .frame(height: 1.5)
                                        .offset(y: 3)
                                }
                            }
                        }

                    if let imageView = folderImages(for: path.path) {
                        imageView
                    }
                }

                Text(path.path)
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .opacity(0.5)
                    .help(path.path)
            }
            .onHover { hovering in
                withAnimation(Animation.easeIn(duration: 0.2)) {
                    self.isHovered = hovering
                }
            }
            .onTapGesture {
                NSWorkspace.shared.selectFile(path.path, inFileViewerRootedAtPath: path.deletingLastPathComponent().path)
            }

            Spacer()

            let displaySize = sizeType == "Real" ? formatByte(size: size!).human :
            sizeType == "Logical" ? formatByte(size: sizeL!).human :
            "\(formatByte(size: sizeL!).byte) (\(formatByte(size: size!).human))"

            Text("\(displaySize)")

        }
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
        }
    }
}

