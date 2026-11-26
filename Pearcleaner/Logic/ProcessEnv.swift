//
//  ProcessEnv.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/6/25.
//

import Foundation

extension ProcessInfo {
    /// A direct, minimal environment for Pearcleaner's own subprocesses.
    /// This does not run an interactive shell or source user startup files.
    public var userEnvironment: [String: String] {
        UserProcessEnvironment.make(
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
            temporaryDirectory: FileManager.default.temporaryDirectory,
            inheritedEnvironment: environment
        )
    }
}
