//
//  UserProcessEnvironment.swift
//  Pearcleaner
//
//  Environment policy for user-owned subprocesses. Deliberately does not
//  inherit SHELL, BASH_ENV, ENV, or a shell-derived PATH: no shell is
//  launched to construct this dictionary, so startup files like .bashrc
//  can never influence privileged or cleanup subprocesses.
//

import Foundation

enum UserProcessEnvironment {
    static let executableSearchPath = [
        "/opt/homebrew/bin", "/opt/homebrew/sbin",
        "/usr/local/bin", "/usr/local/sbin",
        "/usr/bin", "/bin", "/usr/sbin", "/sbin"
    ].joined(separator: ":")

    static func make(
        homeDirectory: URL,
        temporaryDirectory: URL,
        inheritedEnvironment _: [String: String] = [:]
    ) -> [String: String] {
        [
            "HOME": homeDirectory.standardizedFileURL.path,
            "TMPDIR": temporaryDirectory.standardizedFileURL.path,
            "PATH": executableSearchPath
        ]
    }
}
