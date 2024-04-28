//
//  ZombieView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 2/26/24.
//

import Foundation
import SwiftUI

struct ZombieView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @State private var showPop: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.general.selectedSort") var selectedSortAlpha: Bool = true
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @State private var localKey = UUID()
    @Environment(\.colorScheme) var colorScheme
    @Binding var showPopover: Bool
    @Binding var search: String
    @State private var searchZ: String = ""
    var regularWin: Bool
    @State private var elapsedTime = 0
    @State private var timer: Timer? = nil

    var body: some View {

        let totalSelectedZombieSize: (real: String, logical: String, finder: String) = {
            var totalReal: Int64 = 0
            var totalLogical: Int64 = 0

            for url in appState.selectedZombieItems {
                let realSize = appState.zombieFile.fileSize[url] ?? 0
                let logicalSize = appState.zombieFile.fileSizeLogical[url] ?? 0
                totalReal += realSize
                totalLogical += logicalSize
            }
            return (formatByte(size: totalReal).human, formatByte(size:totalLogical).human, "\(formatByte(size: totalLogical).byte) (\(formatByte(size: totalReal).human))")
        }()

        let filteredAndSortedFiles: ([URL], Int64, Int64) = {
            let fileSizeReal = appState.zombieFile.fileSize
            let fileSizeLogical = appState.zombieFile.fileSizeLogical
            let filteredFilesReal = fileSizeReal.filter { (url, _) in
                searchZ.isEmpty || url.lastPathComponent.localizedCaseInsensitiveContains(searchZ)
            }
            let filteredFilesLogical = fileSizeLogical.filter { (url, _) in
                searchZ.isEmpty || url.lastPathComponent.localizedCaseInsensitiveContains(searchZ)
            }
            let filesToSort = (sizeType == "Real" || sizeType == "Finder" ? filteredFilesReal : filteredFilesLogical)
            let sortedFilteredFiles = filesToSort.sorted(by: {
                if selectedSortAlpha {
                    return $0.key.lastPathComponent.pearFormat() < $1.key.lastPathComponent.pearFormat()
                } else {
                    return $0.value > $1.value
                }
            }).map { $0.key }
            let totalSize = filteredFilesReal.values.reduce(0, +)
            let totalSizeL = filteredFilesLogical.values.reduce(0, +)
            return (sortedFilteredFiles, totalSize, totalSizeL)
        }()

        let displaySizeTotal = sizeType == "Real" ? formatByte(size: filteredAndSortedFiles.1).human :
        sizeType == "Logical" ? formatByte(size: filteredAndSortedFiles.2).human :
        "\(formatByte(size: filteredAndSortedFiles.2).byte) (\(formatByte(size: filteredAndSortedFiles.1).human))"

        VStack(alignment: .center) {
            if appState.showProgress {
                VStack {
                    Group {
                        Spacer()

                        Text("Searching the file system").font(.title3)
                            .foregroundStyle(Color("mode").opacity(0.5))

                        ProgressView()
                            .progressViewStyle(.linear)
                            .frame(width: 400, height: 10)


                        Text("\(elapsedTime)")
                            .font(.title).monospacedDigit()
                            .foregroundStyle(Color("mode").opacity(0.5))
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
                                        InfoButton(text: "Leftover file search is not 100% accurate as it doesn't have any app bundles to check against. This searches for files/folders and excludes the ones that have overlap with your currently installed apps. Make sure to confirm files marked for removal are correct.", color: .red, label: "READ")
                                        Spacer()
                                        
                                    }
                                    Text("Remaining files and folders from previous installs")
                                        .font(.callout).foregroundStyle(Color("mode").opacity(0.5))
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text("\(displaySizeTotal)").font(.title).fontWeight(.bold).help("Total size on disk")

                                    Text("\(appState.zombieFile.fileSize.count == 1 ? "\(appState.selectedZombieItems.count) / \(appState.zombieFile.fileSize.count) item" : "\(appState.selectedZombieItems.count) / \(appState.zombieFile.fileSize.count) items")")
                                        .font(.callout).foregroundStyle(Color("mode").opacity(0.5))
                                }

                            }

                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 0)
                    }

                    // Item selection and sorting toolbar
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { appState.selectedZombieItems.count == appState.zombieFile.fileSize.count },
                            set: { newValue in
                                updateOnMain {
                                    appState.selectedZombieItems = newValue ? Set(appState.zombieFile.fileSize.keys) : []
                                }
                            }
                        ))
                        .toggleStyle(SimpleCheckboxToggleStyle())
                        .help("All checkboxes")


                        SearchBar(search: $searchZ, darker: true, glass: glass)
                            .padding(.horizontal)


                        Button("") {
                            selectedSortAlpha.toggle()
                        }
                        .buttonStyle(SimpleButtonStyle(icon: selectedSortAlpha ? "textformat.abc" : "textformat.123", help: selectedSortAlpha ? "Sorted alphabetically" : "Sorted by size"))


                    }
                    .padding(.horizontal)
                    .padding(.vertical)


                    Divider()
                        .padding(.horizontal)

                    ScrollView() {
                        LazyVStack {
                            ForEach(Array(filteredAndSortedFiles.0.enumerated()), id: \.element) { index, file in
                                if let fileSize = appState.zombieFile.fileSize[file], let fileSizeL = appState.zombieFile.fileSizeLogical[file], let fileIcon = appState.zombieFile.fileIcon[file] {
                                    let iconImage = fileIcon.map(Image.init(nsImage:))
                                    VStack {
                                        ZombieFileDetailsItem(size: fileSize, sizeL: fileSizeL, icon: iconImage, path: file)
                                            .padding(.vertical, 5)
                                    }
                                }
                            }

                        }
                        .padding()
                        .onChange(of: sizeType) { _ in
                            localKey = UUID()
                        }
                    }
                    .id(localKey)



                    Spacer()

                    HStack() {

                        Spacer()

                        Button("Rescan") {
                            updateOnMain {
                                appState.zombieFile = .empty
                                appState.showProgress.toggle()
                                reversePreloader(allApps: appState.sortedApps, appState: appState, locations: locations, reverseAddon: true)
                            }
                        }
                        .buttonStyle(RescanButton())

                        Button("\(sizeType == "Logical" ? totalSelectedZombieSize.logical : sizeType == "Finder" ? totalSelectedZombieSize.finder : totalSelectedZombieSize.real)") {
                                Task {
                                    if appState.selectedZombieItems.count == appState.zombieFile.fileSize.keys.count {
                                        updateOnMain {
                                            appState.zombieFile = .empty
                                            search = ""
                                            searchZ = ""
                                            if mini || menubarEnabled {
                                                appState.currentView = .apps
                                                showPopover = false
                                            } else {
                                                appState.currentView = .empty
                                            }
                                        }
                                    }


                                    let selectedItemsArray = Array(appState.selectedZombieItems)

                                    moveFilesToTrash(at: selectedItemsArray) {
                                        withAnimation {
                                            showPopover = false
                                        }
                                        updateOnMain {
                                            // Remove items from the list
                                            appState.zombieFile.fileSize = appState.zombieFile.fileSize.filter { !appState.selectedZombieItems.contains($0.key) }
                                            // Update the selectedZombieFiles to remove references that are no longer present
                                            appState.selectedZombieItems.removeAll()
                                        }

                                    }

                                }

                            }
                            .buttonStyle(UninstallButton(isEnabled: !appState.selectedZombieItems.isEmpty))
                            .disabled(appState.selectedZombieItems.isEmpty)


                    }
                    .padding(.top)
                }
                .transition(.opacity)
                .padding([.horizontal, .bottom], 20)
                .padding(.top, !mini ? 10 : 0)

            }
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

    var body: some View {

        HStack(alignment: .center, spacing: 20) {
            Toggle("", isOn: Binding(
                get: { self.appState.selectedZombieItems.contains(self.path) },
                set: { isChecked in
                    if isChecked {
                        self.appState.selectedZombieItems.insert(self.path)
                    } else {
                        self.appState.selectedZombieItems.remove(self.path)
                    }
                }
            ))
            .toggleStyle(SimpleCheckboxToggleStyle())

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
                                        .fill(Color("mode").opacity(0.5))
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

