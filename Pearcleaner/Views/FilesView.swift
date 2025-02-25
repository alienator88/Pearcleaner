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
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.brew") private var brew: Bool = false
    @AppStorage("settings.menubar.enabled") private var menubarEnabled: Bool = false
    @AppStorage("settings.general.selectedSort") var selectedSortAlpha: Bool = true
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @AppStorage("settings.general.filesWarning") private var warning: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.general.confirmAlert") private var confirmAlert: Bool = false
    @AppStorage("settings.interface.details") private var detailsEnabled: Bool = true
    @AppStorage("settings.general.oneshot") private var oneShotMode: Bool = false
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @State private var showAlert = false
    @Environment(\.colorScheme) var colorScheme
    @Binding var showPopover: Bool
    @Binding var search: String

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

                    HStack(spacing: 10) {
                        Text("Searching the file system").font(.title3)
                            .foregroundStyle(.primary.opacity(0.5))
                        ProgressView().controlSize(.small)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {

                // Titlebar
                HStack(spacing: 0) {

                    Spacer()

                    if mini || menubarEnabled {
                        Button("Close") {
                            updateOnMain {
                                appState.appInfo = AppInfo.empty
                                search = ""
                                appState.currentView = .apps
                                showPopover = false
                            }
                        }
                        .buttonStyle(SimpleButtonStyle(icon: "x.circle", iconFlip: "x.circle.fill", help: String(localized: "Close")))
                    }


                }
                .padding(.top, (mini || menubarEnabled) ? 6 : 30)
                .padding(.trailing, (mini || menubarEnabled) ? 6 : 0)

                VStack(spacing: 0) {

                    // Main Group
                    HStack(alignment: .center) {

                        //app icon, title, size and items
                        VStack(alignment: .leading, spacing: 5){
                            PearGroupBox(header: {
                                HStack(alignment: .center, spacing: 15) {
                                    if let appIcon = appState.appInfo.appIcon {
                                        Image(nsImage: appIcon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 50, height: 50)
                                            .padding(5)
                                            .background{
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color((appState.appInfo.appIcon?.averageColor)!))

                                            }
                                    }
                                    VStack(alignment: .leading) {
                                        HStack(alignment: .center) {
                                            Text(verbatim: "\(appState.appInfo.appName)").font(.title).fontWeight(.bold).lineLimit(1)
                                            Image(systemName: "circle.fill").foregroundStyle(Color("AccentColor")).font(.system(size: 5))
                                            Text(verbatim: "\(appState.appInfo.appVersion)").font(.title3)
                                        }
                                        Text(verbatim: "\(appState.appInfo.bundleIdentifier)")
                                            .lineLimit(1)
                                            .font(.title3)
                                            .foregroundStyle((.primary.opacity(0.5)))
                                    }

                                    Button() {
                                        withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                            detailsEnabled.toggle()
                                        }
                                    } label: {
                                        Text(detailsEnabled ? "Hide Details" : "Show Details")
                                    }
                                    .buttonStyle(.bordered)
                                    .padding()

                                    Spacer()

                                }

                            }, content: {

                                if detailsEnabled {
                                    HStack(spacing: 20) {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text("Total size of files:")
                                                .font(.callout).fontWeight(.bold)
                                            Text(verbatim: "")
                                                .font(.footnote)
                                            Text("Installed Date:")
                                                .font(.footnote)
                                            Text("Modified Date:")
                                                .font(.footnote)
                                            Text("Last Used Date:")
                                                .font(.footnote)

                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 5) {
                                            Text(verbatim: "\(displaySizeTotal)").font(.callout).fontWeight(.bold)//.help("Total size on disk")

                                            Text(verbatim: "\(appState.appInfo.fileSize.count == 1 ? "\(appState.selectedItems.count) \(String(localized: "of"))  \(appState.appInfo.fileSize.count) \(String(localized: "item"))" : "\(appState.selectedItems.count) \(String(localized: "of")) \(appState.appInfo.fileSize.count) \(String(localized: "items"))")")
                                                .font(.footnote)

                                            if let creationDate = appState.appInfo.creationDate {
                                                Text(formattedMDDate(from: creationDate))
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            } else {
                                                Text("Not available")
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }

                                            if let modificationDate = appState.appInfo.contentChangeDate {
                                                Text(formattedMDDate(from: modificationDate))
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            } else {
                                                Text("Not available")
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }

                                            if let lastUsedDate = appState.appInfo.lastUsedDate {
                                                Text(formattedMDDate(from: lastUsedDate))
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            } else {
                                                Text("Not available")
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }



                                        }

                                    }

                                }

                            })


                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 0)


                    }


                    // Item selection and sorting toolbar
                    HStack() {
                        Toggle(isOn: Binding(
                            get: { self.appState.selectedItems.count == self.appState.appInfo.fileSize.keys.count },
                            set: { newValue in
                                updateOnMain {
                                    self.appState.selectedItems = newValue ? Set(self.appState.appInfo.fileSize.keys) : []
                                }
                            }
                        )) { EmptyView() }
                        .toggleStyle(SimpleCheckboxToggleStyle())
                        .help("All checkboxes")

                        Spacer()


                        HStack(alignment: .center, spacing: 10) {

                            if appState.appInfo.webApp {
                                Text("web")
                                    .font(.footnote)
                                    .foregroundStyle(.primary.opacity(0.5))
                                    .frame(minWidth: 30, minHeight: 15)
                                    .padding(2)
                                    .padding(.horizontal, 2)
                                    .background(.primary.opacity(0.1))
                                    .clipShape(.capsule)
                                    .help("This is a web app")

                            }

                            if appState.appInfo.wrapped {
                                Text("iOS")
                                    .font(.footnote)
                                    .foregroundStyle(.primary.opacity(0.5))
                                    .frame(minWidth: 30, minHeight: 15)
                                    .padding(2)
                                    .padding(.horizontal, 2)
                                    .background(.primary.opacity(0.1))
                                    .clipShape(.capsule)
                                    .help("This is a wrapped iOS app")

                            }

                            if appState.appInfo.arch != .empty {
                                Text("\(appState.appInfo.arch)")
                                    .font(.footnote)
                                    .foregroundStyle(.primary.opacity(0.5))
                                    .frame(minWidth: 30, minHeight: 15)
                                    .padding(2)
                                    .padding(.horizontal, 2)
                                    .background(.primary.opacity(0.1))
                                    .clipShape(.capsule)
                                    .help("This bundle's architecture is \(appState.appInfo.arch)")

                            }

                            Text(appState.appInfo.system ? "system" : "user")
                                .font(.footnote)
                                .foregroundStyle(.primary.opacity(0.5))
                                .frame(minWidth: 30, minHeight: 15)
                                .padding(2)
                                .padding(.horizontal, 2)
                                .background(.primary.opacity(0.1))
                                .clipShape(.capsule)
                                .help("This app is located in \(appState.appInfo.system ? "/Applications" : "\(home)")")

                            if appState.appInfo.cask != nil {
                                Text("homebrew")
                                    .font(.footnote)
                                    .foregroundStyle(.primary.opacity(0.5))
                                    .frame(minWidth: 30, minHeight: 15)
                                    .padding(2)
                                    .padding(.horizontal, 2)
                                    .background(.primary.opacity(0.1))
                                    .clipShape(.capsule)
                                    .help("This app is installed via Homebrew")

                            }
                        }


                        Spacer()

                        Button {
                            selectedSortAlpha.toggle()
                        } label: { EmptyView() }
                            .buttonStyle(SimpleButtonStyle(icon: "line.3.horizontal.decrease.circle", label: selectedSortAlpha ? String(localized: "Name") : String(localized: "Size"), help: selectedSortAlpha ? String(localized: "Sorted by Name") : String(localized: "Sorted by Size"), size: 16))

                    }
                    .padding()



                    Divider()
                        .padding(.horizontal)

                    if appState.appInfo.fileSize.keys.count == 0 {
                        Text("Sentinel Monitor found no other files to remove")
                            .font(.title3)
                            .opacity(0.5)
                    } else {
                        ScrollView() {
                            LazyVStack {
                                let sortedFilesSize = appState.appInfo.fileSize.keys.sorted(by: { appState.appInfo.fileSize[$0, default: 0] > appState.appInfo.fileSize[$1, default: 0] })

                                let sortedFilesAlpha = appState.appInfo.fileSize.keys.sorted { firstURL, secondURL in
                                    let isFirstPathApp = firstURL.pathExtension == "app"
                                    let isSecondPathApp = secondURL.pathExtension == "app"
                                    if isFirstPathApp, !isSecondPathApp {
                                        return true // .app extension always comes first
                                    } else if !isFirstPathApp, isSecondPathApp {
                                        return false
                                    } else {
                                        // If neither or both are .app, sort alphabetically
                                        return firstURL.lastPathComponent.pearFormat() < secondURL.lastPathComponent.pearFormat()
                                    }
                                }

                                let sort = selectedSortAlpha ? sortedFilesAlpha : sortedFilesSize

                                ForEach(Array(sort.enumerated()), id: \.element) { index, path in
                                    if let fileSize = appState.appInfo.fileSize[path], let fileSizeL = appState.appInfo.fileSizeLogical[path], let fileIcon = appState.appInfo.fileIcon[path] {
                                        let iconImage = fileIcon.map(Image.init(nsImage:))
                                        VStack {
                                            FileDetailsItem(size: fileSize, sizeL: fileSizeL, icon: iconImage, path: path)
                                                .padding(.vertical, 5)
                                        }
                                    }
                                }

                            }
                            .padding()
                        }
                        .scrollIndicators(scrollIndicators ? .automatic : .never)
                    }

                    Spacer()

                    HStack(alignment: .center) {

                        if !appState.externalPaths.isEmpty {
                            VStack {
                                HStack {
                                    Text("Queue:").font(.title3).opacity(0.5)
                                        .help("⇧ + Scroll")
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            ForEach(appState.externalPaths, id: \.self) { path in
                                                HStack(spacing: 0) {
                                                    Button(path.deletingPathExtension().lastPathComponent) {
                                                        let newApp = AppInfoFetcher.getAppInfo(atPath: path)!
                                                        updateOnMain {
                                                            appState.appInfo = newApp
                                                        }
                                                        showAppInFiles(appInfo: newApp, appState: appState, locations: locations, showPopover: $showPopover)
                                                    }
                                                    Button {
                                                        removePath(path)
                                                    } label: { EmptyView() }
                                                        .buttonStyle(SimpleButtonStyle(icon: "minus.circle", help: "Remove from queue", size: 14))
                                                }
                                            }
                                        }
                                    }
                                }
//                                Text("⇧ + Scroll").font(.callout).foregroundStyle(.secondary).opacity(0.5)
                            }
                        }

                        Spacer()

                        Button {
                            handleUninstallAction()
                        } label: {
                            Text(verbatim: "\(sizeType == "Logical" ? totalSelectedSize.logical : totalSelectedSize.real)")
                        }
                        .buttonStyle(UninstallButton(isEnabled: !appState.selectedItems.isEmpty || (appState.selectedItems.isEmpty && brew)))
                    }
                    .padding(.top, 5)




                }
                .transition(.opacity)
                .padding([.horizontal, .bottom], 20)
                .padding(.top, !mini ? 10 : 0)

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
                            appState.selectedItems.removeAll()
                        }

                        // Determine if it's a full delete
                        let mainAppPath = appState.appInfo.path.absoluteString
                        let wrappedAppPath = appState.appInfo.path.deletingLastPathComponent().deletingLastPathComponent().absoluteString

                        let mainAppRemoved = (!appState.appInfo.wrapped && selectedItemsArray.contains(where: { $0.absoluteString == mainAppPath }))
                        let wrappedAppRemoved = (appState.appInfo.wrapped && selectedItemsArray.contains(where: { $0.absoluteString == wrappedAppPath }))

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
                            // App remains in the list; UI stays the same
                            // Do NOT call `caskCleanup` here since the main app bundle wasn't removed
                            // Keeping this for future use-cases
                            break
                        }

                        // Process the next app if in external mode
                        processNextExternalApp(appWasRemoved: appWasRemoved)
                    }

                    // Send Sentinel FileWatcher start notification
                    sendStartNotificationFW()
                }
            }
        })
    }

    // Helper function to process the next external app
    private func processNextExternalApp(appWasRemoved: Bool) {

        // Remove the processed path to avoid re-processing it
        if !appState.externalPaths.isEmpty {
            appState.externalPaths.removeFirst()
        }

        // Check if the current app requires brew cleanup
        if brew && appState.appInfo.cask != nil {
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
                        if mini || menubarEnabled {
                            appState.currentView = .apps
                            showPopover = false
                        } else {
                            appState.currentView = .empty
                        }
                        appState.appInfo = AppInfo.empty
                    }
                }
            }

            // Terminate if oneShotMode is enabled
            if oneShotMode && !appState.multiMode {
                updateOnMain(after: 2) {
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
                showAppInFiles(appInfo: nextApp, appState: appState, locations: locations, showPopover: $showPopover)
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
                    showAppInFiles(appInfo: nextApp, appState: appState, locations: locations, showPopover: $showPopover)
                } else {
                    // If no more items are left, set appInfo to .empty and change page to default view
                    updateOnMain {
                        appState.appInfo = .empty
                        search = ""
                        withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                            if mini || menubarEnabled {
                                appState.currentView = .apps
                                showPopover = false
                            } else {
                                appState.currentView = .empty
                            }
                        }
                    }
                }
            }
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
    @State private var isHovered = false
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    let size: Int64?
    let sizeL: Int64?
    let icon: Image?
    let path: URL

    var body: some View {

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

            if let appIcon = icon {
                appIcon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

            }


            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center) {
                    Text(showLocalized(url: path))
                        .font(.title3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(path.lastPathComponent)
                        .overlay{
                            if (isHovered) {
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.primary.opacity(0.5))
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
                }

                Text(path.path)
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .opacity(0.5)
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

            let displaySize = sizeType == "Real" ? formatByte(size: size!).human :
            formatByte(size: sizeL!).human
            Text(verbatim: "\(displaySize)")

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
        }

    }
}
