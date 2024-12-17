//
//  Folders.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/20/24.
//


import Foundation
import SwiftUI
import AppKit
import AlinFoundation

struct FolderSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovered = false
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    var body: some View {
        VStack(spacing: 20) {

            // === Application Folders============================================================================================
            PearGroupBox(header: {
                HStack(alignment: .center, spacing: 0) {
                    Text("Search these folders for applications").font(.title2)
                    InfoButton(text: String(localized: "Locations that will be searched for .app files. Click a non-default path to remove it. Default paths can't be removed."))
                        .padding(.leading, 5)
                    Spacer()
                }
            }, content: {
                VStack {
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(fsm.folderPaths.indices, id: \.self) { index in
                                HStack {

                                    Text(fsm.folderPaths[index])
                                        .font(.callout)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .opacity(fsm.defaultPaths.contains(fsm.folderPaths[index]) ? 0.5 : 1)
                                        .padding(5)
                                    Spacer()
                                }
                                .disabled(fsm.defaultPaths.contains(fsm.folderPaths[index]))
                                .onHover { hovering in
                                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                        isHovered = hovering
                                    }
                                    if isHovered && !fsm.defaultPaths.contains(fsm.folderPaths[index]) {
                                        NSCursor.disappearingItem.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                                .onTapGesture {
                                    if !fsm.defaultPaths.contains(fsm.folderPaths[index]) {
                                        fsm.removePath(at: index)
                                    }
                                }

                                if index != fsm.folderPaths.indices.last {
                                    Divider().opacity(0.5)
                                }
                            }

                        }

                    }
                    .scrollIndicators(scrollIndicators ? .automatic : .never)
                    .padding()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onDrop(of: ["public.file-url"], isTargeted: nil) { providers -> Bool in
                        providers.forEach { provider in
                            provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { (data, error) in
                                guard let data = data, error == nil,
                                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                                    printOS("FSM: Failed to load URL")
                                    return
                                }

                                var isDirectory: ObjCBool = false
                                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                                    updateOnMain {
                                        fsm.addPath(url.path)
                                    }
                                } else {
                                    printOS("FSM: The URL is not a directory: \(url.path)")
                                }
                            }
                        }
                        return true
                    }

                    HStack {
                        Spacer()
                        Text("Drop folders above or click to add").opacity(0.5)

                        Button {
                            selectFolder()
                        } label: { EmptyView() }
                        .buttonStyle(SimpleButtonStyle(icon: "plus.circle", help: String(localized: "Add folder"), size: 16, rotate: true))

                        Button {
                            clipboardAdd()
                        } label: { EmptyView() }
                            .buttonStyle(SimpleButtonStyle(icon: "doc.on.clipboard", help: String(localized: "Add folder from clipboard"), size: 16, rotate: false))

                        Spacer()
                    }
                }
            })

            // === Orphaned Folders============================================================================================

            PearGroupBox(header: {
                HStack(spacing: 0) {
                    Text("Exclude these files and folders from orphaned file search").font(.title2)
                    InfoButton(text: String(localized: "Add files or folders that will be ignored when searching for orphaned files. Click a path to remove it from the list."))
                        .padding(.leading, 5)
                    Spacer()
                }
            }, content: {
                VStack {
                    ScrollView {
                        VStack(spacing: 5) {
                            if fsm.fileFolderPathsZ.count == 0 {
                                HStack {
                                    Text("No files or folders added")
                                        .font(.callout)
                                        .opacity(0.5)
                                        .padding(5)
                                    Spacer()
                                }
                                .disabled(true)
                            }
                            ForEach(fsm.fileFolderPathsZ.indices, id: \.self) { index in
                                HStack {

                                    Text(fsm.fileFolderPathsZ[index])
                                        .font(.callout)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .padding(5)
                                    Spacer()
                                }
                                .onHover { hovering in
                                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                        isHovered = hovering
                                    }
                                    if isHovered {
                                        NSCursor.disappearingItem.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                                .onTapGesture {
                                    fsm.removePathZ(at: index)
                                }

                                if index != fsm.fileFolderPathsZ.indices.last {
                                    Divider().opacity(0.5)
                                }
                            }

                        }

                    }
                    .scrollIndicators(scrollIndicators ? .automatic : .never)
                    .padding()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onDrop(of: ["public.file-url"], isTargeted: nil) { providers -> Bool in
                        providers.forEach { provider in
                            provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { (data, error) in
                                guard let data = data, error == nil,
                                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                                    printOS("FSM: Failed to load URL")
                                    return
                                }
                                updateOnMain {
                                    fsm.addPathZ(url.path)
                                }
                            }
                        }
                        return true
                    }

                    HStack {
                        Spacer()
                        Text("Drop files or folders above or click to add").opacity(0.5)
                        Button {
                            selectFilesFoldersZ()
                        } label: { EmptyView() }
                        .buttonStyle(SimpleButtonStyle(icon: "plus.circle", help: String(localized: "Add file/folder"), size: 16, rotate: true))

                        Button {
                            clipboardAdd(zombie: true)
                        } label: { EmptyView() }
                            .buttonStyle(SimpleButtonStyle(icon: "doc.on.clipboard", help: String(localized: "Add file/folder from clipboard"), size: 16, rotate: false))

                        Spacer()
                    }
                }
            })

        }


    }


    private func selectFolder() {
        let dialog = NSOpenPanel()
        dialog.title                   = "Choose a folder"
        dialog.showsResizeIndicator    = false
        dialog.showsHiddenFiles        = false
        dialog.canChooseDirectories    = true
        dialog.canCreateDirectories    = true
        dialog.canChooseFiles          = false

        if dialog.runModal() == NSApplication.ModalResponse.OK {
            if let result = dialog.url {
                fsm.addPath(result.path)
            }
        } else {
            return
        }
    }


    private func selectFilesFoldersZ() {
        let dialog = NSOpenPanel()
        dialog.title                   = "Choose files or folders"
        dialog.showsResizeIndicator    = false
        dialog.showsHiddenFiles        = true
        dialog.canChooseDirectories    = true
        dialog.canCreateDirectories    = false
        dialog.canChooseFiles          = true

        if dialog.runModal() == NSApplication.ModalResponse.OK {
            if let result = dialog.url {
                fsm.addPathZ(result.path)
            }
        } else {
            return
        }
    }

    private func clipboardAdd(zombie: Bool = false) {
        let pasteboard = NSPasteboard.general

        // Check for file URL first
        if let fileURL = pasteboard.propertyList(forType: .fileURL) as? String,
           let folderURL = URL(string: fileURL) {
            processClipboardPath(folderURL.path, zombie: zombie)
        }
        // Fallback to string-based path
        else if let clipboardString = pasteboard.string(forType: .string) {
            processClipboardPath(clipboardString, zombie: zombie)
        } else {
            printOS("FSM: Clipboard does not contain a valid path or file URL")
        }
    }

    // Helper function to process the extracted path
    private func processClipboardPath(_ path: String, zombie: Bool) {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        if fileManager.fileExists(atPath: path, isDirectory: &isDir) {
            if zombie || isDir.boolValue {
                zombie ? fsm.addPathZ(path) : fsm.addPath(path)
            } else {
                printOS("FSM: Clipboard content is not a directory and zombie mode is disabled")
            }
        } else {
            printOS("FSM: Clipboard content is not a valid path")
        }
    }

}



class FolderSettingsManager: ObservableObject {
    @Published var folderPaths: [String] = []
    @Published var fileFolderPathsZ: [String] = []
    private let appsKey = "settings.folders.apps"
    private let zombieKey = "settings.folders.zombie"
    let defaultPaths = ["/Applications", "\(NSHomeDirectory())/Applications"]

    init() {
        loadDefaultPathsIfNeeded()
    }



    // Application folders //////////////////////////////////////////////////////////////////////////////////
    private func loadDefaultPathsIfNeeded() {
        var appsPaths = UserDefaults.standard.stringArray(forKey: appsKey) ?? defaultPaths
        let zombiePaths = UserDefaults.standard.stringArray(forKey: zombieKey) ?? []
        if appsPaths.count < 2 {
            appsPaths = defaultPaths
        }
        UserDefaults.standard.set(appsPaths, forKey: appsKey)
        self.folderPaths = appsPaths
        self.fileFolderPathsZ = zombiePaths
    }

    func addPath(_ path: String) {
        if !self.folderPaths.contains(path) {
            self.folderPaths.append(path)
            UserDefaults.standard.set(self.folderPaths, forKey: appsKey)
        }
    }

    func removePath(at index: Int) {
        guard self.folderPaths.indices.contains(index) else { return }
        self.folderPaths.remove(at: index) // Update local state
        UserDefaults.standard.set(self.folderPaths, forKey: appsKey)
    }

    func removePath(_ path: String) {
        if let index = self.folderPaths.firstIndex(of: path) {
            self.folderPaths.remove(at: index) // Update local state
            UserDefaults.standard.set(self.folderPaths, forKey: appsKey)
        }
    }

    func refreshPaths() {
        self.folderPaths = UserDefaults.standard.stringArray(forKey: appsKey) ?? defaultPaths
    }

    func getPaths() -> [String] {
        return UserDefaults.standard.stringArray(forKey: appsKey) ?? defaultPaths
    }



    // Orphaned files //////////////////////////////////////////////////////////////////////////////////
    func addPathZ(_ path: String) {
        let sanitizedPath = path.hasPrefix("/private") ? String(path.dropFirst(8)) : path

        if !self.fileFolderPathsZ.contains(sanitizedPath) {
            self.fileFolderPathsZ.append(sanitizedPath)
            UserDefaults.standard.set(self.fileFolderPathsZ, forKey: zombieKey)
        }
    }

    func removePathZ(at index: Int) {
        guard self.fileFolderPathsZ.indices.contains(index) else { return }
        self.fileFolderPathsZ.remove(at: index) // Update local state
        UserDefaults.standard.set(self.fileFolderPathsZ, forKey: zombieKey)
    }

    func removePathZ(_ path: String) {
        if let index = self.fileFolderPathsZ.firstIndex(of: path) {
            self.fileFolderPathsZ.remove(at: index) // Update local state
            UserDefaults.standard.set(self.fileFolderPathsZ, forKey: zombieKey)
        }
    }

    func refreshPathsZ() {
        self.fileFolderPathsZ = UserDefaults.standard.stringArray(forKey: zombieKey) ?? []
    }

    func getPathsZ() -> [String] {
        return UserDefaults.standard.stringArray(forKey: zombieKey) ?? []
    }


}
