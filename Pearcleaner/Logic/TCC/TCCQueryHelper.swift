//
//  TCCQueryHelper.swift
//  Pearcleaner
//
//  SQLite3 query helper for TCC (Transparency, Consent, and Control) databases
//

import Foundation
import SQLite3

// MARK: - TCC Query Helper

class TCCQueryHelper {

    /// Query a TCC database for permissions granted to a specific bundle ID
    /// - Parameters:
    ///   - dbPath: Path to the TCC.db file
    ///   - bundleIdentifier: Bundle ID to query (e.g., "com.apple.Safari")
    ///   - source: The source database (user or system)
    /// - Returns: Result containing array of permissions or an error
    static func queryTCCDatabase(
        dbPath: String,
        bundleIdentifier: String,
        source: TCCPermission.PermissionSource
    ) -> Result<[TCCPermission], Error> {

        var db: OpaquePointer?
        var permissions: [TCCPermission] = []

        // Open database in read-only mode
        guard sqlite3_open_v2(
            dbPath,
            &db,
            SQLITE_OPEN_READONLY,
            nil
        ) == SQLITE_OK else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            return .failure(TCCError.databaseOpenFailed(errorMsg))
        }

        defer { sqlite3_close(db) }

        // Query with explicit column selection (defensive against schema changes)
        // Only get bundle ID entries (client_type = 0), not path entries (client_type = 1)
        let query = """
            SELECT service, auth_value, auth_reason, last_modified
            FROM access
            WHERE client_type = 0 AND client = ?
            ORDER BY service ASC
            """

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            return .failure(TCCError.queryPreparationFailed(errorMsg))
        }

        defer { sqlite3_finalize(statement) }

        // Bind bundle identifier parameter (prevents SQL injection)
        sqlite3_bind_text(statement, 1, (bundleIdentifier as NSString).utf8String, -1, nil)

        // Execute query and collect results
        while sqlite3_step(statement) == SQLITE_ROW {
            // Column 0: service (TEXT)
            let servicePtr = sqlite3_column_text(statement, 0)
            let service = servicePtr != nil ? String(cString: servicePtr!) : ""

            // Column 1: auth_value (INTEGER)
            let authValue = Int(sqlite3_column_int(statement, 1))

            // Column 2: auth_reason (INTEGER, nullable)
            let authReason: Int?
            if sqlite3_column_type(statement, 2) != SQLITE_NULL {
                authReason = Int(sqlite3_column_int(statement, 2))
            } else {
                authReason = nil
            }

            // Column 3: last_modified (INTEGER unix epoch, nullable)
            let lastModified: Date?
            if sqlite3_column_type(statement, 3) != SQLITE_NULL {
                let timestamp = sqlite3_column_int64(statement, 3)
                lastModified = Date(timeIntervalSince1970: TimeInterval(timestamp))
            } else {
                lastModified = nil
            }

            let permission = TCCPermission(
                service: service,
                authValue: authValue,
                authReason: authReason,
                lastModified: lastModified,
                source: source
            )

            permissions.append(permission)
        }

        return .success(permissions)
    }

    /// Query both User and System TCC databases
    /// - Parameter bundleIdentifier: Bundle ID to query
    /// - Returns: Combined results from both databases
    static func queryAllDatabases(
        bundleIdentifier: String
    ) async -> TCCQueryResult {

        var result = TCCQueryResult()

        // User database path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let userDBPath = "\(home)/Library/Application Support/com.apple.TCC/TCC.db"

        // System database path (requires Full Disk Access)
        let systemDBPath = "/Library/Application Support/com.apple.TCC/TCC.db"

        // Query user database
        let userResult = queryTCCDatabase(dbPath: userDBPath, bundleIdentifier: bundleIdentifier, source: .user)
        switch userResult {
        case .success(let permissions):
            result.userPermissions = permissions
        case .failure(let error):
            result.userError = error.localizedDescription
        }

        // Query system database (may fail without FDA)
        let systemResult = queryTCCDatabase(dbPath: systemDBPath, bundleIdentifier: bundleIdentifier, source: .system)
        switch systemResult {
        case .success(let permissions):
            result.systemPermissions = permissions
        case .failure(let error):
            result.systemError = error.localizedDescription
        }

        return result
    }
}

// MARK: - TCC Error

/// Errors that can occur when querying TCC databases
enum TCCError: LocalizedError {
    case databaseOpenFailed(String)
    case queryPreparationFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let msg):
            return "Failed to open TCC database: \(msg)"
        case .queryPreparationFailed(let msg):
            return "Failed to prepare query: \(msg)"
        }
    }
}
