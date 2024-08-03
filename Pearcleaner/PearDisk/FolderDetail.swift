//
//  FolderDetailView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 7/20/24.
//

import Foundation
import SwiftUI

//MARK: Detail View
struct FolderDetailView: View {
    let rootURL: URL
    @Binding var currentPath: URL?
    @State private var currentItem: Item?
    @State private var childItems: [Item] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var forwardStack: [URL] = []
    @State private var hoveredItem: Item?

    private var fastSearch: FastFileSearch

    init(rootURL: URL, currentPath: Binding<URL?>) {
        self.rootURL = rootURL
        self._currentPath = currentPath
        self.fastSearch = FastFileSearch()
    }

    var body: some View {
        VStack {

            Spacer()

            if isLoading {
                ProgressView("Loading...")
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else if let currentItem = currentItem {
                if !childItems.isEmpty {

                    TreeMapChart(items: childItems, onItemSelected: { selectedItem in
                        NSWorkspace.shared.selectFile(selectedItem.url.path, inFileViewerRootedAtPath: selectedItem.url.deletingLastPathComponent().path)
                    }, hoveredItem: $hoveredItem)

                    HStack {
                        Text("Total size: \(ByteCountFormatter.string(fromByteCount: currentItem.size, countStyle: .file))")
                        Spacer()

                        if let hoveredItem = hoveredItem {
                            Text("\(hoveredItem.name) (\(formatSize(hoveredItem.size)))")
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            HStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [Color.cyan, Color.blue]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 10, height: 10)
                                Text("Directory")
                                    .padding(.trailing)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [Color.pink, Color.orange]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 10, height: 10)
                                Text("File")
                            }

                        }


                    }
                    .padding(5)

                } else {
                    Text("This folder is empty or there was an error loading its contents.")
                        .padding(5)
                }
            } else {
                Text("No data available")
                    .padding(5)
            }

            Spacer()
        }
        .padding()
        .onChange(of: currentPath) { newValue in
            if let newPath = newValue {
                loadContents(url: newPath)
            }
        }
        // Might need this in another app where I won't use a Navigation View
//        .onAppear {
//            loadContents(url: rootURL)
//        }
        .toolbar {

//            ToolbarItem(placement: .navigation) {
//                Button {
//                    goBack()
//                } label: {
//                    Image(systemName: "arrow.left")
//                }
//                .disabled(currentPath == rootURL)
//            }

//            ToolbarItem(placement: .navigation) {
//                Button {
//                    goForward()
//                } label: {
//                    Image(systemName: "arrow.right")
//                }
//                .disabled(forwardStack.isEmpty)
//            }

            ToolbarItem(placement: .principal) {
                if let currentPath = currentPath {
                    Text(currentPath.path)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(5)
                        .padding(.horizontal, 2)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.primary)
                                .opacity(0.05)
                        }

                }
            }

            ToolbarItemGroup(placement: .automatic) {
                Spacer()

                Button {
                    printItemsCount()
                } label: {
                    Image(systemName: "number.square")
                }

                Button {
                    refreshCurrentFolder()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
//                Button {
//                    Task {
//                        await wipeSwiftDataStorage()
//                    }
//                } label: {
//                    Image(systemName: "xmark.bin")
//                }
//                Button {
//                    Task {
//                        await printSwiftDataCacheSize()
//                    }
//                } label: {
//                    Image(systemName: "number.square")
//                }
            }
        }
    }

    private func loadContents(url: URL, wipeCache: Bool = false) {
        isLoading = true
        errorMessage = nil

        fastSearch.search(url: url) { result in
            switch result {
            case .success(let items):
                self.childItems = items
                self.currentPath = url
                self.currentItem = Item(url: url, name: url.lastPathComponent, size: items.reduce(0) { $0 + $1.size })
            case .failure(let error):
                self.errorMessage = "Error loading contents: \(error.localizedDescription)"
                print("Error loading contents: \(error)")
            }
            self.isLoading = false
        }
    }

    private func refreshCurrentFolder() {
        if let currentPath = currentPath {
            loadContents(url: currentPath, wipeCache: true)
        }
    }

    private func printItemsCount() {
        print("Number of items: \(childItems.count)")
    }
}
