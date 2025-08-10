//
//  FilesView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/1/23.
//

import Foundation
import SwiftUI
import AlinFoundation

struct FilesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @State private var showPop: Bool = false
    @State private var windowController = WindowManager()
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.brew") private var brew: Bool = false
//    @AppStorage("settings.general.selectedSort") var selectedSortAlpha: Bool = true
    @AppStorage("settings.general.selectedSort") var selectedSort: SortOptionList = .name
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @AppStorage("settings.general.filesWarning") private var warning: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.general.confirmAlert") private var confirmAlert: Bool = false
    @AppStorage("settings.interface.details") private var detailsEnabled: Bool = true
    @AppStorage("settings.general.oneshot") private var oneShotMode: Bool = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @State private var showAlert = false
    @Environment(\.colorScheme) var colorScheme
    @Binding var search: String
    @State private var sortedFiles: [URL] = []
    @State private var infoSidebar: Bool = false

    var body: some View {


        var totalSelectedSize: (real: String, logical: String) {
            var totalReal: Int64 = 0
            var totalLogical: Int64 = 0
            for url in appState.selectedItems {
                let realSize = appState.appInfo.fileSize[url] ?? 0
                let logicalSize = appState.appInfo.fileSizeLogical[url] ?? 0
                totalReal += realSize
                totalLogical += logicalSize
            }
            return (real: formatByte(size: totalReal).human, logical: formatByte(size: totalLogical).human)
        }

        let displaySizeTotal = sizeType == "Real" ? formatByte(size: appState.appInfo.totalSize).human :
        formatByte(size: appState.appInfo.totalSizeLogical).human

        VStack(alignment: .center) {
            if appState.showProgress {
                VStack {
                    Spacer()

                    ProgressStepView(currentStep: appState.progressStep)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {

                ZStack {

                    FileListView(
                        sortedFiles: $sortedFiles,
                        infoSidebar: $infoSidebar,
                        selectedSort: $selectedSort,
                        locations: locations,
                        windowController: windowController,
                        handleUninstallAction: handleUninstallAction,
                        sizeType: sizeType,
                        displaySizeTotal: displaySizeTotal,
                        totalSelectedSize: totalSelectedSize,
                        updateSortedFiles: updateSortedFiles,
                        removeSingleZombieAssociation: removeSingleZombieAssociation,
                        removePath: removePath
                    )
                    
                    SidebarView(infoSidebar: $infoSidebar, displaySizeTotal: displaySizeTotal)

                }
                .animation(.easeInOut(duration: animationEnabled ? 0.35 : 0), value: infoSidebar)
                .padding(20)

            }

        }
        .sheet(isPresented: $showAlert, content: {
            VStack(spacing: 10) {
                Text("Important")
                    .font(.headline)
                Divider()
                Spacer()
                Text("Always confirm the files marked for removal. In rare cases, unrelated files may be found when app names are too similar.")
                    .font(.subheadline)
                Spacer()
                Button("Close") {
                    warning = true
                    showAlert = false
                }
                .buttonStyle(SimpleButtonStyle(icon: "x.circle.fill", label: String(localized: "Close"), help: String(localized: "Dismiss")))//                Spacer()
            }
            .padding(15)
            .frame(width: 400, height: 250)
            .background(GlassEffect(material: .hudWindow, blendingMode: .behindWindow))
        })
        .onAppear {
            if !warning {
                showAlert = true
            }
        }

    }

    // Function to handle the uninstall action
    private func handleUninstallAction() {
        showCustomAlert(enabled: confirmAlert, title: String(localized: "Warning"), message: String(localized: "Are you sure you want to remove these files?"), style: .warning, onOk: {
            Task {
                let selectedItemsArray = Array(appState.selectedItems)
                var appWasRemoved = false

                // Stop Sentinel FileWatcher momentarily to ignore .app bundle being sent to Trash
                sendStopNotificationFW()

                killApp(appId: appState.appInfo.bundleIdentifier) {

                    let result = moveFilesToTrash(appState: appState, at: selectedItemsArray)
                    if result {
                        // Update the app's file list by removing the deleted files
                        updateOnMain {
                            appState.appInfo.fileSize = appState.appInfo.fileSize.filter { !selectedItemsArray.contains($0.key) }
                            appState.appInfo.fileSizeLogical = appState.appInfo.fileSizeLogical.filter { !selectedItemsArray.contains($0.key) }
                            appState.appInfo.fileIcon = appState.appInfo.fileIcon.filter { !selectedItemsArray.contains($0.key) }
                            appState.selectedItems.removeAll()
                            updateSortedFiles()
                        }

                        // Determine if it's a full delete
                        let appPath = appState.appInfo.path.absoluteString
                        let appRemoved = selectedItemsArray.contains(where: { $0.absoluteString == appPath })

                        let mainAppRemoved = !appState.appInfo.wrapped && appRemoved
                        let wrappedAppRemoved = appState.appInfo.wrapped && appRemoved

                        let isInTrash = appState.appInfo.path.path.contains(".Trash")

                        var deleteType: DeleteType

                        if mainAppRemoved || wrappedAppRemoved || isInTrash {
                            deleteType = .fullDelete
                        } else {
                            deleteType = .semiDelete
                        }

                        switch deleteType {
                        case .fullDelete:
                            // The main app bundle is deleted or is already in Trash (Sentinel delete)
                            appWasRemoved = true
                            // Remove the app from the app list
                            removeApp(appState: appState, withPath: appState.appInfo.path)

                        case .semiDelete:
                            // Some files deleted but main app bundle remains
                            // App remains in the list; removes only deleted items
                            break
                        }

                        // Process the next app if in external mode
                        processNextExternalApp(appWasRemoved: appWasRemoved, isInTrash: isInTrash)
                    }

                    // Send Sentinel FileWatcher start notification
                    sendStartNotificationFW()
                }
            }
        })
    }

    // Helper function to process the next external app
    private func processNextExternalApp(appWasRemoved: Bool, isInTrash: Bool) {

        // Remove the processed path to avoid re-processing it
        if !appState.externalPaths.isEmpty {
            appState.externalPaths.removeFirst()
        }

        // Check if the current app requires brew cleanup (Is brew cleanup enabled, was main app bundle removed or was main bundle in Trash)
        if brew && (appWasRemoved || isInTrash) && appState.appInfo.cask != nil {
            // Set terminal view for the current app
            updateOnMain {
                appState.currentView = .terminal
            }

            // Exit early to wait for the user to close the terminal
            return
        }

        // Check if there are more paths in externalPaths
        if appState.externalPaths.isEmpty {
            // No more paths; now update the UI if the app was removed
            if appWasRemoved {
                updateOnMain {
                    search = ""
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        appState.currentView = .empty
                        appState.appInfo = AppInfo.empty
                    }
                }
            }

            // Terminate if oneShotMode is enabled
            if oneShotMode && !appState.multiMode {
                updateOnMain() {
                    NSApp.terminate(nil)
                }
            } else {
                // Reset external/multi mode
                appState.externalMode = false
                appState.multiMode = false
            }
        } else if let nextPath = appState.externalPaths.first {
            // More paths exist; continue processing
            if let nextApp = AppInfoFetcher.getAppInfo(atPath: nextPath) {
                updateOnMain {
                    appState.appInfo = nextApp
                }
                showAppInFiles(appInfo: nextApp, appState: appState, locations: locations)
            }
        }

        // Update the files list
        updateSortedFiles()
    }

    // Function to remove a path from externalPaths and update appInfo if necessary
    private func removePath(_ path: URL) {
        if let index = appState.externalPaths.firstIndex(of: path) {
            appState.externalPaths.remove(at: index)
            // Check if the removed path matches the current appInfo
            if appState.appInfo.path == path {
                // If there are more items in externalPaths, set appInfo to the next app
                if let nextPath = appState.externalPaths.first {
                    let nextApp = AppInfoFetcher.getAppInfo(atPath: nextPath)!
                    updateOnMain {
                        appState.appInfo = nextApp
                    }
                    showAppInFiles(appInfo: nextApp, appState: appState, locations: locations)
                } else {
                    // If no more items are left, set appInfo to .empty and change page to default view
                    updateOnMain {
                        appState.appInfo = .empty
                        search = ""
                        withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                            appState.currentView = .empty
                        }
                    }
                }
            }
        }
    }

    private func updateSortedFiles() {
        let sortedFilesSize = appState.appInfo.fileSize.keys.sorted(by: {
            appState.appInfo.fileSize[$0, default: 0] > appState.appInfo.fileSize[$1, default: 0]
        })

        let sortedFilesAlpha = appState.appInfo.fileSize.keys.sorted { firstURL, secondURL in
            let isFirstPathApp = firstURL.pathExtension == "app"
            let isSecondPathApp = secondURL.pathExtension == "app"
            if isFirstPathApp, !isSecondPathApp {
                return true
            } else if !isFirstPathApp, isSecondPathApp {
                return false
            } else {
                //                return firstURL.lastPathComponent.pearFormat() < secondURL.lastPathComponent.pearFormat()
                return showLocalized(url: firstURL).localizedCaseInsensitiveCompare(showLocalized(url: secondURL)) == .orderedAscending
            }
        }

        let sortedFilesByPath = appState.appInfo.fileSize.keys.sorted { firstURL, secondURL in
            let isFirstPathApp = firstURL.pathExtension == "app"
            let isSecondPathApp = secondURL.pathExtension == "app"
            if isFirstPathApp, !isSecondPathApp {
                return true
            } else if !isFirstPathApp, isSecondPathApp {
                return false
            } else {
                return firstURL.path.localizedCaseInsensitiveCompare(secondURL.path) == .orderedAscending
            }
        }

        switch selectedSort {
        case .size:
            sortedFiles = sortedFilesSize
        case .name:
            sortedFiles = sortedFilesAlpha
        case .path:
            sortedFiles = sortedFilesByPath
        }
//        sortedFiles = selectedSortAlpha ? sortedFilesAlpha : sortedFilesSize
    }

    private func removeZombieAssociations() {
        updateOnMain {
            let associatedFiles = ZombieFileStorage.shared.getAssociatedFiles(for: appState.appInfo.path)

            // Remove associated files from appInfo storage
            appState.appInfo.fileSize = appState.appInfo.fileSize.filter { !associatedFiles.contains($0.key) }
            appState.appInfo.fileSizeLogical = appState.appInfo.fileSizeLogical.filter { !associatedFiles.contains($0.key) }
            appState.appInfo.fileIcon = appState.appInfo.fileIcon.filter { !associatedFiles.contains($0.key) }

            // Remove from sorted list
            sortedFiles.removeAll { associatedFiles.contains($0) }

            // Remove from selected items
            appState.selectedItems = appState.selectedItems.filter { !associatedFiles.contains($0) }

            // Clear stored associations
            ZombieFileStorage.shared.clearAssociations(for: appState.appInfo.path)
            updateSortedFiles()
        }
    }

    private func removeSingleZombieAssociation(_ path: URL) {
        updateOnMain {
            var associatedFiles = ZombieFileStorage.shared.getAssociatedFiles(for: appState.appInfo.path)

            // Remove only the specified path
            associatedFiles.removeAll { $0 == path }

            // Update app info storage
            appState.appInfo.fileSize.removeValue(forKey: path)
            appState.appInfo.fileSizeLogical.removeValue(forKey: path)
            appState.appInfo.fileIcon.removeValue(forKey: path)

            // Update sorted list
            sortedFiles.removeAll { $0 == path }

            // Update selected items
            appState.selectedItems.remove(path)

            // Update stored associations
            if associatedFiles.isEmpty {
                ZombieFileStorage.shared.clearAssociations(for: appState.appInfo.path)
            } else {
                ZombieFileStorage.shared.associatedFiles[appState.appInfo.path] = associatedFiles
            }
            updateSortedFiles()
        }
    }

}

// Define the DeleteType enum
enum DeleteType {
    case fullDelete
    case semiDelete
}

struct FileDetailsItem: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    let path: URL
    let removeAssociation: (URL) -> Void

    var body: some View {

        let realSize = appState.appInfo.fileSize[path] ?? 0
        let logicalSize = appState.appInfo.fileSizeLogical[path] ?? 0
        let fileIcon = appState.appInfo.fileIcon[path]
        let iconImage = fileIcon.flatMap { $0.map(Image.init(nsImage:)) }

        let displaySize = sizeType == "Real" ? formatByte(size: realSize).human : formatByte(size: logicalSize).human

        HStack(alignment: .center, spacing: 20) {
            Toggle(isOn: Binding(
                get: { self.appState.selectedItems.contains(self.path) },
                set: { isChecked in
                    if isChecked {
                        self.appState.selectedItems.insert(self.path)
                    } else {
                        self.appState.selectedItems.remove(self.path)
                    }
                }
            )) { EmptyView() }
                .toggleStyle(SimpleCheckboxToggleStyle())
                .disabled(self.path.path.contains(".Trash"))

            if let appIcon = iconImage {
                appIcon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

            }


            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center) {
                    Text(showLocalized(url: path))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        .font(.title3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(path.lastPathComponent)
                        .overlay{
                            if (isHovered) {
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
                                        .frame(height: 1.5)
                                        .offset(y: 3)
                                }
                            }
                        }

                    if isNested(path: path) {
                        InfoButton(text: String(localized: "Application file is nested within subdirectories. To prevent deleting incorrect folders, Pearcleaner will leave these alone. You may manually delete the remaining folders if required."))                    }

                    if let imageView = folderImages(for: path.path) {
                        imageView
                    }

                    if ZombieFileStorage.shared.isPathAssociated(path) {
                        Image(systemName: "link")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
                    }

                }

                path.path.pathWithArrows(separatorColor: ThemeColors.shared(for: colorScheme).primaryText)
                    .font(.footnote)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .help(path.path)

            }
            .onTapGesture {
                NSWorkspace.shared.selectFile(path.path, inFileViewerRootedAtPath: path.deletingLastPathComponent().path)
            }
            .onHover { hovering in
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                    self.isHovered = hovering
                }
            }


            Spacer()

            //            let displaySize = sizeType == "Real" ? formatByte(size: size!).human :
            //            formatByte(size: sizeL!).human
            Text(verbatim: "\(displaySize)")
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

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
            if ZombieFileStorage.shared.isPathAssociated(path) {
                Button("Unlink File") {
                    removeAssociation(path)
                }
            }
        }

    }
}
