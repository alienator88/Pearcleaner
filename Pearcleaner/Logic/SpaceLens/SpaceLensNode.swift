//
//  SpaceLensNode.swift
//  Pearcleaner
//

import Foundation

// Node identity must come from the path, not UUID(): partial scans republish the
// whole tree every second, and fresh random IDs would make focusedNode.id change
// on each publish, remounting the chart and dismissing any open context menu.
// A file path is stable across republishes of the same tree.
struct SpaceLensNode: Identifiable, Sendable {
    let id: UUID
    let url: URL
    let name: String
    var size: Int64 = 0
    var isPackage: Bool = false
    var isProtected: Bool = false
    var isAggregated: Bool = false
    var children: [SpaceLensNode] = []
    var accessError: String? = nil

    init(id: UUID? = nil, url: URL, name: String? = nil, size: Int64 = 0,
         isPackage: Bool = false, isProtected: Bool = false, isAggregated: Bool = false,
         children: [SpaceLensNode] = [], accessError: String? = nil) {
        self.id = id ?? SpaceLensNode.stableID(forPath: url.path)
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.size = size
        self.isPackage = isPackage
        self.isProtected = isProtected
        self.isAggregated = isAggregated
        self.children = children
        self.accessError = accessError
    }

    // Live disk probe, not stored state: tiles are snapshots and the filesystem
    // moves under them, so callers check the real path at interaction time.
    var isDirectoryOnDisk: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    func child(withID id: UUID) -> SpaceLensNode? {
        if self.id == id { return self }
        for child in children {
            if let match = child.child(withID: id) { return match }
        }
        return nil
    }

    func parent(ofID id: UUID) -> SpaceLensNode? {
        for child in children {
            if child.id == id { return self }
            if let match = child.parent(ofID: id) { return match }
        }
        return nil
    }

    func path(toID id: UUID) -> [SpaceLensNode] {
        if self.id == id { return [self] }
        for child in children {
            let chain = child.path(toID: id)
            if !chain.isEmpty { return [self] + chain }
        }
        return []
    }

    func hasAccessErrors() -> Bool {
        if accessError != nil { return true }
        return children.contains { $0.hasAccessErrors() }
    }

    // Replaces the subtree under nodeID and rebalances ancestor sizes by the delta.
    // The delta only flows through nodes that actually contain the old subtree;
    // siblings keep their size.
    func replacing(nodeID: UUID, with replacement: SpaceLensNode) -> SpaceLensNode {
        if id == nodeID {
            return replacement
        }
        var node = self
        if let oldChild = child(withID: nodeID) {
            node.size += replacement.size - oldChild.size
            node.children = node.children.map { $0.replacing(nodeID: nodeID, with: replacement) }
        }
        return node
    }

    func sortedBySize() -> SpaceLensNode {
        var node = self
        node.children = node.children
            .map { $0.sortedBySize() }
            .sorted { $0.size > $1.size }
        return node
    }

    // FNV-1a over the path bytes, same hash family the hue uses. A fixed seed
    // keeps IDs stable per path; collisions only risk a wrong focus lookup,
    // which clearStaleFocus() already handles by falling back to the root.
    static func stableID(forPath path: String) -> UUID {
        var hash: UInt64 = 1469598103934665603
        for byte in path.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        // Spread the 8 hash bytes over the 16 UUID bytes; UUID has no
        // array initializer, so the tuple is spelled out
        var bytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: &hash) { hashBytes in
            for index in 0..<16 {
                bytes[index] = hashBytes[index % 8]
            }
        }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
