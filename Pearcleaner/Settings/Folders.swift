//
//  Folders.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/20/24.
//

//
//  General.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI
import AppKit

struct FolderSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @State private var isHovered = false
    @State private var isHoveredPlus = false

    var body: some View {
        Form {
            VStack {

                HStack(spacing: 0) {
                    Text("Apps").font(.title2)
                    InfoButton(text: "Locations that will be searched for .app files. Click a non-default path to remove it. Add new folders below or drag/drop a folder over the list.", color: nil, label: "")
                    Spacer()
                }


                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(fsm.folderPaths.indices, id: \.self) { index in
                            HStack {

                                Text(fsm.folderPaths[index])
                                    .font(.callout)
                                    .opacity(fsm.defaultPaths.contains(fsm.folderPaths[index]) ? 0.5 : 1)
                                    .padding(5)
                                Spacer()
                            }
                            .disabled(fsm.defaultPaths.contains(fsm.folderPaths[index]))
                            .onHover { hovering in
                                withAnimation(Animation.easeInOut(duration: 0.4)) {
                                    isHovered = hovering
                                }
                                if isHovered && !fsm.defaultPaths.contains(fsm.folderPaths[index]) {
                                    NSCursor.disappearingItem.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .onTapGesture {
                                if !fsm.defaultPaths.contains(fsm.folderPaths[index]) {
                                    fsm.removePath(at: index)
                                }
                            }

                            if index != fsm.folderPaths.indices.last {
                                Divider().opacity(0.5)
                            }
                        }

                    }

                }
                .scrollIndicators(.automatic)
                .padding()
                .background(Color("mode").opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onDrop(of: ["public.file-url"], isTargeted: nil) { providers -> Bool in
                    providers.forEach { provider in
                        provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { (data, error) in
                            guard let data = data, error == nil,
                                  let url = URL(dataRepresentation: data, relativeTo: nil),
                                  url.hasDirectoryPath else {
                                printOS("FSM: Failed to load URL or the item is not a folder")
                                return
                            }
                            updateOnMain {
                                fsm.addPath(url.path)
                            }
                        }
                    }
                    return true
                }





                // === OTHER ================================================================================================

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color("mode").opacity(0.1))
//                        .strokeBorder(Color("mode").opacity(0.1), lineWidth: 2)
                        .frame(width: 300, height: 100)

                    Image(systemName: "plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundStyle(isHoveredPlus ? Color("mode") : Color("mode").opacity(0.5))
                }
                .padding(.top)
                .onTapGesture {
                    selectFolder()
                }
                .onHover { hovering in
                    withAnimation(Animation.easeInOut(duration: 0.4)) {
                        isHoveredPlus = hovering
                    }
                    if isHoveredPlus {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }





                Spacer()
            }


        }
        .padding(20)
        .frame(width: 500, height: 420)

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

}



class FolderSettingsManager: ObservableObject {
    @Published var folderPaths: [String] = []
    private let userDefaultsKey = "settings.folders.apps"
    let defaultPaths = ["/Applications", "\(NSHomeDirectory())/Applications"]

    init() {
        loadDefaultPathsIfNeeded()
    }

    private func loadDefaultPathsIfNeeded() {
        var paths = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? defaultPaths
        if paths.count < 2 {
            paths = defaultPaths
        }
        UserDefaults.standard.set(paths, forKey: userDefaultsKey)
        self.folderPaths = paths
    }

    func addPath(_ path: String) {
        if !self.folderPaths.contains(path) {
            self.folderPaths.append(path)
            UserDefaults.standard.set(self.folderPaths, forKey: userDefaultsKey)
        }
    }

    func removePath(at index: Int) {
        guard self.folderPaths.indices.contains(index) else { return }
        self.folderPaths.remove(at: index) // Update local state
        UserDefaults.standard.set(self.folderPaths, forKey: userDefaultsKey)
    }

    func refreshPaths() {
        self.folderPaths = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? defaultPaths
    }

    func getPaths() -> [String] {
        return UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? defaultPaths
    }
}
