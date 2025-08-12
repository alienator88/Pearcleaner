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
    @Environment(\.colorScheme) var colorScheme
    @Binding var sortedFiles: [URL]
    @Binding var infoSidebar: Bool
    @Binding var selectedSort: SortOptionList
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
                                switch selectedSort {
                                case .size:
                                    selectedSort = .name
                                case .name:
                                    selectedSort = .path
                                case .path:
                                    selectedSort = .size
                                }
                                updateSortedFiles()
                            } label: { EmptyView() }
                                .buttonStyle(SimpleButtonStyleFlipped(
                                    icon: "line.3.horizontal.decrease.circle",
                                    label: selectedSort.title,
                                    help: "Sorted by \(selectedSort.rawValue.capitalized)",
                                    color: ThemeColors.shared(for: colorScheme).primaryText,
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
                }
            }

            Spacer()

            HStack(alignment: .center) {

                HStack(spacing: 10) {
                    Text("\(appState.selectedItems.count) / \(appState.appInfo.fileSize.count)")
                        .font(.footnote)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .frame(minWidth: 80, alignment: .leading)

                    Spacer()

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

                    Button {
                        handleUninstallAction()
                    } label: {
                        Label {
                            Text(verbatim: "\(sizeType == "Logical" ? totalSelectedSize.logical : totalSelectedSize.real)")
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                    .buttonStyle(ControlGroupButtonStyle(
                        foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                        shape: Capsule(style: .continuous),
                        level: .secondary,
                        disabled: appState.selectedItems.isEmpty
                    ))

                    Spacer()

                    Button {
                        infoSidebar.toggle()
                    } label: {
                        Image(systemName: "sidebar.trailing")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .transition(.move(edge: .trailing))
                    .help("See app details")
                    .frame(minWidth: 80, alignment: .trailing)

                }
                .padding(.top)
            }

            if !appState.externalPaths.isEmpty {
                ScrollView(.horizontal, showsIndicators: scrollIndicators) {
                    HStack(spacing: 10) {
                        ForEach(appState.externalPaths, id: \.self) { path in
                            HStack(spacing: 5) {
                                Button(path.deletingPathExtension().lastPathComponent) {
                                    let newApp = AppInfoFetcher.getAppInfo(atPath: path)!
                                    updateOnMain {
                                        appState.appInfo = newApp
                                    }
                                    showAppInFiles(appInfo: newApp, appState: appState, locations: locations)
                                }
                                .buttonStyle(.link)
                                Button {
                                    removePath(path)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.top)
            }

        }
    }
}
