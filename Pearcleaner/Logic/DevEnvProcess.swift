//
//  DevEnvProcess.swift
//  Pearcleaner
//
//  Runs CLI tools that manage developer VM/container runtimes and returns
//  their output for listing. Pure reads: no mutating command goes through here.
//

import Foundation

enum DevEnvProcess {
    /// Runs a binary with a timeout. Returns nil when the binary is missing,
    /// exits non-zero, or exceeds the timeout (slow or hung daemons degrade
    /// to filesystem-only listing instead of blocking the view).
    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 10) -> String? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardInput = nil
        process.environment = ProcessInfo.processInfo.userEnvironment

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do {
            try process.run()
        } catch {
            return nil
        }

        // Async drain keeps pipes from deadlocking on large outputs.
        var outData = Data()
        var errData = Data()
        out.fileHandleForReading.readabilityHandler = { handle in outData.append(handle.availableData) }
        err.fileHandleForReading.readabilityHandler = { handle in errData.append(handle.availableData) }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            out.fileHandleForReading.readabilityHandler = nil
            err.fileHandleForReading.readabilityHandler = nil
            return nil
        }

        out.fileHandleForReading.readabilityHandler = nil
        err.fileHandleForReading.readabilityHandler = nil
        outData.append(out.fileHandleForReading.readDataToEndOfFile())
        errData.append(err.fileHandleForReading.readDataToEndOfFile())

        guard process.terminationStatus == 0 else { return nil }
        return String(data: outData, encoding: .utf8)
    }

    /// Locates a CLI by trying the common install roots first, then the user PATH.
    /// SPM binaries inherit a minimal environment, so PATH lookup alone misses
    /// Homebrew and app-bundle CLIs.
    static func which(_ name: String) -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.orbstack/bin/\(name)",
            "\(home)/.rd/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate) {
            return candidate
        }
        // Fall back to the shell's own lookup so user-local installs still work.
        guard let output = run("/usr/bin/which", [name], timeout: 5) else { return nil }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Parses docker-style human size strings ("13.6MB", "1.24GB", "0B")
    /// into bytes. Returns nil for "N/A" and friends.
    static func parseSizeString(_ raw: String) -> Int64? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != "N/A" else { return nil }
        let digits = text.prefix { !$0.isLetter && $0 != " " }
        guard let value = Double(digits), !digits.isEmpty else { return nil }
        let unit = text.dropFirst(digits.count).trimmingCharacters(in: .whitespaces).uppercased()
        let multiplier: Double
        switch unit {
        case "", "B": multiplier = 1
        case "KB": multiplier = 1_000
        case "MB": multiplier = 1_000_000
        case "GB": multiplier = 1_000_000_000
        case "TB": multiplier = 1_000_000_000_000
        default: return nil
        }
        return Int64((value * multiplier).rounded())
    }
}