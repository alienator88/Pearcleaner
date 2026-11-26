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
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @State private var newKeyword: String = ""
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.folders.defaultPathsLocked") private var defaultPathsLocked: Bool = true

    var body: some View {
        VStack(spacing: 20) {

            // === Application Folders============================================================================================
            PearGroupBox(header: {
                HStack(alignment: .center, spacing: 0) {
                    Text("Search these folders for applications").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2)
                        .padding(.leading, 5)
                    Spacer()
                }
            }, content: {
                VStack {
                    ScrollView {
                        VStack(spacing: 5) {
                            // Header row
                            HStack(spacing: 8) {
                                Text("Application Folder")
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    .padding(5)

                                Spacer()
                            }

                            Divider().opacity(0.5)

                            ForEach(fsm.folderPaths.indices.sorted(by: {
                                fsm.folderPaths[$0] < fsm.folderPaths[$1]
                            }), id: \.self) { index in
                                HStack(spacing: 8) {
                                    Text(fsm.folderPaths[index])
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                        .font(.callout)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .padding(5)

                                    Spacer()

                                    // Delete button
                                    Button(action: {
                                        if !(defaultPathsLocked && fsm.defaultPaths.contains(fsm.folderPaths[index])) {
                                            fsm.removePath(at: index)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove folder")
                                    .disabled(defaultPathsLocked && fsm.defaultPaths.contains(fsm.folderPaths[index]))
                                    .opacity(defaultPathsLocked && fsm.defaultPaths.contains(fsm.folderPaths[index]) ? 0.3 : 1)
                                    .frame(width: 24)
                                }
                                .background(Color.clear)

                                if index != fsm.folderPaths.indices.last {
                                    Divider().opacity(0.5)
                                }
                            }

                        }

                    }
                    .scrollIndicators(scrollIndicators ? .automatic : .never)
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
                        Text("Drop folders above or click to add").foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        Button {
                            selectFolder()
                        } label: { EmptyView() }
                            .buttonStyle(SimpleButtonStyle(icon: "plus.circle", help: String(localized: "Add folder"), color: ThemeColors.shared(for: colorScheme).secondaryText, size: 16, rotate: true))

//                        Button {
//                            clipboardAdd()
//                        } label: { EmptyView() }
//                            .buttonStyle(SimpleButtonStyle(icon: "doc.on.clipboard", help: String(localized: "Add folder from clipboard"), color: ThemeColors.shared(for: colorScheme).secondaryText, size: 16, rotate: false))

                        Button {
                            toggleDefaultPathsLock()
                        } label: { EmptyView() }
                            .buttonStyle(SimpleButtonStyle(icon: defaultPathsLocked ? "lock.fill" : "lock.open.fill", help: defaultPathsLocked ? "Unlock to remove default paths" : "Lock to restore default paths", color: ThemeColors.shared(for: colorScheme).secondaryText, size: 16, rotate: false))

                        Spacer()
                    }
                }
            })

            // === Orphaned Folders============================================================================================

            PearGroupBox(header: {
                HStack(spacing: 0) {
                    Text("Exclude these files and folders").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2)
                        .padding(.leading, 5)
                    Spacer()
                }
            }, content: {
                VStack {
                    ScrollView {
                        VStack(spacing: 5) {
                            // Compute combined list of all unique paths
                            let allPaths = Array(Set(fsm.fileFolderPathsZ + fsm.fileFolderPathsApps)).sorted()

                            if allPaths.isEmpty {
                                HStack {
                                    Text("No files or folders added")
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                        .font(.callout)
                                        .padding(5)
                                    Spacer()
                                }
                                .disabled(true)
                            } else {
                                // Header row with toggle labels
                                HStack(spacing: 8) {
                                    Text("Path / Keyword")
                                        .font(.caption)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                        .padding(5)

                                    Spacer()

                                    Text("Orphans")
                                        .font(.caption)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                        .frame(width: 44, alignment: .center)

                                    Text("Apps")
                                        .font(.caption)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                        .frame(width: 44, alignment: .center)

                                    // Spacing for delete button
                                    Color.clear.frame(width: 20)
                                }

                                Divider().opacity(0.5)
                            }

                            ForEach(allPaths, id: \.self) { path in
                                HStack(spacing: 8) {
                                    Text(path)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                        .font(.callout)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .padding(5)

                                    Spacer()

                                    // Orphans toggle
                                    Toggle("", isOn: Binding(
                                        get: { fsm.fileFolderPathsZ.contains(path) },
                                        set: { enabled in
                                            if enabled {
                                                fsm.addPathZ(path)
                                            } else {
                                                fsm.removePathZ(path)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.switch)
                                    .controlSize(.mini)
                                    .help("Exclude from orphaned file search")
                                    .frame(width: 44, alignment: .center)

                                    // Apps toggle
                                    Toggle("", isOn: Binding(
                                        get: { fsm.fileFolderPathsApps.contains(path) },
                                        set: { enabled in
                                            if enabled {
                                                fsm.addPathApps(path)
                                            } else {
                                                fsm.removePathApps(path)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.switch)
                                    .controlSize(.mini)
                                    .help("Exclude from app file search")
                                    .frame(width: 44, alignment: .center)

                                    // Delete button
                                    Button(action: {
                                        fsm.removePathZ(path)
                                        fsm.removePathApps(path)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove from both lists")
                                    .frame(width: 24)
                                }
                                .background(Color.clear)

                                if path != allPaths.last {
                                    Divider().opacity(0.5)
                                }
                            }

                        }

                    }
                    .scrollIndicators(scrollIndicators ? .automatic : .never)
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
                                    // Add to orphans by default
                                    fsm.addPathZ(url.path)
                                }
                            }
                        }
                        return true
                    }

                    TextField("Type a keyword to exclude, Enter ↵ to save", text: $newKeyword)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .padding(.horizontal, 20)
                        .onSubmit {
                            // Add to orphans by default
                            fsm.addKeywordZ(newKeyword)
                            newKeyword = ""
                        }

                    HStack {
                        Spacer()
                        Text("Drop files or folders above or click to add").foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        Button {
                            selectFilesFoldersZ()
                        } label: { EmptyView() }
                            .buttonStyle(SimpleButtonStyle(icon: "plus.circle", help: String(localized: "Add file/folder"), color: ThemeColors.shared(for: colorScheme).secondaryText, size: 16, rotate: true))

//                        Button {
//                            clipboardAdd(zombie: true)
//                        } label: { EmptyView() }
//                            .buttonStyle(SimpleButtonStyle(icon: "doc.on.clipboard", help: String(localized: "Add file/folder from clipboard"), color: ThemeColors.shared(for: colorScheme).secondaryText, size: 16, rotate: false))

                        Button {
                            fsm.removeAllPathsZ()
                            fsm.removeAllPathsApps()
                        } label: { EmptyView() }
                            .buttonStyle(SimpleButtonStyle(icon: "trash", help: String(localized: "Remove all files/folders"), color: ThemeColors.shared(for: colorScheme).secondaryText, size: 16, rotate: false))

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

//    private func clipboardAdd(zombie: Bool = false) {
//        let pasteboard = NSPasteboard.general
//
//        // Check for file URL first
//        if let fileURL = pasteboard.propertyList(forType: .fileURL) as? String,
//           let folderURL = URL(string: fileURL) {
//            processClipboardPath(folderURL.path, zombie: zombie)
//        }
//        // Fallback to string-based path
//        else if let clipboardString = pasteboard.string(forType: .string) {
//            processClipboardPath(clipboardString, zombie: zombie)
//        } else {
//            printOS("FSM: Clipboard does not contain a valid path or file URL")
//        }
//    }

    // Helper function to process the extracted path
//    private func processClipboardPath(_ path: String, zombie: Bool) {
//        let fileManager = FileManager.default
//        var isDir: ObjCBool = false
//
//        if fileManager.fileExists(atPath: path, isDirectory: &isDir) {
//            if zombie || isDir.boolValue {
//                zombie ? fsm.addPathZ(path) : fsm.addPath(path)
//            } else {
//                printOS("FSM: Clipboard content is not a directory and orphans mode is disabled")
//            }
//        } else {
//            printOS("FSM: Clipboard content is not a valid path")
//        }
//    }

    private func toggleDefaultPathsLock() {
        defaultPathsLocked.toggle()

        if defaultPathsLocked {
            // Re-locking: add back missing default paths
            for defaultPath in fsm.defaultPaths {
                if !fsm.folderPaths.contains(defaultPath) {
                    fsm.addPath(defaultPath)
                }
            }
        } else {
            // Unlocking: show warning
            showCustomAlert(
                title: "Default Paths Unlocked",
                message: "You can now remove the default application paths.\n\nWarning: If all paths are removed, no applications will be found during scans.",
                style: .warning
            )
        }
    }

}



class FolderSettingsManager: ObservableObject {
    static let shared = FolderSettingsManager()
    
    @Published var folderPaths: [String] = []
    @Published var fileFolderPathsZ: [String] = []
    @Published var fileFolderPathsApps: [String] = []
    private let preferences: FolderPreferencesStoring
    let defaultPaths: [String]

    init(
        preferences: FolderPreferencesStoring = PearcleanerPreferencesStore.shared,
        defaultPaths: [String] = ["/Applications", "\(NSHomeDirectory())/Applications"]
    ) {
        self.preferences = preferences
        self.defaultPaths = defaultPaths
        loadDefaultPathsIfNeeded()
    }



    // Application folders //////////////////////////////////////////////////////////////////////////////////
    private func loadDefaultPathsIfNeeded() {
        var appsPaths = preferences.stringArray(for: .applications) ?? defaultPaths
        let zombiePaths = preferences.stringArray(for: .orphanExclusions) ?? []
        let appsExclusionPaths = preferences.stringArray(for: .appFileExclusions) ?? []
        if appsPaths.count < 2 {
            appsPaths = defaultPaths
        }
        preferences.set(appsPaths, for: .applications)
        self.folderPaths = appsPaths
        self.fileFolderPathsZ = zombiePaths
        self.fileFolderPathsApps = appsExclusionPaths
    }

    func addPath(_ path: String) {
        if !self.folderPaths.contains(path) {
            self.folderPaths.append(path)
            preferences.set(self.folderPaths, for: .applications)
        }
    }

    func removePath(at index: Int) {
        guard self.folderPaths.indices.contains(index) else { return }
        self.folderPaths.remove(at: index) // Update local state
        preferences.set(self.folderPaths, for: .applications)
    }

    func removePath(_ path: String) {
        if let index = self.folderPaths.firstIndex(of: path) {
            self.folderPaths.remove(at: index) // Update local state
            preferences.set(self.folderPaths, for: .applications)
        }
    }

    func refreshPaths() {
        self.folderPaths = preferences.stringArray(for: .applications) ?? defaultPaths
    }

    func getPaths() -> [String] {
        return preferences.stringArray(for: .applications) ?? defaultPaths
    }



    // Orphaned files //////////////////////////////////////////////////////////////////////////////////
    func addPathZ(_ path: String) {
        let sanitizedPath = URL(fileURLWithPath: path).standardizedFileURL.path

        if !self.fileFolderPathsZ.contains(sanitizedPath) {
            self.fileFolderPathsZ.append(sanitizedPath)
            preferences.set(self.fileFolderPathsZ, for: .orphanExclusions)
        }
    }

    func addKeywordZ(_ keyword: String) {
        if !self.fileFolderPathsZ.contains(keyword) {
            self.fileFolderPathsZ.append(keyword)
            preferences.set(self.fileFolderPathsZ, for: .orphanExclusions)
        }
    }

    func removePathZ(at index: Int) {
        guard self.fileFolderPathsZ.indices.contains(index) else { return }
        self.fileFolderPathsZ.remove(at: index) // Update local state
        preferences.set(self.fileFolderPathsZ, for: .orphanExclusions)
    }

    func removePathZ(_ path: String) {
        if let index = self.fileFolderPathsZ.firstIndex(of: path) {
            self.fileFolderPathsZ.remove(at: index) // Update local state
            preferences.set(self.fileFolderPathsZ, for: .orphanExclusions)
        }
    }

    func removeAllPathsZ() {
        self.fileFolderPathsZ.removeAll()
        preferences.set([], for: .orphanExclusions)
    }

    func refreshPathsZ() {
        self.fileFolderPathsZ = preferences.stringArray(for: .orphanExclusions) ?? []
    }

    func getPathsZ() -> [String] {
        return preferences.stringArray(for: .orphanExclusions) ?? []
    }



    // App file exclusions //////////////////////////////////////////////////////////////////////////////////
    func addPathApps(_ path: String) {
        // Only standardize if it's an actual file path (starts with / or ~), not a keyword
        let sanitizedPath: String
        if path.hasPrefix("/") || path.hasPrefix("~") {
            sanitizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        } else {
            sanitizedPath = path
        }

        if !self.fileFolderPathsApps.contains(sanitizedPath) {
            self.fileFolderPathsApps.append(sanitizedPath)
            preferences.set(self.fileFolderPathsApps, for: .appFileExclusions)
        }
    }

    func addKeywordApps(_ keyword: String) {
        if !self.fileFolderPathsApps.contains(keyword) {
            self.fileFolderPathsApps.append(keyword)
            preferences.set(self.fileFolderPathsApps, for: .appFileExclusions)
        }
    }

    func removePathApps(at index: Int) {
        guard self.fileFolderPathsApps.indices.contains(index) else { return }
        self.fileFolderPathsApps.remove(at: index)
        preferences.set(self.fileFolderPathsApps, for: .appFileExclusions)
    }

    func removePathApps(_ path: String) {
        if let index = self.fileFolderPathsApps.firstIndex(of: path) {
            self.fileFolderPathsApps.remove(at: index)
            preferences.set(self.fileFolderPathsApps, for: .appFileExclusions)
        }
    }

    func removeAllPathsApps() {
        self.fileFolderPathsApps.removeAll()
        preferences.set([], for: .appFileExclusions)
    }

    func refreshPathsApps() {
        self.fileFolderPathsApps = preferences.stringArray(for: .appFileExclusions) ?? []
    }

    func getPathsApps() -> [String] {
        return preferences.stringArray(for: .appFileExclusions) ?? []
    }


}
