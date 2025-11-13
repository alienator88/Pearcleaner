//
//  IOSAppInstaller.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/12/25.
//

import Foundation
import AppKit
import AlinFoundation

// MARK: - Supporting Types

struct IOSVersionInfo {
    let version: String
    let build: String
    let bundleID: String
}

struct IOSPreservedMetadata {
    let protectedMetadata: Data
    let itemId: Int64?
    let artistName: String?
    let purchaseDate: Date?
    let appleId: String?
    let storefrontCountryCode: String?
    let releaseDate: String?
    let genre: String?
    let rawPlist: [String: Any]  // Keep entire original for safe merge
}

enum IOSAppInstallerError: Error, LocalizedError {
    case noAppBundleFound
    case extractionFailed(String)
    case invalidInfoPlist
    case noExistingInstallation
    case missingProtectedMetadata
    case apiLookupFailed
    case atomicReplacementFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAppBundleFound:
            return "No .app bundle found in IPA Payload"
        case .extractionFailed(let details):
            return "IPA extraction failed: \(details)"
        case .invalidInfoPlist:
            return "Invalid Info.plist in app bundle"
        case .noExistingInstallation:
            return "No existing app installation found"
        case .missingProtectedMetadata:
            return "Missing protectedMetadata in existing installation"
        case .apiLookupFailed:
            return "Failed to fetch app metadata from iTunes API"
        case .atomicReplacementFailed(let details):
            return "Atomic replacement failed: \(details)"
        }
    }
}

// MARK: - IOSAppInstaller

class IOSAppInstaller {

    /// Install or update an iOS app from IPA file
    static func installIOSApp(
        ipaPath: String,
        adamID: UInt64,
        existingAppPath: URL,
        progress: @escaping (Double, String) -> Void
    ) async throws {

        // 1. Extract IPA to temp directory (80-85%)
        progress(0.80, "Installing...")
        let extractedPayload = try await extractIPA(ipaPath: ipaPath, adamID: adamID)

        // 2. Detect wrapped bundle name (NOT hardcoded!)
        let wrappedBundleName = try detectWrappedBundleName(payloadDir: extractedPayload)

        let extractedApp = extractedPayload.appendingPathComponent(wrappedBundleName)

        // 3. Read new version info from extracted app
        let versionInfo = try readVersionInfo(from: extractedApp)

        // 4. Preserve critical metadata from existing installation (85%)
        progress(0.85, "Installing...")
        let preservedData = try preserveExistingMetadata(appPath: existingAppPath)

        // 5. Generate updated metadata files
        let newITunesMetadata = try await generateITunesMetadata(
            adamID: adamID,
            versionInfo: versionInfo,
            preservedData: preservedData
        )
        let newBundleMetadata = try generateBundleMetadata()

        // 6. Build new Wrapper structure in temp
        let newWrapper = try buildWrapperStructure(
            extractedApp: extractedApp,
            iTunesMetadata: newITunesMetadata,
            bundleMetadata: newBundleMetadata,
            adamID: adamID
        )

        // 7. Atomic replacement with root privileges (90%)
        progress(0.90, "Installing...")
        try await performAtomicReplacement(
            existingAppPath: existingAppPath,
            newWrapper: newWrapper,
            wrappedBundleName: wrappedBundleName
        )

        // 8. Cleanup (95%)
        progress(0.95, "Installing...")

        // Remove entire temp directory (includes extracted IPA and hard link)
        let tempDir = "/tmp/pearcleaner-ios-\(adamID)"
        if FileManager.default.fileExists(atPath: tempDir) {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        progress(1.0, "Completed")
    }

    // MARK: - Private Helper Methods

    /// Detect the wrapped bundle name dynamically (e.g., "Runner.app", "DREO.app")
    private static func detectWrappedBundleName(payloadDir: URL) throws -> String {
        let contents = try FileManager.default.contentsOfDirectory(
            at: payloadDir,
            includingPropertiesForKeys: nil
        )

        // Find first .app bundle in Payload directory
        guard let appBundle = contents.first(where: { $0.pathExtension == "app" }) else {
            throw IOSAppInstallerError.noAppBundleFound
        }

        return appBundle.lastPathComponent
    }

    /// Extract IPA to temp directory
    private static func extractIPA(ipaPath: String, adamID: UInt64) async throws -> URL {
        // Clean up any stale temp directories from previous operations
        cleanupPearcleanerTempDirs()

        let extractDir = URL(fileURLWithPath: "/tmp/pearcleaner-ios-\(adamID)/extracted")

        // Create extraction directory
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        // Extract using ditto (handles LZFSE compression)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", ipaPath, extractDir.path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw IOSAppInstallerError.extractionFailed(errorString)
        }

        // Return Payload directory path
        return extractDir.appendingPathComponent("Payload")
    }

    /// Read version info from app bundle
    private static func readVersionInfo(from appPath: URL) throws -> IOSVersionInfo {
        let infoPlistPath = appPath.appendingPathComponent("Info.plist")
        let infoPlistData = try Data(contentsOf: infoPlistPath)
        let plist = try PropertyListSerialization.propertyList(
            from: infoPlistData,
            format: nil
        ) as! [String: Any]

        guard let version = plist["CFBundleShortVersionString"] as? String,
              let build = plist["CFBundleVersion"] as? String,
              let bundleID = plist["CFBundleIdentifier"] as? String else {
            throw IOSAppInstallerError.invalidInfoPlist
        }

        return IOSVersionInfo(version: version, build: build, bundleID: bundleID)
    }

    /// Preserve critical metadata from existing installation
    private static func preserveExistingMetadata(appPath: URL) throws -> IOSPreservedMetadata {
        let metadataPath = appPath
            .appendingPathComponent("Wrapper")
            .appendingPathComponent("iTunesMetadata.plist")

        guard FileManager.default.fileExists(atPath: metadataPath.path) else {
            throw IOSAppInstallerError.noExistingInstallation
        }

        let data = try Data(contentsOf: metadataPath)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as! [String: Any]

        // Extract all fields that must be preserved
        guard let protectedMetadata = plist["protectedMetadata"] as? Data else {
            throw IOSAppInstallerError.missingProtectedMetadata
        }

        return IOSPreservedMetadata(
            protectedMetadata: protectedMetadata,
            itemId: plist["itemId"] as? Int64,
            artistName: plist["artistName"] as? String,
            purchaseDate: plist["purchaseDate"] as? Date,
            appleId: plist["appleId"] as? String,
            storefrontCountryCode: plist["storefrontCountryCode"] as? String,
            releaseDate: plist["releaseDate"] as? String,
            genre: plist["genre"] as? String,
            rawPlist: plist  // Keep entire original for safe merge
        )
    }

    /// Generate updated iTunesMetadata.plist
    private static func generateITunesMetadata(
        adamID: UInt64,
        versionInfo: IOSVersionInfo,
        preservedData: IOSPreservedMetadata
    ) async throws -> [String: Any] {

        // Fetch latest metadata from iTunes API
        let url = URL(string: "https://itunes.apple.com/lookup?id=\(adamID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let results = json["results"] as! [[String: Any]]

        guard let appData = results.first else {
            throw IOSAppInstallerError.apiLookupFailed
        }

        // Start with preserved metadata (keeps ALL original fields)
        var metadata = preservedData.rawPlist

        // Update ONLY version-specific fields
        metadata["bundleShortVersionString"] = versionInfo.version
        metadata["bundleVersion"] = versionInfo.build
        metadata["softwareVersionExternalIdentifier"] = appData["version"]

        // CRITICAL: Ensure protectedMetadata is preserved
        metadata["protectedMetadata"] = preservedData.protectedMetadata

        return metadata
    }

    /// Generate BundleMetadata.plist
    private static func generateBundleMetadata() throws -> [String: Any] {
        let installDate = Date().timeIntervalSinceReferenceDate

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sw_vers")
        process.arguments = ["-buildVersion"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let buildVersion = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "25B78"

        return [
            "installDate": installDate,
            "installBuildVersion": buildVersion,
            "installType": 0,
            "autoInstallOverride": 0
        ]
    }

    /// Build new Wrapper structure in temp directory
    private static func buildWrapperStructure(
        extractedApp: URL,
        iTunesMetadata: [String: Any],
        bundleMetadata: [String: Any],
        adamID: UInt64
    ) throws -> URL {

        let wrapperDir = URL(fileURLWithPath: "/tmp/pearcleaner-ios-\(adamID)/Wrapper")
        try FileManager.default.createDirectory(at: wrapperDir, withIntermediateDirectories: true)

        // Copy extracted app to Wrapper/
        let appName = extractedApp.lastPathComponent
        try FileManager.default.copyItem(
            at: extractedApp,
            to: wrapperDir.appendingPathComponent(appName)
        )

        // Write metadata plists
        let iTunesData = try PropertyListSerialization.data(
            fromPropertyList: iTunesMetadata,
            format: .xml,
            options: 0
        )
        try iTunesData.write(to: wrapperDir.appendingPathComponent("iTunesMetadata.plist"))

        let bundleData = try PropertyListSerialization.data(
            fromPropertyList: bundleMetadata,
            format: .xml,
            options: 0
        )
        try bundleData.write(to: wrapperDir.appendingPathComponent("BundleMetadata.plist"))

        return wrapperDir
    }

    /// Perform atomic replacement using unified privileged command wrapper
    private static func performAtomicReplacement(
        existingAppPath: URL,
        newWrapper: URL,
        wrappedBundleName: String
    ) async throws {

        let oldWrapper = existingAppPath.appendingPathComponent("Wrapper")
        let backupWrapper = URL(fileURLWithPath: "/tmp/pearcleaner-ios-backup-\(UUID().uuidString)")
        let symlinkPath = existingAppPath.appendingPathComponent("WrappedBundle")

        // Script 1: Atomic replacement (all commands chained with &&)
        let installScript = """
        pkill -x '\(wrappedBundleName.replacingOccurrences(of: ".app", with: ""))' 2>/dev/null || true && \
        mv '\(oldWrapper.path)' '\(backupWrapper.path)' && \
        mv '\(newWrapper.path)' '\(oldWrapper.path)' && \
        chown -R root:wheel '\(existingAppPath.path)' && \
        chmod -R 755 '\(existingAppPath.path)' && \
        rm -f '\(symlinkPath.path)' && \
        ln -s 'Wrapper/\(wrappedBundleName)' '\(symlinkPath.path)' && \
        rm -rf '\(backupWrapper.path)'
        """

        let result = try await runSUCommand(
            installScript,
            errorContext: "Failed to install iOS app",
            throwOnFailure: false
        )

        // Script 2: Restore on failure (only runs if Script 1 fails)
        if !result.0 {
            printOS("Atomic replacement failed, attempting to restore backup...")

            if FileManager.default.fileExists(atPath: backupWrapper.path) {
                let restoreScript = "mv '\(backupWrapper.path)' '\(oldWrapper.path)'"
                let _ = try await runSUCommand(
                    restoreScript,
                    errorContext: "Failed to restore backup after failed installation"
                )
            }

            throw IOSAppInstallerError.atomicReplacementFailed(result.1)
        }
    }
}
