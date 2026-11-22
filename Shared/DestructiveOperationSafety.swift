//
//  DestructiveOperationSafety.swift
//  Pearcleaner
//
//  Decision layer for destructive CLI operations, kept free of filesystem
//  and UI dependencies so the authorization rules are testable in isolation.
//

import Foundation

/// The result of the non-mutating preflight performed before a destructive CLI
/// operation. Keeping the decision separate from presentation makes it
/// testable without launching the app or touching the user's Trash.
enum DestructiveOperationAuthorization: Equatable {
    case confirmationRequired(preview: String)
    case privilegedAuthorizationRequired(protectedPaths: [String])
    case authorized

    static func evaluate(
        paths: [URL],
        acknowledged: Bool,
        hasPrivilegedAuthorization: Bool,
        isWritable: (URL) -> Bool
    ) -> Self {
        guard acknowledged else {
            return .confirmationRequired(preview: DestructiveOperationPreview.message(for: paths))
        }

        let protectedPaths = paths
            .filter { !isWritable($0) }
            .map(\.path)
            .sorted()
        guard protectedPaths.isEmpty || hasPrivilegedAuthorization else {
            return .privilegedAuthorizationRequired(protectedPaths: protectedPaths)
        }

        return .authorized
    }
}

enum DestructiveOperationPreview {
    static func message(for paths: [URL]) -> String {
        let sortedPaths = paths.map(\.path).sorted()
        let heading = "Preview — the following \(sortedPaths.count) item(s) would be moved to the Trash:"
        return ([heading] + sortedPaths + ["Re-run this command with --yes to confirm."]).joined(separator: "\n")
    }
}
