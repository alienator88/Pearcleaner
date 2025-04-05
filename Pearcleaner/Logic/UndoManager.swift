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
        let trashPath = (NSHomeDirectory() as NSString).appendingPathComponent(".Trash")
        let dispatchSemaphore = DispatchSemaphore(value: 0)  // Semaphore to make it synchronous
        var finalStatus = false  // Store the final success/failure status

        var tempFilePairs: [(trashURL: URL, originalURL: URL)] = []
        var seenFileNames: [String: Int] = [:]

        let hasProtectedFiles = urls.contains { $0.isProtected }

        let mvCommands = urls.map { file -> String in
            var fileName = file.lastPathComponent

            if let count = seenFileNames[fileName] {
                let newCount = count + 1
                seenFileNames[fileName] = newCount
                let newName = "\(file.deletingPathExtension().lastPathComponent)\(newCount).\(file.pathExtension)"
                fileName = newName
            } else {
                seenFileNames[fileName] = 1
            }

            let destinationURL = URL(fileURLWithPath: (trashPath as NSString).appendingPathComponent(fileName))
            tempFilePairs.append((trashURL: destinationURL, originalURL: file))

            let source = "\"\(file.path)\""
            let destination = "\"\(destinationURL.path)\""
            return "/bin/mv \(source) \(destination)"
        }.joined(separator: " ; ")

        let filePairs = tempFilePairs

        if executeFileCommands(mvCommands, isCLI: isCLI, hasProtectedFiles: hasProtectedFiles) {
            undoManager.registerUndo(withTarget: self) { target in
                let result = target.restoreFiles(filePairs: filePairs)
                if !result {
                    printOS("Trash Error: Could not restore files.")
                }
            }
            undoManager.setActionName("Delete File")

            finalStatus = true
        } else {
//            printOS("Trash Error: \(isCLI ? "Could not run commands directly with sudo." : "Could not perform privileged commands.")")
            updateOnMain {
                AppState.shared.trashError = true
            }
            finalStatus = false
        }

        dispatchSemaphore.signal()

        dispatchSemaphore.wait()
        return finalStatus
    }

    func restoreFiles(filePairs: [(trashURL: URL, originalURL: URL)], isCLI: Bool = false) -> Bool {
        let dispatchSemaphore = DispatchSemaphore(value: 0)
        var finalStatus = true

        let hasProtectedFiles = filePairs.contains {
            $0.originalURL.deletingLastPathComponent().isProtected
        }

        let commands = filePairs.map {
            let source = "\"\($0.trashURL.path)\""
            let destination = "\"\($0.originalURL.path)\""
            return "/bin/mv \(source) \(destination)"
        }.joined(separator: " ; ")

        if executeFileCommands(commands, isCLI: isCLI, hasProtectedFiles: hasProtectedFiles, isRestore: true) {
            finalStatus = true
        } else {
//            printOS("Trash Error: \(isCLI ? "Failed to run restore CLI commands" : "Failed to run restore privileged commands")")
            updateOnMain {
                AppState.shared.trashError = true
            }
            finalStatus = false
        }

        dispatchSemaphore.signal()
        dispatchSemaphore.wait()
        return finalStatus
    }

    // Helper function to perform shell commands based on available privileges
    private func executeFileCommands(_ commands: String, isCLI: Bool, hasProtectedFiles: Bool, isRestore: Bool = false) -> Bool {
        var status = false

        if HelperToolManager.shared.isHelperToolInstalled {
            printOS(isRestore ? "Attempting restore using helper tool" : "Attempting delete using helper tool")
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
                printOS(isRestore ? "Restore Error: \(output)" : "Trash Error: \(output)")
                updateOnMain {
                    AppState.shared.trashError = true
                }
            }
        } else {
            if isCLI || !hasProtectedFiles {
                printOS(isRestore ? "Attempting restore using direct shell command" : "Attempting delete using direct shell command")
                let result = runDirectShellCommand(command: commands)
                status = result.0
                if !status {
                    printOS(isRestore ? "Restore Error: \(result.1)" : "Trash Error: \(result.1)")
                    updateOnMain {
                        AppState.shared.trashError = true
                    }
                }
            } else {
                printOS(isRestore ? "Attempting restore using authorization services" : "Attempting delete using authorization services")
                let result = performPrivilegedCommands(commands: commands)
                status = result.0
                if !status {
                    printOS(isRestore ? "Restore Error: performPrivilegedCommands failed (\(result.1))" : "Trash Error: performPrivilegedCommands failed (\(result.1))")
                    updateOnMain {
                        AppState.shared.trashError = true
                    }
                }
            }
        }

        return status
    }

    // Helper to run direct non-privileged shell commands
    private func runDirectShellCommand(command: String) -> (Bool, String) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
