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
    @Environment(\.colorScheme) var colorScheme
    @Binding var showPopover: Bool
    @Binding var search: String
    @State private var toggles: Bool = true

    var body: some View {
        VStack(alignment: .center) {
            if appState.showProgress { //!self.showDetails {
                VStack {
                    Spacer()
                    //                    ProgressView("Finding application files..")
                    //                        .progressViewStyle(.linear)
                    //                    Spacer()
                    Text("Gathering leftover files, this might take a while..").font(.title3)
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
                    HStack() {
                        //icon
//                        if let appIcon = appState.appInfo.appIcon {
//                            Image(nsImage: appIcon)
//                                .resizable()
//                                .scaledToFit()
//                            //                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 50, height: 50)
//                                .clipShape(RoundedRectangle(cornerRadius: 8))
//                                .padding(.leading)
//                        }
                        //app title, size and items
                        VStack(alignment: .center) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 5){
                                    HStack(alignment: .center) {
                                        Text("Leftover Files").font(.title).fontWeight(.bold)
                                        //                                            .foregroundStyle(Color("AccentColor"))
//                                        Text("•").foregroundStyle(Color("AccentColor"))
//                                        Text("\(appState.appInfo.appVersion)").font(.title3)
                                        //                                            .foregroundStyle(.gray.opacity(0.8))
                                    }
//                                    Text("\(appState.appInfo.bundleIdentifier)").font(.title3)
//                                        .foregroundStyle((.gray.opacity(0.8)))
                                }

                                Spacer()

                                Text("\(formatByte(size: appState.zombieFile.totalSize))").font(.title).fontWeight(.bold)


                            }


                            Divider().padding(.bottom, 7)

                            HStack{
                                Text("Files and folders remaining from previously installed applications")
                                    .font(.callout)
                                //                                    .foregroundStyle(Color("AccentColor"))
                                    .opacity(0.8)
                                Spacer()
                                Text("\(appState.zombieFile.fileSize.count > 1 ? "\(appState.zombieFile.fileSize.count) items" : "\(appState.zombieFile.fileSize.count) item")").font(.callout)
//                                                                    .foregroundStyle(Color("AccentColor").opacity(0.7))
                                    .underline()
                            }
                            HStack() {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .popover(isPresented: $showPop, arrowEdge: .top) {
                                        VStack() {
                                            Text("Leftover file search is not 100% accurate as it doesn't have any app bundles to check against.\nThis searches for files/folders and excludes the ones that have overlap with your currently installed apps. \nMake sure to confirm files marked for removal are correct.")
                                                .padding()
                                                .font(.title2)
                                        }

                                    }

                                Text("Warning")
                                    .foregroundStyle(Color.red)

                                Spacer()
                                Toggle("\(toggles ? "Selected: All" : "Selected: None")", isOn: $toggles)
                                    .controlSize(.small)
//                                    .toggleStyle(.switch)
                                    .onChange(of: toggles) { value in
                                        if value {
                                            updateOnMain {
                                                appState.selectedZombieItems = Set(appState.zombieFile.fileSize.keys)
                                            }
                                        } else {
                                            updateOnMain {
                                                appState.selectedZombieItems.removeAll()
                                            }
                                        }
                                    }
                            }
                            .padding(.top)
                            .onTapGesture {
                                showPop = true
                            }

                            


                        }
                        .padding(20)
                    }
                    //                    .padding(.horizontal)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                        //                            .strokeBorder(Color("AccentColor"), lineWidth: 0.5)
                            .fill(Color("mode").opacity(colorScheme == .dark ? 0.05 : 0.05))
                        //                            .background(
                        //                                RoundedRectangle(cornerRadius: 8)
                        //                                    .strokeBorder(Color("AccentColor").opacity(colorScheme == .dark ? 0.1 : 0.1), lineWidth: 1)
                        //                            )
                    )



                    ScrollView() {
                        LazyVStack {
                            ForEach(appState.zombieFile.fileSize.keys.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }), id: \.self) { file in
                                if let fileSize = appState.zombieFile.fileSize[file], let fileIcon = appState.zombieFile.fileIcon[file] {
                                    let iconImage = fileIcon.map(Image.init(nsImage:))

                                    ZombieFileDetailsItem(size: fileSize, icon: iconImage, path: file)
                                        .padding(.trailing)

                                    if file != appState.zombieFile.fileSize.keys.sorted(by: { $0.absoluteString < $1.absoluteString }).last {
                                        Divider().padding(.leading, 40)
                                    }
                                }
                            }
                        }

                    }
                    .padding()

                    HStack() {
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
                        }


                        Button("Rescan") {
                            updateOnMain {
                                appState.zombieFile = .empty
                                appState.showProgress.toggle()
                                reversePathsSearch(appState: appState, locations: locations)
                            }
                        }

                        Button("Remove") {
                            Task {
                                updateOnMain {
                                    appState.zombieFile = .empty
                                    search = ""
                                    if mini {
                                        appState.currentView = .apps
                                        showPopover = false
                                    } else {
                                        appState.currentView = .empty
                                    }
                                }

                                let selectedItemsArray = Array(appState.selectedZombieItems)
                                    .filter { !$0.path.contains(".Trash") }

                                killApp(appId: appState.appInfo.bundleIdentifier) {
                                    moveFilesToTrash(at: selectedItemsArray) {
                                        withAnimation {
                                            showPopover = false
                                            updateOnMain {
                                                appState.isReminderVisible.toggle()
                                                if sentinel {
                                                    launchctl(load: true)
                                                }
                                            }
                                        }
                                    }
                                }

                            }

                        }
                        .disabled(appState.selectedZombieItems.isEmpty)
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
                    .lineLimit(2)
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

