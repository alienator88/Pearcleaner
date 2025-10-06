//
//  ProcessEnv.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/6/25.
//

import Foundation

public extension Process {
    static func execute(_ parameters: Process.ExecutionParameters) throws -> Data? {
        let task = Process(parameters: parameters)

        return try? task.runAndReadStdout()
    }

    static func executeAsUser(_ parameters: Process.ExecutionParameters) throws -> Data? {
        let userParams = parameters.userShellInvocation()

        let task = Process(parameters: userParams)

        return try? task.runAndReadStdout()
    }

    static func readOutput(from launchPath: String, arguments: [String] = [], environment: [String : String] = [:]) -> Data? {
        let params = Process.ExecutionParameters(path: launchPath, arguments: arguments, environment: environment)

        return try? execute(params)
    }

    func runAndReadStdout() throws -> Data? {
        let pipe = Pipe()

        standardOutput = pipe

        try run()

        waitUntilExit()

        return try pipe.fileHandleForReading.readToEnd()
    }
}





public extension Process {
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

    var parameters: ExecutionParameters {
        get {
            return ExecutionParameters(path: self.executableURL?.path ?? "",
                                       arguments: arguments ?? [],
                                       environment: self.environment,
                                       currentDirectoryURL: self.currentDirectoryURL)
        }
        set {
            self.executableURL = URL(fileURLWithPath: newValue.path)
            self.arguments = newValue.arguments
            self.environment = newValue.environment
            self.currentDirectoryURL = newValue.currentDirectoryURL
        }
    }

    convenience init(parameters: ExecutionParameters) {
        self.init()

        self.parameters = parameters
    }
}





public extension Process {
    typealias Environment = [String : String]
}

extension ProcessInfo {
    /// Cached password database entry to avoid multiple syscalls
    private var passwd: UnsafeMutablePointer<passwd>? {
        return getpwuid(getuid())
    }

    /// The path to the current user's shell executable
    ///
    /// This attempts to query the `SHELL` environment variable, the
    /// password directory (via `getpwuid`), or if those fail
    /// falls back to "/bin/bash".
    public var shellExecutablePath: String {
        if let value = environment["SHELL"], !value.isEmpty {
            return value
        }

        if let value = pwShell, !value.isEmpty {
            return value
        }

        // this is a terrible fallback, but we need something
        return "/bin/bash"
    }

    public var pwShell: String? {
        guard let cString = passwd?.pointee.pw_shell else {
            return nil
        }

        return String(cString: cString)
    }

    public var pwUserName: String? {
        guard let cString = passwd?.pointee.pw_name else {
            return nil
        }

        return String(cString: cString)
    }

    public var pwDir: String? {
        guard let cString = passwd?.pointee.pw_dir else {
            return nil
        }

        return String(cString: cString)
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

        if let path = pwDir {
            return path
        }

        return "/Users/\(userName)"
    }

    /// Capture the interactive-login shell environment
    ///
    /// This method attempts to reconstruct the user
    /// envrionment that would be set up when logging into
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
        let charSet = CharacterSet.whitespaces

        string.enumerateLines { (line, _) in
            let components = line.split(separator: "=")

            guard let key = components.first?.trimmingCharacters(in: charSet) else {
                return
            }

            let value = components.dropFirst().joined(separator: "=").trimmingCharacters(in: charSet)

            env[key] = value
        }

        return env
    }
}
