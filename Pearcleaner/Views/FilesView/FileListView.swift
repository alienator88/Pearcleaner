//
//  FileListView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 7/31/25.
//

import Foundation
import SwiftUI
import AlinFoundation

struct FileListView: View {
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.general.brew") private var brew: Bool = false
    @EnvironmentObject var appState: AppState
    @Binding var sortedFiles: [URL]
    @Binding var infoSidebar: Bool
    @Binding var selectedSortAlpha: Bool
    @Binding var isHoveredChevron: Bool
    let locations: Locations
    let windowController: WindowManager
    let handleUninstallAction: () -> Void
    let sizeType: String
    let displaySizeTotal: String
    let totalSelectedSize: (real: String, logical: String)
    let updateSortedFiles: () -> Void
    let removeSingleZombieAssociation: (URL) -> Void
    let removePath: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if appState.appInfo.fileSize.keys.count == 0 {
                Text("Sentinel Monitor found no other files to remove")
                    .font(.title3)
                    .opacity(0.5)
            } else {
                HStack {
                    VStack(spacing: 0) {
                        HStack {
                            Toggle(
                                isOn: Binding(
                                    get: {
                                        appState.selectedItems.count == appState.appInfo.fileSize.count
                                    },
                                    set: { newValue in
                                        updateOnMain {
                                            appState.selectedItems = newValue ? Set(appState.appInfo.fileSize.keys) : []
                                        }
                                    }
                                )
                            ) { EmptyView() }
                                .toggleStyle(SimpleCheckboxToggleStyle())
                                .help("All checkboxes")

                            Spacer()

                            Button {
                                selectedSortAlpha.toggle()
                                updateSortedFiles()
                            } label: { EmptyView() }
                                .buttonStyle(SimpleButtonStyleFlipped(
                                    icon: "line.3.horizontal.decrease.circle",
                                    label: selectedSortAlpha ? "Name" : "Size",
                                    help: selectedSortAlpha ? "Sorted by Name" : "Sorted by Size",
                                    size: 16
                                ))
                        }

                        Divider().padding(.vertical, 5)

                        ScrollView {
                            LazyVStack {
                                ForEach(Array(sortedFiles.enumerated()), id: \.element) { index, path in
                                    VStack {
                                        FileDetailsItem(path: path, removeAssociation: removeSingleZombieAssociation)
                                            .padding(.vertical, 5)
                                    }
                                }
                            }
                            .onAppear { updateSortedFiles() }
                        }
                        .scrollIndicators(scrollIndicators ? .automatic : .never)
                    }
                    .padding(.horizontal)
                    .blur(radius: infoSidebar ? 2 : 0)

                    Button {
                        infoSidebar.toggle()
                    } label: {
                        Image(systemName: isHoveredChevron ? "chevron.left.circle.fill" : "chevron.left.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                    }
                    .onHover { hovering in
                        isHoveredChevron = hovering
                    }
                    .buttonStyle(.borderless)
                    .transition(.move(edge: .trailing))
                    .help("See app details")
                }
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
                                                showAppInFiles(appInfo: newApp, appState: appState, locations: locations)
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
                    }
                }

                Spacer()

                HStack(spacing: 10) {

                    if appState.trashError {
                        InfoButton(text: "A trash error has occurred, please open the debug window(⌘+D) to see what went wrong", color: .orange, label: "View Error", warning: true, extraView: {
                            Button("View Debug Window") {
                                windowController.open(with: ConsoleView(), width: 600, height: 400)
                            }
                        })
                        .onDisappear {
                            appState.trashError = false
                        }
                    }

                    Text("\(appState.selectedItems.count) of \(appState.appInfo.fileSize.count) items")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    // Trash Button
                    Button {
                        handleUninstallAction()
                    } label: {
                        Text(verbatim: "\(sizeType == "Logical" ? totalSelectedSize.logical : totalSelectedSize.real)")
                    }
                    .buttonStyle(UninstallButton(isEnabled: !appState.selectedItems.isEmpty || (appState.selectedItems.isEmpty && brew)))
                }
            }
        }
    }
}
