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
    @State private var toggles: Bool = true

    var body: some View {
        VStack(alignment: .center) {
            if appState.showProgress { //!self.showDetails {
                VStack {
                    Spacer()
//                    ProgressView("Finding application files..")
//                        .progressViewStyle(.linear)
//                    Spacer()
                    Text("Almost there, still gathering files..").font(.title3)
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
                        if let appIcon = appState.appInfo.appIcon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .scaledToFit()
//                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.leading)
                        }
                        //app title, size and items
                        VStack(alignment: .center) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 5){
                                    HStack {
                                        Text("\(appState.appInfo.appName)").font(.title).fontWeight(.bold)
//                                            .foregroundStyle(Color("AccentColor"))
                                        Text("•").foregroundStyle(Color("AccentColor"))
                                        Text("\(appState.appInfo.appVersion)").font(.title3)
//                                            .foregroundStyle(.gray.opacity(0.8))
                                    }
                                    Text("\(appState.appInfo.bundleIdentifier)").font(.title3)
                                        .foregroundStyle((.gray.opacity(0.8)))
                                }
                                
                                Spacer()
                                
                                Text("\(formatByte(size: appState.appInfo.totalSize))").font(.title).fontWeight(.bold)


                            }
                            
                            
                            Divider().padding(.bottom, 7)
                            
                            HStack{
                                Text("Application files and folders")
                                    .font(.callout)
//                                    .foregroundStyle(Color("AccentColor"))
                                    .opacity(0.8)
                                Spacer()
                                Text("\(appState.appInfo.fileSize.count > 1 ? "\(appState.appInfo.fileSize.count) items" : "\(appState.appInfo.fileSize.count) item")").font(.callout)
//                                    .foregroundStyle(Color("AccentColor").opacity(0.7))
                                    .underline()
                            }
                            if appState.appInfo.webApp {
                                HStack {
                                    Text("web")
                                        .font(.footnote)
                                        .foregroundStyle(Color("mode").opacity(0.5))
                                        .frame(minWidth: 30, minHeight: 15)
                                        .padding(2)
                                        .background(Color("mode").opacity(0.1))
                                        .clipShape(.capsule)
                                    Spacer()
                                }
                                
                            }
                            if appState.appInfo.appName.count < 5 {
                                HStack(alignment: .center) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                        .popover(isPresented: $showPop, arrowEdge: .top) {
                                            VStack() {
                                                Text("Pearcleaner searches for files via a combination of bundle id and app name.\n**\(appState.appInfo.appName)** has a common or short app name so there might be unrelated files found.\nPlease check the list thoroughly before uninstalling.")
                                                    .padding()
                                                    .font(.title2)
                                            }
                                            
                                        }
                                    
                                    Text("Warning")
                                        .foregroundStyle(Color.red)

                                    Spacer()
                                }
                                .padding(.top)
                                
                                .onTapGesture {
                                    showPop = true
                                }
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
                    
                    
                    HStack(alignment: .center) {
                        Spacer()

                        Text("\(toggles ? "Selected: All" : "Selected: None")").font(.subheadline)
                        Toggle("", isOn: $toggles)
                            .onChange(of: toggles) { value in
                                if value {
                                    updateOnMain {
                                        appState.selectedItems = Set(appState.appInfo.files)
                                    }
                                } else {
                                    updateOnMain {
                                        appState.selectedItems.removeAll()
                                    }
                                }
                            }
                    }
                    .padding(.top)

                    ScrollView() {
                        VStack {
                            let sortedFilesSize = appState.appInfo.files.sorted(by: { appState.appInfo.fileSize[$0, default: 0] > appState.appInfo.fileSize[$1, default: 0] })

//                            let sortedFilesAlpha = appState.appInfo.files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

                            let sort = selectedOption == "Default" ? appState.appInfo.files : sortedFilesSize

                            ForEach(sort, id: \.self) { path in
                                if let fileSize = appState.appInfo.fileSize[path], let fileIcon = appState.appInfo.fileIcon[path] {
                                    let iconImage = fileIcon.map(Image.init(nsImage:))
                                    VStack {
                                        FileDetailsItem(size: fileSize, icon: iconImage, path: path)
                                        if path != appState.appInfo.files.last {
                                            Divider().padding(.leading, 40)
                                        }
                                    }
//                                    .padding(.leading, 47).padding(.trailing)
//                                    if let firstPath = appState.appInfo.files.first, path == firstPath {
//                                        FileDetailsItem(size: fileSize, icon: iconImage, path: path)
//                                            .padding(.trailing)
//                                        Divider().padding(.leading, 40).padding(.trailing)
//                                    } else {
//                                        VStack {
//                                            FileDetailsItem(size: fileSize, icon: iconImage, path: path)
//                                            if path != appState.appInfo.files.last {
//                                                Divider().padding(.leading, 40)
//                                            }
//                                        }
//                                        .padding(.leading, 47).padding(.trailing)
//                                    }
                                }
                            }
                        }
                    }
                    .padding([.bottom])
                    
                    HStack() {
                        Picker(selection: $selectedOption, label: Text("Sort")) {
                            Text("Default").tag("Default")
                            Text("Size").tag("Size")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 150)

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
//                            .buttonStyle(FilesViewActionButton(action: .close))
                        }


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
                                    } else if appFolderURL.pathComponents.count > 2 {
                                        // Insert into selectedItemsArray only if there is an intermediary folder
                                        selectedItemsArray.insert(appFolderURL, at: 0)
                                    }
                                }

                                // Save trashed files for undo operation
//                                updateOnMain {
//                                    appState.trashedFiles = selectedItemsArray
//                                }

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
                                        refreshAppList(appState.appInfo)
                                    }
                                }
                                
                            }
                            
                        }
                        .disabled(appState.selectedItems.isEmpty)
//                        .buttonStyle(FilesViewActionButton(action: .uninstall))
                    }
//                    .padding(.top)
                    
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
//                get: { self.appState.selectedItems.contains(self.path) },
//                set: { isChecked in
//                    if isChecked {
//                        self.appState.selectedItems.insert(self.path)
//                        if self.path == appState.appInfo.path {
//                            self.appState.appInfo.fileSize.keys.forEach {
//                                self.appState.selectedItems.insert($0)
//                            }
//                        }
//                    } else {
//                        self.appState.selectedItems.remove(self.path)
//                        if self.path == appState.appInfo.path {
//                            self.appState.selectedItems.forEach {
//                                self.appState.selectedItems.remove($0)
//                            }
//                        }
//                    }
//                }
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
