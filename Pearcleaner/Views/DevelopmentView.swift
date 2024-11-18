//
//  DevelopmentView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/15/24.
//
import SwiftUI
import AlinFoundation

struct Path: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let paths: [String]
}

struct EnvironmentCleanerView: View {
    @State private var selectedEnvironment: Path?
    @State private var paths: [Path] = PathLibrary.getPaths()

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

                        if let selectedEnvironment = selectedEnvironment {
                            Text("Checked \(selectedEnvironment.paths.count) paths for \(selectedEnvironment.name)")
                                .font(.footnote)
                        } else {
                            Text("Total environment paths available")
                                .font(.footnote)
                        }

                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Picker(selection: $selectedEnvironment) {
                            Text("Select One").tag(Path?.none)
                            ForEach(paths) { environment in
                                Text(environment.name).tag(environment as Path?)
                            }
                        } label: { EmptyView() }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: 300)

                        if let selectedEnvironment = selectedEnvironment {
                            Text(verbatim: "\(selectedEnvironment.paths.count)")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Text(verbatim: "\(paths.reduce(0) { $0 + $1.paths.count })")
                                .font(.footnote).foregroundStyle(.secondary)
                        }

                    }


                }
            })


            if let selectedEnvironment = selectedEnvironment {
//                Text("Paths for \(selectedEnvironment.name):")
//                    .font(.headline)

                ScrollView {
                    ForEach(selectedEnvironment.paths, id: \.self) { path in
                        PathRowView(path: path)
                    }
                }

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

    var body: some View {
        VStack(alignment: .leading) {
            if !matchingPaths.isEmpty {
                ForEach(matchingPaths, id: \.self) { matchedPath in
                    HStack {
                        Text(matchedPath)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button("Open") {
                            openInFinder(matchedPath)
                        }
                        .foregroundColor(.blue)

                        Button("Delete Folder") {
                            deleteFolder(matchedPath)
                        }
                        .foregroundColor(.red)

                        Button("Delete Contents") {
                            deleteFolderContents(matchedPath)
                        }
                        .foregroundColor(.orange)
                        .disabled(isEmpty)
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
        .padding(5)
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
    static func getPaths() -> [Path] {
        return [
            Path(name: "Android Studio", paths: [
                "~/.android/",
                "~/Library/Application Support/Google/AndroidStudio*/",
                "~/Library/Logs/AndroidStudio/"
            ]),
            Path(name: "Cargo (Rust)", paths: [
                "~/.cargo/bin/",
                "~/.cargo/registry/"
            ]),
            Path(name: "Carthage", paths: [
                "~/Carthage/",
                "~/Library/Caches/org.carthage.CarthageKit/"
            ]),
            Path(name: "Swift", paths: [
                "~/.swiftpm/",
            ]),
            Path(name: "Composer (PHP)", paths: [
                "~/.composer/cache/"
            ]),
            Path(name: "Conda", paths: [
                "~/.conda/environments.txt",
                "~/anaconda3/envs/",
                "~/miniconda3/envs/"
            ]),
            Path(name: "CocoaPods", paths: [
                "~/Library/Caches/CocoaPods/",
                "~/.cocoapods/repos/"
            ]),
            Path(name: "Go Modules", paths: [
                "~/go/bin/",
                "~/go/pkg/mod/"
            ]),
            Path(name: "Gradle", paths: [
                "~/.gradle/caches/",
                "~/.gradle/wrapper/"
            ]),
            Path(name: "Haskell Stack", paths: [
                "~/.stack/",
                "~/.stack/global-project/",
                "~/.stack/snapshots/"
            ]),
            Path(name: "IntelliJ IDEA (JetBrains Products)", paths: [
                "~/Library/Application Support/JetBrains/",
                "~/Library/Caches/JetBrains/",
                "~/Library/Logs/JetBrains/"
            ]),
            Path(name: "Maven", paths: [
                "~/.m2/repository/",
                "~/.m2/settings.xml"
            ]),
            Path(name: "Nix", paths: [
                "/nix/store/",
                "~/.cache/nix/"
            ]),
            Path(name: "NPM", paths: [
                "/usr/local/lib/node_modules/",
                "~/.nvm/versions/node/*/",
                "~/.npm/",
                "~/.nvm/"
            ]),
            Path(name: "Pip", paths: [
                "~/.cache/pip/"
            ]),
            Path(name: "Poetry", paths: [
                "~/Library/Caches/pypoetry/"
            ]),
            Path(name: "Pub (Dart/Flutter)", paths: [
                "~/.pub-cache/"
            ]),
            Path(name: "Pyenv", paths: [
                "~/.pyenv/cache/",
                "~/.pyenv/versions/"
            ]),
            Path(name: "Ruby Gems", paths: [
                "~/.gem/",
                "~/.gem/ruby/*/"
            ]),
            Path(name: "VS Code", paths: [
                "~/Library/Application Support/Code/",
                "~/.vscode/extensions/"
            ]),
            Path(name: "Xcode", paths: [
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
            Path(name: "Yarn", paths: [
                "~/.cache/yarn/",
                "~/.yarn-cache/",
                "~/.yarn/global/"
            ])
        ]
            .map { Path(name: $0.name, paths: $0.paths.sorted()) } // Sort paths within each environment
            .sorted { $0.name < $1.name } // Sort environments by name
    }
}
