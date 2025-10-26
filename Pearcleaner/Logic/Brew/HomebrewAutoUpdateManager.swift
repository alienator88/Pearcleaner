//
//  HomebrewAutoUpdateManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/25/25.
//

import Foundation
import AppKit
import AlinFoundation

// MARK: - Schedule Model

struct ScheduleOccurrence: Identifiable, Codable, Hashable {
    let id: UUID
    var weekday: Int      // 0=Sunday, 1=Monday, ... 6=Saturday
    var hour: Int         // 0-23
    var minute: Int       // 0-59
    var isEnabled: Bool

    init(weekday: Int? = nil, hour: Int? = nil, minute: Int? = nil, isEnabled: Bool = true) {
        self.id = UUID()

        // Use current date/time as defaults
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: now)

        // Convert Calendar.weekday (1=Sunday...7=Saturday) to our format (0=Sunday...6=Saturday)
        let currentWeekday = (components.weekday ?? 1) - 1

        self.weekday = weekday ?? currentWeekday
        self.hour = hour ?? (components.hour ?? 9)
        self.minute = minute ?? (components.minute ?? 0)
        self.isEnabled = isEnabled
    }
}

// MARK: - AutoUpdate Manager

class HomebrewAutoUpdateManager: ObservableObject {
    @Published var schedules: [ScheduleOccurrence] = []
    @Published var isAgentLoaded: Bool = false
    @Published var isEnabled: Bool = false  // Master toggle for entire schedule
    @Published var logFileExists: Bool = false

    // Global actions that apply to ALL schedules
    @Published var runUpdate: Bool = true
    @Published var runUpgrade: Bool = false
    @Published var runCleanup: Bool = false

    private let plistPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.alienator88.Pearcleaner.homebrew-autoupdate.plist"
    private let plistPathDisabled = "\(NSHomeDirectory())/Library/LaunchAgents/com.alienator88.Pearcleaner.homebrew-autoupdate.plist.disabled"
    private let label = "com.alienator88.Pearcleaner.homebrew-autoupdate"
    private let logPath = "/tmp/homebrew-autoupdate.log"

    init() {
        loadSchedule()
        checkAgentStatus()
        checkLogFiles()
        updateEnabledState()
    }

    // MARK: - Public Methods

    /// Toggle the entire schedule on/off
    func toggleEnabled(_ enabled: Bool) throws {
        let fileManager = FileManager.default

        if enabled {
            // Enable: Rename .disabled -> regular, then bootstrap
            if fileManager.fileExists(atPath: plistPathDisabled) {
                try fileManager.moveItem(atPath: plistPathDisabled, toPath: plistPath)

                // Bootstrap the agent
                let uid = getuid()
                let bootstrapCommand = "launchctl bootstrap gui/\(uid) \(plistPath)"
                let result = shell(bootstrapCommand)

                if result.exitCode != 0 {
                    // Rollback rename on failure
                    try? fileManager.moveItem(atPath: plistPath, toPath: plistPathDisabled)
                    throw HomebrewAutoUpdateError.registrationFailed(result.stderr)
                }
            }
        } else {
            // Disable: Bootout agent, then rename regular -> .disabled
            try? unregisterAgent()

            if fileManager.fileExists(atPath: plistPath) {
                try fileManager.moveItem(atPath: plistPath, toPath: plistPathDisabled)
            }
        }

        updateEnabledState()
        checkAgentStatus()
    }

    /// Update isEnabled state based on file existence
    private func updateEnabledState() {
        let fileManager = FileManager.default
        isEnabled = fileManager.fileExists(atPath: plistPath) && !fileManager.fileExists(atPath: plistPathDisabled)
    }

    /// Apply current schedules by generating plist and registering LaunchAgent
    func applySchedule() throws {
        // Check if we have any enabled schedules
        let enabledSchedules = schedules.filter { $0.isEnabled }

        guard !enabledSchedules.isEmpty else {
            // No enabled schedules - clean up
            try unregisterAgent()

            // Delete plist file
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: plistPath) {
                try fileManager.removeItem(atPath: plistPath)
            }

            checkAgentStatus()
            return
        }

        // Generate plist content
        let plistContent = generatePlist()

        // Validate plist format
        guard let data = plistContent.data(using: .utf8) else {
            throw HomebrewAutoUpdateError.invalidEncoding
        }

        do {
            _ = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw HomebrewAutoUpdateError.invalidFormat(error.localizedDescription)
        }

        // Write plist to LaunchAgents directory (must exist before registering!)
        let plistURL = URL(fileURLWithPath: plistPath)
        try data.write(to: plistURL)

        // Verify file was written
        guard FileManager.default.fileExists(atPath: plistPath) else {
            throw HomebrewAutoUpdateError.fileWriteFailed
        }

        // Unregister old service (if exists) then register new one
        try? unregisterAgent()  // Ignore error if not registered

        // Register with launchctl
        let uid = getuid()
        let bootstrapCommand = "launchctl bootstrap gui/\(uid) \(plistPath)"

        let result = shell(bootstrapCommand)
        if result.exitCode != 0 {
            throw HomebrewAutoUpdateError.registrationFailed(result.stderr)
        }

        // Update state
        updateEnabledState()
        checkAgentStatus()
    }

    /// Unregister LaunchAgent
    func unregisterAgent() throws {
        let uid = getuid()
        let bootoutCommand = "launchctl bootout gui/\(uid)/\(label)"

        let result = shell(bootoutCommand)
        // Note: bootout returns error if service not loaded, which is fine
        if result.exitCode != 0 && !result.stderr.contains("Could not find service") {
            throw HomebrewAutoUpdateError.registrationFailed(result.stderr)
        }

        checkAgentStatus()
    }

    /// Check if LaunchAgent is currently loaded
    func checkAgentStatus() {
        let uid = getuid()
        let printCommand = "launchctl print gui/\(uid)/\(label)"

        let result = shell(printCommand)
        // If launchctl print succeeds, the service is loaded
        isAgentLoaded = (result.exitCode == 0)
    }

    /// Check if log file exists
    func checkLogFiles() {
        let fileManager = FileManager.default
        logFileExists = fileManager.fileExists(atPath: logPath)
    }

    /// Open log file in default text editor
    func openLogFile() {
        let url = URL(fileURLWithPath: logPath)
        NSWorkspace.shared.open(url)
    }

    /// Reload schedule from existing plist file (single source of truth)
    func loadSchedule() {
        let fileManager = FileManager.default

        // Check both regular and disabled plist paths
        let pathToLoad: String?
        if fileManager.fileExists(atPath: plistPath) {
            pathToLoad = plistPath
        } else if fileManager.fileExists(atPath: plistPathDisabled) {
            pathToLoad = plistPathDisabled
        } else {
            schedules = []
            return
        }

        // Read and parse plist
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: pathToLoad!)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            printOS("Failed to read plist at \(pathToLoad!)")
            schedules = []
            return
        }

        // Extract StartCalendarInterval array
        guard let calendarIntervals = plist["StartCalendarInterval"] as? [[String: Int]] else {
            schedules = []
            return
        }

        // Extract global actions from ProgramArguments (apply to all schedules)
        if let programArgs = plist["ProgramArguments"] as? [String],
           programArgs.count >= 3 {
            let command = programArgs[2]
            runUpdate = command.contains("brew update")
            runUpgrade = command.contains("brew upgrade")
            runCleanup = command.contains("brew autoremove") || command.contains("brew cleanup")
        }

        // Parse each interval into ScheduleOccurrence
        schedules = calendarIntervals.compactMap { interval in
            guard let weekday = interval["Weekday"],
                  let hour = interval["Hour"],
                  let minute = interval["Minute"] else {
                return nil
            }

            return ScheduleOccurrence(
                weekday: weekday,
                hour: hour,
                minute: minute,
                isEnabled: true  // All schedules in plist are enabled
            )
        }
    }

    // MARK: - Private Methods

    /// Execute shell command and return result
    private func shell(_ command: String) -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let stdout = String(data: outputData, encoding: .utf8) ?? ""
            let stderr = String(data: errorData, encoding: .utf8) ?? ""

            return (stdout, stderr, process.terminationStatus)
        } catch {
            return ("", error.localizedDescription, -1)
        }
    }

    /// Generate plist XML from current schedules
    private func generatePlist() -> String {
        let enabledSchedules = schedules.filter { $0.isEnabled }

        // Build command as a shell script block for clean output
        let brewPath = HomebrewController.shared.getBrewPrefix() + "/bin/brew"
        var scriptLines: [String] = []

        // Header
        scriptLines.append("echo \"\"")
        scriptLines.append("echo \"================================\"")
        scriptLines.append("echo \"Homebrew Auto-Update - $(date)\"")
        scriptLines.append("echo \"================================\"")
        scriptLines.append("echo \"\"")

        // Update section
        if runUpdate {
            scriptLines.append("echo \"[ Updating Homebrew ]\"")
            scriptLines.append("\(brewPath) update 2>&1")
            scriptLines.append("echo \"\"")
        }

        // Upgrade section
        if runUpgrade {
            scriptLines.append("echo \"[ Upgrading Packages ]\"")
            scriptLines.append("\(brewPath) upgrade --greedy 2>&1")
            scriptLines.append("echo \"\"")
        }

        // Cleanup section
        if runCleanup {
            scriptLines.append("echo \"[ Cleaning Up ]\"")
            scriptLines.append("\(brewPath) autoremove 2>&1")
            scriptLines.append("\(brewPath) cleanup --prune=all 2>&1")
            scriptLines.append("echo \"\"")
        }

        // Footer
        scriptLines.append("echo \"================================\"")
        scriptLines.append("echo \"Completed at $(date)\"")
        scriptLines.append("echo \"================================\"")

        // Wrap in braces for single execution block
        let scriptBlock = "{ " + scriptLines.joined(separator: "; ") + "; } 2>&1"

        // Escape XML special characters for plist
        let escapedCommand = scriptBlock
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        // Generate StartCalendarInterval entries
        let calendarIntervals = enabledSchedules.map { schedule in
            """
                    <dict>
                        <key>Weekday</key>
                        <integer>\(schedule.weekday)</integer>
                        <key>Hour</key>
                        <integer>\(schedule.hour)</integer>
                        <key>Minute</key>
                        <integer>\(schedule.minute)</integer>
                    </dict>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/sh</string>
                <string>-c</string>
                <string>\(escapedCommand)</string>
            </array>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>\(HomebrewController.shared.getBrewPrefix())/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
            </dict>
            <key>RunAtLoad</key>
            <false/>
            <key>StandardOutPath</key>
            <string>/tmp/homebrew-autoupdate.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/homebrew-autoupdate.log</string>
            <key>StartCalendarInterval</key>
            <array>
        \(calendarIntervals)
            </array>
        </dict>
        </plist>
        """
    }
}

// MARK: - Error Types

enum HomebrewAutoUpdateError: LocalizedError {
    case invalidEncoding
    case invalidFormat(String)
    case fileWriteFailed
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Failed to encode plist content"
        case .invalidFormat(let details):
            return "Invalid plist format: \(details)"
        case .fileWriteFailed:
            return "Failed to write plist file to LaunchAgents directory"
        case .registrationFailed(let details):
            return "Failed to register LaunchAgent: \(details)"
        }
    }
}
