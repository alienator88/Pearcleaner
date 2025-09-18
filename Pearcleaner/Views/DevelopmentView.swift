//
//  DevelopmentView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/15/24.
//
import SwiftUI
import AlinFoundation

struct PathEnv: Identifiable, Hashable, Equatable {
    let id = UUID()
    let name: String
    let paths: [String]
}

struct EnvironmentCleanerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var paths: [PathEnv] = []
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    // Store all paths, including "All" and each environment
    private var allPaths: [PathEnv] {
        let realPaths = PathLibrary.getPaths()
        let combined = realPaths.flatMap { $0.paths }
        return [PathEnv(name: "All", paths: combined)] + realPaths
    }

    private func refreshPaths() {
        let fileManager = FileManager.default
        paths = allPaths.map { env in
            let validPaths = env.paths.filter {
                let expanded = NSString(string: $0).expandingTildeInPath
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: expanded, isDirectory: &isDir) {
                    if isDir.boolValue {
                        if let contents = try? fileManager.contentsOfDirectory(atPath: expanded) {
                            return contents.filter { $0 != ".DS_Store" }.isEmpty == false
                        }
                    } else {
                        return true
                    }
                }
                return false
            }
            return PathEnv(name: env.name, paths: validPaths)
        }

        // Update selected environment to its refreshed version
        if let selected = appState.selectedEnvironment {
            if let updated = paths.first(where: { $0.name == selected.name }) {
                appState.selectedEnvironment = updated
            } else {
                appState.selectedEnvironment = nil
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            HStack(alignment: .center, spacing: 15) {

                VStack(alignment: .leading){
                    Text("Development Environments").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title).fontWeight(.bold)
                    Text("Clean stored files and cache for common IDEs")
                        .font(.callout).foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

                Spacer()

                Menu {
                    ForEach(paths, id: \.self) { environment in
                        Group {
                            if environment.paths.isEmpty {
                                Text("\(environment.name) (0)")
                                    .foregroundStyle(.gray)
                            } else {
                                Button("\(environment.name) (\(environment.paths.count))") {
                                    appState.selectedEnvironment = environment
                                }
                            }
                        }
                    }
                } label: {
                    Text(appState.selectedEnvironment?.name ?? "Select Environment")
                }
                .buttonStyle(ControlGroupButtonStyle(
                    foregroundColor: ThemeColors.shared(for: colorScheme).primaryText,
                    shape: Capsule(style: .continuous),
                    level: .primary
                ))

            }

            if let selectedEnvironment = appState.selectedEnvironment {

                // Add workspace storage cleaner for VS Code and Cursor
                if selectedEnvironment.name == "VS Code" || selectedEnvironment.name == "Cursor" {
                    WorkspaceStorageCleanerView(ideName: selectedEnvironment.name)
                        .id(selectedEnvironment.name)
                        .padding(.bottom, 10)
                }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(selectedEnvironment.paths, id: \.self) { path in
                            PathRowView(path: path) {
                                refreshPaths()
                                if let env = appState.selectedEnvironment,
                                   paths.first(where: { $0.name == env.name })?.paths.isEmpty ?? true {
                                    appState.selectedEnvironment = nil
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(scrollIndicators ? .automatic : .never)
            } else {
                VStack(alignment: .center) {
                    Spacer()
                    Text("Select an environment to view stored cache")
                        .font(.title2)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)

            }


            // Add bulk delete buttons if selectedEnvironment and has valid paths
            if let selectedEnvironment = appState.selectedEnvironment, !selectedEnvironment.paths.isEmpty {

                HStack {
                    Spacer()
                    HStack(spacing: 10) {

                        Button {
                            refreshPaths()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .help("Refresh")

                        Divider().frame(height: 10)

                        Button {
                            showCustomAlert(title: "Warning", message: "This will delete all the selected folders. Are you sure?", style: .warning, onOk:  {
                                for path in selectedEnvironment.paths {
                                    let expanded = NSString(string: path).expandingTildeInPath
                                    let _ = try? FileManager.default.removeItem(atPath: expanded)
                                }
                                refreshPaths()
                                if let env = appState.selectedEnvironment,
                                   paths.first(where: { $0.name == env.name })?.paths.isEmpty ?? true {
                                    appState.selectedEnvironment = nil
                                }
                            })

                        } label: {
                            Label("Delete All Folders", systemImage: "folder")
                        }

                        Divider().frame(height: 10)

                        Button {
                            showCustomAlert(title: "Warning", message: "This will delete all the contents of the selected folders. Are you sure?", style: .warning, onOk: {
                                for path in selectedEnvironment.paths {
                                    let expanded = NSString(string: path).expandingTildeInPath
                                    let fm = FileManager.default
                                    if let contents = try? fm.contentsOfDirectory(atPath: expanded) {
                                        for item in contents {
                                            let itemPath = (expanded as NSString).appendingPathComponent(item)
                                            let _ = try? fm.removeItem(atPath: itemPath)
                                        }
                                    }
                                }
                                refreshPaths()
                                if let env = appState.selectedEnvironment,
                                   paths.first(where: { $0.name == env.name })?.paths.isEmpty ?? true {
                                    appState.selectedEnvironment = nil
                                }
                            })
                        } label: {
                            Label("Delete All Contents", systemImage: "shippingbox")
                        }

                    }
                    .controlSize(.small)
                    .buttonStyle(.plain)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .controlGroup(Capsule(style: .continuous), level: .primary)

                    Spacer()
                }

            } else {
                Spacer()
            }

        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .onAppear {
            refreshPaths()
        }
    }
}

struct PathRowView: View {
    @Environment(\.colorScheme) var colorScheme
    let path: String
    let onDelete: () -> Void
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

                            Button {
                                openInFinder(matchedPath)
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)

                            matchedPath.pathWithArrows()
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                .font(.headline)

                            Spacer()

                            Text(formatByte(size: size).human)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                            HStack {
                                Button {
                                    deleteFolder(matchedPath)
                                } label: {
                                    Label("Delete Folder", systemImage: "folder")
                                }
                                .help("Delete the folder")

                                Divider().frame(height: 10)

                                Button {
                                    deleteFolderContents(matchedPath)
                                } label: {
                                    Label("Delete Contents", systemImage: "shippingbox")
                                }
                                .disabled(isEmpty)
                                .help("Delete all files within this folder")
                            }
                            .controlSize(.small)
                            .buttonStyle(.plain)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .controlGroup(Capsule(style: .continuous), level: .primary)

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

                    }

                }
            } else {
                HStack {
                    Text(expandTilde(path))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.gray)

                    Spacer()
                    Text("Not Found")
                        .foregroundStyle(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ThemeColors.shared(for: colorScheme).secondaryBG.clipShape(RoundedRectangle(cornerRadius: 8)))
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
            onDelete()
        } catch {
            printOS("Error deleting folder: \(error)")
        }
    }
}

struct WorkspaceStorageCleanerView: View {
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @Environment(\.colorScheme) var colorScheme
    let ideName: String
    @State private var orphanedWorkspaces: [OrphanedWorkspace] = []
    @State private var isScanning = false
    @State private var lastScanDate: Date?
    
    struct OrphanedWorkspace {
        let id = UUID()
        let name: String
        let path: String
        let folderPath: String
        let size: String
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "macwindow")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workspace Storage Cleaner")
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    Text("Remove workspace storage for deleted project folders")
                        .font(.caption)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                
                Spacer()
                
                Button(action: scanForOrphanedWorkspaces) {
                    HStack(spacing: 6) {
                        if isScanning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(isScanning ? "Scanning..." : "Scan")
                    }
                }
                .disabled(isScanning)
                .controlSize(.small)
                .buttonStyle(.plain)
                .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .controlGroup(Capsule(style: .continuous), level: .primary)
            }
            
            if !orphanedWorkspaces.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Found \(orphanedWorkspaces.count) orphaned workspace\(orphanedWorkspaces.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        
                        Spacer()
                    }

                    ScrollView {
                        ForEach(orphanedWorkspaces, id: \.id) { workspace in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workspace.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Text("\(workspace.folderPath)")
                                        .font(.caption)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                }

                                Spacer()

                                Text(workspace.size)
                                    .font(.caption2)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                                Button("Delete") {
                                    cleanOrphanedWorkspace(workspace)
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.mini)
                                .foregroundStyle(.red)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .scrollIndicators(scrollIndicators ? .automatic : .never)
                    .frame(height: 180)

                    HStack {
                        Spacer()

                        Button("Delete All") {
                            cleanAllOrphanedWorkspaces()
                        }
                        .disabled(isScanning)
                        .controlSize(.small)
                        .buttonStyle(.plain)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .controlGroup(Capsule(style: .continuous), level: .primary)

                        Button("Cancel") {
                            cancelWorkspaceCleanup()
                        }
                        .disabled(isScanning)
                        .controlSize(.small)
                        .buttonStyle(.plain)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .controlGroup(Capsule(style: .continuous), level: .primary)
                    }
                }
            } else if lastScanDate != nil {
                Text("No orphaned workspaces found")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    .italic()
            }
        }
        .padding()
        .background(ThemeColors.shared(for: colorScheme).primaryText.opacity(0.05))
        .cornerRadius(10)
    }
    
    private func scanForOrphanedWorkspaces() {
        isScanning = true
        orphanedWorkspaces = []
        
        Task {
            let found = await findOrphanedWorkspaces()
            
            await MainActor.run {
                self.orphanedWorkspaces = found
                self.lastScanDate = Date()
                self.isScanning = false
            }
        }
    }
    
    private func findOrphanedWorkspaces() async -> [OrphanedWorkspace] {
        let configPath = ideName == "VS Code" ? 
            "~/Library/Application Support/Code" : 
            "~/Library/Application Support/Cursor"
        
        let expandedPath = NSString(string: configPath).expandingTildeInPath
        let workspaceStoragePath = "\(expandedPath)/User/workspaceStorage"
        
        let fileManager = FileManager.default
        var orphaned: [OrphanedWorkspace] = []
        
        guard let workspaceDirs = try? fileManager.contentsOfDirectory(atPath: workspaceStoragePath) else {
            return orphaned
        }
        
        for workspaceDir in workspaceDirs {
            let workspacePath = "\(workspaceStoragePath)/\(workspaceDir)"
            let workspaceJsonPath = "\(workspacePath)/workspace.json"
            
            if fileManager.fileExists(atPath: workspaceJsonPath) {
                if let folderPath = extractFolderPath(from: workspaceJsonPath),
                   !fileManager.fileExists(atPath: folderPath) {
                    
                    let size = calculateDirectorySize(at: workspacePath)
                    
                    orphaned.append(OrphanedWorkspace(
                        name: workspaceDir,
                        path: workspacePath,
                        folderPath: folderPath,
                        size: size
                    ))
                }
            }
        }
        
        return orphaned
    }
    
    private func extractFolderPath(from workspaceJsonPath: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: workspaceJsonPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let folder = json["folder"] as? String else {
            return nil
        }
        
        // Remove file:// prefix and decode URL encoding
        var cleanPath = folder.replacingOccurrences(of: "file://", with: "")
        cleanPath = cleanPath.removingPercentEncoding ?? cleanPath
        cleanPath = cleanPath.replacingOccurrences(of: "+", with: " ")
        
        return cleanPath
    }
    
    private func calculateDirectorySize(at path: String) -> String {
        let url = URL(fileURLWithPath: path)
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return "0 B"
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  let fileSize = resourceValues.fileSize,
                  let isDirectory = resourceValues.isDirectory,
                  !isDirectory else {
                continue
            }
            
            totalSize += Int64(fileSize)
        }
        
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    private func cleanOrphanedWorkspace(_ workspace: OrphanedWorkspace) {
        do {
            try FileManager.default.removeItem(atPath: workspace.path)
            orphanedWorkspaces.removeAll { $0.id == workspace.id }
        } catch {
            print("Error removing workspace \(workspace.name): \(error)")
        }
    }
    
    private func cleanAllOrphanedWorkspaces() {
        for workspace in orphanedWorkspaces {
            cleanOrphanedWorkspace(workspace)
        }
    }

    private func cancelWorkspaceCleanup() {
        orphanedWorkspaces = []
        lastScanDate = nil
        isScanning = false
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
                "~/.conda/",
                "~/anaconda3/envs/",
                "~/miniconda3/envs/"
            ]),
            PathEnv(name: "CocoaPods", paths: [
                "~/Library/Caches/CocoaPods/",
                "~/.cocoapods/repos/"
            ]),
            PathEnv(name: "Cursor", paths: [
                "~/Library/Application Support/Cursor/",
                "~/Library/Application Support/Cursor/Cache",
                "~/Library/Application Support/Cursor/GPUCache",
                "~/Library/Application Support/Cursor/CachedConfigurations",
                "~/Library/Application Support/Cursor/CachedData",
                "~/Library/Application Support/Cursor/CachedExtensionVSIXs",
                "~/Library/Application Support/Cursor/CachedExtensions",
                "~/Library/Application Support/Cursor/CachedProfilesData",
                "~/Library/Application Support/Cursor/Code Cache",
                "~/Library/Application Support/Cursor/User",
                "~/.cursor/",
                "~/.cursor/extensions/"
            ]),
            PathEnv(name: "Deno", paths: [
                "~/Library/Caches/deno"
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
                "~/.m2/"
            ]),
            PathEnv(name: "Nix", paths: [
                "/nix/store/",
                "~/.cache/nix/"
            ]),
            PathEnv(name: "NPM", paths: [
                "/usr/local/lib/node_modules/",
                "~/.nvm/versions/node/*/",
                "~/.npm/",
                "~/.nvm/",
                "~/Library/pnpm/store"
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
                "~/Library/Application Support/Code/Cache",
                "~/Library/Application Support/Code/GPUCache",
                "~/Library/Application Support/Code/CachedConfigurations",
                "~/Library/Application Support/Code/CachedData",
                "~/Library/Application Support/Code/CachedExtensionVSIXs",
                "~/Library/Application Support/Code/CachedExtensions",
                "~/Library/Application Support/Code/CachedProfilesData",
                "~/Library/Application Support/Code/Code Cache",
                "~/Library/Application Support/Code/User",
                "~/.vscode/",
                "~/.vscode/extensions/",
                "~/.vscode/cli/"
            ]),
            PathEnv(name: "Xcode", paths: [
                "~/Library/Caches/com.apple.dt.xcodebuild/",
                "~/Library/Caches/com.apple.dt.Xcode.sourcecontrol.Git/",
                "~/Library/Developer/CoreSimulator/Devices/",
                "~/Library/Developer/DeveloperDiskImages/",
                "~/Library/Developer/Xcode/Archives/",
                "~/Library/Developer/Xcode/DerivedData/",
                "~/Library/Developer/Xcode/DocumentationCache/",
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
