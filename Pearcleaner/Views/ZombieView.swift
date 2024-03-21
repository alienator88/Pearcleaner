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
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.instant") private var instantSearch: Bool = true
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @Binding var showPopover: Bool
    @Binding var search: String
    @State private var searchZ: String = ""
    @State private var selectedOption = "Default"
    var regularWin: Bool
    @State private var elapsedTime = 0
    @State private var timer: Timer? = nil

    var body: some View {

        let filteredAndSortedFiles: ([URL], Int64) = {
            let filteredFiles = appState.zombieFile.fileSize.filter { (url, _) in
                searchZ.isEmpty || url.lastPathComponent.localizedCaseInsensitiveContains(searchZ)
            }

            let sortedFilteredFiles = filteredFiles.sorted(by: {
                selectedOption == "Default" ?
                $0.key.lastPathComponent < $1.key.lastPathComponent :
                $0.value > $1.value
            }).map { $0.key }

            let totalSize = filteredFiles.values.reduce(0, +)

            return (sortedFilteredFiles, totalSize)
        }()

        VStack(alignment: .center) {
            if appState.showProgress {
                VStack {
                    Group {
                        Spacer()

                        Text("Searching the file system").font(.title3)
                            .foregroundStyle((.gray.opacity(0.8)))

                        HStack {
                            ProgressView()
                                .progressViewStyle(.linear)
                                .frame(width: 400, height: 10)
                            Image(systemName: "\(elapsedTime).circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundStyle((.gray.opacity(0.8)))
                                .opacity(elapsedTime == 0 ? 0 : 1)
                        }


                        Spacer()
                    }
                    .transition(.opacity)

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        self.elapsedTime += 1
                    }
                }
                .onDisappear {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.elapsedTime = 0
                }
            } else {
                // Titlebar
                if !regularWin {
                    HStack(spacing: 0) {
                        Spacer()

                        Button("Rescan") {
                            updateOnMain {
                                appState.zombieFile = .empty
                                appState.showProgress.toggle()
                                if instantSearch {
                                    let reverse = ReversePathsSearcher(appState: appState, locations: locations)
                                    reverse.reversePathsSearch()
//                                    reversePathsSearch(appState: appState, locations: locations)
                                } else {
                                    loadAllPaths(allApps: appState.sortedApps, appState: appState, locations: locations, reverseAddon: true)
                                }
                            }
                        }
                        .buttonStyle(NavButtonBottomBarStyle(image: "arrow.counterclockwise.circle.fill", help: "Rescan files"))

                        Button("Close") {
                            updateOnMain {
                                appState.appInfo = AppInfo.empty
                                search = ""
                                appState.currentView = .apps
                                showPopover = false
                            }
                        }
                        .buttonStyle(NavButtonBottomBarStyle(image: "x.circle.fill", help: "Close"))
                    }
                    .padding([.horizontal, .top], 5)
                }

                VStack() {
                    // Main Group
                    HStack() {

                        VStack(alignment: .center) {

                            HStack(alignment: .center) {
                                Image(systemName: "clock.arrow.circlepath")
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
                                    Text("Files and folders remaining from previously installed applications")
                                        .font(.callout).foregroundStyle((.gray.opacity(0.8)))
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text("\(formatByte(size: filteredAndSortedFiles.1))").font(.title).fontWeight(.bold)
                                    Text("\(filteredAndSortedFiles.0.count == 1 ? "\(filteredAndSortedFiles.0.count) item" : "\(filteredAndSortedFiles.0.count) items")").font(.callout).underline().foregroundStyle((.gray.opacity(0.8)))
                                }

                            }

                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 0)
                    }

                    SearchBarMiniBottom(search: $searchZ)
                        .padding(.top)

                    Divider()
                        .padding()

                    ScrollView() {
                        LazyVStack {

                            ForEach(filteredAndSortedFiles.0, id: \.self) { file in
                                if let fileSize = appState.zombieFile.fileSize[file], let fileIcon = appState.zombieFile.fileIcon[file] {
                                    let iconImage = fileIcon.map(Image.init(nsImage:))

                                    ZombieFileDetailsItem(size: fileSize, icon: iconImage, path: file)
                                        .padding(.trailing)

                                    if file != appState.zombieFile.fileSize.keys.sorted(by: { $0.absoluteString < $1.absoluteString }).last {
                                        Divider().padding(.leading, 40).opacity(0.5)
                                    }
                                }
                            }
                        }

                    }
                    .padding()

                    HStack() {

                        Picker("", selection: Binding(
                            get: { appState.selectedZombieItems.count == appState.zombieFile.fileSize.count ? true : false },
                            set: { newValue in
                                updateOnMain {
                                    appState.selectedZombieItems = newValue ? Set(appState.zombieFile.fileSize.keys) : []
                                }
                            }
                        )) {
                            Image(systemName: "checkmark.square").tag(true)
                            Image(systemName: "square").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 100)
                        .offset(x: -8)
                        .help("Item Selection")
                        
                        Spacer()

                        if !appState.selectedZombieItems.isEmpty {
                            Button("Remove") {
                                Task {
                                    updateOnMain {
                                        appState.zombieFile = .empty
                                        search = ""
                                        if !regularWin {
                                            appState.currentView = .apps
                                            showPopover = false
                                        } else {
                                            appState.currentView = .empty
                                        }
                                    }

                                    let selectedItemsArray = Array(appState.selectedZombieItems)

                                    killApp(appId: appState.appInfo.bundleIdentifier) {
                                        moveFilesToTrash(at: selectedItemsArray) {
                                            withAnimation {
                                                showPopover = false
                                                updateOnMain {
                                                    appState.isReminderVisible.toggle()
                                                }
                                            }
                                        }
                                    }

                                }

                            }
                            .buttonStyle(NavButtonBottomBarStyle(image: "trash.fill", help: "Remove"))
                        } else {
                            Text("No files selected to remove").font(.title).foregroundStyle(Color("mode")).opacity(0.2)
                                .padding(5)
                        }

                        Spacer()

                        Picker("", selection: $selectedOption) {
                            Image(systemName: "textformat.abc").tag("Default")
                            Image(systemName: "number").tag("Size")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 100)
                        .help("Sorting alphabetically or by size")
                    }

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
    let size: Int64?
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

            if let appIcon = icon {
                appIcon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

            }
            VStack(alignment: .leading, spacing: 5) {
                Text(path.lastPathComponent)
                    .font(.title3)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(path.lastPathComponent)
                Text(path.path)
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .opacity(0.5)
                //                    .foregroundStyle(Color("AccentColor"))
                    .help(path.path)
            }

            Spacer()

            Text(formatByte(size:size!))



            Button("") {
                NSWorkspace.shared.selectFile(path.path, inFileViewerRootedAtPath: path.deletingLastPathComponent().path)
            }
            .buttonStyle(SimpleButtonStyle(icon: "folder.fill", help: "Show in Finder", color: Color("mode")))

        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0))
        )
    }
}

