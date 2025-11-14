//
//  GlobalConsoleManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/13/24.
//

import Foundation
import SwiftUI

/// Console state persisted across app launches
struct ConsoleState: Codable {
    var isOpen: Bool
    var height: Double

    static let `default` = ConsoleState(isOpen: false, height: 200)
}

/// Global console manager for streaming operation output across all app pages
/// Provides thread-safe console output with source tagging
class GlobalConsoleManager: ObservableObject {
    static let shared = GlobalConsoleManager()

    /// Console output visible to all views
    @MainActor @Published var consoleOutput: String = ""

    /// Tracks if any operation is currently running
    @MainActor @Published var isOperationRunning: Bool = false

    /// Console visibility state (synchronized across all views)
    @MainActor @Published var showConsole: Bool = false

    /// Console height (synchronized across all views)
    @MainActor @Published var consoleHeight: Double = 200

    private init() {}

    /// Append text to console output with optional source tag
    /// - Parameters:
    ///   - text: Text to append
    ///   - source: Source identifier (e.g., "Homebrew", "PKG", "Daemon")
    @MainActor
    func appendOutput(_ text: String, source: String? = nil) {
        let taggedText: String
        if let source = source, !source.isEmpty {
            // Only add tag if it's the start of a new line or console is empty
            if consoleOutput.isEmpty || consoleOutput.hasSuffix("\n") {
                taggedText = "[\(source)] \(text)"
            } else {
                taggedText = text
            }
        } else {
            taggedText = text
        }

        consoleOutput += taggedText
    }

    /// Clear all console output
    @MainActor
    func clearOutput() {
        consoleOutput = ""
    }

    /// Trim console to specified number of lines to prevent memory bloat
    /// - Parameter maxLines: Maximum number of lines to keep (default 300)
    @MainActor
    func trimOutput(toLines maxLines: Int = 300) {
        let lines = consoleOutput.components(separatedBy: "\n")
        if lines.count > maxLines {
            consoleOutput = lines.suffix(maxLines).joined(separator: "\n")
        }
    }
}
