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
    @State private var appSize: String = ""
    @State private var showDetails: Bool = false
    @State private var showPop: Bool = false
    @State private var itemDetails: [(size: String, icon: Image?)] = []
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .center) {
            if !self.showDetails {
                VStack {
                    Spacer()
                    ProgressView("Finding application files..")
                    Spacer()
                }
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
                                .padding(.leading)
                        }
                        //app title, size and items
                        VStack(alignment: .center) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 5){
                                    HStack {
                                        Text("\(appState.appInfo.appName)").font(mini ? .title2 :.title).fontWeight(.bold)
//                                            .foregroundStyle(Color("AccentColor"))
                                        Text("•").foregroundStyle(Color("AccentColor"))
                                        Text("\(appState.appInfo.appVersion)").font(.title3)
//                                            .foregroundStyle(.gray.opacity(0.8))
                                    }
                                    Text("\(appState.appInfo.bundleIdentifier)").font(mini ? .footnote :.title3)
                                        .foregroundStyle((.gray.opacity(0.8)))
                                }
                                
                                Spacer()
                                
                                Text("\(appSize)").font(mini ? .title2 :.title).fontWeight(.bold)
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
                            if appState.appInfo.appName.count < 5 {
                                HStack(alignment: .center) {
                                    Button(""){
                                        showPop = true
                                    }
                                    .buttonStyle(SimpleButtonStyle(icon: "exclamationmark.triangle.fill", help: "Warning", color: .red))
                                    .popover(isPresented: $showPop, arrowEdge: .top) {
                                        VStack() {
                                            Text("Pearcleaner searches for files with a combination of bundle id and app name.\n**\(appState.appInfo.appName)** has a common or short app name so there might be unrelated files found.\nPlease check the list thoroughly before uninstalling.")
                                                .padding(20)
                                                .font(.title2)
                                        }
                                        
                                    }
                                    Text("Read caution message")
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
                    .padding([.horizontal, .bottom])
                    .background(
                        RoundedRectangle(cornerRadius: 8)
//                            .strokeBorder(Color("AccentColor"), lineWidth: 0.5)
                            .fill(Color("mode").opacity(colorScheme == .dark ? 0.05 : 0.05))
//                            .background(
//                                RoundedRectangle(cornerRadius: 8)
//                                    .strokeBorder(Color("AccentColor").opacity(colorScheme == .dark ? 0.1 : 0.1), lineWidth: 1)
//                            )
                    )
                    
                    
                    
                    ScrollView {
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
                        
//                        if appState.trashLaunch {
//                            Button("Close") {
//                                Task {
//                                    NSApp.terminate(nil)
//                                    exit(0)
//                                }
//                            }
//                            .buttonStyle(WindowActionButton(action: .cancel))
//                        }
                        
                        
                        Button("Uninstall") {
                            Task {
                                updateOnMain {
                                    appState.appInfo = AppInfo.empty
                                    appState.currentView = .empty
                                }
                                let selectedItemsArray = Array(appState.selectedItems).filter { !$0.path.contains(".Trash") }
                                killApp(appId: appState.appInfo.bundleIdentifier) {
                                    moveFilesToTrash(at: selectedItemsArray) {
                                        withAnimation {
                                            appState.isReminderVisible.toggle()
                                        }
                                        refreshAppList(appState.appInfo)
                                    }
                                }
                            }
                        }
                        .disabled(appState.selectedItems.isEmpty)
                        .buttonStyle(WindowActionButton(action: .accept))
                    }
//                    .padding(.top)
                    
                }
                .transition(.opacity)
                .padding(20)
                
            }
            
        }
//        .frame(minWidth: 700)
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
        appState.sortedApps.userApps = []
        appState.sortedApps.systemApps = []
        appState.sortedApps.userApps = sortedApps.userApps
        appState.sortedApps.systemApps = sortedApps.systemApps
    }
}



struct FileDetailsItem: View {
    @EnvironmentObject var appState: AppState
    let size: String
    let icon: Image?
    let path: URL

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


func writeLog(string: String) {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser.path
    let logFilePath = "\(home)/Downloads/log.txt"
    
    // Check if the log file exists, and create it if it doesn't
    if !fileManager.fileExists(atPath: logFilePath) {
        if !fileManager.createFile(atPath: logFilePath, contents: nil, attributes: nil) {
            print("Failed to create the log file.")
            return
        }
    }
    
    do {
        if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
            let ns = "\(string)\n"
            fileHandle.seekToEndOfFile()
            fileHandle.write(ns.data(using: .utf8)!)
            fileHandle.closeFile()
        } else {
            print("Error opening file for appending")
        }
    }
}

//struct FilesView: View {
//    @EnvironmentObject var appState: AppState
//    @State private var appSize: String = ""
//    @State private var showDetails: Bool = false
//    @State private var itemDetails: [(size: String, icon: Image?)] = []
//    
//    var body: some View {
//        VStack(alignment: .center) {
//            if !self.showDetails {
//                ProgressView("Finding application files..")
//            } else {
//                VStack() {
//                    HStack() {
//                        Text("\(appState.paths.count > 1 ? "\(appState.paths.count) files found" : "\(appState.paths.count) file found")")
//                        Text("•")
//                        Text("\(appSize)")
//                    }
//                    .padding()
//                    
//                    if appState.appInfo.appName.count < 5 {
//                        Text("Short or common word app name, there might be unrelated files found")
//                            .font(.footnote)
//                            .foregroundStyle(.red)
//                    }
//                    
//                    ScrollView {
//                        ForEach(Array(zip(appState.paths, itemDetails)), id: \.0) { path, details in
//                            FileDetailsItem(size: details.size, icon: details.icon, path: path)
//                        }
//                    }
//                    .frame(width: 500)
//                    
//                    Button("Remove") {
//                        Task {
//                            updateOnMain {
//                                appState.appInfo = AppInfo.empty
//                            }
//                            let selectedItemsArray = Array(appState.selectedItems)
//                            killApp(appId: appState.appInfo.bundleIdentifier) {
//                                moveFilesToTrash(at: selectedItemsArray) {
//                                    refreshAppList(appState.appInfo)
//                                }
//                            }
//                        }
//                    }
//                    .disabled(appState.selectedItems.isEmpty)
//                }
//                .padding()
//                
//            }
//            
//        }
//        .frame(minWidth: 500)
//        .onAppear {
//            Task {
//                //                appState.appInfo = appInfo
//                //                findPathsForApp(appState: appState, appInfo: appState.appInfo)
//                calculateFileDetails()
//            }
//        }
//    }
//    
//    
//    func calculateFileDetails() {
//        if appState.paths.count != 0 {
//            itemDetails = Array(repeating: (size: "", icon: nil), count: appState.paths.count)
//            
//            Task {
//                for (index, path) in appState.paths.enumerated() {
//                    var size = ""
//                    var icon: Image? = nil
//                    
//                    if let appSize = totalSizeOnDisk(for: path) {
//                        size = "\(appSize)"
//                    } else {
//                        print("Error calculating the total size on disk for item \(index).")
//                    }
//                    
//                    if let folderIcon = getIconForFileOrFolder(atPath: path) {
//                        icon = folderIcon
//                    }
//                    
//                    itemDetails[index] = (size: size, icon: icon)
//                    
//                    
//                    
//                }
//                
//                if let appSize = totalSizeOnDisk(for: appState.paths) {
//                    self.appSize = "\(appSize)"
//                    //                    updateOnMain {
//                    //                        appState.doneLoading = true
//                    //                    }
//                    self.showDetails = true
//                    //                    appState.doneLoading = true
//                } else {
//                    print("Error calculating the total size on disk.")
//                }
//            }
//        } else {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                calculateFileDetails()
//            }
//        }
//    }
//    
//    func refreshAppList(_ appInfo: AppInfo) {
//        let sortedApps = getSortedApps()
//        appState.sortedApps.userApps = []
//        appState.sortedApps.systemApps = []
//        appState.sortedApps.userApps = sortedApps.userApps
//        appState.sortedApps.systemApps = sortedApps.systemApps
//    }
//}
