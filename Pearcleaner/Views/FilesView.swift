//
//  FilesView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/1/23.
//

import Foundation
import SwiftUI

struct FilesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @State private var showPop: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @Binding var showPopover: Bool
    @Binding var search: String
    @State private var selectedOption = "Default"

    var body: some View {
        VStack(alignment: .center) {
            if appState.showProgress {
                VStack {
                    Spacer()
                    Text("Searching the file system").font(.title3)
                        .foregroundStyle((.gray.opacity(0.8)))
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(width: 400, height: 10)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                VStack() {

                    // Main Group
                    HStack(alignment: .center) {

                        //app icon, title, size and items
                        VStack(alignment: .center) {
                            HStack(alignment: .center) {
                                if let appIcon = appState.appInfo.appIcon {
                                    Image(nsImage: appIcon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .padding(.trailing)
                                }

                                VStack(alignment: .leading, spacing: 5){
                                    HStack {
                                        Text("\(appState.appInfo.appName)").font(.title).fontWeight(.bold)
                                        Text("•").foregroundStyle(Color("AccentColor"))
                                        Text("\(appState.appInfo.appVersion)").font(.title3)
                                        if appState.appInfo.appName.count < 5 {
                                            InfoButton(text: "Pearcleaner searches for files via a combination of bundle id and app name. \(appState.appInfo.appName) has a common or short app name so there might be unrelated files found. Please check the list thoroughly before uninstalling.", color: nil)
                                        }

                                    }
                                    Text("\(appState.appInfo.bundleIdentifier)").font(.title3)
                                        .foregroundStyle((.gray.opacity(0.8)))
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text("\(formatByte(size: appState.appInfo.totalSize))").font(.title).fontWeight(.bold)
                                    Text("\(appState.appInfo.fileSize.count > 1 ? "\(appState.appInfo.fileSize.count) items" : "\(appState.appInfo.fileSize.count) item")").font(.callout).underline().foregroundStyle((.gray.opacity(0.8)))
                                }


                            }


                            if appState.appInfo.webApp || appState.appInfo.wrapped {
                                HStack(alignment: .center, spacing: 10) {

                                    Spacer()

                                    if appState.appInfo.webApp {
                                        Text("web")
                                            .font(.footnote)
                                            .foregroundStyle(Color("mode").opacity(0.5))
                                            .frame(minWidth: 30, minHeight: 15)
                                            .padding(2)
                                            .background(Color("mode").opacity(0.1))
                                            .clipShape(.capsule)

                                    }

                                    if appState.appInfo.wrapped {
                                        Text("iOS")
                                            .font(.footnote)
                                            .foregroundStyle(Color("mode").opacity(0.5))
                                            .frame(minWidth: 30, minHeight: 15)
                                            .padding(2)
                                            .background(Color("mode").opacity(0.1))
                                            .clipShape(.capsule)

                                    }

                                }
                            }




                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }

                    Divider()
                        .padding()

                    ScrollView() {
                        VStack {
                            let sortedFilesSize = appState.appInfo.files.sorted(by: { appState.appInfo.fileSize[$0, default: 0] > appState.appInfo.fileSize[$1, default: 0] })

                            let sortedFilesAlpha = appState.appInfo.files

                            let sort = selectedOption == "Default" ? sortedFilesAlpha : sortedFilesSize

                            ForEach(sort, id: \.self) { path in
                                if let fileSize = appState.appInfo.fileSize[path], let fileIcon = appState.appInfo.fileIcon[path] {
                                    let iconImage = fileIcon.map(Image.init(nsImage:))
                                    VStack {
                                        FileDetailsItem(size: fileSize, icon: iconImage, path: path)
                                        if path != appState.appInfo.files.last {
                                            Divider().padding(.leading, 40)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }

                    Spacer()

                    HStack() {

                        Picker("", selection: Binding(
                            get: { appState.selectedItems.count == appState.appInfo.files.count ? true : false },
                            set: { newValue in
                                updateOnMain {
                                    appState.selectedItems = newValue ? Set(appState.appInfo.files) : []
                                }
                            }
                        )) {
                            Text("􀃲").tag(true)
                            Text("􀂒").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 100)
                        .offset(x: -8)
                        .help("Item Selection")

                        Spacer()

                        if mini {

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

                        if !appState.selectedItems.isEmpty {
                            Button("Uninstall") {
                                Task {
                                    updateOnMain {
                                        appState.appInfo = AppInfo.empty
                                        search = ""
                                        if mini {
                                            appState.currentView = .apps
                                            showPopover = false
                                        } else {
                                            appState.currentView = .empty
                                        }
                                    }
                                    var selectedItemsArray = Array(appState.selectedItems)
                                        .filter { !$0.path.contains(".Trash") }
                                        .map { path in
                                            return path.path.contains("Wrapper") ? path.deletingLastPathComponent().deletingLastPathComponent() : path
                                        }

                                    if let url = URL(string: appState.appInfo.path.absoluteString) {
                                        let appFolderURL = url.deletingLastPathComponent() // Get the immediate parent directory

                                        if appFolderURL.path == "/Applications" || appFolderURL.path == "\(home)/Applications" {
                                            // Do nothing, skip insertion
                                        } else if appFolderURL.pathComponents.count > 2 && appFolderURL.path.contains("Applications") {
                                            // Insert into selectedItemsArray only if there is an intermediary folder
                                            selectedItemsArray.insert(appFolderURL, at: 0)
                                        }
                                    }


                                    killApp(appId: appState.appInfo.bundleIdentifier) {
                                        moveFilesToTrash(at: selectedItemsArray) {
                                            withAnimation {
                                                showPopover = false
                                                updateOnMain {
                                                    appState.isReminderVisible.toggle()
                                                }
                                            }
                                            refreshAppList(appState.appInfo)
                                        }
                                    }

                                }

                            }
                            .buttonStyle(NavButtonBottomBarStyle(image: "trash.fill", help: "Uninstall"))

                        } else {
                            Text("No files selected to clean").font(.title).foregroundStyle(Color("mode")).opacity(0.2)
                                .padding(5)
                        }


                        Spacer()

                        Picker("", selection: $selectedOption) {
                            Text("􀅐").tag("Default")
                            Text("􀆃").tag("Size")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 100)
                        .help("Sorting Selection")
                    }

                }
                .transition(.opacity)
                .padding(20)

            }

        }
    }

    func refreshAppList(_ appInfo: AppInfo) {
        showPopover = false
        let sortedApps = getSortedApps()
        updateOnMain {
            appState.sortedApps.userApps = []
            appState.sortedApps.systemApps = []
            appState.sortedApps.userApps = sortedApps.userApps
            appState.sortedApps.systemApps = sortedApps.systemApps
        }
        Task(priority: .high){
            loadAllPaths(allApps: sortedApps.userApps + sortedApps.systemApps, appState: appState, locations: locations)
        }
    }
}



struct FileDetailsItem: View {
    @EnvironmentObject var appState: AppState
    let size: Int64?
    let icon: Image?
    let path: URL

    var body: some View {

        HStack(alignment: .center, spacing: 20) {
            Toggle("", isOn: Binding(
                get: { self.appState.selectedItems.contains(self.path) },
                set: { isChecked in
                    if isChecked {
                        self.appState.selectedItems.insert(self.path)
                    } else {
                        self.appState.selectedItems.remove(self.path)
                    }
                }
            ))

            .disabled(self.path.path.contains(".Trash"))

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
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .opacity(0.5)
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
