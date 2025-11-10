//
//  UndoHistoryManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/10/25.
//

import Foundation
import SwiftUI
import AlinFoundation

// MARK: - UndoHistoryRecord

struct UndoHistoryRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let appName: String
    let bundleFolderPath: String
    let filePairs: [(original: String, trashed: String)]
    let fileCount: Int

    enum CodingKeys: String, CodingKey {
        case id, timestamp, appName, bundleFolderPath, filePairs, fileCount
    }

    // Custom encoding/decoding for tuples
    init(id: UUID = UUID(), timestamp: Date, appName: String, bundleFolderPath: String, filePairs: [(String, String)], fileCount: Int) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.bundleFolderPath = bundleFolderPath
        self.filePairs = filePairs
        self.fileCount = fileCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        appName = try container.decode(String.self, forKey: .appName)
        bundleFolderPath = try container.decode(String.self, forKey: .bundleFolderPath)
        fileCount = try container.decode(Int.self, forKey: .fileCount)

        let pairs = try container.decode([[String]].self, forKey: .filePairs)
        filePairs = pairs.map { ($0[0], $0[1]) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(appName, forKey: .appName)
        try container.encode(bundleFolderPath, forKey: .bundleFolderPath)
        try container.encode(fileCount, forKey: .fileCount)

        let pairs = filePairs.map { [$0.original, $0.trashed] }
        try container.encode(pairs, forKey: .filePairs)
    }
}

// MARK: - UndoHistoryManager

@MainActor
class UndoHistoryManager: ObservableObject {
    static let shared = UndoHistoryManager()

    @Published private(set) var history: [UndoHistoryRecord] = []

    private let maxHistoryCount = 10
    private let historyFileURL: URL

    private init() {
        // Store in Application Support folder
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let pearcleanerDir = appSupport.appendingPathComponent("Pearcleaner")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: pearcleanerDir, withIntermediateDirectories: true)

        historyFileURL = pearcleanerDir.appendingPathComponent("UndoHistory.json")

        loadHistory()
    }

    // MARK: - Public Methods

    /// Add a new delete operation to history
    func addRecord(appName: String, bundleFolderPath: String, filePairs: [(String, String)]) {
        let record = UndoHistoryRecord(
            timestamp: Date(),
            appName: appName,
            bundleFolderPath: bundleFolderPath,
            filePairs: filePairs,
            fileCount: filePairs.count
        )

        // Insert at beginning (most recent first)
        history.insert(record, at: 0)

        // Keep only last 10
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }

        saveHistory()
    }

    /// Restore selected records from history
    func restoreRecords(_ records: [UndoHistoryRecord]) async throws {
        for record in records {
            // Validate bundle folder still exists
            guard FileManager.default.fileExists(atPath: record.bundleFolderPath) else {
                printOS("⚠️ Skipping restore for \(record.appName) - bundle folder no longer exists")
                continue
            }

            // Build file pairs from stored paths
            let filePairs: [(trashURL: URL, originalURL: URL)] = record.filePairs.map {
                (trashURL: URL(fileURLWithPath: $0.trashed), originalURL: URL(fileURLWithPath: $0.original))
            }

            // Restore using FileManagerUndo (runs synchronously via semaphore)
            let success = FileManagerUndo.shared.restoreFiles(filePairs: filePairs)

            if !success {
                printOS("⚠️ Failed to restore files for \(record.appName)")
                throw NSError(domain: "UndoHistoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to restore \(record.appName)"])
            }

            // Remove from history after successful restore
            if let index = history.firstIndex(where: { $0.id == record.id }) {
                history.remove(at: index)
            }
        }

        saveHistory()
    }

    /// Remove a specific record by bundle folder path (called when user does Cmd+Z undo)
    func removeRecord(bundleFolderPath: String) {
        if let index = history.firstIndex(where: { $0.bundleFolderPath == bundleFolderPath }) {
            history.remove(at: index)
            saveHistory()
        }
    }

    /// Remove stale entries where bundle folder no longer exists in trash
    func cleanupStaleEntries() {
        let initialCount = history.count

        history.removeAll { record in
            !FileManager.default.fileExists(atPath: record.bundleFolderPath)
        }

        if history.count < initialCount {
            saveHistory()
        }
    }

    /// Check if a record's files still exist in trash
    func isRecordValid(_ record: UndoHistoryRecord) -> Bool {
        return FileManager.default.fileExists(atPath: record.bundleFolderPath)
    }

    // MARK: - Persistence

    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(history)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            printOS("❌ Failed to save undo history: \(error.localizedDescription)")
        }
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            history = try decoder.decode([UndoHistoryRecord].self, from: data)

            // Cleanup stale entries on load
            cleanupStaleEntries()
        } catch {
            printOS("❌ Failed to load undo history: \(error.localizedDescription)")
        }
    }
}
