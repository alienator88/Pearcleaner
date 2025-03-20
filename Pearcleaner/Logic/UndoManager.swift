//
//  UndoManager.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 2/24/25.
//

import Foundation
import AlinFoundation

class FileManagerUndo {
    // MARK: - Singleton Instance
    static let shared = FileManagerUndo()

    // Private initializer to enforce singleton pattern
    private init() {}

    // NSUndoManager instance to handle undo/redo actions
    let undoManager = UndoManager()

    // Delete a file and register an undo action to restore it
    func deleteFiles(at urls: [URL], isCLI: Bool = false) -> Bool {
        // Check if any file is protected
        let hasProtectedFiles = urls.contains { !FileManager.default.isWritableFile(atPath: $0.path) }
        let trashPath = (NSHomeDirectory() as NSString).appendingPathComponent(".Trash")
        let dispatchSemaphore = DispatchSemaphore(value: 0)  // Semaphore to make it synchronous
        var finalStatus = false  // Store the final success/failure status

        if hasProtectedFiles {
            // Collect file pairs and build mv commands
            var tempFilePairs: [(trashURL: URL, originalURL: URL)] = []
            var seenFileNames: [String: Int] = [:]

            let mvCommands = urls.map { file -> String in
                var fileName = file.lastPathComponent

                // Check if the filename has already been used in this batch
                if let count = seenFileNames[fileName] {
                    // Increment counter and append it to the filename
                    let newCount = count + 1
                    seenFileNames[fileName] = newCount

                    let newName = "\(file.deletingPathExtension().lastPathComponent)\(newCount).\(file.pathExtension)"
                    fileName = newName
                } else {
                    // First occurrence of this filename
                    seenFileNames[fileName] = 1
                }

                // Construct the trash destination URL with the possibly updated filename
                let destinationURL = URL(fileURLWithPath: (trashPath as NSString).appendingPathComponent(fileName))
                tempFilePairs.append((trashURL: destinationURL, originalURL: file))

                let source = "\"\(file.path)\""
                let destination = "\"\(destinationURL.path)\""
                return "/bin/mv \(source) \(destination)"
            }.joined(separator: " ; ")

            // Make filePairs immutable
            let filePairs = tempFilePairs

            // Conditional Execution using Helper Tool if installed
            if executeFileCommands(mvCommands, isCLI: isCLI) {
                // Register undo action with the immutable filePairs
                undoManager.registerUndo(withTarget: self) { target in
                    let result = target.restoreFiles(filePairs: filePairs)
                    if !result {
                        printOS("Trash Error: Could not restore files.")
                    }
                }
                undoManager.setActionName("Delete File")

                finalStatus = true
            } else {
                printOS("Trash Error: \(isCLI ? "Could not run commands directly with sudo." : "Could not perform privileged commands.")")
                updateOnMain {
                    AppState.shared.trashError = true
                }
                finalStatus = false
            }

            dispatchSemaphore.signal()

        } else {
            // If no files are protected, trash them normally
            for url in urls {
                var trashedNSURL: NSURL?
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: &trashedNSURL)
                    if let trashURL = trashedNSURL as URL? {
                        undoManager.registerUndo(withTarget: self) { target in
                            let result = target.restoreFiles(filePairs: [(trashURL, url)])
                            if !result {
                                printOS("Trash Error: Could not restore file from \(trashURL) to \(url)")
                            }
                        }
                        undoManager.setActionName("Delete File")
                    }
                } catch {
                    printOS("Error trashing file at \(url): \(error)")
                    updateOnMain {
                        AppState.shared.trashError = true
                    }
                    finalStatus = false
                    dispatchSemaphore.signal()
                    return false
                }
            }

            finalStatus = true  // Success for non-protected files
            dispatchSemaphore.signal()

        }

        dispatchSemaphore.wait()
        return finalStatus
    }

    func restoreFiles(filePairs: [(trashURL: URL, originalURL: URL)], isCLI: Bool = false) -> Bool {
        // Check if any file is protected
        let hasProtectedFiles = filePairs.contains {
            !FileManager.default.isWritableFile(atPath: $0.originalURL.deletingLastPathComponent().path)
        }

        let dispatchSemaphore = DispatchSemaphore(value: 0)  // Semaphore to make it synchronous
        var finalStatus = true  // Assume success, set to false on error

        if hasProtectedFiles {
            // Build all mv commands chained with ;
            let commands = filePairs.map {
                let source = "\"\($0.trashURL.path)\""
                let destination = "\"\($0.originalURL.path)\""
                return "/bin/mv \(source) \(destination)"
            }.joined(separator: " ; ")

            // Conditional Execution using Helper Tool if installed
            if executeFileCommands(commands, isCLI: isCLI) {
                finalStatus = true
            } else {
                printOS("Trash Error: \(isCLI ? "Failed to run restore CLI commands" : "Failed to run restore privileged commands")")
                finalStatus = false
            }

            // Signal the semaphore to continue
            dispatchSemaphore.signal()

        } else {
            // If no files are protected, restore them normally
            for pair in filePairs {
                do {
                    try FileManager.default.moveItem(at: pair.trashURL, to: pair.originalURL)
                } catch {
                    printOS("Error restoring file from \(pair.trashURL) to \(pair.originalURL): \(error)")
                    finalStatus = false  // Failure
                }
            }

            // Signal the semaphore to continue
            dispatchSemaphore.signal()
        }

        // Wait for all operations to complete
        dispatchSemaphore.wait()

        return finalStatus  // Return the final status
    }

    private func executeFileCommands(_ commands: String, isCLI: Bool) -> Bool {
        var status = false

        if HelperToolManager.shared.isHelperToolInstalled {
            let semaphore = DispatchSemaphore(value: 0)
            var success = false
            var output = ""

            Task {
                let result = await HelperToolManager.shared.runCommand(commands)
                success = result.0
                output = result.1
                semaphore.signal()
            }
            semaphore.wait()

            status = success
            if !success {
                printOS("Trash Error: \(output)")
                updateOnMain {
                    AppState.shared.trashError = true
                }
            }
        } else {
            if isCLI {
                status = runDirectShellCommand(command: commands)
            } else {
                status = performPrivilegedCommands(commands: commands)
            }
        }

        return status
    }

}

func runDirectShellCommand(command: String) -> Bool {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", command]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    task.launch()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        if output.lowercased().contains("permission denied") {
            return false
        }
    }

    return task.terminationStatus == 0
}

// Helper to check if the file is in a protected location by verifying writability
private func isProtected(url: URL) -> Bool {
    return !FileManager.default.isWritableFile(atPath: url.path)
}
