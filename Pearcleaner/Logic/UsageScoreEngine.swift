//
//  UsageScoreEngine.swift
//  Pearcleaner
//
//  Created by Pearcleaner on 2026-11-22.
//
//  Usage-scoring engine: attributes files to owners and scores how likely a
//  file is orphaned (owner gone or file unused). Signals, strongest first:
//    - quarantine xattr agent bundle id (who downloaded it)
//    - owner app installed? (bundle id / name / team id match)
//    - Spotlight usage metadata (kMDItemLastUsedDate / UseCount)
//    - filesystem dates (creation / content change)
//  Score is 0-100: 100 = certainly orphaned, 0 = certainly in use.

import Foundation
import AppKit

struct UsageSignals {
    var quarantineAgentBundleId: String?
    var quarantineDate: Date?
    var lastUsedDate: Date?
    var useCount: Int?
    var creationDate: Date?
    var contentChangeDate: Date?
}

enum UsageScoreEngine {

    // MARK: - Signal collection

    /// Read provenance + usage signals for one file. Cheap: two xattr/plist reads
    /// plus one MDItem lookup. Returns nil when the path is unreadable.
    static func signals(for url: URL) -> UsageSignals? {
        var signals = UsageSignals()

        // Provenance: quarantine xattr holds the agent (downloader) bundle id
        if let quarantineProps = try? url.resourceValues(forKeys: [.quarantinePropertiesKey]).quarantineProperties {
            signals.quarantineAgentBundleId = quarantineProps["LSQuarantineAgentBundleIdentifier"] as? String
            signals.quarantineDate = quarantineProps["LSQuarantineTimeStamp"] as? Date
        }

        // Usage: Spotlight metadata when indexed, filesystem dates otherwise
        if let item = MDItemCreate(nil, url.path as CFString) {
            if let used = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date {
                signals.lastUsedDate = used
            }
            if let count = MDItemCopyAttribute(item, kMDItemUseCount as CFString) as? NSNumber {
                signals.useCount = count.intValue
            }
        }

        if let attrs = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) {
            signals.creationDate = attrs.creationDate
            signals.contentChangeDate = attrs.contentModificationDate
        }

        return signals
    }

    // MARK: - Owner attribution

    /// Which installed app (if any) plausibly owns this file.
    /// Quarantine agent bundle id is authoritative; name/team-id matching is a fallback.
    static func owningApp(for url: URL, signals: UsageSignals, installedApps: [AppInfo]) -> AppInfo? {
        let rawPath = url.path
        let formattedPath = rawPath.pearFormat()

        // 1. Quarantine agent: the exact app that wrote the file
        if let agentId = signals.quarantineAgentBundleId?.pearFormat(), agentId.count >= 5 {
            if let app = installedApps.first(where: { $0.bundleIdentifier.pearFormat() == agentId }) {
                return app
            }
        }

        // 2. Bundle id / name / team id match against installed apps
        for app in installedApps {
            let formattedBundleId = app.bundleIdentifier.pearFormat()
            if formattedBundleId.count >= 5 && formattedPath.contains(formattedBundleId) {
                return app
            }
            let formattedAppName = app.appName.pearFormat()
            if formattedAppName.count >= 5 && formattedPath.contains(formattedAppName) {
                return app
            }
            // TeamID-prefixed container names like TEAMID.com.vendor.app.
            // Match on the raw path: a team id is a 10-char alphanumeric id,
            // never a substring of a normal file name, so "contains" is safe here.
            if let teamId = app.teamIdentifier, teamId.count >= 5, rawPath.contains(teamId) {
                return app
            }
        }

        return nil
    }

    // MARK: - Scoring

    /// 0-100 confidence that the file is orphaned junk.
    /// 90+  owner provably gone (quarantine agent uninstalled) or in a known junk location
    /// 60-89 owner gone but attribution is name-based (weaker)
    /// 30-59 no owner matched, only staleness signals
    /// 0-29  owner installed or file recently used
    static func orphanScore(for url: URL, signals: UsageSignals, owner: AppInfo?) -> Int {
        var score = 0

        // Owner attribution is the dominant signal
        if owner != nil {
            score = 10
            // Recent use strongly overrides orphan status
            if let lastUsed = signals.lastUsedDate, lastUsed > Date().addingTimeInterval(-90 * 24 * 3600) {
                return 5
            }
            if let change = signals.contentChangeDate, change > Date().addingTimeInterval(-90 * 24 * 3600) {
                return 5
            }
        } else if signals.quarantineAgentBundleId != nil {
            // Downloader app identifiable and NOT installed: strongest orphan case
            score = 90
        } else {
            // No owner matched at all
            score = 35
        }

        // Staleness adjustments, max ±20
        var staleness = 0
        let now = Date()

        if let lastUsed = signals.lastUsedDate {
            let days = Int(now.timeIntervalSince(lastUsed) / 86400)
            if days > 365 { staleness += 20 }
            else if days > 180 { staleness += 12 }
            else if days < 30 { staleness -= 20 }
        } else if let change = signals.contentChangeDate {
            let days = Int(now.timeIntervalSince(change) / 86400)
            if days > 365 { staleness += 15 }
            else if days > 180 { staleness += 8 }
            else if days < 30 { staleness -= 15 }
        }

        if let count = signals.useCount, count == 0 {
            staleness += 5
        }

        score += staleness
        return max(0, min(100, score))
    }
}