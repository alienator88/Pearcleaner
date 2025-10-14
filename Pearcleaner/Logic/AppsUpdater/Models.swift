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

    var icon: String {
        switch self {
        case .homebrew:
            return "🍺"
        case .appStore:
            return "􀎶"
        case .sparkle:
            return "✨"
        }
    }
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case downloading
    case installing
    case verifying
    case completed
    case failed(String)

    static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.checking, .checking),
             (.downloading, .downloading),
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
    let source: UpdateSource
    let adamID: UInt64?
    let appStoreURL: String?  // Store URL from iTunes API for "Open in App Store" button
    var status: UpdateStatus = .idle
    var progress: Double = 0.0

    // Sparkle metadata (optional, only populated for Sparkle apps)
    let releaseTitle: String?
    let releaseDescription: String?
    let releaseDate: String?

    var canUpdate: Bool {
        source == .homebrew || source == .appStore
    }
}
