//
//  ProcessEnv.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/6/25.
//

import Foundation

public extension Process {
    static func executeAsUser(_ parameters: Process.ExecutionParameters) throws -> Data? {
        let userParams = parameters.userShellInvocation()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: userParams.path)
        task.arguments = userParams.arguments
        task.environment = userParams.environment
        task.currentDirectoryURL = userParams.currentDirectoryURL
        return try? task.runAndReadStdout()
    }

    func runAndReadStdout() throws -> Data? {
        let pipe = Pipe()

        standardOutput = pipe

        try run()

        waitUntilExit()

        return try pipe.fileHandleForReading.readToEnd()
    }

    // MARK: - Execution Parameters

    /// Wraps up all of the parameters needed for starting a Process into one single type.
    struct ExecutionParameters: Codable, Hashable, Sendable {
        public var path: String
        public var arguments: [String]
        public var environment: [String : String]?
        public var currentDirectoryURL: URL?

        public init(path: String, arguments: [String] = [], environment: [String : String]? = nil, currentDirectoryURL: URL? = nil) {
            self.path = path
            self.arguments = arguments
            self.environment = environment
            self.currentDirectoryURL = currentDirectoryURL
        }

        public var command: String {
            return ([path] + arguments).joined(separator: " ")
        }

        /// Returns parameters that emulate an invocation in the user's shell
        ///
        /// This is done by executing:
        ///
        ///     shellExecutablePath -ilc <command>
        ///
        /// This method executes this with the `environment` environment
        /// variables set. But, it also ensures that the `TERM`, `HOME`, and
        /// `PATH` variables have values, if aren't present in `environment`.
        ///
        /// The `-i` and `-l` flags are critical, as they control how many
        /// shells read configuration files.
        public func userShellInvocation() -> ExecutionParameters {
            let processInfo = ProcessInfo.processInfo

            let shellPath = processInfo.shellExecutablePath
            let args = ["-ilc", command]
            let cwdURL = currentDirectoryURL

            let defaultEnv = ["TERM": "xterm-256color",
                              "HOME": processInfo.homePath,
                              "PATH": processInfo.path]

            let baseEnv = environment ?? defaultEnv

            let env = baseEnv.merging(defaultEnv, uniquingKeysWith: { (a, _) in a })

            return ExecutionParameters(path: shellPath,
                                       arguments: args,
                                       environment: env,
                                       currentDirectoryURL: cwdURL)
        }
    }
}

extension ProcessInfo {
    /// The path to the current user's shell executable
    ///
    /// This attempts to query the `SHELL` environment variable, the
    /// password directory (via `getpwuid`), or if those fail
    /// falls back to "/bin/bash".
    public var shellExecutablePath: String {
        if let value = environment["SHELL"], !value.isEmpty {
            return value
        }

        if let passwd = getpwuid(getuid()),
           let cString = passwd.pointee.pw_shell {
            let shellPath = String(cString: cString)
            if !shellPath.isEmpty {
                return shellPath
            }
        }

        // this is a terrible fallback, but we need something
        return "/bin/bash"
    }
    /// Returns the value of PATH
    ///
    /// If PATH is set in the envrionment, it is returned. If not,
    /// the fallback value of "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    /// is returned.
    public var path: String {
        return environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }

    public var homePath: String {
        if let path = environment["HOME"] {
            return path
        }

        if let passwd = getpwuid(getuid()),
           let cString = passwd.pointee.pw_dir {
            return String(cString: cString)
        }

        return "/Users/\(userName)"
    }

    /// Capture the interactive-login shell environment
    ///
    /// This method attempts to reconstruct the user
    /// environment that would be set up when logging into
    /// a terminal session.
    public var userEnvironment: [String : String] {
        guard let data = try? Process.executeAsUser(.init(path: "/usr/bin/env", environment: environment)) else {
            return environment
        }

        return parseEnvOutput(data)
    }

    func parseEnvOutput(_ data: Data) -> [String : String] {
        guard let string = String(data: data, encoding: .utf8) else {
            return [:]
        }

        var env: [String: String] = [:]

        string.enumerateLines { (line, _) in
            guard let separatorIndex = line.firstIndex(of: "=") else {
                return
            }

            let key = line[..<separatorIndex].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespaces)

            env[key] = value
        }

        return env
    }
}
