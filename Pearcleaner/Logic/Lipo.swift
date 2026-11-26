//
//  Lipo.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/10/25.
//

import Foundation


// Helper structs for Mach-O parsing
public struct FatArch {
    public let cpuType: UInt32
    public let cpuSubtype: UInt32
    public let offset: UInt32
    public let size: UInt32
    public let align: UInt32
    
    public init(cpuType: UInt32, cpuSubtype: UInt32, offset: UInt32, size: UInt32, align: UInt32) {
        self.cpuType = cpuType
        self.cpuSubtype = cpuSubtype
        self.offset = offset
        self.size = size
        self.align = align
    }
}

// MARK: - Mach-O inspection

private let machoCPUTypeX86: UInt32 = 7
private let machoCPUTypeX8664: UInt32 = 0x0100_0007
private let machoCPUTypeARM: UInt32 = 12
private let machoCPUTypeARM64: UInt32 = 0x0100_000C

/// One architecture slice of a Mach-O file.
struct MachOSliceInfo {
    let cpuType: UInt32
    let cpuSubtype: UInt32
    let offset: UInt64
    let size: UInt64
}

/// Result of inspecting a file for Mach-O content. Both thin and fat binaries
/// are represented as a list of slices, so callers do not have to special-case
/// byte order or 32/64-bit fat headers.
struct MachOInfo {
    let isFat: Bool
    let slices: [MachOSliceInfo]
    let fileSize: UInt64

    /// Bytes that can be removed on the current machine: every slice that is
    /// not the architecture the host CPU runs. A thin binary has no savings.
    func removableBytes(forHostCPU hostCPU: UInt32) -> UInt64 {
        guard isFat, slices.count > 1 else { return 0 }
        return slices.reduce(0) { total, slice in
            slice.cpuType == hostCPU ? total : total + slice.size
        }
    }
}

func machoHostCPUType() -> UInt32 {
#if arch(arm64)
    return machoCPUTypeARM64
#else
    return machoCPUTypeX8664
#endif
}

private func machoReadUInt32(_ bytes: [UInt8], at offset: Int, bigEndian: Bool) -> UInt32? {
    guard offset >= 0, offset + 4 <= bytes.count else { return nil }
    let b0 = UInt32(bytes[offset])
    let b1 = UInt32(bytes[offset + 1])
    let b2 = UInt32(bytes[offset + 2])
    let b3 = UInt32(bytes[offset + 3])
    if bigEndian {
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }
    return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
}

private func machoReadUInt64(_ bytes: [UInt8], at offset: Int, bigEndian: Bool) -> UInt64? {
    guard offset >= 0, offset + 8 <= bytes.count else { return nil }
    let parts = (0..<8).map { UInt64(bytes[offset + $0]) }
    if bigEndian {
        return parts.reduce(0) { ($0 << 8) | $1 }
    }
    return parts.reversed().reduce(0) { ($0 << 8) | $1 }
}

/// Reads the Mach-O headers of a file without loading the whole file. Returns
/// nil for anything that is not a valid thin or fat Mach-O binary, which makes
/// this safe to call for every file in an app bundle.
func inspectMachO(at url: URL) -> MachOInfo? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }

    let fileSize = handle.seekToEndOfFile()
    guard fileSize >= 8 else { return nil }

    try? handle.seek(toOffset: 0)
    guard let headerData = try? handle.read(upToCount: 8), headerData.count == 8 else {
        return nil
    }
    let header = [UInt8](headerData)

    // Fat headers are always written big-endian, but accept the byte-swapped
    // variants as well. 64-bit fat headers use 32-byte entries.
    let fat32Big = header[0] == 0xCA && header[1] == 0xFE && header[2] == 0xBA && header[3] == 0xBE
    let fat32Little = header[0] == 0xBE && header[1] == 0xBA && header[2] == 0xFE && header[3] == 0xCA
    let fat64Big = header[0] == 0xCA && header[1] == 0xFE && header[2] == 0xBA && header[3] == 0xBF
    let fat64Little = header[0] == 0xBF && header[1] == 0xBA && header[2] == 0xFE && header[3] == 0xCA

    if fat32Big || fat32Little || fat64Big || fat64Little {
        let isFat64 = fat64Big || fat64Little
        let bigEndian = fat32Big || fat64Big

        guard let count = machoReadUInt32(header, at: 4, bigEndian: bigEndian),
              count > 0, count < 100 else {
            return nil
        }

        let entrySize = isFat64 ? 32 : 20
        let tableSize = Int(count) * entrySize
        try? handle.seek(toOffset: 8)
        guard let tableData = try? handle.read(upToCount: tableSize),
              tableData.count == tableSize else {
            return nil
        }
        let table = [UInt8](tableData)

        var slices: [MachOSliceInfo] = []
        slices.reserveCapacity(Int(count))

        for index in 0..<Int(count) {
            let base = index * entrySize
            guard let cpuType = machoReadUInt32(table, at: base, bigEndian: bigEndian),
                  let cpuSubtype = machoReadUInt32(table, at: base + 4, bigEndian: bigEndian) else {
                continue
            }

            let offset: UInt64
            let size: UInt64
            if isFat64 {
                guard let parsedOffset = machoReadUInt64(table, at: base + 8, bigEndian: bigEndian),
                      let parsedSize = machoReadUInt64(table, at: base + 16, bigEndian: bigEndian) else {
                    continue
                }
                offset = parsedOffset
                size = parsedSize
            } else {
                guard let parsedOffset = machoReadUInt32(table, at: base + 8, bigEndian: bigEndian),
                      let parsedSize = machoReadUInt32(table, at: base + 12, bigEndian: bigEndian) else {
                    continue
                }
                offset = UInt64(parsedOffset)
                size = UInt64(parsedSize)
            }

            // Ignore slices that point outside the file. Malformed headers
            // should not make an app look lipoable.
            guard size > 0, offset < fileSize else { continue }
            slices.append(
                MachOSliceInfo(
                    cpuType: cpuType,
                    cpuSubtype: cpuSubtype,
                    offset: offset,
                    size: min(size, fileSize - offset)
                ))
        }

        guard !slices.isEmpty else { return nil }
        return MachOInfo(isFat: true, slices: slices, fileSize: fileSize)
    }

    // Thin Mach-O files. The magic tells us the byte order of the header.
    let thin64Little = header[0] == 0xCF && header[1] == 0xFA && header[2] == 0xED && header[3] == 0xFE
    let thin64Big = header[0] == 0xFE && header[1] == 0xED && header[2] == 0xFA && header[3] == 0xCF
    let thin32Little = header[0] == 0xCE && header[1] == 0xFA && header[2] == 0xED && header[3] == 0xFE
    let thin32Big = header[0] == 0xFE && header[1] == 0xED && header[2] == 0xFA && header[3] == 0xCE

    guard thin64Little || thin64Big || thin32Little || thin32Big else { return nil }

    let bigEndian = thin64Big || thin32Big
    guard let cpuType = machoReadUInt32(header, at: 4, bigEndian: bigEndian) else {
        return nil
    }

    let isFat = false
    return MachOInfo(
        isFat: isFat,
        slices: [
            MachOSliceInfo(
                cpuType: cpuType,
                cpuSubtype: 0,
                offset: 0,
                size: fileSize
            )
        ],
        fileSize: fileSize
    )
}

// Function to thin an entire app bundle with size tracking
public func thinAppBundle(at bundlePath: URL, dryRun: Bool = false) -> (Bool, [String: UInt64]?) {
    // Get the total bundle size before thinning
    let preTotalSize = UInt64(totalSizeOnDisk(for: bundlePath))
    
    let result = recursivelyThinBundle(at: bundlePath, dryRun: dryRun)
    
    if result.success {
        if dryRun {
            // For dry run, calculate estimated post-size based on binary savings
            let binarySavings = result.sizes?["binarySavings"] ?? 0
            let estimatedPostSize = preTotalSize > binarySavings ? preTotalSize - binarySavings : preTotalSize
            let sizes = ["pre": preTotalSize, "post": estimatedPostSize]
            return (true, sizes)
        } else {
            // For real thinning, get the actual bundle size after thinning
            let postTotalSize = UInt64(totalSizeOnDisk(for: bundlePath))
            let sizes = ["pre": preTotalSize, "post": postTotalSize]
            return (true, sizes)
        }
    } else {
        return (result.success, result.sizes)
    }
}

// Recursively thin all binaries in a bundle
func recursivelyThinBundle(at path: URL, dryRun: Bool = false) -> (success: Bool, sizes: [String: UInt64]?) {
    let fileManager = FileManager.default

    guard let enumerator = fileManager.enumerator(at: path,
                                                  includingPropertiesForKeys: [.isDirectoryKey, .isExecutableKey],
                                                  options: [.skipsHiddenFiles]) else {
        print("Bundle Error: Could not enumerate bundle contents")
        return (false, nil)
    }

    var processedFiles: [String] = []
    var totalPreSize: UInt64 = 0
    var totalPostSize: UInt64 = 0

    // Collect all file URLs first to avoid keeping enumerator handles open
    var candidateFiles: [URL] = []
    autoreleasepool {
        for case let fileURL as URL in enumerator {
            autoreleasepool {
                // Skip directories early
                let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues?.isDirectory == true {
                    return
                }
                candidateFiles.append(fileURL)
            }
        }
    }

    // Process files in batches to limit memory and file descriptor usage
    let hostCPU = machoHostCPUType()
    let batchSize = 50
    for batchStart in stride(from: 0, to: candidateFiles.count, by: batchSize) {
        autoreleasepool {
            let batchEnd = min(batchStart + batchSize, candidateFiles.count)
            let batch = Array(candidateFiles[batchStart..<batchEnd])

            for fileURL in batch {
                autoreleasepool {
                    // Parse the Mach-O header once. Files that are not Mach-O,
                    // or that only contain the architecture we are running,
                    // cannot be thinned.
                    guard let info = inspectMachO(at: fileURL) else { return }
                    let removableSize = info.removableBytes(forHostCPU: hostCPU)
                    guard removableSize > 0 else { return }

                    let preSize = info.fileSize

                    if dryRun {
                        // Calculate potential savings without modifying files.
                        let postSize = preSize > removableSize ? preSize - removableSize : 0
                        totalPreSize += preSize
                        totalPostSize += postSize
                        processedFiles.append(fileURL.path)
                    } else {
                        // Real thinning
                        if thinBinaryUsingMachO(executablePath: fileURL.path) {
                            let postSize =
                                (try? fileManager.attributesOfItem(atPath: fileURL.path))?[.size]
                                as? UInt64
                                ?? (preSize > removableSize ? preSize - removableSize : 0)
                            totalPreSize += preSize
                            totalPostSize += postSize
                            processedFiles.append(fileURL.path)
                        }
                    }
                }
            }
        }
    }

    // Only report success when at least one binary actually had an architecture
    // to remove. Previously this was always true, which made apps that were
    // already lipo'd (or never lipoable) look like valid candidates.
    let success = !processedFiles.isEmpty
    var sizes: [String: UInt64]? = nil

    if totalPreSize > 0 {
        if dryRun {
            // For dry run, include the binary savings calculation
            let binarySavings = totalPreSize > totalPostSize ? totalPreSize - totalPostSize : 0
            sizes = ["pre": totalPreSize, "post": totalPostSize, "binarySavings": binarySavings]
        } else {
            // For real thinning, just include pre/post
            sizes = ["pre": totalPreSize, "post": totalPostSize]
        }
    }

    return (success, sizes)
}

// Find the app bundle path by traversing up the directory tree
func findAppBundlePath(from url: URL) -> URL {
    var currentURL = url
    
    // Keep going up until we find a .app bundle or reach the root
    while currentURL.path != "/" {
        if currentURL.pathExtension == "app" {
            return currentURL
        }
        currentURL = currentURL.deletingLastPathComponent()
    }
    
    // Fallback: assume it's a traditional app bundle structure
    var fallbackURL = url
    while fallbackURL.path != "/" && !fallbackURL.path.hasSuffix(".app") {
        fallbackURL = fallbackURL.deletingLastPathComponent()
    }
    
    return fallbackURL
}

// Check if a file is a Mach-O executable binary (thin or universal)
public func isExecutableBinary(_ url: URL) -> Bool {
    inspectMachO(at: url) != nil
}

// Helper function to thin a binary using Mach-O APIs
public func thinBinaryUsingMachO(executablePath: String) -> Bool {
    // Determine the target architecture based on the current OS
    let targetCPU = machoHostCPUType()

    // Find the app bundle path by searching up the directory tree
    let executableURL = URL(fileURLWithPath: executablePath)
    let appBundlePath = findAppBundlePath(from: executableURL)

    return autoreleasepool {
        guard let info = inspectMachO(at: executableURL), info.isFat,
              let targetSlice = info.slices.first(where: { $0.cpuType == targetCPU }) else {
            return false
        }

        do {
            let fileHandle = try FileHandle(forReadingFrom: executableURL)
            defer { try? fileHandle.close() }

            try fileHandle.seek(toOffset: targetSlice.offset)
            guard let extractedData = try fileHandle.read(upToCount: Int(targetSlice.size)),
                  extractedData.count == Int(targetSlice.size) else {
                return false
            }

            // Overwrite in place so ownership and permissions are preserved.
            try extractedData.write(to: executableURL)

            // Update file timestamp to refresh Finder bundle size right away
            if !appBundlePath.path.isEmpty && appBundlePath.path != "/" {
                try? FileManager.default.setAttributes(
                    [.modificationDate: Date()], ofItemAtPath: appBundlePath.path)
            }

            return true
        } catch {
            print("Mach-O Error: \(error)")
            return false
        }
    }
}

// Get the size of different architecture slices in a Mach-O binary
public func getArchitectureSliceSizes(from executablePath: String) throws -> (
    arm: UInt32, intel: UInt32, full: UInt32
)? {
    guard !executablePath.isEmpty else {
        throw NSError(
            domain: "LipoError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Empty executable path"])
    }

    guard let info = inspectMachO(at: URL(fileURLWithPath: executablePath)) else {
        throw NSError(
            domain: "LipoError", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Not a Mach-O binary"])
    }

    let armSize = info.slices
        .filter { $0.cpuType == machoCPUTypeARM64 }
        .reduce(UInt64(0)) { $0 + $1.size }
    let intelSize = info.slices
        .filter { $0.cpuType == machoCPUTypeX8664 || $0.cpuType == machoCPUTypeX86 }
        .reduce(UInt64(0)) { $0 + $1.size }
    let fullSize = min(info.fileSize, UInt64(UInt32.max))

    return (
        arm: UInt32(clamping: armSize),
        intel: UInt32(clamping: intelSize),
        full: UInt32(clamping: fullSize)
    )
}



// Get size of files (logical size - matches Finder)
public func totalSizeOnDisk(for paths: [URL]) -> Int64 {
    let fileManager = FileManager.default
    var totalFileSize: Int64 = 0

    for url in paths {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            let keys: [URLResourceKey] = [.fileSizeKey]
            if isDirectory.boolValue {

                //MARK: Directory Size
                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, errorHandler: nil) {
                    for case let fileURL as URL in enumerator {
                        do {
                            if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                                totalFileSize += Int64(size)
                            }
                        }
                    }
                }
            } else {
                //MARK: File Size
                do {
                    if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                        totalFileSize += Int64(size)
                    }
                }
            }
        }
    }

    return totalFileSize
}



public func totalSizeOnDisk(for path: URL) -> Int64 {
    return totalSizeOnDisk(for: [path])
}
