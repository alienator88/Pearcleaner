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
    @State private var appSize: String = ""
    @State private var showDetails: Bool = false
    @State private var showPop: Bool = false
    @State private var itemDetails: [(size: String, icon: Image?)] = []
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @Binding var showPopover: Bool
    @Binding var search: String

    var body: some View {
        VStack(alignment: .center) {
            if !self.showDetails {
                VStack {
                    Spacer()
//                    ProgressView("Finding application files..")
//                        .progressViewStyle(.linear)
//                    Spacer()
                    Text("Finding application files..").font(.title3)
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
                                
                                Text("\(appSize)").font(.title).fontWeight(.bold)
//                                    .foregroundStyle(Color("AccentColor"))
                            }
                            
                            
                            Divider().padding(.bottom, 7)
                            
                            HStack{
                                Text("Application files and folders")
                                    .font(.callout)
//                                    .foregroundStyle(Color("AccentColor"))
                                    .opacity(0.8)
                                Spacer()
                                Text("\(appState.paths.count > 1 ? "\(appState.paths.count) items" : "\(appState.paths.count) item")").font(.callout)
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
                    
                    
                    
                    ScrollView() {
                        VStack {
                            ForEach(Array(zip(appState.paths, itemDetails)), id: \.0) { path, details in
                                if let firstPath = appState.paths.first, path == firstPath {
                                    FileDetailsItem(size: details.size, icon: details.icon, path: path)
                                        .padding(.trailing)
                                    Divider().padding(.leading, 40).padding(.trailing)
                                } else {
                                    VStack {
                                        FileDetailsItem(size: details.size, icon: details.icon, path: path)
                                        if path != appState.paths.last {
                                            Divider().padding(.leading, 40)
                                        }
                                    }
                                    .padding(.leading, 47).padding(.trailing)

                                    
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
//                            .buttonStyle(FilesViewActionButton(action: .close))
                        }


                        Button("Uninstall") {
                            Task {
                                updateOnMain {
                                    appState.appInfo = AppInfo.empty
                                    if mini {
                                        search = ""
                                        appState.currentView = .apps
                                        showPopover = false
                                    } else {
                                        appState.currentView = .empty
                                    }
                                }
                                
                                let selectedItemsArray = Array(appState.selectedItems)
                                    .filter { !$0.path.contains(".Trash") }
                                    .map { path in
                                        return path.path.contains("Wrapper") ? path.deletingLastPathComponent().deletingLastPathComponent() : path
                                    }

                                killApp(appId: appState.appInfo.bundleIdentifier) {
                                    moveFilesToTrash(at: selectedItemsArray) {
                                        withAnimation {
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
//        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            Task {
                calculateFileDetails()
            }
        }
    }
    
    
    func calculateFileDetails() {
        if appState.paths.count != 0 {
            itemDetails = Array(repeating: (size: "", icon: nil), count: appState.paths.count)
            Task {
                for (index, path) in appState.paths.enumerated() {
                    var size = ""
                    var icon: Image? = nil
                    
                    if let appSize = totalSizeOnDisk(for: path) {
                        size = "\(appSize)"
                    } else {
                        print("Error calculating the total size on disk for item \(index).")
                    }
                    if let folderIcon = getIconForFileOrFolder(atPath: path) {
                        icon = folderIcon
                    }
                    itemDetails[index] = (size: size, icon: icon)
                }
                if let appSize = totalSizeOnDisk(for: appState.paths) {
                    self.appSize = "\(appSize)"
                    self.showDetails = true
                } else {
                    print("Error calculating the total size on disk.")
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                calculateFileDetails()
            }
        }
    }
    
    
    func refreshAppList(_ appInfo: AppInfo) {
        let sortedApps = getSortedApps()
        updateOnMain {
            appState.sortedApps.userApps = []
            appState.sortedApps.systemApps = []
            appState.sortedApps.userApps = sortedApps.userApps
            appState.sortedApps.systemApps = sortedApps.systemApps
        }
        
    }
}



struct FileDetailsItem: View {
    @EnvironmentObject var appState: AppState
    let size: String
    let icon: Image?
    let path: URL

//    init(size: String, icon: Image?, path: URL) {
//        self.size = size
//        self.icon = icon
//        self.path = path.path.contains("Wrapper") ? path.deletingLastPathComponent().deletingLastPathComponent() : path
//    }

    var body: some View {

        HStack(alignment: .center, spacing: 20) {
            Toggle("", isOn: Binding(
                get: { self.appState.selectedItems.contains(self.path) },
                set: { isChecked in
                    if isChecked {
                        self.appState.selectedItems.insert(self.path)
                        if self.path == appState.appInfo.path {
                            self.appState.paths.forEach { self.appState.selectedItems.insert($0) }
                        }
                    } else {
                        self.appState.selectedItems.remove(self.path)
                        if self.path == appState.appInfo.path {
                            self.appState.selectedItems.forEach { self.appState.selectedItems.remove($0) }
                        }
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
//                    .foregroundStyle(Color("AccentColor"))
                    .help(path.path)
            }
            
            Spacer()
            if size.isEmpty {
                ProgressView().controlSize(.small)
            } else {
                Text(size)
            }
            
            
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
