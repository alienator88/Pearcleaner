//
//  DevelopmentView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/15/24.
//
import SwiftUI
import AlinFoundation

struct PathEnv: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let paths: [String]
}

struct EnvironmentCleanerView: View {
    @EnvironmentObject var appState: AppState
//    @State private var selectedEnvironment: Path?
    @State private var paths: [PathEnv] = PathLibrary.getPaths()
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            PearGroupBox(header: {
                HStack(alignment: .center, spacing: 15) {
                    Image(systemName: "hammer.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .symbolRenderingMode(.hierarchical)

                    VStack(alignment: .leading){
                        Text("Development Environments (Beta)").font(.title).fontWeight(.bold)
                        Text("Clean stored files and cache for common development environments")
                            .font(.callout).foregroundStyle(.primary.opacity(0.5))
                    }
                }
            }, content: {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Environment")
                            .font(.callout).fontWeight(.bold)

                        if let selectedEnvironment = appState.selectedEnvironment {
                            Text("Checked paths for \(selectedEnvironment.name)")
                                .font(.footnote)
                        } else {
                            Text("Total environment paths available")
                                .font(.footnote)
                        }

                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Menu {
                            ForEach(paths) { environment in
                                Button(environment.name) {
                                    appState.selectedEnvironment = environment
                                }
                            }
                        } label: {
                            Text(appState.selectedEnvironment?.name ?? "Select Environment")
                        }
                        .frame(maxWidth: 300)

                        if let selectedEnvironment = appState.selectedEnvironment {
                            Text(verbatim: "\(selectedEnvironment.paths.count) paths")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Text(verbatim: "\(paths.reduce(0) { $0 + $1.paths.count }) paths")
                                .font(.footnote).foregroundStyle(.secondary)
                        }

                    }


                }
            })


            if let selectedEnvironment = appState.selectedEnvironment {

                ScrollView {
                    ForEach(selectedEnvironment.paths, id: \.self) { path in
                        PathRowView(path: path)
                    }
                }
                .scrollIndicators(scrollIndicators ? .automatic : .never)

            } else {
                Text("Select an environment to view paths.")
                    .italic()
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .padding(.top)
    }
}

struct PathRowView: View {
    let path: String
    @State private var exists: Bool = false
    @State private var isEmpty: Bool = false
    @State private var matchingPaths: [String] = []
    @State private var sizeLoading: Bool = true
    @State private var size: Int64 = 0
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {
            if !matchingPaths.isEmpty {
                ForEach(matchingPaths, id: \.self) { matchedPath in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {

                            Text(matchedPath)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer()

                            Text(formatByte(size: size).human)
                                .foregroundColor(.secondary)
                        }
                        .onAppear {
                            DispatchQueue.global(qos: .userInitiated).async {
                                if let url = URL(string: matchedPath) {
                                    let calculatedSize = sizeType == "Real" ? totalSizeOnDisk(for: url).real : totalSizeOnDisk(for: url).logical

                                    DispatchQueue.main.async {
                                        self.size = calculatedSize
                                    }
                                }
                            }
                        }

                        HStack {

                            Button {
                                openInFinder(matchedPath)
                            } label: {
                                Label("Open", systemImage: "folder")
                                    .padding(4)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)

                            Spacer()

                            HStack {
                                Button {
                                    deleteFolder(matchedPath)
                                } label: {
                                    Label("Delete Folder", systemImage: "trash")
                                        .padding(4)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)

                                Button {
                                    deleteFolderContents(matchedPath)
                                } label: {
                                    Label("Delete Contents", systemImage: "trash.circle")
                                        .padding(4)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .disabled(isEmpty)
                                .help(isEmpty ? "Folder is empty" : "Delete all files within this folder")
                            }

                        }

                    }

                }
            } else {
                HStack {
                    Text(expandTilde(path))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.gray)

                    Spacer()
                    Text("Not Found")
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(.quaternary.opacity(0.3))
            .shadow(radius: 2))
        .onAppear {
            checkPath(path)
        }
    }

    private func checkPath(_ path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let fileManager = FileManager.default

        if path.contains("*") {
            // Handle wildcard paths
            if expandedPath.contains("/*/") {
                // Handle middle wildcard like ~/.gem/ruby/*/cache/
                let components = expandedPath.split(separator: "*", maxSplits: 1, omittingEmptySubsequences: true)
                guard components.count == 2 else {
                    exists = false
                    matchingPaths = []
                    return
                }

                let basePath = String(components[0]) // Path before wildcard
                let remainderPath = String(components[1]) // Path after wildcard

                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: basePath)
                        .filter { $0 != ".DS_Store" } // Exclude .DS_Store

                    let matchingFolders = contents.filter {
                        fileManager.fileExists(atPath: (basePath as NSString).appendingPathComponent($0), isDirectory: nil)
                    }.map { (basePath as NSString).appendingPathComponent($0) }

                    matchingPaths = matchingFolders.compactMap { folder in
                        let fullPath = (folder as NSString).appendingPathComponent(remainderPath)
                        return fileManager.fileExists(atPath: fullPath) ? fullPath : nil
                    }

                    exists = !matchingPaths.isEmpty
                    isEmpty = matchingPaths.allSatisfy { folder in
                        if let innerContents = try? fileManager.contentsOfDirectory(atPath: folder) {
                            return innerContents.filter { $0 != ".DS_Store" }.isEmpty
                        }
                        return true
                    }
                } catch {
                    exists = false
                    matchingPaths = []
                }
            } else {
                // Handle partial folder wildcard like ~/Library/Application Support/Google/AndroidStudio*/
                let basePath = NSString(string: expandedPath).deletingLastPathComponent
                let partialComponent = NSString(string: expandedPath).lastPathComponent.replacingOccurrences(of: "*", with: "")

                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: basePath)
                        .filter { $0 != ".DS_Store" } // Exclude .DS_Store

                    matchingPaths = contents.filter { $0.hasPrefix(partialComponent) }
                        .map { (basePath as NSString).appendingPathComponent($0) }

                    exists = !matchingPaths.isEmpty
                    isEmpty = matchingPaths.allSatisfy { folder in
                        if let innerContents = try? fileManager.contentsOfDirectory(atPath: folder) {
                            return innerContents.filter { $0 != ".DS_Store" }.isEmpty
                        }
                        return true
                    }
                } catch {
                    exists = false
                    matchingPaths = []
                }
            }
        } else {
            // Normal path handling
            exists = fileManager.fileExists(atPath: expandedPath)
            if exists {
                if let contents = try? fileManager.contentsOfDirectory(atPath: expandedPath) {
                    isEmpty = contents.filter { $0 != ".DS_Store" }.isEmpty // Exclude .DS_Store
                } else {
                    isEmpty = true
                }
                matchingPaths = [expandedPath]
            } else {
                matchingPaths = []
            }
        }
    }

    private func expandTilde(_ path: String) -> String {
        return NSString(string: path).expandingTildeInPath
    }

    private func openInFinder(_ matchedPath: String) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: matchedPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: matchedPath))
        }
    }

    private func deleteFolderContents(_ matchedPath: String) {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: matchedPath)
            for item in contents {
                let itemPath = (matchedPath as NSString).appendingPathComponent(item)
                try fileManager.removeItem(atPath: itemPath)
            }
            checkPath(path) // Recheck the state after deletion
        } catch {
            printOS("Error deleting contents of folder: \(error)")
        }
    }

    private func deleteFolder(_ matchedPath: String) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: matchedPath)
            checkPath(path) // Recheck the state after deletion
        } catch {
            printOS("Error deleting folder: \(error)")
        }
    }
}


struct PathLibrary {
    static func getPaths() -> [PathEnv] {
        return [
            PathEnv(name: "Android Studio", paths: [
                "~/.android/",
                "~/Library/Application Support/Google/AndroidStudio*/",
                "~/Library/Logs/AndroidStudio/",
                "~/Library/Caches/Google/AndroidStudio*/"
            ]),
            PathEnv(name: "Cargo (Rust)", paths: [
                "~/.cargo/bin/",
                "~/.cargo/registry/"
            ]),
            PathEnv(name: "Carthage", paths: [
                "~/Carthage/",
                "~/Library/Caches/org.carthage.CarthageKit/"
            ]),
            PathEnv(name: "Swift", paths: [
                "~/.swiftpm/",
            ]),
            PathEnv(name: "Composer (PHP)", paths: [
                "~/.composer/cache/"
            ]),
            PathEnv(name: "Conda", paths: [
                "~/.conda/environments.txt",
                "~/anaconda3/envs/",
                "~/miniconda3/envs/"
            ]),
            PathEnv(name: "CocoaPods", paths: [
                "~/Library/Caches/CocoaPods/",
                "~/.cocoapods/repos/"
            ]),
            PathEnv(name: "Go Modules", paths: [
                "~/go/bin/",
                "~/go/pkg/mod/"
            ]),
            PathEnv(name: "Gradle", paths: [
                "~/.gradle/caches/",
                "~/.gradle/wrapper/"
            ]),
            PathEnv(name: "Haskell Stack", paths: [
                "~/.stack/",
                "~/.stack/global-project/",
                "~/.stack/snapshots/"
            ]),
            PathEnv(name: "IntelliJ IDEA (JetBrains Products)", paths: [
                "~/Library/Application Support/JetBrains/",
                "~/Library/Caches/JetBrains/",
                "~/Library/Logs/JetBrains/"
            ]),
            PathEnv(name: "Maven", paths: [
                "~/.m2/repository/",
                "~/.m2/settings.xml"
            ]),
            PathEnv(name: "Nix", paths: [
                "/nix/store/",
                "~/.cache/nix/"
            ]),
            PathEnv(name: "NPM", paths: [
                "/usr/local/lib/node_modules/",
                "~/.nvm/versions/node/*/",
                "~/.npm/",
                "~/.nvm/"
            ]),
            PathEnv(name: "Pip", paths: [
                "~/.cache/pip/"
            ]),
            PathEnv(name: "Poetry", paths: [
                "~/Library/Caches/pypoetry/"
            ]),
            PathEnv(name: "Pub (Dart/Flutter)", paths: [
                "~/.pub-cache/",
                "~/Library/Caches/flutter_engine/"
            ]),
            PathEnv(name: "Pyenv", paths: [
                "~/.pyenv/cache/",
                "~/.pyenv/versions/"
            ]),
            PathEnv(name: "Ruby Gems", paths: [
                "~/.gem/",
                "~/.gem/ruby/*/"
            ]),
            PathEnv(name: "VS Code", paths: [
                "~/Library/Application Support/Code/",
                "~/.vscode/extensions/"
            ]),
            PathEnv(name: "Xcode", paths: [
                "~/Library/Caches/com.apple.dt.xcodebuild/",
                "~/Library/Caches/com.apple.dt.Xcode.sourcecontrol.Git/",
                "~/Library/Developer/CoreSimulator/Devices/",
                "~/Library/Developer/DeveloperDiskImages/",
                "~/Library/Developer/Xcode/Archives/",
                "~/Library/Developer/Xcode/DerivedData/",
                "~/Library/Developer/Xcode/iOS DeviceSupport/",
                "~/Library/Developer/Xcode/tvOS DeviceSupport/",
                "~/Library/Developer/Xcode/watchOS DeviceSupport/",
                "~/Library/Developer/Xcode/macOS DeviceSupport/",
                "~/Library/Developer/Xcode/UserData/"
            ]),
            PathEnv(name: "Yarn", paths: [
                "~/.cache/yarn/",
                "~/.yarn-cache/",
                "~/.yarn/global/"
            ])
        ]
            .map { PathEnv(name: $0.name, paths: $0.paths.sorted()) } // Sort paths within each environment
            .sorted { $0.name < $1.name } // Sort environments by name
    }
}
