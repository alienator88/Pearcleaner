//
//  AppStoreReset.swift
//  Pearcleaner
//
//  Based on mas-cli's reset command
//  Copyright © 2018 mas-cli. All rights reserved.
//  License: MIT
//

import Foundation
import AppKit
import StoreFoundation
import CommerceKit

/// Manages App Store service reset operations
/// Based on mas-cli's Reset.swift implementation
/// Use this when App Store downloads are stuck or broken
class AppStoreReset {

    /// Result of a reset operation
    enum ResetResult {
        case success
        case failure(String)
    }

    /// Resets the App Store by:
    /// 1. Terminating Dock and storeuid processes (handles App Store UI)
    /// 2. Killing Mac App Store system daemons
    /// 3. Deleting download cache directory
    ///
    /// - Returns: ResetResult indicating success or failure with error message
    static func reset() async -> ResetResult {
        // Step 1: Terminate App Store UI processes
        let terminatedApps = terminateAppStoreApps()

        // Step 2: Kill system daemons
        let killedDaemons = await killAppStoreDaemons()

        // Step 3: Delete download cache
        let deletedCache = deleteDownloadCache()

        // Check if all steps succeeded
        if terminatedApps && killedDaemons && deletedCache {
            return .success
        } else {
            var errors: [String] = []
            if !terminatedApps { errors.append("Failed to terminate App Store apps") }
            if !killedDaemons { errors.append("Failed to kill system daemons") }
            if !deletedCache { errors.append("Failed to delete download cache") }
            return .failure(errors.joined(separator: ", "))
        }
    }

    // MARK: - Private Implementation

    /// Terminates Dock and storeuid processes (handles App Store UI)
    private static func terminateAppStoreApps() -> Bool {
        let appNames = ["Dock", "storeuid"]
        var allTerminated = true

        for appName in appNames {
            // Find running instance
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.\(appName)").first else {
                // App not running, skip (not an error)
                continue
            }

            // Terminate app
            if !app.terminate() {
                allTerminated = false
            }
        }

        return allTerminated
    }

    /// Kills Mac App Store system daemons using sysctl + proc_pidpath
    /// This is the low-level approach mas-cli uses (not using NSRunningApplication)
    private static func killAppStoreDaemons() async -> Bool {
        let daemonPaths = [
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Versions/A/Resources/storekitagent",
            "/System/Library/PrivateFrameworks/AppStoreDaemon.framework/Support/appstoreagent",
            "/System/Library/PrivateFrameworks/AppStoreDaemon.framework/Support/appstored",
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Versions/Current/Resources/storekitagent",
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Resources/storekitagent",
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Versions/A/Resources/storeaccountd",
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Versions/Current/Resources/storeaccountd",
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Resources/storeaccountd",
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Versions/A/Resources/storeassetd",
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Versions/Current/Resources/storeassetd",
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Resources/storeassetd",
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Versions/A/Resources/storedownloadd",
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Versions/Current/Resources/storedownloadd",
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Resources/storedownloadd",
            "/System/Library/PrivateFrameworks/AppStoreDaemon.framework/Versions/A/Support/appstorecomponentsd",
            "/System/Library/PrivateFrameworks/AppStoreDaemon.framework/Support/appstorecomponentsd"
        ]

        var allKilled = true

        for daemonPath in daemonPaths {
            // Find PID for daemon path using sysctl
            if let pid = findPID(forExecutablePath: daemonPath) {
                // Kill process
                let result = kill(pid, SIGTERM)
                if result != 0 {
                    allKilled = false
                }
            }
            // If daemon not running, that's fine (not an error)
        }

        return allKilled
    }

    /// Finds the PID for a given executable path using sysctl
    /// This is how mas-cli does it (low-level process enumeration)
    private static func findPID(forExecutablePath targetPath: String) -> pid_t? {
        // Get all process PIDs using sysctl
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var length: size_t = 0

        // Get required buffer size
        if sysctl(&name, u_int(name.count), nil, &length, nil, 0) == -1 {
            return nil
        }

        // Allocate buffer
        let count = length / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)

        // Get process list
        if sysctl(&name, u_int(name.count), &procs, &length, nil, 0) == -1 {
            return nil
        }

        // Iterate through processes
        let actualCount = length / MemoryLayout<kinfo_proc>.stride
        for i in 0..<actualCount {
            let pid = procs[i].kp_proc.p_pid

            // Get executable path for this PID using proc_pidpath
            var pathBuffer = [Int8](repeating: 0, count: Int(MAXPATHLEN))
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))

            if pathLength > 0 {
                let executablePath = String(cString: pathBuffer)
                if executablePath == targetPath {
                    return pid
                }
            }
        }

        return nil
    }

    /// Deletes the App Store download cache using CommerceKit's CKDownloadDirectory()
    private static func deleteDownloadCache() -> Bool {
        // Get download directory from CommerceKit (mas-cli approach)
        let downloadDirPath = CKDownloadDirectory(nil)
        let fileManager = FileManager.default

        // Check if directory exists
        guard fileManager.fileExists(atPath: downloadDirPath) else {
            // Directory doesn't exist, nothing to delete (not an error)
            return true
        }

        // Delete directory
        do {
            try fileManager.removeItem(atPath: downloadDirPath)
            return true
        } catch {
            return false
        }
    }
}
