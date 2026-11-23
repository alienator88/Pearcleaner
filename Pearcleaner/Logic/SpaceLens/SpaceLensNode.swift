//
//  SpaceLensNode.swift
//  Pearcleaner
//

import Foundation

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

    init(id: UUID = UUID(), url: URL, name: String? = nil, size: Int64 = 0,
         isPackage: Bool = false, isProtected: Bool = false, isAggregated: Bool = false,
         children: [SpaceLensNode] = [], accessError: String? = nil) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.size = size
        self.isPackage = isPackage
        self.isProtected = isProtected
        self.isAggregated = isAggregated
        self.children = children
        self.accessError = accessError
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
}
