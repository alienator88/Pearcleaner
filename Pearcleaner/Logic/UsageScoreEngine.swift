//
//  UsageScoreEngine.swift
//  Pearcleaner
//
//  Created by Pearcleaner on 2026-11-22.
//
//  Usage-scoring engine: attributes files to owners and scores how likely a
//  file is orphaned (owner gone or file unused). Signals, strongest first:
//    - sandbox container metadata (MCMMetadataIdentifier: the bundle id
//      containermanagerd recorded when the container was created)
//    - quarantine xattr agent bundle id (who downloaded it)
//    - owner app installed? (bundle id / name / team id match)
//    - InstallHistory.plist co-installation windows (file created while a
//      now-removed package was installed)
//    - Spotlight usage metadata (kMDItemLastUsedDate, kMDItemUseCount)
//    - filesystem dates (creation / content change)
//  Score is 0-100:
//    90+   owner provably gone (container metadata or quarantine agent
//          names an app that is no longer installed)
//    60-89 gone-package co-installation evidence plus staleness
//    30-59 no attribution, staleness signals only
//    0-29  owner installed, file recently used, or Apple-owned

import Foundation
import AppKit

struct UsageSignals {
    var quarantineAgentBundleId: String?
    var quarantineDate: Date?
    var lastUsedDate: Date?
    var useCount: Int?
    var creationDate: Date?
    var contentChangeDate: Date?
    var containerOwnerBundleId: String?
}

/// Scan-lifetime context: installed app identities plus InstallHistory
/// events, loaded once per orphan scan and shared by every score call.
/// The scan processes items serially, so no internal locking is needed.
final class UsageScoreContext {

    private struct InstallEvent {
        let date: Date
        let formattedIdentifiers: [String]
    }

    private let installedApps: [AppInfo]
    private let installedFormattedIds: [String]
    private let installEvents: [InstallEvent]

    init(installedApps: [AppInfo]) {
        self.installedApps = installedApps
        self.installedFormattedIds = installedApps
            .map { $0.bundleIdentifier.pearFormat() }
            .filter { $0.count >= 5 }
        self.installEvents = Self.loadInstallHistory()
    }

    /// InstallHistory.plist records every pkg install. Apple-only events
    /// (XProtect and friends install almost weekly) carry no third-party
    /// evidence, so they are dropped at load. Kept sorted by date for
    /// window lookups.
    private static func loadInstallHistory() -> [InstallEvent] {
        let url = URL(fileURLWithPath: "/Library/Receipts/InstallHistory.plist")
        guard let raw = NSArray(contentsOf: url) as? [[String: Any]] else { return [] }
        return raw.compactMap { entry -> InstallEvent? in
            guard let date = entry["date"] as? Date,
                  let identifiers = entry["packageIdentifiers"] as? [String] else { return nil }
            let thirdParty = identifiers
                .filter { !$0.hasPrefix("com.apple.") }
                .map { $0.pearFormat() }
                .filter { !$0.isEmpty }
            guard !thirdParty.isEmpty else { return nil }
            return InstallEvent(date: date, formattedIdentifiers: thirdParty)
        }
        .sorted { $0.date < $1.date }
    }

    /// Is this bundle id installed right now? Short ids cannot prove an app
    /// is gone, so they fail safe as installed. Helper and XPC bundle ids
    /// (com.vendor.app.helper) count as installed when their parent app is.
    func isInstalled(bundleId: String) -> Bool {
        let formatted = bundleId.pearFormat()
        guard formatted.count >= 5 else { return true }
        for app in installedApps {
            let instFormatted = app.bundleIdentifier.pearFormat()
            if instFormatted == formatted { return true }
            let raw = bundleId.lowercased()
            let instRaw = app.bundleIdentifier.lowercased()
            if raw.hasPrefix(instRaw + ".") || instRaw.hasPrefix(raw + ".") { return true }
        }
        return false
    }

    enum CoInstallEvidence { case none, installedPackage, gonePackage }

    /// A file created around the time a package was installed is likely
    /// that package's doing. Window: from 24h before to 48h after the event.
    /// An event matching a still-installed app wins over gone evidence
    /// (under-reporting orphans is the safe direction).
    func coInstallEvidence(forCreation date: Date) -> CoInstallEvidence {
        let windowStart = date.addingTimeInterval(-24 * 3600)
        let windowEnd = date.addingTimeInterval(48 * 3600)

        var installedHit = false
        var goneHit = false

        for event in eventsBetween(windowStart, windowEnd) {
            let matchesInstalled = event.formattedIdentifiers.contains { pkgId in
                installedFormattedIds.contains { installedId in
                    pkgId.contains(installedId) || installedId.contains(pkgId)
                }
            }
            if matchesInstalled {
                installedHit = true
                break
            } else {
                goneHit = true
            }
        }

        if installedHit { return .installedPackage }
        if goneHit { return .gonePackage }
        return .none
    }

    /// Binary search over the date-sorted event list; the 72h window
    /// usually holds a handful of events.
    private func eventsBetween(_ start: Date, _ end: Date) -> ArraySlice<InstallEvent> {
        var lo = 0
        var hi = installEvents.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if installEvents[mid].date < start { lo = mid + 1 } else { hi = mid }
        }
        let first = lo

        var lo2 = first
        var hi2 = installEvents.count
        while lo2 < hi2 {
            let mid = (lo2 + hi2) / 2
            if installEvents[mid].date <= end { lo2 = mid + 1 } else { hi2 = mid }
        }
        return installEvents[first..<lo2]
    }
}

enum UsageScoreEngine {

    // MARK: - Signal collection

    /// Read provenance + usage signals for one file. Cheap: two xattr/plist
    /// reads plus one MDItem lookup. Returns nil when the path is unreadable.
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
            if let count = MDItemCopyAttribute(item, "kMDItemUseCount" as CFString) as? NSNumber {
                signals.useCount = count.intValue
            }
        }

        if let attrs = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) {
            signals.creationDate = attrs.creationDate
            signals.contentChangeDate = attrs.contentModificationDate
        }

        // Container ownership: containermanagerd records the owning bundle id
        // in a hidden plist inside every sandbox/group container, and the
        // record survives the app being uninstalled. Only probed under
        // container directories so flat files pay no extra read.
        if url.path.contains("/Containers/") || url.path.contains("/Group Containers/") || url.path.contains("/HTTPStorages/") {
            let metaURL = url.appending(path: ".com.apple.containermanagerd.metadata.plist", directoryHint: .notDirectory)
            if let dict = NSDictionary(contentsOf: metaURL) {
                signals.containerOwnerBundleId = dict["MCMMetadataIdentifier"] as? String
            }
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
    /// owner: name-matched installed app, already resolved by the caller.
    /// context: scan-lifetime InstallHistory + installed-app identities.
    static func orphanScore(for url: URL, signals: UsageSignals, owner: AppInfo?, context: UsageScoreContext) -> Int {
        let now = Date()

        // Apple-owned files are never suggested for deletion, no matter what
        // the other signals say.
        if url.path.contains("com.apple.")
            || signals.containerOwnerBundleId?.hasPrefix("com.apple.") == true
            || signals.quarantineAgentBundleId?.hasPrefix("com.apple.") == true {
            return 0
        }

        // Container metadata is authoritative ownership: if the recorded
        // owner is installed the file is in use, regardless of name matches.
        if let containerOwner = signals.containerOwnerBundleId {
            if context.isInstalled(bundleId: containerOwner) {
                return recentlyUsed(signals, now) ? 5 : 10
            }
            // Recorded owner provably gone: strongest orphan case.
            var score = 88
            score += stalenessDelta(signals, now)
            return max(0, min(100, score))
        }

        // Installed owner from quarantine agent or name matching.
        if let owner {
            return recentlyUsed(signals, now) ? 5 : 10
        }

        var score = 35

        // Quarantine downloader identified and not installed.
        if let agentId = signals.quarantineAgentBundleId {
            if context.isInstalled(bundleId: agentId) {
                return recentlyUsed(signals, now) ? 5 : 10
            }
            score = 92
        }

        // Co-installation evidence: file created during an install event of
        // a package that is fully gone now.
        if let created = signals.creationDate {
            switch context.coInstallEvidence(forCreation: created) {
            case .gonePackage:
                score += 15
            case .installedPackage:
                return recentlyUsed(signals, now) ? 5 : 10
            case .none:
                break
            }
        }

        // Spotlight never recorded a use on top of an old last-used date.
        if signals.useCount == 0,
           let lastUsed = signals.lastUsedDate,
           now.timeIntervalSince(lastUsed) > 90 * 24 * 3600 {
            score += 10
        }

        score += stalenessDelta(signals, now)
        return max(0, min(100, score))
    }

    private static func recentlyUsed(_ signals: UsageSignals, _ now: Date) -> Bool {
        if let lastUsed = signals.lastUsedDate, lastUsed > now.addingTimeInterval(-90 * 24 * 3600) {
            return true
        }
        if let change = signals.contentChangeDate, change > now.addingTimeInterval(-90 * 24 * 3600) {
            return true
        }
        return false
    }

    /// Staleness adjustments, max ±20, from Spotlight dates when indexed
    /// and filesystem dates otherwise.
    private static func stalenessDelta(_ signals: UsageSignals, _ now: Date) -> Int {
        if let lastUsed = signals.lastUsedDate {
            let days = Int(now.timeIntervalSince(lastUsed) / 86400)
            if days > 365 { return 20 }
            if days > 180 { return 12 }
            if days < 30 { return -20 }
        } else if let change = signals.contentChangeDate {
            let days = Int(now.timeIntervalSince(change) / 86400)
            if days > 365 { return 15 }
            if days > 180 { return 8 }
            if days < 30 { return -15 }
        }
        return 0
    }
}