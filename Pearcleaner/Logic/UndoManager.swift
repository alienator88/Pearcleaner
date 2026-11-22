//
//  UndoManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 2/24/25.
//
// Modified for the independently maintained Pearcleaner fork.

import Foundation
import SwiftUI
import AlinFoundation
import Darwin

func pathExistsWithoutFollowingSymlinks(_ url: URL) -> Bool {
    var fileInfo = stat()
    return lstat(url.path, &fileInfo) == 0
}

func pathIsDirectoryWithoutFollowingSymlinks(_ url: URL) -> Bool {
    var fileInfo = stat()
    guard lstat(url.path, &fileInfo) == 0 else {
        return false
    }
    return (fileInfo.st_mode & S_IFMT) == S_IFDIR
}

func normalizedDeletionURLs(
    _ urls: [URL],
    isDirectory: (URL) -> Bool = pathIsDirectoryWithoutFollowingSymlinks
) -> [URL] {
    var seenPaths = Set<String>()
    let uniqueURLs = urls
        .map(\.standardizedFileURL)
        .filter { seenPaths.insert($0.path).inserted }
        .sorted {
            let leftDepth = $0.pathComponents.count
            let rightDepth = $1.pathComponents.count
            return leftDepth == rightDepth ? $0.path < $1.path : leftDepth < rightDepth
        }

    var retained: [(url: URL, isDirectory: Bool)] = []
    for candidate in uniqueURLs {
        let candidatePath = candidate.path
        let isCoveredByDirectory = retained.contains { retainedItem in
            retainedItem.isDirectory &&
            candidatePath.hasPrefix(retainedItem.url.path.hasSuffix("/")
                ? retainedItem.url.path
                : retainedItem.url.path + "/")
        }
        if !isCoveredByDirectory {
            retained.append((candidate, isDirectory(candidate)))
        }
    }
    return retained.map(\.url)
}

func makeTrashBundleURL(
    trashRoot: URL,
    displayName _: String,
    timestamp: String,
    operationSuffix: String
) -> URL? {
    let timestampPattern = #"^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$"#
    let suffixPattern = #"^[0-9A-Fa-f]{8}$"#
    guard timestamp.range(of: timestampPattern, options: .regularExpression) != nil,
          operationSuffix.range(of: suffixPattern, options: .regularExpression) != nil else {
        return nil
    }

    let standardizedRoot = trashRoot.standardizedFileURL
    let candidate = standardizedRoot
        .appendingPathComponent("Pearcleaner_\(timestamp)_\(operationSuffix)", isDirectory: true)
        .standardizedFileURL
    guard candidate.deletingLastPathComponent() == standardizedRoot else {
        return nil
    }
    return candidate
}

func isGeneratedTrashBundleFolder(_ folder: URL, trashRoot: URL) -> Bool {
    let standardizedRoot = trashRoot.standardizedFileURL
    let standardizedFolder = folder.standardizedFileURL
    guard standardizedFolder.deletingLastPathComponent() == standardizedRoot else {
        return false
    }

    let generatedNamePattern = #"_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_[0-9A-Fa-f]{8}$"#
    return standardizedFolder.lastPathComponent.range(
        of: generatedNamePattern,
        options: .regularExpression
    ) != nil
}

func reserveUniqueTrashLeafName(
    for baseName: String,
    reservedNames: inout Set<String>,
    destinationExists: (String) -> Bool
) -> String {
    var suffix = 0
    var candidate = baseName
    while reservedNames.contains(candidate) || destinationExists(candidate) {
        suffix += 1
        candidate = "\(baseName)-\(suffix)"
    }
    reservedNames.insert(candidate)
    return candidate
}

enum FileOperationDispatchDecision: Equatable {
    case direct
    case rejectProtected
}

func fileOperationDispatchDecision(
    hasProtectedPaths: Bool
) -> FileOperationDispatchDecision {
    hasProtectedPaths ? .rejectProtected : .direct
}

func shouldRejectRootCLIFileOperation(
    isCLI: Bool,
    effectiveUserID: uid_t
) -> Bool {
    isCLI && effectiveUserID == 0
}

struct FileDeletionResult {
    let requestedURLs: [URL]
    let movedURLs: [URL]
    let failedURLs: [URL]
    let protectedURLs: [URL]

    init(
        requestedURLs: [URL],
        movedURLs: [URL],
        failedURLs: [URL],
        protectedURLs: [URL] = []
    ) {
        self.requestedURLs = requestedURLs
        self.movedURLs = movedURLs
        self.failedURLs = failedURLs
        self.protectedURLs = protectedURLs
    }

    var allSucceeded: Bool {
        !requestedURLs.isEmpty &&
        failedURLs.isEmpty &&
        movedURLs.count == requestedURLs.count
    }

    var isPartial: Bool {
        !movedURLs.isEmpty && !failedURLs.isEmpty
    }

    func includingRequestedURLs(_ urls: [URL]) -> FileDeletionResult {
        var seenPaths = Set<String>()
        let uniqueURLs = urls.filter {
            seenPaths.insert($0.standardizedFileURL.path).inserted
        }
        let movedPaths = Set(movedURLs.map { $0.standardizedFileURL.path })
        return FileDeletionResult(
            requestedURLs: uniqueURLs,
            movedURLs: movedURLs,
            failedURLs: uniqueURLs.filter {
                !movedPaths.contains($0.standardizedFileURL.path)
            },
            protectedURLs: protectedURLs
        )
    }
}

class FileManagerUndo {
    // MARK: - Singleton Instance
    static let shared = FileManagerUndo()

    // Private initializer to enforce singleton pattern
    private init() {}

    // NSUndoManager instance to handle undo/redo actions
    let undoManager = UndoManager()
    private var lastUndoSucceeded: Bool?
    private(set) var lastRestoredOriginalURLs: [URL] = []

    // MARK: - Path Validation
    /// Validates that a path is safe to delete (not a critical system path or app folder)
    private func validatePath(_ path: String) -> Bool {
        // Normalize path
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path

        // Block empty paths
        guard !normalizedPath.trimmingCharacters(in: .whitespaces).isEmpty else {
            printOS("⚠️ Blocked deletion: Empty path")
            return false
        }

        // Combine critical system paths + user app folder paths into single set
        let criticalSystemPaths = [
            "/",
            "/Applications",
            "/Library",
            "/System",
            "/usr",
            "/bin",
            "/sbin",
            "/etc",
            "/var",
            "/private",
            "/opt",
            NSHomeDirectory()
        ]

        let userAppPaths = FolderSettingsManager.shared.folderPaths
        let blockedPaths = Set(criticalSystemPaths + userAppPaths)

        // Block if path exactly matches any blocked path
        if blockedPaths.contains(normalizedPath) {
            printOS("⚠️ Blocked deletion: Protected path '\(normalizedPath)'")
            return false
        }

        return true
    }

    func deleteFiles(at urls: [URL], isCLI: Bool = false, bundleName: String? = nil) -> Bool {
        deleteFilesWithResult(at: urls, isCLI: isCLI, bundleName: bundleName).allSucceeded
    }

    func deleteFilesWithResult(
        at urls: [URL],
        isCLI: Bool = false,
        bundleName: String? = nil
    ) -> FileDeletionResult {
        var seenPaths = Set<String>()
        let requestedURLs = urls.filter {
            seenPaths.insert($0.standardizedFileURL.path).inserted
        }

        if shouldRejectRootCLIFileOperation(
            isCLI: isCLI,
            effectiveUserID: geteuid()
        ) {
            let message =
                "Refusing to move files to a user's Trash while running as root. Rerun Pearcleaner without sudo."
            printOS("Trash Error: \(message)")
            return FileDeletionResult(
                requestedURLs: requestedURLs,
                movedURLs: [],
                failedURLs: requestedURLs
            )
        }

        // Filter out invalid/dangerous paths before deletion
        let validRequestedURLs = requestedURLs.filter {
            validatePath($0.path) && pathExistsWithoutFollowingSymlinks($0)
        }
        let validURLs = normalizedDeletionURLs(validRequestedURLs)

        // If no valid paths remain, return early
        guard !validURLs.isEmpty else {
            printOS("⚠️ All paths were blocked - no files deleted")
            return FileDeletionResult(
                requestedURLs: requestedURLs,
                movedURLs: [],
                failedURLs: requestedURLs
            )
        }

        // Log if any requested paths were invalid. Descendants covered by a
        // selected directory are intentionally coalesced into one move.
        if validRequestedURLs.count < requestedURLs.count {
            printOS("⚠️ Filtered out \(requestedURLs.count - validRequestedURLs.count) missing or dangerous path(s)")
        }
        let trashRootURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".Trash", isDirectory: true)
            .standardizedFileURL

        var tempFilePairs: [(trashURL: URL, originalURL: URL)] = []
        var reservedFileNames = Set<String>()
        let operationDirectoryPaths = Set(
            validURLs
                .filter(pathIsDirectoryWithoutFollowingSymlinks)
                .map { $0.standardizedFileURL.path }
        )

        // Moving an item requires write access to its parent directory, not to
        // the item contents themselves.
        let protectedURLs = validURLs.filter {
            !FileManager.default.isWritableFile(atPath: $0.deletingLastPathComponent().path)
        }
        let dispatchDecision = fileOperationDispatchDecision(
            hasProtectedPaths: !protectedURLs.isEmpty
        )
        guard dispatchDecision == .direct else {
            let message =
                "Protected paths were skipped. Pearcleaner does not send user-controlled Trash paths to its privileged helper."
            printOS("Trash Error: \(message)")
            updateOnMain {
                AppState.shared.trashError = true
                AppState.shared.trashErrorMessage = message
            }
            return FileDeletionResult(
                requestedURLs: requestedURLs,
                movedURLs: [],
                failedURLs: requestedURLs,
                protectedURLs: protectedURLs
            )
        }

        // Keep the display name as metadata only; it must never influence the
        // filesystem path used for the Trash bundle.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let folderName: String
        if let customBundleName = bundleName {
            folderName = customBundleName
        } else if !AppState.shared.appInfo.appName.isEmpty {
            folderName = AppState.shared.appInfo.appName
        } else {
            // Fallback for plugins: use the first file's name or "Mixed Files"
            if let firstFile = validURLs.first {
                folderName = firstFile.deletingPathExtension().lastPathComponent
            } else {
                folderName = "Mixed Files"
            }
        }

        let operationSuffix = String(UUID().uuidString.prefix(8))
        guard let bundleFolderURL = makeTrashBundleURL(
            trashRoot: trashRootURL,
            displayName: folderName,
            timestamp: timestamp,
            operationSuffix: operationSuffix
        ) else {
            printOS("Trash Error: Could not create a safe Trash bundle path.")
            return FileDeletionResult(
                requestedURLs: requestedURLs,
                movedURLs: [],
                failedURLs: requestedURLs
            )
        }
        let bundleFolderPath = bundleFolderURL.path

        guard pathIsDirectoryWithoutFollowingSymlinks(trashRootURL) else {
            printOS("Trash Error: The user Trash directory is unavailable.")
            return FileDeletionResult(
                requestedURLs: requestedURLs,
                movedURLs: [],
                failedURLs: requestedURLs
            )
        }

        // A plain mkdir fails closed if an unexpected entry already occupies
        // the random destination.
        let createFolderCommand = "/bin/mkdir \(bundleFolderPath.shellQuoted)"

        let mvCommands = validURLs.map { file -> String in
            let baseName = file.lastPathComponent
            let finalName = reserveUniqueTrashLeafName(
                for: baseName,
                reservedNames: &reservedFileNames,
                destinationExists: { candidate in
                    pathExistsWithoutFollowingSymlinks(
                        bundleFolderURL.appendingPathComponent(candidate)
                    )
                }
            )

            let destinationURL = bundleFolderURL.appendingPathComponent(finalName)
            tempFilePairs.append((trashURL: destinationURL, originalURL: file))

            let source = file.path.shellQuoted
            let destination = destinationURL.path.shellQuoted
            return "/bin/mv -n \(source) \(destination)"
        }.joined(separator: " && ")

        // Stop at the first failed move. Afterwards, inspect the filesystem so
        // history and the UI describe only items that actually moved.
        let finalCommands = "\(createFolderCommand) && \(mvCommands)"
        let filePairs = tempFilePairs

        let commandSucceeded = executeFileCommands(
            finalCommands,
            isRestore: false
        )
        let movedPairs = filePairs.filter {
            pathExistsWithoutFollowingSymlinks($0.trashURL) &&
            !pathExistsWithoutFollowingSymlinks($0.originalURL)
        }
        let validRequestedPaths = Set(validRequestedURLs.map { $0.standardizedFileURL.path })
        let movedOperationPaths = Set(movedPairs.map { $0.originalURL.standardizedFileURL.path })
        let movedURLs = requestedURLs.filter { requestedURL in
            let requestedPath = requestedURL.standardizedFileURL.path
            guard validRequestedPaths.contains(requestedPath) else {
                return false
            }
            return movedOperationPaths.contains(requestedPath) ||
                operationDirectoryPaths.contains { directoryPath in
                    movedOperationPaths.contains(directoryPath) &&
                    requestedPath.hasPrefix(directoryPath.hasSuffix("/")
                        ? directoryPath
                        : directoryPath + "/")
                }
        }
        let movedPaths = Set(movedURLs.map { $0.standardizedFileURL.path })
        let failedURLs = requestedURLs.filter {
            !movedPaths.contains($0.standardizedFileURL.path)
        }
        let result = FileDeletionResult(
            requestedURLs: requestedURLs,
            movedURLs: movedURLs,
            failedURLs: failedURLs
        )

        if !movedPairs.isEmpty {
            registerDeletionUndo(
                filePairs: movedPairs,
                restoredRequestedURLs: movedURLs
            )

            // Record in persistent history
            Task { @MainActor in
                UndoHistoryManager.shared.addRecord(
                    appName: folderName,
                    bundleFolderPath: bundleFolderPath,
                    filePairs: movedPairs.map { ($0.originalURL.path, $0.trashURL.path) }
                )
            }

            // Play the sound only when at least one item actually moved.
            if !isCLI {
                playTrashSound()
            }
        } else {
            _ = rmdir(bundleFolderURL.path)
        }

        if !commandSucceeded || !result.allSucceeded {
            updateOnMain {
                AppState.shared.trashError = true
            }
        }

        return result
    }

    func registerDeletionUndo(
        filePairs: [(trashURL: URL, originalURL: URL)],
        restoredRequestedURLs: [URL]
    ) {
        let register = {
            self.undoManager.registerUndo(withTarget: self) { target in
                let result = target.restoreFiles(filePairs: filePairs)
                if result {
                    // A selected directory can coalesce selected descendants
                    // into one physical move. Preserve the complete requested
                    // selection so File Search can restore every cached row.
                    target.lastRestoredOriginalURLs = restoredRequestedURLs
                }
                target.lastUndoSucceeded = result
                if !result {
                    printOS("Trash Error: Could not restore files.")
                }
            }
            self.undoManager.setActionName("Delete File")
        }

        if Thread.isMainThread {
            register()
        } else {
            DispatchQueue.main.sync(execute: register)
        }
    }

    func restoreFiles(
        filePairs: [(trashURL: URL, originalURL: URL)],
        isCLI: Bool = false,
        trashRoot suppliedTrashRoot: URL? = nil
    ) -> Bool {
        lastRestoredOriginalURLs = []

        func rejectRestore(_ message: String) -> Bool {
            printOS("Restore Error: \(message)")
            updateOnMain {
                AppState.shared.trashError = true
                AppState.shared.trashErrorMessage = message
            }
            return false
        }

        guard !filePairs.isEmpty else {
            return rejectRestore("No files were provided.")
        }

        guard !shouldRejectRootCLIFileOperation(
            isCLI: isCLI,
            effectiveUserID: geteuid()
        ) else {
            return rejectRestore(
                "Refusing to restore files from a user's Trash while running as root. Rerun Pearcleaner without sudo."
            )
        }

        let systemTrashRoot = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".Trash", isDirectory: true)
            .standardizedFileURL
        let trashRootURL = (suppliedTrashRoot ?? systemTrashRoot).standardizedFileURL
        let standardizedPairs = filePairs.map {
            (
                trashURL: $0.trashURL.standardizedFileURL,
                originalURL: $0.originalURL.standardizedFileURL
            )
        }
        guard pathIsDirectoryWithoutFollowingSymlinks(trashRootURL),
              let bundleFolder = standardizedPairs.first?.trashURL.deletingLastPathComponent(),
              isGeneratedTrashBundleFolder(bundleFolder, trashRoot: trashRootURL),
              pathIsDirectoryWithoutFollowingSymlinks(bundleFolder),
              standardizedPairs.allSatisfy({
                  $0.trashURL.deletingLastPathComponent() == bundleFolder
              }) else {
            return rejectRestore("The Trash bundle path is not trusted.")
        }

        let sourcePaths = standardizedPairs.map { $0.trashURL.path }
        let destinationPaths = standardizedPairs.map { $0.originalURL.path }
        guard Set(sourcePaths).count == sourcePaths.count,
              Set(destinationPaths).count == destinationPaths.count,
              standardizedPairs.allSatisfy({
                  validatePath($0.originalURL.path) &&
                  $0.trashURL != $0.originalURL
              }) else {
            return rejectRestore("The restore paths are invalid or duplicated.")
        }

        // Refuse the whole restore before moving anything if a source is gone
        // or a newer item occupies an original path.
        let missingSources = standardizedPairs.filter {
            !pathExistsWithoutFollowingSymlinks($0.trashURL)
        }
        let occupiedDestinations = standardizedPairs.filter {
            pathExistsWithoutFollowingSymlinks($0.originalURL)
        }
        guard missingSources.isEmpty, occupiedDestinations.isEmpty else {
            if !occupiedDestinations.isEmpty {
                printOS("Restore Error: Refusing to overwrite \(occupiedDestinations.count) existing item(s).")
            }
            if !missingSources.isEmpty {
                printOS("Restore Error: \(missingSources.count) trashed item(s) are missing.")
            }
            return rejectRestore("Preflight checks failed.")
        }

        let hasProtectedFiles = standardizedPairs.contains {
            !FileManager.default.isWritableFile(atPath: $0.originalURL.deletingLastPathComponent().path)
        }
        guard fileOperationDispatchDecision(
            hasProtectedPaths: hasProtectedFiles
        ) == .direct else {
            return rejectRestore(
                "Protected restores are disabled because mutable Trash paths cannot be sent safely to a privileged shell. Restore this item manually."
            )
        }

        let directResult = runDirectRestoreTransaction(standardizedPairs)
        let commandSucceeded = directResult.0
        if !directResult.0 {
            printOS("Restore Error: \(directResult.1)")
        }

        let restoredPairs = standardizedPairs.filter {
            pathExistsWithoutFollowingSymlinks($0.originalURL) &&
            !pathExistsWithoutFollowingSymlinks($0.trashURL)
        }
        let restoredAll = commandSucceeded && restoredPairs.count == standardizedPairs.count

        if restoredAll {
            lastRestoredOriginalURLs = restoredPairs.map { $0.originalURL }

            // Bundle cleanup is best-effort and must not turn a successful
            // restore into a failure if metadata remains in the folder.
            _ = rmdir(bundleFolder.path)

            // Remove from persistent history after successful restore
            if trashRootURL == systemTrashRoot {
                Task { @MainActor in
                    UndoHistoryManager.shared.removeRecord(bundleFolderPath: bundleFolder.path)
                }
            }
        } else {
            updateOnMain {
                AppState.shared.trashError = true
                AppState.shared.trashErrorMessage =
                    "The restore failed. \(directResult.1)"
            }
        }

        return restoredAll
    }

    private func runDirectRestoreTransaction(
        _ filePairs: [(trashURL: URL, originalURL: URL)]
    ) -> (Bool, String) {
        let fileManager = FileManager.default
        var movedPairs: [(trashURL: URL, originalURL: URL)] = []

        do {
            for pair in filePairs {
                guard pathExistsWithoutFollowingSymlinks(pair.trashURL),
                      !pathExistsWithoutFollowingSymlinks(pair.originalURL) else {
                    throw NSError(
                        domain: "PearcleanerRestore",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "A restore path changed after preflight."]
                    )
                }

                try fileManager.moveItem(at: pair.trashURL, to: pair.originalURL)
                movedPairs.append(pair)
                guard !pathExistsWithoutFollowingSymlinks(pair.trashURL),
                      pathExistsWithoutFollowingSymlinks(pair.originalURL) else {
                    throw NSError(
                        domain: "PearcleanerRestore",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "A restored item could not be verified."]
                    )
                }
            }
            return (true, "")
        } catch {
            var rollbackErrors: [String] = []
            for pair in movedPairs.reversed() {
                guard pathExistsWithoutFollowingSymlinks(pair.originalURL),
                      !pathExistsWithoutFollowingSymlinks(pair.trashURL) else {
                    rollbackErrors.append(pair.originalURL.path)
                    continue
                }
                do {
                    try fileManager.moveItem(at: pair.originalURL, to: pair.trashURL)
                } catch {
                    rollbackErrors.append("\(pair.originalURL.path): \(error.localizedDescription)")
                }
            }

            let rollbackDescription = rollbackErrors.isEmpty
                ? "Earlier moves were rolled back."
                : "Rollback also failed for: \(rollbackErrors.joined(separator: ", "))."
            return (false, "\(error.localizedDescription) \(rollbackDescription)")
        }
    }

    func undoLastDeletion() -> Bool {
        guard undoManager.canUndo else {
            return false
        }

        lastUndoSucceeded = nil
        lastRestoredOriginalURLs = []
        undoManager.undo()
        return lastUndoSucceeded == true
    }

    private func executeFileCommands(
        _ commands: String,
        isRestore: Bool
    ) -> Bool {
        let shellResult = runDirectShellCommand(command: commands)
        if !shellResult.0 {
            printOS(
                isRestore
                    ? "Restore Error: \(shellResult.1)"
                    : "Trash Error: \(shellResult.1)"
            )
            updateOnMain {
                AppState.shared.trashError = true
            }
        }
        return shellResult.0
    }

    // Helper to run direct non-privileged shell commands
    private func runDirectShellCommand(command: String) -> (Bool, String) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
        } catch {
            return (false, error.localizedDescription)
        }

        // Drain while the child runs so verbose failures cannot fill the pipe
        // and deadlock the caller.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""

        if output.lowercased().contains("permission denied") {
            return (false, output)
        }

        return (task.terminationStatus == 0, output)
    }

}

extension URL {
    var isProtected: Bool {
        !FileManager.default.isWritableFile(atPath: self.path)
    }
}
