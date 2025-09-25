//
//  FileListView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 7/31/25.
//

import AlinFoundation
import Foundation
import SwiftUI

struct FileListView: View {
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @AppStorage("settings.general.brew") private var brew: Bool = false
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Binding var sortedFiles: [URL]
    @Binding var infoSidebar: Bool
    @Binding var selectedSort: SortOptionList
    @State private var searchText: String = ""
    @State private var selectedFileItemsLocal: Set<URL> = []
    @State private var memoizedFiles: [URL] = []
    let locations: Locations
    let windowController: WindowManager
    let handleUninstallAction: () -> Void
    let sizeType: String
    let displaySizeTotal: String
    let totalSelectedSize: (real: String, logical: String)
    let updateSortedFiles: () -> Void
    let removeSingleZombieAssociation: (URL) -> Void
    let removePath: (URL) -> Void


    var filteredFiles: [URL] {
        if searchText.isEmpty {
            return memoizedFiles
        } else {
            return memoizedFiles.filter { path in
                path.lastPathComponent.localizedCaseInsensitiveContains(searchText)
                    || path.path.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if appState.appInfo.fileSize.keys.count == 0 {
                Text("Sentinel Monitor found no other files to remove")
                    .font(.title3)
                    .opacity(0.5)
            } else {
                VStack(alignment: .leading, spacing: 0) {

                    VStack(spacing: 0) {
                        // Select all checkbox row
                        HStack {
                            Toggle(
                                isOn: Binding(
                                    get: {
                                        if searchText.isEmpty {
                                            return selectedFileItemsLocal.count
                                                == appState.appInfo.fileSize.count
                                        } else {
                                            let currentlyVisibleFiles = Set(filteredFiles)
                                            let selectedVisibleFiles =
                                                selectedFileItemsLocal.intersection(
                                                    currentlyVisibleFiles)
                                            return !currentlyVisibleFiles.isEmpty
                                                && selectedVisibleFiles.count
                                                    == currentlyVisibleFiles.count
                                        }
                                    },
                                    set: { newValue in
                                        updateOnMain {
                                            if newValue {
                                                selectedFileItemsLocal = Set(filteredFiles)
                                            } else {
                                                let filesToDeselect = Set(filteredFiles)
                                                selectedFileItemsLocal.subtract(filesToDeselect)
                                            }
                                            // Sync with appState
                                            appState.selectedItems = selectedFileItemsLocal
                                        }
                                    }
                                )
                            ) { EmptyView() }
                            .toggleStyle(SimpleCheckboxToggleStyle())
                            .help("All checkboxes")
                            .padding([.bottom, .trailing])

                            //                            Spacer()
                            // Search bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(
                                        ThemeColors.shared(for: colorScheme).secondaryText)

                                TextField("Search...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(
                                        ThemeColors.shared(for: colorScheme).primaryText)

                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(
                                                ThemeColors.shared(for: colorScheme).secondaryText)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                            .controlGroup(Capsule(style: .continuous), level: .primary)
                            .padding(.bottom)
                        }

                        // File list
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(Array(filteredFiles.enumerated()), id: \.element) {
                                    index, path in
                                    FileDetailsItem(
                                        path: path,
                                        removeAssociation: removeSingleZombieAssociation,
                                        isSelected: binding(for: path)
                                    )
                                }
                            }
                            .onAppear {
                                updateSortedFiles()
                                updateMemoizedFiles()
                            }
                            .onChange(of: sortedFiles) { newVal in
                                updateMemoizedFiles()
                            }
                        }
                        .scrollIndicators(scrollIndicators ? .automatic : .never)
                        .padding(.bottom)
                    }

                    // Bottom toolbar
                    HStack(spacing: 10) {
                        Text(
                            "\(selectedFileItemsLocal.intersection(Set(filteredFiles)).count) / \(filteredFiles.count)"
                        )
                        .font(.footnote)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .frame(minWidth: 80, alignment: .leading)

                        Spacer()

                        if appState.trashError {
                            InfoButton(
                                text:
                                    "A trash error has occurred, please open the debug window(⌘+D) to see what went wrong or try again",
                                color: .orange, label: "View Error", warning: true,
                                extraView: {
                                    Button("View Debug Window") {
                                        windowController.open(
                                            with: ConsoleView(), width: 600, height: 400)
                                    }
                                }
                            )
                            .onDisappear {
                                appState.trashError = false
                            }
                        }

                        Button {
                            handleUninstallAction()
                        } label: {
                            Label {
                                Text(
                                    verbatim:
                                        "\(sizeType == "Logical" ? totalSelectedSize.logical : totalSelectedSize.real)"
                                )
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                        .buttonStyle(
                            ControlGroupButtonStyle(
                                foregroundColor: ThemeColors.shared(for: colorScheme).accent,
                                shape: Capsule(style: .continuous),
                                level: .primary,
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
                    }
                }
                .opacity(infoSidebar ? 0.5 : 1)
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
                                    showAppInFiles(
                                        appInfo: newApp, appState: appState, locations: locations)
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
        .frame(maxWidth: .infinity)
        .padding([.horizontal, .bottom], 20)

    }

    // Helper function to create binding for individual files
    private func binding(for file: URL) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                selectedFileItemsLocal.contains(file) && filteredFiles.contains(file)
            },
            set: { isSelected in
                if isSelected {
                    if filteredFiles.contains(file) {
                        selectedFileItemsLocal.insert(file)
                    }
                } else {
                    selectedFileItemsLocal.remove(file)
                }
                // Sync with appState
                appState.selectedItems = selectedFileItemsLocal
            }
        )
    }

    // Helper function to update memoized files
    private func updateMemoizedFiles() {
        memoizedFiles = sortedFiles
        // Sync local selection with appState
        selectedFileItemsLocal = appState.selectedItems
    }
}
