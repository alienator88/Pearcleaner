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
    @State private var showAlert = false
    @Environment(\.colorScheme) var colorScheme
    @Binding var showPopover: Bool
    @Binding var search: String

    var body: some View {


        var totalSelectedSize: (real: String, logical: String, finder: String) {
            var totalReal: Int64 = 0
            var totalLogical: Int64 = 0
            for url in appState.selectedItems {
                let realSize = appState.appInfo.fileSize[url] ?? 0
                let logicalSize = appState.appInfo.fileSizeLogical[url] ?? 0
                totalReal += realSize
                totalLogical += logicalSize
            }
            return (real: formatByte(size: totalReal).human, logical: formatByte(size: totalLogical).human, finder: "\(formatByte(size: totalLogical).byte) (\(formatByte(size: totalReal).human))")
        }

        let displaySizeTotal = sizeType == "Real" ? formatByte(size: appState.appInfo.totalSize).human :
        sizeType == "Logical" ? formatByte(size: appState.appInfo.totalSizeLogical).human :
        "\(formatByte(size: appState.appInfo.totalSizeLogical).byte) (\(formatByte(size: appState.appInfo.totalSize).human))"

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
                        .buttonStyle(SimpleButtonStyle(icon: "x.circle", iconFlip: "x.circle.fill", help: "Close"))
                    }


                }
                .padding(.top, (mini || menubarEnabled) ? 6 : 30)
                .padding(.trailing, (mini || menubarEnabled) ? 6 : 0)

                VStack(spacing: 0) {

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
                                        .padding()
                                        .background{
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color((appState.appInfo.appIcon?.averageColor)!))

                                        }
                                }

                                VStack(alignment: .leading, spacing: 5){
                                    HStack {
                                        Text("\(appState.appInfo.appName)").font(.title).fontWeight(.bold).lineLimit(1)
                                        Text("•").foregroundStyle(Color("AccentColor"))
                                        Text("v\(appState.appInfo.appVersion)").font(.title3)

                                    }
                                    Text("\(appState.appInfo.bundleIdentifier)")
                                        .lineLimit(1)
                                        .font(.title3)
                                        .foregroundStyle((.primary.opacity(0.5)))

                                    if let creationDate = appState.appInfo.creationDate {
                                        Text("Installed: \(formattedMDDate(from: creationDate))")
                                            .font(.footnote)
                                    }
                                    if let modificationDate = appState.appInfo.contentChangeDate {
                                        Text("Modified: \(formattedMDDate(from: modificationDate))")
                                            .font(.footnote)
                                    }
                                    if let lastUsedDate = appState.appInfo.lastUsedDate {
                                        Text("Last Used: \(formattedMDDate(from: lastUsedDate))")
                                            .font(.footnote)
                                    }
                                }
                                .padding(.leading)

                                Spacer()

                                VStack(alignment: .trailing, spacing: 5) {

                                    Text("\(displaySizeTotal)").font(.title).fontWeight(.bold).help("Total size on disk")
                                    Text("\(appState.appInfo.fileSize.count == 1 ? "\(appState.selectedItems.count) / \(appState.appInfo.fileSize.count) item" : "\(appState.selectedItems.count) / \(appState.appInfo.fileSize.count) items")")
                                        .font(.callout).foregroundStyle((.primary.opacity(0.5)))


                                }

                            }

                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 0)

                    }


                    // Item selection and sorting toolbar
                    HStack() {
                        Toggle("", isOn: Binding(
                            get: { self.appState.selectedItems.count == self.appState.appInfo.fileSize.keys.count },
                            set: { newValue in
                                updateOnMain {
                                    self.appState.selectedItems = newValue ? Set(self.appState.appInfo.fileSize.keys) : []
                                }
                            }
                        ))
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
                        }


                        Spacer()

                        Button("") {
                            selectedSortAlpha.toggle()
                        }
                        .buttonStyle(SimpleButtonStyle(icon: selectedSortAlpha ? "textformat.abc" : "textformat.123", help: selectedSortAlpha ? "Sorted alphabetically" : "Sorted by size"))

                    }
                    .padding()



                    Divider()
                        .padding(.horizontal)



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



                    Spacer()

                    HStack(alignment: .center) {

                        Spacer()

                        if appState.appInfo.fileSize.keys.count == 0 {
                            Text("Sentinel Monitor found no other files to remove")
                                .font(.title2)
                                .opacity(0.5)
                                .padding(.top)
                        }

                        Spacer()

                        InfoButton(text: "Always double-check the files/folders marked for removal. In some rare cases, Pearcleaner may find some unrelated files when app names are too similar.", color: .primary.opacity(0.5), warning: true, edge: .top)
                            .padding(.top)


                        Button("\(sizeType == "Logical" ? totalSelectedSize.logical : sizeType == "Finder" ? totalSelectedSize.finder : totalSelectedSize.real)") {
                            showCustomAlert(enabled: confirmAlert, title: "Warning", message: "Are you sure you want to remove these files?", style: .warning, onOk: {
                                Task {

                                    let selectedItemsArray = Array(appState.selectedItems)

                                    killApp(appId: appState.appInfo.bundleIdentifier) {

                                        moveFilesToTrash(appState: appState, at: selectedItemsArray) { success in

                                            // Send Sentinel FileWatcher start notification
                                            sendStartNotificationFW()

                                            guard success else {
                                                return
                                            }

                                            if appState.selectedItems.count == appState.appInfo.fileSize.keys.count {
                                                updateOnMain {
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

                                            // Remove app from app list if main app bundle is removed for regular and wrapped apps
                                            if (appState.appInfo.wrapped && selectedItemsArray.contains(where: { $0.absoluteString == appState.appInfo.path.deletingLastPathComponent().deletingLastPathComponent().absoluteString })) ||
                                                (!appState.appInfo.wrapped && selectedItemsArray.contains(where: { $0.absoluteString == appState.appInfo.path.absoluteString })) {
                                                // Change view back to empty/apps if main app bundle is removed
                                                updateOnMain {
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
                                                // Match found, remove the app
                                                removeApp(appState: appState, withPath: appState.appInfo.path)

                                                if appState.oneShotMode {
                                                    NSApp.terminate(nil)
                                                }

                                            } else {
                                                // Run brew cleanup if sent from Sentinel
                                                if brew && appState.sentinelMode {
                                                    caskCleanup(app: appState.appInfo.appName)
                                                }

                                                // Add deleted appInfo object to trashed array
                                                appState.trashedFiles.append(appState.appInfo)

                                                updateOnMain {
                                                    // Remove items from the list
                                                    appState.appInfo.fileSize = appState.appInfo.fileSize.filter { !appState.selectedItems.contains($0.key) }
                                                    // Update the selectedFiles to remove references that are no longer present
                                                    appState.selectedItems.removeAll()
                                                    appState.sentinelMode = false
                                                    if appState.oneShotMode {
                                                        NSApp.terminate(nil)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                }
                            })


                        }
                        .buttonStyle(UninstallButton(isEnabled: !appState.selectedItems.isEmpty))
                        .disabled(appState.selectedItems.isEmpty)
                        .padding(.top)


                    }

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
                Text("Always confirm the files marked for removal. In rare cases, unrelated files may be found when app names are too similar.\n\nNOTE: Pearcleaner uses AppleScript to remove files. Currently macOS does not allow AppleScript to authenticate using the fingerprint sensor, only password authentication is supported.")
                    .font(.subheadline)
                Spacer()
                Button("Close") {
                    warning = true
                    showAlert = false
                }
                .buttonStyle(SimpleButtonStyle(icon: "x.circle.fill", label: "Close", help: "Dismiss"))
//                Spacer()
            }
            .padding(15)
            .frame(width: 400, height: 250)
            .background(GlassEffect(material: .hudWindow, blendingMode: .behindWindow))
        })
        .sheet(isPresented: $appState.showConditionBuilder, content: {
            ConditionBuilderView(showAlert: $appState.showConditionBuilder, bundle: appState.appInfo.bundleIdentifier)
        })
        .onAppear {
            if !warning {
                showAlert = true
            }
        }
    }

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
                        InfoButton(text: "Application file is nested within subdirectories. To prevent deleting incorrect folders, Pearcleaner will leave these alone. You may manually delete the remaining folders if required.")
                    }

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
            sizeType == "Logical" ? formatByte(size: sizeL!).human :
            "\(formatByte(size: sizeL!).byte) (\(formatByte(size: size!).human))"

            Text("\(displaySize)")

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
