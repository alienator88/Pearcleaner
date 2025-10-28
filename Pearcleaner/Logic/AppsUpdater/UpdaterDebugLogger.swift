//
//  UpdaterDebugLogger.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/25/25.
//

import Foundation
import SwiftUI

/// In-memory debug logger for updater sources
/// Stores logs in memory when enabled, can be exported to file
class UpdaterDebugLogger: ObservableObject {
    static let shared = UpdaterDebugLogger()

    // Separate log storage for each source
    @Published private(set) var appStoreLogs: [String] = []
    @Published private(set) var sparkleLogs: [String] = []
    @Published private(set) var homebrewLogs: [String] = []

    private init() {}

    /// Check if debug logging is currently enabled (reads directly from UserDefaults)
    private var isDebugEnabled: Bool {
        UserDefaults.standard.object(forKey: "settings.updater.debugLogging") as? Bool ?? true
    }

    /// Log a message for a specific update source
    func log(_ source: UpdateSource, _ message: String) {
        guard isDebugEnabled else { return }

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logLine = "[\(timestamp)] \(message)"

        DispatchQueue.main.async { [weak self] in
            switch source {
            case .appStore:
                self?.appStoreLogs.append(logLine)
            case .sparkle:
                self?.sparkleLogs.append(logLine)
            case .homebrew:
                self?.homebrewLogs.append(logLine)
            case .unsupported:
                // No logs for unsupported apps (they don't have updates to debug)
                break
            }
        }
    }

    /// Generate formatted debug output with all three sources
    func generateDebugReport() -> String {
        var report = ""

        report += "=" + String(repeating: "=", count: 78) + "\n"
        report += "UPDATER DEBUG LOG\n"
        report += "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))\n"
        report += "=" + String(repeating: "=", count: 78) + "\n\n"

        // App Store Section
        report += "━" + String(repeating: "━", count: 78) + "\n"
        report += "APP STORE UPDATE CHECKER (\(appStoreLogs.count) entries)\n"
        report += "━" + String(repeating: "━", count: 78) + "\n"
        if appStoreLogs.isEmpty {
            report += "  (No logs recorded)\n"
        } else {
            for log in appStoreLogs {
                report += "  \(log)\n"
            }
        }
        report += "\n"

        // Sparkle Section
        report += "━" + String(repeating: "━", count: 78) + "\n"
        report += "SPARKLE UPDATE DETECTOR (\(sparkleLogs.count) entries)\n"
        report += "━" + String(repeating: "━", count: 78) + "\n"
        if sparkleLogs.isEmpty {
            report += "  (No logs recorded)\n"
        } else {
            for log in sparkleLogs {
                report += "  \(log)\n"
            }
        }
        report += "\n"

        // Homebrew Section
        report += "━" + String(repeating: "━", count: 78) + "\n"
        report += "HOMEBREW UPDATE CHECKER (\(homebrewLogs.count) entries)\n"
        report += "━" + String(repeating: "━", count: 78) + "\n"
        if homebrewLogs.isEmpty {
            report += "  (No logs recorded)\n"
        } else {
            for log in homebrewLogs {
                report += "  \(log)\n"
            }
        }
        report += "\n"

        report += "=" + String(repeating: "=", count: 78) + "\n"
        report += "END OF DEBUG LOG\n"
        report += "=" + String(repeating: "=", count: 78) + "\n"

        return report
    }

    /// Clear all logs from memory
    func clearLogs() {
        DispatchQueue.main.async { [weak self] in
            self?.appStoreLogs.removeAll()
            self?.sparkleLogs.removeAll()
            self?.homebrewLogs.removeAll()
        }
    }

    /// Check if any logs exist
    var hasLogs: Bool {
        !appStoreLogs.isEmpty || !sparkleLogs.isEmpty || !homebrewLogs.isEmpty
    }
}
