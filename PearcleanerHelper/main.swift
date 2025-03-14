//
//  main.swift
//  PearcleanerHelper
//
//  Created by Alin Lupascu on 3/14/25.
//

import Foundation

@objc(HelperToolProtocol)
public protocol HelperToolProtocol {
    func runCommand(command: String, withReply reply: @escaping (Bool, String) -> Void)
}

// XPC Communication setup
class HelperToolDelegate: NSObject, NSXPCListenerDelegate, HelperToolProtocol {
    private var activeConnections = Set<NSXPCConnection>()
    private var lastActivityTime = Date() // Track last connection timestamp
    private var exitTimer: Timer?

    override init() {
        super.init()
        startExitTimer()
    }

    // Accept new XPC connections by setting up the exported interface and object.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HelperToolProtocol.self)
        newConnection.exportedObject = self
        newConnection.invalidationHandler = { [weak self] in
            self?.activeConnections.remove(newConnection)
            if self?.activeConnections.isEmpty == true {
                exit(0) // Exit when no active connections remain
            }
        }
        activeConnections.insert(newConnection)
        newConnection.resume()
        lastActivityTime = Date()
        return true
    }

    // Execute the shell command and reply with output.
    func runCommand(command: String, withReply reply: @escaping (Bool, String) -> Void) {
        lastActivityTime = Date()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            reply(false, "Failed to run command: \(error.localizedDescription)")
            return
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let success = (process.terminationStatus == 0) // Check if process exited successfully
        reply(success, output.isEmpty ? "No output" : output)
    }

    // Start a timer that periodically checks for inactivity
    private func startExitTimer() {
        exitTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkForExit()
        }
    }

    // Check if 10 seconds have passed since the last activity
    private func checkForExit() {
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)
        if timeSinceLastActivity >= 10 { // No activity for 10 seconds? Exit.
            exit(0)
        }
    }
}

// Set up and start the XPC listener.
let delegate = HelperToolDelegate()
let listener = NSXPCListener(machServiceName: "com.alienator88.Pearcleaner.PearcleanerHelper")
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
