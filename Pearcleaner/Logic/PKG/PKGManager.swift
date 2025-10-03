//
//  PKGManager.swift
//  Pearcleaner
//
//  Wrapper for Apple's private PackageKit framework APIs
//

import Foundation
import AlinFoundation

@available(macOS 10.5, *)
class PKGManager {

    // MARK: - Package Enumeration

    /// Get all installed packages on a volume
    /// - Parameter volume: Volume path (default: "/")
    /// - Returns: Array of PKReceipt objects
    static func getAllPackages(volume: String = "/") -> [PKReceipt] {
        guard let receipts = PKReceipt.receiptsOnVolume(atPath: volume) as? [PKReceipt] else {
            return []
        }
        return receipts
    }

    // MARK: - Package Information

    /// Extract package information from a PKReceipt
    /// - Parameter receipt: PKReceipt object
    /// - Returns: Structured PackageInfo object
    static func getPackageInfo(from receipt: PKReceipt) -> PackageInfo? {
        guard let packageId = receipt.packageIdentifier() as? String else {
            return nil
        }

        let packageName = ""
        let packageFileName = (receipt._packageName() as? String) ?? ""
        let version = (receipt.packageVersion() as? String) ?? ""
        let installDate = formatInstallDate(receipt.installDate())
        let installLocation = (receipt.installPrefixPath() as? String) ?? "/"
        let installProcessName = (receipt.installProcessName() as? String) ?? ""

        // Get package groups (e.g., com.apple.group.documentation)
        let packageGroups = (receipt.packageGroups() as? [String]) ?? []

        // Get additional info string if available
        let additionalInfo = (receipt.additionalInfo() as? String) ?? ""

        // Check if package is secure/signed
        let isSecure = receipt._isSecure()

        // Get all receipt storage paths
        let receiptStoragePaths = (receipt.receiptStoragePaths() as? [String]) ?? []

        // Get receipt path (main plist file)
        let receiptPath = receiptStoragePaths.first(where: { $0.hasSuffix(".plist") })
            ?? "/var/db/receipts/\(packageId).plist"

        // Get BOM info if available
        var totalSizeFromBOM: Int64 = 0
        var totalFilesInBOM: Int = 0

        if let bomInfo = getBOMInfo(for: receipt) {
            totalSizeFromBOM = bomInfo.totalSize
            totalFilesInBOM = bomInfo.fileCount
        }

        return PackageInfo(
            packageId: packageId,
            packageName: packageName,
            packageFileName: packageFileName,
            version: version,
            installDate: installDate,
            installProcessName: installProcessName,
            bomFiles: [],
            receiptPath: receiptPath,
            installLocation: installLocation,
            bomFilesLoaded: false,
            packageGroups: packageGroups,
            additionalInfo: additionalInfo,
            isSecure: isSecure,
            receiptStoragePaths: receiptStoragePaths,
            totalSizeFromBOM: totalSizeFromBOM,
            totalFilesInBOM: totalFilesInBOM
        )
    }

    // MARK: - BOM Operations

    /// Get BOM statistics (size and file count)
    /// - Parameter receipt: PKReceipt object
    /// - Returns: Tuple with total size and file count, or nil if BOM not available
    static func getBOMInfo(for receipt: PKReceipt) -> (totalSize: Int64, fileCount: Int)? {
        guard let bomPath = findBOMPath(for: receipt) else {
            return nil
        }

        guard let bom = PKBOM(bomPath: bomPath) else {
            return nil
        }

        let totalSize = Int64(bom.totalSize())
        let fileCount = Int(bom.fileCount())

        return (totalSize, fileCount)
    }

    /// Get all files from package BOM
    /// - Parameters:
    ///   - receipt: PKReceipt object
    ///   - installLocation: Install prefix path
    /// - Returns: Array of absolute file paths
    static func getPackageFiles(receipt: PKReceipt, installLocation: String) -> [String] {
        guard let enumerator = receipt._directoryEnumerator() as? NSEnumerator else {
            return []
        }

        var files: [String] = []
        let prefixPath = installLocation.hasSuffix("/") ? installLocation : installLocation + "/"

        while let path = enumerator.nextObject() as? String {
            // Build absolute path
            let absolutePath: String
            if path.hasPrefix("/") {
                absolutePath = path
            } else {
                absolutePath = prefixPath + path
            }

            // Filter out Apple resource fork files
            if !absolutePath.contains("._") {
                files.append(absolutePath)
            }
        }

        return files
    }

    /// Find BOM file path for a receipt
    /// - Parameter receipt: PKReceipt object
    /// - Returns: BOM file path or nil if not found
    private static func findBOMPath(for receipt: PKReceipt) -> String? {
        guard let receiptPaths = receipt.receiptStoragePaths() as? [String] else {
            return nil
        }

        // Find .bom file in receipt storage paths
        return receiptPaths.first(where: { $0.hasSuffix(".bom") })
    }

    // MARK: - Package Removal

    /// Get all receipt file paths that need to be deleted to forget a package
    /// - Parameter receipt: PKReceipt object
    /// - Returns: Array of file paths to delete
    static func getReceiptFilePaths(for receipt: PKReceipt) -> [String] {
        return (receipt.receiptStoragePaths() as? [String]) ?? []
    }

    // MARK: - Helpers

    /// Format install date from PKReceipt
    /// - Parameter date: Date object from receipt
    /// - Returns: Formatted date string or Unix timestamp
    private static func formatInstallDate(_ date: Any?) -> String {
        if let date = date as? Date {
            return String(Int(date.timeIntervalSince1970))
        }
        return ""
    }

    /// Check if a package is secure/signed
    /// - Parameter receipt: PKReceipt object
    /// - Returns: True if package is secure
    static func isPackageSecure(receipt: PKReceipt) -> Bool {
        return receipt._isSecure()
    }

    /// Get package groups
    /// - Parameter receipt: PKReceipt object
    /// - Returns: Array of group identifiers
    static func getPackageGroups(receipt: PKReceipt) -> [String] {
        return (receipt.packageGroups() as? [String]) ?? []
    }
}
