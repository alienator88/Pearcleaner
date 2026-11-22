//
//  main.swift
//  PearcleanerHelper
//
//  Created by Alin Lupascu on 3/14/25.
//

import Foundation
import ObjectiveC
import os

private let logger = Logger(subsystem: "com.alienator88.Pearcleaner", category: "privileged-helper")

@objc(HelperToolProtocol)
public protocol HelperToolProtocol {
    func runCommand(command: String, withReply reply: @escaping (Bool, String) -> Void)
    func runThinning(atPath: String, withReply reply: @escaping (Bool, String) -> Void)
    func runBundleThinning(bundlePath: String, withReply reply: @escaping (Bool, String, [String: UInt64]) -> Void)
}

// XPC Communication setup
class HelperToolDelegate: NSObject, NSXPCListenerDelegate, HelperToolProtocol {
    private var activeConnections = Set<NSXPCConnection>()
    private let connectionLock = NSLock()
    // Serial queue so overlapping thinning requests cannot interleave writes
    // to the same bundle.
    private let thinningQueue = HelperOperationSerialiser()
    
    // Accept new XPC connections by setting up the exported interface and object.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard isValidClient(connection: newConnection) else {
            logger.error("Rejected connection from unauthorized client")
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: HelperToolProtocol.self)
        newConnection.exportedObject = self
        newConnection.invalidationHandler = { [weak self] in
            guard let self = self else { return }
            self.connectionLock.lock()
            self.activeConnections.remove(newConnection)
            let connectionsEmpty = self.activeConnections.isEmpty
            self.connectionLock.unlock()
            if connectionsEmpty {
                exit(0) // Exit when no active connections remain
            }
            logger.info("Helper client connection invalidated")
        }
        connectionLock.lock()
        activeConnections.insert(newConnection)
        connectionLock.unlock()
        newConnection.resume()
        return true
    }
    
    // Execute the shell command and reply with output.
    func runCommand(command: String, withReply reply: @escaping (Bool, String) -> Void) {
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
    
    // Execute app lipo using privileges for apps owned by root.
    // The path is pinned by PrivilegedBundleThinner: only direct children of
    // /Applications that are root-owned .app bundles can be touched.
    func runThinning(atPath: String, withReply reply: @escaping (Bool, String) -> Void) {
        let success = thinBinaryUsingMachO(executablePath: atPath)
        reply(success, success ? "Success" : "Failed")
    }

    func runBundleThinning(bundlePath: String, withReply reply: @escaping (Bool, String, [String: UInt64]) -> Void) {
        thinningQueue.execute {
            let result = PrivilegedBundleThinner.thin(bundlePath: bundlePath)
            logger.info("Privileged bundle thinning: success=\(result.succeeded, privacy: .public) pre=\(result.preSize) post=\(result.postSize)")
            let sizes: [String: UInt64] = ["pre": result.preSize, "post": result.postSize]
            let message = result.succeeded
                ? "Bundle thinning completed successfully"
                : "Bundle rejected: not a root-owned /Applications .app bundle"
            reply(result.succeeded, message, sizes)
        }
    }

    // Check that the codesigning matches between the main app and the helper app
    private func isValidClient(connection: NSXPCConnection) -> Bool {
        do {
            return try CodesignCheck.codeSigningMatches(pid: connection.processIdentifier)
        } catch {
            logger.error("Helper code signing check failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}

// Set up and start the XPC listener.
let delegate = HelperToolDelegate()
let listener = NSXPCListener(machServiceName: "com.alienator88.Pearcleaner.PearcleanerHelper")
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
