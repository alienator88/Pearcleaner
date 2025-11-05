//
//  Models.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/13/25.
//

import Foundation
import SwiftUI

enum UpdateSource: String, CaseIterable {
    case homebrew = "Homebrew"
    case appStore = "App Store"
    case sparkle = "Sparkle"
    case unsupported = "Unsupported"

    var icon: String {
        switch self {
        case .homebrew:
            return "🍺"
        case .appStore:
            return "􀎶"
        case .sparkle:
            return "✨"
        case .unsupported:
            return "❓"
        }
    }
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case downloading
    case extracting
    case installing
    case verifying
    case completed
    case failed(String)

    static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.checking, .checking),
             (.downloading, .downloading),
             (.extracting, .extracting),
             (.installing, .installing),
             (.verifying, .verifying),
             (.completed, .completed):
            return true
        case (.failed(let lhsMsg), .failed(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

struct UpdateableApp: Identifiable {
    let id = UUID()
    let appInfo: AppInfo
    var availableVersion: String?
    var availableBuildNumber: String?  // Remote build number (CFBundleVersion) for smart version display
    let source: UpdateSource
    let adamID: UInt64?
    let appStoreURL: String?  // Store URL from iTunes API for "Open in App Store" button
    var status: UpdateStatus = .idle
    var progress: Double = 0.0
    var isSelectedForUpdate: Bool = true  // Default to selected for "Update All" queue

    // Sparkle/App Store metadata (optional)
    let releaseTitle: String?
    let releaseDescription: String?
    let releaseNotesLink: String?  // URL to external release notes page
    let releaseDate: String?
    let isPreRelease: Bool  // True for Sparkle pre-release updates (has channel tag or SemVer pre-release identifier)
    let isIOSApp: Bool  // True for wrapped iPad/iOS apps that must be updated via App Store app
    let foundInRegion: String?  // App Store region code where update was found (e.g., "US", "CN")

    var canUpdate: Bool {
        source == .homebrew || source == .appStore
    }

    /// Unique identifier for tracking hidden apps
    var uniqueIdentifier: String {
        appInfo.bundleIdentifier
    }
}
