//
//  PearDiskView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 7/17/24.
//

import SwiftUI
import AlinFoundation

//MARK: Main View
struct PearDiskView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedVolume: URL?
    @State private var currentPath: URL?

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedVolume: $selectedVolume)
        } detail: {
            if let volume = selectedVolume {
                FolderDetailView(rootURL: volume, currentPath: $currentPath)
            } else {
                Text("Select a volume")
            }
        }
        .onChange(of: selectedVolume) { path in
                currentPath = path
        }
    }
}


//MARK: Sidebar
struct SidebarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedVolume: URL?
    @State private var volumes: [URL] = []

    var body: some View {
        List(volumes, id: \.self) { volume in
            Text(volume.lastPathComponent)
                .onTapGesture {
                    selectedVolume = volume
                }
        }
        .onAppear {
            loadVolumes()
        }
        .background(backgroundView(themeManager: themeManager))
    }

    private func loadVolumes() {
        let fileManager = FileManager.default

        // Define the base paths for the directories you want to scan
        let basePaths = [
            URL(fileURLWithPath: "/Volumes"),
            URL(fileURLWithPath: "/Users"),
//            URL(fileURLWithPath: "/Users/alin"),
            URL(fileURLWithPath: "/"),
        ]

        for basePath in basePaths {
            do {
                let urls = try fileManager.contentsOfDirectory(at: basePath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

                // Iterate over each URL in the directory
                for url in urls {
                    if url.isSymlink() {
                        // If the item is a symbolic link, resolve it
                        let resolvedUrl = url.resolvingSymlinksInPath()
                        volumes.append(resolvedUrl)
                    } else {
                        volumes.append(url)
                    }
                }
            } catch {
                print("Error loading volumes: \(error)")
            }
        }
    }

}


extension URL {
    public func isSymlink() -> Bool {
        do {
            let _ = try self.checkResourceIsReachable()
            let resourceValues = try self.resourceValues(forKeys: [.isSymbolicLinkKey])
            return resourceValues.isSymbolicLink == true
        } catch {
            return false
        }
    }
}
