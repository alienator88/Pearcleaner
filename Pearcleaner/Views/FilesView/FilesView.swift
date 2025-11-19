//
//  FilesView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/1/23.
//

import AlinFoundation
import Foundation
import SwiftUI

struct FilesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fsm: FolderSettingsManager
    @EnvironmentObject var locations: Locations
    @State private var showPop: Bool = false
    @State private var windowController = WindowManager()
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.brew") private var brew: Bool = false
    //    @AppStorage("settings.general.selectedSort") var selectedSortAlpha: Bool = true
    @AppStorage("settings.general.selectedSort") var selectedSort: SortOptionList = .name
    @AppStorage("settings.interface.fileListViewMode") private var viewMode: FileListViewMode = .simple
    @AppStorage("settings.general.filesWarning") private var warning: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.general.confirmAlert") private var confirmAlert: Bool = false
    @AppStorage("settings.interface.details") private var detailsEnabled: Bool = true
    @AppStorage("settings.general.oneshot") private var oneShotMode: Bool = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.files.showSidebarOnLoad") private var showSidebarOnLoad: Bool = false
    @State private var showAlert = false
    @Environment(\.colorScheme) var colorScheme
    @State private var sortedFiles: [URL] = []
    @State private var infoSidebar: Bool = false
    @AppStorage("settings.general.searchSensitivity") private var globalSensitivityLevel: SearchSensitivityLevel = .strict
    @ObservedObject private var consoleManager = GlobalConsoleManager.shared

    var body: some View {

        var totalSelectedSize: String {
            var total: Int64 = 0
            for url in appState.selectedItems {
                let size = appState.appInfo.fileSize[url] ?? 0
                total += size
            }
            return formatByte(size: total).human
        }

        let displaySizeTotal = formatByte(size: appState.appInfo.totalSize).human

        VStack(alignment: .center) {
            if appState.showProgress {
                VStack {
                    Spacer()

                    ProgressView()
//                    ProgressStepView(currentStep: appState.progressStep)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all)
//                .transition(.opacity)
//                .animation(.none, value: appState.showProgress)
            } else {

                ZStack {

                    FileListView(
                        sortedFiles: $sortedFiles,
                        infoSidebar: $infoSidebar,
                        selectedSort: $selectedSort,
                        viewMode: $viewMode,
                        locations: locations,
                        windowController: windowController,
                        handleUninstallAction: handleUninstallAction,
                        displaySizeTotal: displaySizeTotal,
                        totalSelectedSize: totalSelectedSize,
                        updateSortedFiles: updateSortedFiles,
                        removeSingleZombieAssociation: removeSingleZombieAssociation,
                        removePath: removePath
                    )

                    SidebarView(infoSidebar: $infoSidebar, displaySizeTotal: displaySizeTotal)
                        .padding([.trailing, .bottom], 20)

                }
                .animation(
                    animationEnabled ? .spring(response: 0.35, dampingFraction: 0.8) : .none,
                    value: infoSidebar)

            }

        }
        .sheet(
            isPresented: $showAlert,
            content: {
                VStack(spacing: 10) {
                    Text("Important")
                        .font(.headline)
                    Divider()
                    Spacer()
                    Text(
                        "Always confirm the files marked for removal. In rare cases, unrelated files may be found when app names are too similar."
                    )
                    .font(.subheadline)
                    Spacer()
                    Button("Close") {
                        warning = true
                        showAlert = false
                    }
                    .buttonStyle(
                        SimpleButtonStyle(
                            icon: "x.circle.fill", label: String(localized: "Close"),
                            help: String(localized: "Dismiss")))  //                Spacer()
                }
                .padding(15)
                .frame(width: 400, height: 250)
                .background(GlassEffect(material: .hudWindow, blendingMode: .behindWindow))
            }
        )
        .onAppear {
            if !warning {
                showAlert = true
            }
            if showSidebarOnLoad {
                infoSidebar = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FileSearchViewShouldRefresh"))) { _ in
            // Refresh current app's files
            if !appState.appInfo.bundleIdentifier.isEmpty {
                let currentAppInfo = appState.appInfo
                showAppInFiles(appInfo: currentAppInfo, appState: appState, locations: locations)
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {

            ToolbarItem { Spacer() }

            TahoeToolbarItem(isGroup: true) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        consoleManager.showConsole.toggle()
                    }
                } label: {
                    Label("Console", systemImage: consoleManager.showConsole ? "terminal.fill" : "terminal")
                }
                .help("Toggle console output")

                Button {
                    viewMode = viewMode == .simple ? .categorized : .simple
                } label: {
                    Label("View", systemImage: viewMode == .simple ? "list.bullet" : "checklist")
                }
                .help(viewMode == .simple ? "Switch to categorized view" : "Switch to simple view")

                Button {
                    // Cycle through sort options
                    let allOptions = SortOptionList.allCases
                    if let currentIndex = allOptions.firstIndex(of: selectedSort) {
                        let nextIndex = (currentIndex + 1) % allOptions.count
                        selectedSort = allOptions[nextIndex]
                        updateSortedFiles()
                    }
                } label: {
                    Label(selectedSort.title, systemImage: selectedSort.systemImage)
                }
                .help("Sort by \(selectedSort.title). Click to cycle through options")


                Button {
                    GlobalConsoleManager.shared.appendOutput("Refreshing files for \(appState.appInfo.appName)...\n", source: CurrentPage.applications.title)
                    let currentAppInfo = appState.appInfo
                    updateOnMain {
                        appState.selectedItems = []
                    }
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        showAppInFiles(
                            appInfo: currentAppInfo, appState: appState,
                            locations: locations)
                    }
                    GlobalConsoleManager.shared.appendOutput("✓ Refreshed files\n", source: CurrentPage.applications.title)
                } label: {
                    Label("Refresh", systemImage: "arrow.counterclockwise")
                }

                Button {
                    if GlobalConsoleManager.shared.showConsole {
                        GlobalConsoleManager.shared.showConsole.toggle()
                    }
                    infoSidebar.toggle()
                } label: {
                    Label("Info", systemImage: "sidebar.trailing")
                }
                .help("See app details")
            }


        }

    }

    // Function to handle the uninstall action
    private func handleUninstallAction() {
        showCustomAlert(
            enabled: confirmAlert, title: String(localized: "Warning"),
            message: String(localized: "Are you sure you want to remove these files?"),
            style: .warning,
            onOk: {
                Task {
                    GlobalConsoleManager.shared.appendOutput("Starting deletion for \(appState.appInfo.appName)...\n", source: CurrentPage.applications.title)
                    let selectedItemsArray = Array(appState.selectedItems)
                    var appWasRemoved = false

                    // Stop Sentinel FileWatcher momentarily to ignore .app bundle being sent to Trash
                    sendStopNotificationFW()

                    // Kill the app before proceeding
                    await killApp(appId: appState.appInfo.bundleIdentifier)

                    // Trash the files
                    let _ = moveFilesToTrash(appState: appState, at: selectedItemsArray)

                    // Always cleanup UI, regardless of whether files physically existed
                    updateOnMain {
                        // Remove selected items from app's file list
                        appState.appInfo.fileSize = appState.appInfo.fileSize.filter {
                            !selectedItemsArray.contains($0.key)
                        }
                        appState.appInfo.fileIcon = appState.appInfo.fileIcon.filter {
                            !selectedItemsArray.contains($0.key)
                        }
                        appState.selectedItems.removeAll()
                        updateSortedFiles()
                    }

                    // Determine if it's a full delete
                    let appPath = appState.appInfo.path.absoluteString
                    let appRemoved = selectedItemsArray.contains(where: {
                        $0.absoluteString == appPath
                    })

                    // For wrapped apps, also check if the container is being deleted
                    let containerRemoved: Bool = {
                        if appState.appInfo.wrapped {
                            // Get container path by going up two levels from inner app
                            // e.g., Container.app/Wrapper/ActualApp.app -> Container.app
                            let containerPath = appState.appInfo.path
                                .deletingLastPathComponent()  // Remove ActualApp.app -> Container.app/Wrapper
                                .deletingLastPathComponent()  // Remove Wrapper -> Container.app

                            return selectedItemsArray.contains(where: {
                                $0.absoluteString == containerPath.absoluteString
                            })
                        }
                        return false
                    }()

                    let mainAppRemoved = !appState.appInfo.wrapped && appRemoved
                    let wrappedAppRemoved = appState.appInfo.wrapped && (appRemoved || containerRemoved)

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
                        await removeApp(appState: appState, withPath: appState.appInfo.path)
                        GlobalConsoleManager.shared.appendOutput("✓ Completed full deletion for \(appState.appInfo.appName)\n", source: CurrentPage.applications.title)

                    case .semiDelete:
                        // Some files deleted but main app bundle remains
                        // App remains in the list; removes only deleted items
                        GlobalConsoleManager.shared.appendOutput("✓ Completed partial deletion for \(appState.appInfo.appName)\n", source: CurrentPage.applications.title)
                        break
                    }

                    // Process the next app if in external mode
                    processNextExternalApp(
                        appWasRemoved: appWasRemoved, isInTrash: isInTrash)

                    // Send Sentinel FileWatcher start notification
                    sendStartNotificationFW()
                }
            })
    }

    // Helper function to process the next external app
    private func processNextExternalApp(appWasRemoved: Bool, isInTrash: Bool) {
        // Store the current app path before any removal
        let currentAppPath = appState.appInfo.path

        // Check if the current app requires brew cleanup (Is brew cleanup enabled, was main app bundle removed or was main bundle in Trash)
        if brew && (appWasRemoved || isInTrash), let caskName = appState.appInfo.cask {
            // Set flag to show progress indicator
            updateOnMain {
                appState.isBrewCleanupInProgress = true
            }

            // Run Homebrew cleanup and WAIT for it to complete
            Task {
                do {
                    try await HomebrewUninstaller.shared.uninstallPackage(
                        name: caskName,
                        cask: true,
                        zap: true
                    )
                } catch {
                    printOS("Homebrew cleanup failed for \(caskName): \(error.localizedDescription)")
                }

                // Remove the CURRENT app from the queue (not necessarily the first)
                await MainActor.run {
                    if let index = appState.externalPaths.firstIndex(of: currentAppPath) {
                        appState.externalPaths.remove(at: index)
                    }
                }

                // Process remaining apps (transitions UI state)
                await processRemainingApps(appWasRemoved: appWasRemoved)

                // Clear progress flag AFTER UI has transitioned
                await MainActor.run {
                    appState.isBrewCleanupInProgress = false
                }
            }
            return
        }

        // Remove the CURRENT app from the queue (not necessarily the first)
        if let index = appState.externalPaths.firstIndex(of: currentAppPath) {
            appState.externalPaths.remove(at: index)
        }

        // Continue processing remaining apps
        Task {
            await processRemainingApps(appWasRemoved: appWasRemoved)
        }
    }

    // Helper function to process remaining apps after current app is done
    private func processRemainingApps(appWasRemoved: Bool) async {
        // Check if there are more paths to process
        if !appState.externalPaths.isEmpty {
            // Get the next path
            if let nextPath = appState.externalPaths.first {
                // Load the next app's info
                if let nextApp = AppInfoFetcher.getAppInfo(atPath: nextPath) {
                    updateOnMain {
                        appState.appInfo = nextApp
                    }
                    showAppInFiles(appInfo: nextApp, appState: appState, locations: locations)
                }
            }
        } else {
            // All external apps processed
            if appWasRemoved {
                updateOnMain {
                    appState.appInfo = .empty
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        appState.currentView = .empty
                    }
                }
            }

            // Handle oneshot mode termination (only when launched externally for a single app)
            if oneShotMode && appState.externalMode && !appState.multiMode {
                updateOnMain {
                    NSApp.terminate(nil)
                }
            }
        }
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
                return showLocalized(url: firstURL).localizedCaseInsensitiveCompare(
                    showLocalized(url: secondURL)) == .orderedAscending
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
                return firstURL.path.localizedCaseInsensitiveCompare(secondURL.path)
                    == .orderedAscending
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
            let associatedFiles = ZombieFileStorage.shared.getAssociatedFiles(
                for: appState.appInfo.path)

            // Remove associated files from appInfo storage
            appState.appInfo.fileSize = appState.appInfo.fileSize.filter {
                !associatedFiles.contains($0.key)
            }
            appState.appInfo.fileIcon = appState.appInfo.fileIcon.filter {
                !associatedFiles.contains($0.key)
            }

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
            var associatedFiles = ZombieFileStorage.shared.getAssociatedFiles(
                for: appState.appInfo.path)

            // Remove only the specified path
            associatedFiles.removeAll { $0 == path }

            // Update app info storage
            appState.appInfo.fileSize.removeValue(forKey: path)
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

            // Remove from exclusion list
            fsm.removePathZ(path.path)

            // Final update
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
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    let path: URL
    let removeAssociation: (URL) -> Void
    @Binding var isSelected: Bool

    var body: some View {

        let size = appState.appInfo.fileSize[path] ?? 0
        let fileIcon = appState.appInfo.fileIcon[path]
        let iconImage = fileIcon.flatMap { $0.map(Image.init(nsImage:)) }
        let displaySize = formatByte(size: size).human

        HStack(alignment: .center, spacing: 15) {
            Button(action: {
                if !self.path.path.contains(".Trash") {
                    isSelected.toggle()
                }
            }) {
                EmptyView()
            }
            .buttonStyle(CircleCheckboxButtonStyle(isSelected: isSelected))
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
                        .overlay {
                            if isHovered {
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            ThemeColors.shared(for: colorScheme).primaryText
                                                .opacity(0.5)
                                        )
                                        .frame(height: 1.5)
                                        .offset(y: 3)
                                }
                            }
                        }

                    if isNested(path: path) {
                        InfoButton(
                            text: String(
                                localized:
                                    "Application file is nested within subdirectories. To prevent deleting incorrect folders, Pearcleaner will leave these alone. You may manually delete the remaining folders if required."
                            ))
                    }

                    if let imageView = folderImages(for: path.path) {
                        imageView
                    }

                    if ZombieFileStorage.shared.isPathAssociated(path) {
                        Image(systemName: "link")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13)
                            .foregroundStyle(
                                ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
                    }

                }

                path.path.pathWithArrows(
                    separatorColor: ThemeColors.shared(for: colorScheme).primaryText
                )
                .font(.footnote)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                .help(path.path)

            }
            .onTapGesture {
                NSWorkspace.shared.selectFile(
                    path.path, inFileViewerRootedAtPath: path.deletingLastPathComponent().path)
            }
            .onHover { hovering in
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                    self.isHovered = hovering
                }
            }

            Spacer()

            Text(verbatim: "\(displaySize)")
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

        }
        .padding(.vertical, 8)
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
                NSWorkspace.shared.selectFile(
                    path.path, inFileViewerRootedAtPath: path.deletingLastPathComponent().path)
            }
            if ZombieFileStorage.shared.isPathAssociated(path) {
                Button("Unlink File") {
                    removeAssociation(path)
                }
            }
        }

    }
}
