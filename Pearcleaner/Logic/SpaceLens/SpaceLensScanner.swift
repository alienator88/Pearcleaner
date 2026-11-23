//
//  SpaceLensScanner.swift
//  Pearcleaner
//

import Foundation
import AppKit

enum SpaceLensDisplayMode: String, CaseIterable {
    case sunburst
    case treemap
}

enum SpaceLensScanPhase: Equatable {
    case idle
    case scanning(String)
    // Scan target needs a TCC grant the app does not hold yet; the walker would
    // block on the OS consent dialog, so the scan never started
    case waitingForPermissions(String)
    case complete
    case cancelled
}

// Reading the system TCC.db requires Full Disk Access itself, so a readable db
// doubles as the standard FDA probe used across the app
enum FullDiskAccessProbe {
    static func isGranted() -> Bool {
        FileManager.default.isReadableFile(atPath: "/Library/Application Support/com.apple.TCC/TCC.db")
    }

    // True when a walk of this target can reach a TCC-protected folder, where the
    // OS consent dialog would block the walker mid-scan. The root and any ancestor
    // of home cover Desktop, Documents and Downloads as descendants; anything
    // else (an app bundle, /Applications, ~/Projects) walks fine without FDA and
    // must not be parked behind a permission wait it never triggers.
    static func targetMayHitTCC(_ path: String) -> Bool {
        var normalized = path
        while normalized.count > 1, normalized.hasSuffix("/") { normalized.removeLast() }
        if normalized == "/" { return true }
        let home = NSHomeDirectory()
        if home.hasPrefix(normalized + "/") { return true }
        if normalized == home { return true }
        for protected in ["Desktop", "Documents", "Downloads"] {
            let prefix = home + "/" + protected
            if normalized == prefix || normalized.hasPrefix(prefix + "/") { return true }
        }
        return false
    }
}

// Root system locations are measured but never deletable from tiles
private let protectedRootPaths: Set<String> = ["/System", "/usr", "/private", "/Library", "/Applications"]

// /System/Volumes is the firmlink alias surface of the Data volume; walking it would
// read the whole disk a second time. /.nofollow is Apple's hidden root mirror with the
// same behavior: empty for stat-based tools, full disk contents for an FDA enumerator.
private let firmlinkRoot = "/System/Volumes"
private let rootSkipPaths: Set<String> = [firmlinkRoot, "/.nofollow"]
private let rootSkipNames: Set<String> = [".nofollow", "Volumes"]

actor SpaceLensScanner {

    // Generation counter instead of a stop Bool: cancel() must invalidate every
    // walk started before it while sparing walks started after. A Bool flag races
    // with a restart: cancel() landing after the new scan already reset the flag
    // would kill the new scan instead of the old one.
    private var generation = 0
    private var cancelledThrough = 0

    func cancel() {
        cancelledThrough = generation
    }

    private func isCancelled(_ gen: Int) -> Bool {
        gen <= cancelledThrough
    }

    // MARK: Unprivileged scan

    // Walks the target's top level in parallel waves. Walkers build `maxDepth` levels of
    // the tree in a single traversal and publish partial subtrees while they run, so the
    // first levels fill in before the deep ones finish.
    func scan(target: URL, isFullDisk: Bool, maxDepth: Int = 1,
              onPartialTree: ((SpaceLensNode) async -> Void)? = nil) async -> SpaceLensNode {
        generation += 1
        let gen = generation
        let skipFirmlinks = isFullDisk || target.path == "/"
        let fm = FileManager.default

        var rootName = target.lastPathComponent
        if target.path == "/" || isFullDisk {
            let values = try? target.resourceValues(forKeys: [.volumeNameKey])
            rootName = values?.volumeName ?? "Macintosh HD"
        }

        guard Self.isDirectory(url: target, fm: fm) else {
            var fileRoot = SpaceLensNode(url: target, name: rootName, isProtected: Self.isProtectedRoot(target.path))
            fileRoot.size = await Self.allocatedSize(url: target) ?? 0
            return fileRoot
        }

        // Publish a usable root before the walk so the UI has a target to show
        await onPartialTree?(SpaceLensNode(url: target, name: rootName, isProtected: Self.isProtectedRoot(target.path)))

        let entries = Self.topLevelEntries(of: target, fm: fm)
        let state = PartialState()
        var index = 0
        let waveSize = 8

        while index < entries.count, !Task.isCancelled, !isCancelled(gen) {
            let wave = entries[index..<min(index + waveSize, entries.count)]
            index += wave.count

            await withTaskGroup(of: SpaceLensNode.self) { group in
                for entry in wave {
                    group.addTask {
                        if entry.isDir {
                            // Packages (.app bundles) measure recursively but stay one
                            // atomic tile; plain directories expose their levels
                            let depth = entry.isPackage ? 0 : maxDepth
                            return await Self.walkDirectory(url: entry.url, skipFirmlinks: skipFirmlinks, maxDepth: depth) { partial in
                                state.record(partial: partial)
                                await Self.publishSnapshot(target: target, rootName: rootName,
                                                           state: state, onPartialTree: onPartialTree)
                            }
                        }
                        return SpaceLensNode(url: entry.url,
                                             size: await Self.allocatedSize(url: entry.url) ?? 0,
                                             isPackage: entry.isPackage)
                    }
                }
                for await node in group {
                    if node.accessError == "cancelled" { break }
                    state.record(completion: node)
                    await Self.publishSnapshot(target: target, rootName: rootName,
                                               state: state, onPartialTree: onPartialTree)
                }
            }
        }

        return state.finalRoot(target: target, rootName: rootName)
    }

    // Thread-safe accumulation of walker results shared by the parallel group tasks
    final class PartialState: @unchecked Sendable {
        private let lock = NSLock()
        private var completed: [SpaceLensNode] = []
        private var running: [String: SpaceLensNode] = [:]

        func record(partial: SpaceLensNode) {
            lock.lock()
            running[partial.url.path] = partial
            lock.unlock()
        }

        func record(completion: SpaceLensNode) {
            lock.lock()
            completed.append(completion)
            running.removeValue(forKey: completion.url.path)
            lock.unlock()
        }

        var children: [SpaceLensNode] {
            lock.lock()
            defer { lock.unlock() }
            return completed + Array(running.values)
        }

        func finalRoot(target: URL, rootName: String) -> SpaceLensNode {
            var root = SpaceLensNode(url: target, name: rootName, isProtected: SpaceLensScanner.isProtectedRoot(target.path))
            root.children = children
            root.size = root.children.reduce(Int64(0)) { $0 + $1.size }
            return root.sortedBySize()
        }
    }

    nonisolated private static func publishSnapshot(target: URL, rootName: String,
                                                    state: PartialState,
                                                    onPartialTree: ((SpaceLensNode) async -> Void)?) async {
        var root = SpaceLensNode(url: target, name: rootName, isProtected: isProtectedRoot(target.path))
        // Walker partials and completions arrive pre-sorted at every level, so ranking
        // the top children here is all the merge needs
        root.children = state.children.sorted { $0.size > $1.size }
        root.size = root.children.reduce(Int64(0)) { $0 + $1.size }
        await onPartialTree?(root)
    }

    // Rescans a single subtree. Returns nil only when the path is gone; files come
    // back as leaf nodes so lazy drill-down never deletes live tiles.
    func rescanSubtree(at url: URL, skipFirmlinks: Bool = false, maxDepth: Int = 1) async -> SpaceLensNode? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }
        guard isDir.boolValue else {
            return SpaceLensNode(url: url, size: await Self.allocatedSize(url: url) ?? 0)
        }
        return await Self.walkDirectory(url: url, skipFirmlinks: skipFirmlinks, maxDepth: maxDepth)
    }

    // MARK: Privileged scan (du -k -x)

    // Session-elevated scan: runs du as root through the session credential
    // held by SessionPrivilegeManager (one password per session). The root scan
    // needs the /System/Volumes subtree pruned at parse time because du reaches
    // the Data volume both through the root firmlinks and through
    // /System/Volumes/Data, which would double the real usage.
    func privilegedScan(duPath: String, rootName: String,
                        onPartialTree: ((SpaceLensNode) async -> Void)? = nil) async -> SpaceLensNode? {
        generation += 1
        let gen = generation
        let tempFile = NSTemporaryDirectory() + "spacelens-du-\(UUID().uuidString).txt"
        // Escaping neutralizes quotes in folder names before the root shell runs
        let escaped = duPath.replacingOccurrences(of: "'", with: "'\\''")
        let command = "du -k -x '\(escaped)' > '\(tempFile)' 2>/dev/null"
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        let (ok, _) = await SessionPrivilegeManager.runPrivilegedShell(command)
        guard ok, !isCancelled(gen) else { return nil }

        return await parseDuOutput(atPath: tempFile, rootName: rootName,
                                    pruneSystemVolumes: duPath == "/",
                                    gen: gen,
                                    onPartialTree: onPartialTree)
    }

    // MARK: Internals

    struct TopEntry: Sendable {
        let url: URL
        let isDir: Bool
        let isPackage: Bool
    }

    static func topLevelEntries(of directory: URL, fm: FileManager) -> [TopEntry] {
        var entries: [TopEntry] = []
        guard let names = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: []) else {
            return entries
        }
        for url in names.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            // contentsOfDirectory reports /.nofollow with a trailing slash, so match on the name
            if directory.path == "/", rootSkipPaths.contains(url.path) || rootSkipNames.contains(url.lastPathComponent) { continue }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true { continue }
            entries.append(TopEntry(url: url,
                                    isDir: values?.isDirectory ?? false,
                                    isPackage: values?.isPackage ?? false))
        }
        return entries
    }

    nonisolated static func isDirectory(url: URL, fm: FileManager) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    nonisolated static func isPackageAtPath(_ path: String) -> Bool {
        (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isPackageKey]))?.isPackage == true
    }

    nonisolated static func isProtectedRoot(_ path: String) -> Bool {
        if protectedRootPaths.contains(path) { return true }
        return protectedRootPaths.contains { path.hasPrefix($0 + "/") }
    }

    nonisolated static func allocatedSize(url: URL) async -> Int64? {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
        return values?.totalFileAllocatedSize.map { Int64($0) }
    }

    nonisolated static func isFirmlinkPath(_ path: String) -> Bool {
        path == firmlinkRoot || path.hasPrefix(firmlinkRoot + "/")
    }

    // Canonical form of a walked directory's path for prefix matching against
    // enumerator output. The root keeps an empty prefix so "/System" splits as "System".
    nonisolated static func canonicalParentPath(_ url: URL) -> String {
        if url.path == "/" {
            return ""
        }
        var buf = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
        return realpath(url.path, &buf).map { String(cString: $0) } ?? url.path
    }

    // The enumerator returns the whole subtree flat. Each item adds its allocated size to
    // the subtree total and to its chain of ancestor nodes down to maxDepth, so one pass
    // yields a real multi-level tree instead of single-level children with sums inside.
    // onProgress republishes the partial subtree on a time interval, not per item, so the
    // UI refreshes at a steady cadence instead of in a hot loop.
    nonisolated static func walkDirectory(url: URL, skipFirmlinks: Bool, maxDepth: Int = 1,
                                          onProgress: ((SpaceLensNode) async -> Void)? = nil) async -> SpaceLensNode {
        if Task.isCancelled {
            return SpaceLensNode(url: url, accessError: "cancelled")
        }
        let fm = FileManager.default
        guard isDirectory(url: url, fm: fm) else {
            return SpaceLensNode(url: url, size: await allocatedSize(url: url) ?? 0)
        }

        if skipFirmlinks && url.path == "/System" {
            return await walkSystemShallow(maxDepth: maxDepth)
        }

        var node = SpaceLensNode(url: url, isPackage: (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage == true,
                                  isProtected: isProtectedRoot(url.path))

        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
                                     .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: keys, options: []) else {
            // Enumerator creation fails when the folder is unreadable (TCC or root-owned)
            node.accessError = String(localized: "Access denied")
            return node
        }

        // The enumerator reports canonicalized paths (/tmp -> /private/tmp), so a
        // parent given through a symlink never matches its children's prefixes.
        // realpath crosses firmlink-style links that resolvingSymlinksInPath leaves
        // alone (/tmp, /var); fall back to the original if the path vanished meanwhile
        let parentPath = Self.canonicalParentPath(url)
        var subtreeSize: Int64 = 0
        var childTrees: [String: ChildTree] = [:]
        // Paths of package bundles seen so far; the enumerator visits parents before
        // their contents, so any file under one of these lands on the package node
        // itself and never descends into Contents/Library/etc
        var packagePaths: Set<String> = []
        var itemCount = 0
        var lastPublish = ContinuousClock.now

        while let item = enumerator.nextObject() {
            if Task.isCancelled { break }
            itemCount += 1
            guard let fileURL = item as? URL else { continue }
            if skipFirmlinks && isFirmlinkPath(fileURL.path) { continue }
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true { continue }

            let allocated = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            subtreeSize += allocated

            if values.isDirectory == true, values.isPackage == true {
                packagePaths.insert(fileURL.path)
            }

            guard fileURL.path.hasPrefix(parentPath + "/") else { continue }
            let rel = String(fileURL.path.dropFirst(parentPath.count + 1))
            guard !rel.isEmpty else { continue }
            let components = rel.split(separator: "/", omittingEmptySubsequences: true)
            guard let childName = components.first.map(String.init) else { continue }
            let tree: ChildTree
            if let existing = childTrees[childName] {
                tree = existing
            } else {
                tree = ChildTree(key: childName, parentPath: parentPath)
                childTrees[childName] = tree
            }
            tree.add(components: components, size: allocated, maxDepth: maxDepth,
                     packageRoots: packagePaths)

            if let onProgress = onProgress, itemCount % 500 == 0,
               ContinuousClock.now - lastPublish >= .seconds(1) {
                lastPublish = ContinuousClock.now
                var partial = node
                partial.size = subtreeSize
                // Package walks (maxDepth 0) stay atomic mid-scan too, or "Contents"
                // flashes as a tile until the walk completes
                if maxDepth >= 1 {
                    partial.children = childTrees.values.map { $0.snapshot() }.sorted { $0.size > $1.size }
                }
                await onProgress(partial)
            }

            if itemCount % 500 == 0 {
                await Task.yield()
            }
        }

        node.size = subtreeSize
        // A cancel landing between the entry check and the first enumerated item leaves
        // an empty tree indistinguishable from a completed one; mark it so the scan
        // wave loop drops the subtree instead of recording a phantom zero-size child
        if itemCount == 0, Task.isCancelled {
            node.accessError = "cancelled"
            return node
        }
        // The enumerator is created lazily and silently yields nothing for unreadable
        // folders (chmod 000), so creation never fails there; flag it directly or
        // the tile reads as an empty folder
        if itemCount == 0, !fm.isReadableFile(atPath: url.path) {
            node.accessError = String(localized: "Access denied")
            return node
        }
        // maxDepth 0 callers (package bundles) get one atomic node: the walk measures
        // everything below, the package's own top-level children never become tiles
        if maxDepth >= 1 {
            node.children = childTrees.values.map { $0.snapshot() }.sorted { $0.size > $1.size }
        }
        return node
    }

    // Accumulator for one top-level child of the walked directory. While the enumerator
    // streams items, add() threads each file's size through its ancestor chain up to
    // maxDepth; snapshot() freezes the current state into immutable SpaceLensNode values.
    private final class ChildTree: @unchecked Sendable {
        private let root: TreeNode

        init(key: String, parentPath: String) {
            let path = parentPath + "/" + key
            root = TreeNode(name: key, path: path,
                            isPackage: isPackageAtPath(path))
        }

        func add(components: [Substring], size: Int64, maxDepth: Int,
                 packageRoots: Set<String> = []) {
            var current = root
            current.size += size
            // components[0] is the accumulator key itself; deeper levels start at index 1
            guard components.count > 1, maxDepth >= 1 else { return }
            var last = min(components.count - 1, maxDepth)
            // The accumulator root itself can be the package (a .app directly inside
            // the walked directory); collapse everything onto it and stop there.
            // Otherwise walk the chain and stop at the first nested package boundary:
            // the package node absorbs the size, its internals never become levels
            var path = root.path
            if packageRoots.contains(path) { return }
            for index in 1...last {
                path += "/" + components[index]
                if packageRoots.contains(path) {
                    last = index
                    break
                }
            }
            for index in 1...last {
                let name = String(components[index])
                if let child = current.children[name] {
                    child.size += size
                    current = child
                } else {
                    let child = TreeNode(name: name, path: current.path + "/" + name,
                                         isPackage: packageRoots.contains(current.path + "/" + name))
                    child.size += size
                    current.children[name] = child
                    current = child
                }
            }
        }

        func snapshot() -> SpaceLensNode {
            root.toNode()
        }

        private final class TreeNode {
            let name: String
            let path: String
            let isPackage: Bool
            var size: Int64 = 0
            var children: [String: TreeNode] = [:]

            init(name: String, path: String, isPackage: Bool = false) {
                self.name = name
                self.path = path
                self.isPackage = isPackage
            }

            func toNode() -> SpaceLensNode {
                var node = SpaceLensNode(url: URL(fileURLWithPath: path), name: name, size: size,
                                         isPackage: isPackage,
                                         isProtected: isProtectedRoot(path))
                node.children = children.values
                    .map { $0.toNode() }
                    .sorted { $0.size > $1.size }
                return node
            }
        }
    }

    // /System holds the Data volume mount tree under Volumes; skipping it by name keeps
    // the walk on the sealed system volume only.
    nonisolated static func walkSystemShallow(maxDepth: Int = 1) async -> SpaceLensNode {
        let fm = FileManager.default
        var node = SpaceLensNode(url: URL(fileURLWithPath: "/System"), isProtected: true)
        guard let children = try? fm.contentsOfDirectory(atPath: "/System") else { return node }

        for childName in children.sorted() {
            if Task.isCancelled { break }
            if childName == "Volumes" { continue }
            let childURL = URL(fileURLWithPath: "/System/\(childName)")
            if isDirectory(url: childURL, fm: fm) {
                let childNode = await walkDirectory(url: childURL, skipFirmlinks: true, maxDepth: maxDepth)
                node.size += childNode.size
                node.children.append(childNode)
            } else {
                let size = await allocatedSize(url: childURL) ?? 0
                node.size += size
                node.children.append(SpaceLensNode(url: childURL, name: childName, size: size))
            }
        }
        return node
    }

    // MARK: du parsing

    struct DuLine {
        let id: UUID
        let path: String
        let depth: Int
        let size: Int64
    }

    // du -k lines: "size_in_kb<TAB>path". Sizes are KB, the path prefix order gives the tree.
    // du finishes each subtree before its parent, so reversed order is parents-first.
    func parseDuOutput(atPath path: String, rootName: String, pruneSystemVolumes: Bool, gen: Int,
                               onPartialTree: ((SpaceLensNode) async -> Void)?) async -> SpaceLensNode? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }

        var lines: [DuLine] = []
        for line in content.split(separator: "\n") {
            if isCancelled(gen) { return nil }
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2,
                  let kb = Int64(parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
            let rawPath = String(parts[1])
            guard !rawPath.hasSuffix("[") && !rawPath.hasSuffix("]") else { continue }
            lines.append(DuLine(id: SpaceLensNode.stableID(forPath: rawPath), path: rawPath,
                                depth: rawPath.split(separator: "/").count,
                                size: kb * 1024))
        }

        guard let rootLine = lines.last else { return nil }

        // Prefixes of the reversed list are valid partial trees rooted at the scan target.
        let ordered = Array(lines.reversed())

        // Batches of 20k lines published incrementally, matching the normal scan UX
        if let onPartialTree = onPartialTree, ordered.count > 20000 {
            let step = max(20000, ordered.count / 10)
            var index = step
            while index < ordered.count {
                if isCancelled(gen) { return nil }
                await onPartialTree(Self.buildTree(from: Array(ordered[..<index]), rootName: nil,
                                                   pruneSystemVolumes: pruneSystemVolumes)
                                    ?? SpaceLensNode(url: URL(fileURLWithPath: rootLine.path), name: rootName))
                index += step
            }
        }

        return Self.buildTree(from: ordered, rootName: rootLine.path == "/" ? rootName : nil,
                              pruneSystemVolumes: pruneSystemVolumes)
    }

    static func buildTree(from lines: [DuLine], rootName: String?,
                          pruneSystemVolumes: Bool) -> SpaceLensNode? {
        guard let first = lines.first else { return nil }

        var prunedTotal: Int64 = 0
        var kept = lines
        if pruneSystemVolumes {
            var filtered: [DuLine] = []
            for line in lines {
                if line.path == firmlinkRoot {
                    prunedTotal = line.size
                } else if !line.path.hasPrefix(firmlinkRoot + "/") {
                    filtered.append(line)
                }
            }
            kept = filtered
        }

        var childrenMap: [UUID: [SpaceLensNode]] = [:]
        var stack: [(id: UUID, depth: Int)] = []

        for line in kept {
            // A node's parent is the closest previous line with a smaller depth
            while let top = stack.last, top.depth >= line.depth {
                stack.removeLast()
            }
            if let parentID = stack.last?.id {
                childrenMap[parentID, default: []].append(
                    SpaceLensNode(id: line.id,
                                  url: URL(fileURLWithPath: line.path),
                                  name: URL(fileURLWithPath: line.path).lastPathComponent,
                                  size: line.size,
                                  isProtected: isProtectedPathStatic(line.path)))
            }
            stack.append((line.id, line.depth))
        }

        var root = SpaceLensNode(id: first.id,
                                 url: URL(fileURLWithPath: first.path),
                                 name: first.path == "/" && rootName != nil
                                    ? rootName!
                                    : URL(fileURLWithPath: first.path).lastPathComponent,
                                 size: first.size,
                                 isProtected: isProtectedPathStatic(first.path))
        root.children = (childrenMap[first.id] ?? []).sorted { $0.size > $1.size }

        if pruneSystemVolumes, prunedTotal > 0 {
            // The / and /System totals printed by du include the pruned subtree
            root.size -= prunedTotal
            if let index = root.children.firstIndex(where: { $0.url.path == "/System" }) {
                root.children[index].size -= prunedTotal
            }
        }

        return root
    }

    private static func isProtectedPathStatic(_ path: String) -> Bool {
        if protectedRootPaths.contains(path) { return true }
        return protectedRootPaths.contains { path.hasPrefix($0 + "/") }
    }
}
