//
//  Lipo.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/10/25.
//

import Foundation


// Helper structs for Mach-O parsing
public struct FatHeader {
    public let magic: UInt32
    public let numArchitectures: UInt32
    
    public init(magic: UInt32, numArchitectures: UInt32) {
        self.magic = magic
        self.numArchitectures = numArchitectures
    }
}

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

// Function to thin an entire app bundle with size tracking
public func thinAppBundle(at bundlePath: URL, dryRun: Bool = false) -> (Bool, [String: UInt64]?) {
    // Get the total bundle size before thinning
    let preTotalSize = UInt64(totalSizeOnDisk(for: bundlePath).logical)
    
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
            let postTotalSize = UInt64(totalSizeOnDisk(for: bundlePath).logical)
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
    var skippedFiles: [String] = []
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
    let batchSize = 50
    for batchStart in stride(from: 0, to: candidateFiles.count, by: batchSize) {
        autoreleasepool {
            let batchEnd = min(batchStart + batchSize, candidateFiles.count)
            let batch = Array(candidateFiles[batchStart..<batchEnd])

            for fileURL in batch {
                autoreleasepool {
                    if shouldThinFile(fileURL) {
                        // Get file size before thinning
                        if let preAttributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                           let preSize = preAttributes[.size] as? UInt64 {

                            if dryRun {
                                // For dry run, calculate potential savings without modifying files
                                do {
                                    if let sizes = try getArchitectureSliceSizes(from: fileURL.path) {
                                        totalPreSize += preSize
#if arch(arm64)
                                        let removedSize = UInt64(sizes.intel)
#else
                                        let removedSize = UInt64(sizes.arm)
#endif
                                        let estimatedPostSize = preSize > removedSize ? preSize - removedSize : preSize
                                        totalPostSize += estimatedPostSize
                                        processedFiles.append(fileURL.path)
                                    } else {
                                        skippedFiles.append(fileURL.path)
                                    }
                                } catch {
                                    skippedFiles.append(fileURL.path)
                                }
                            } else {
                                // Real thinning
                                if thinBinaryUsingMachO(executablePath: fileURL.path) {
                                    // Get file size after thinning
                                    if let postAttributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                                       let postSize = postAttributes[.size] as? UInt64 {
                                        totalPreSize += preSize
                                        totalPostSize += postSize
                                    }
                                    processedFiles.append(fileURL.path)
                                } else {
                                    skippedFiles.append(fileURL.path)
                                }
                            }
                        } else {
                            skippedFiles.append(fileURL.path)
                        }
                    }
                }
            }
        }
    }

    let success = processedFiles.count > 0 || (processedFiles.count == 0 && skippedFiles.count >= 0)
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

// Determine if a file should be thinned
func shouldThinFile(_ url: URL) -> Bool {
    // Check if it's an executable binary
    return isExecutableBinary(url)
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

// Check if a file is an executable binary
public func isExecutableBinary(_ url: URL) -> Bool {
    // First check file extension for known binary types
    let pathExtension = url.pathExtension.lowercased()
    let knownBinaryExtensions = ["dylib", "so", "bundle"]

    // If it's a known binary extension, assume it's a binary (faster than reading file)
    if knownBinaryExtensions.contains(pathExtension) {
        return true
    }

    // Special handling for bundle structures that might contain binaries
    // (.appex, .xpc, .framework are bundles, but we want to check their executables inside)
    let bundleExtensions = ["appex", "xpc", "framework"]
    if bundleExtensions.contains(pathExtension) {
        // These are bundles - the enumerator will traverse into them
        // and find the actual executable inside
        return false
    }

    // For other files, check magic numbers - use FileHandle to read only 4 bytes
    guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
        return false
    }

    defer {
        try? fileHandle.close()
    }

    guard let magicData = try? fileHandle.read(upToCount: 4), magicData.count == 4 else {
        return false
    }

    let magic = magicData.withUnsafeBytes { $0.load(as: UInt32.self) }
    let FAT_MAGIC: UInt32 = 0xcafebabe
    let FAT_MAGIC_SWAPPED: UInt32 = 0xbebafeca // Little-endian version
    let MH_MAGIC_64: UInt32 = 0xfeedfacf
    let MH_CIGAM_64: UInt32 = 0xcffaedfe
    let MH_MAGIC: UInt32 = 0xfeedface
    let MH_CIGAM: UInt32 = 0xcefaedfe

    return magic == FAT_MAGIC || magic == FAT_MAGIC_SWAPPED ||
           magic == MH_MAGIC_64 || magic == MH_CIGAM_64 ||
           magic == MH_MAGIC || magic == MH_CIGAM
}

// Helper function to thin a binary using Mach-O APIs
public func thinBinaryUsingMachO(executablePath: String) -> Bool {
    // Determine the target architecture based on the current OS
    var targetArch: String
#if arch(arm64)
    targetArch = "arm64"
#else
    targetArch = "x86_64"
#endif

    // Find the app bundle path by searching up the directory tree
    let executableURL = URL(fileURLWithPath: executablePath)
    let appBundlePath = findAppBundlePath(from: executableURL)

    return autoreleasepool {
        do {
            // Use FileHandle instead of loading entire file into memory
            guard let fileHandle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: executablePath)) else {
                return false
            }
            defer {
                try? fileHandle.close()
            }

            // Read just the header to check if it's a fat binary
            guard let headerData = try? fileHandle.read(upToCount: 8), headerData.count == 8 else {
                return false
            }

            let FAT_MAGIC: UInt32 = 0xcafebabe
            let fatHeader = headerData.withUnsafeBytes { ptr in
                FatHeader(
                    magic: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                    numArchitectures: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian
                )
            }

            guard fatHeader.magic == FAT_MAGIC else {
    //            printOS("Mach-O Error: Not a universal binary, skipping thinning.")
                return false
            }

            var offset = 8
            var foundArch: FatArch?

            for _ in 0..<fatHeader.numArchitectures {
                guard let archData = try? fileHandle.read(upToCount: 20), archData.count == 20 else {
                    return false
                }

                let arch = archData.withUnsafeBytes { ptr in
                    FatArch(
                        cpuType: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                        cpuSubtype: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian,
                        offset: ptr.load(fromByteOffset: 8, as: UInt32.self).bigEndian,
                        size: ptr.load(fromByteOffset: 12, as: UInt32.self).bigEndian,
                        align: ptr.load(fromByteOffset: 16, as: UInt32.self).bigEndian
                    )
                }

                let cpuType = arch.cpuType
                if (targetArch == "arm64" && cpuType == 0x100000C) || (targetArch == "x86_64" && cpuType == 0x01000007) {
                    foundArch = arch
                    break
                }

                offset += 20
            }

            guard let targetArchData = foundArch else {
    //            printOS("Mach-O Error: Target architecture \(targetArch) not found in binary.")
                return false
            }

            // Now read the entire file to extract the target slice
            // We need to do this to get the complete architecture slice
            try? fileHandle.seek(toOffset: 0)
            guard let fileData = try? fileHandle.readToEnd() else {
                return false
            }

            let extractedData = fileData.subdata(in: Int(targetArchData.offset)..<Int(targetArchData.offset + targetArchData.size))
            try extractedData.write(to: URL(fileURLWithPath: executablePath))

            // Update file timestamp to refresh Finder bundle size right away
            if !appBundlePath.path.isEmpty && appBundlePath.path != "/" {
                try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: appBundlePath.path)
            }

            return true

        } catch {
            print("Mach-O Error: \(error)")
            return false
        }
    }
}

// Get the size of different architecture slices in a Mach-O binary
public func getArchitectureSliceSizes(from executablePath: String) throws -> (arm: UInt32, intel: UInt32, full: UInt32)? {
    guard !executablePath.isEmpty else {
        throw NSError(domain: "LipoError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty executable path"])
    }

    return try autoreleasepool {
        let fileURL = URL(fileURLWithPath: executablePath)

        // Use FileHandle to read only necessary bytes
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            throw NSError(domain: "LipoError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not open file"])
        }
        defer {
            try? fileHandle.close()
        }

        // Get file size efficiently using FileHandle
        let fileSize = fileHandle.seekToEndOfFile()
        let fullSize = UInt32(min(fileSize, UInt64(UInt32.max)))

        // Seek back to beginning to read header
        try fileHandle.seek(toOffset: 0)

        guard let headerData = try? fileHandle.read(upToCount: 8), headerData.count >= 8 else {
            throw NSError(domain: "LipoError", code: 3, userInfo: [NSLocalizedDescriptionKey: "File too small to contain valid header"])
        }

        let FAT_MAGIC: UInt32 = 0xcafebabe

        let header = try headerData.withUnsafeBytes { ptr -> FatHeader in
            guard ptr.count >= 8 else {
                throw NSError(domain: "LipoError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Insufficient data for header"])
            }
            return FatHeader(
                magic: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                numArchitectures: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian
            )
        }

        var armSize: UInt32 = 0
        var intelSize: UInt32 = 0

        if header.magic == FAT_MAGIC {
            guard header.numArchitectures > 0 && header.numArchitectures < 100 else {
                throw NSError(domain: "LipoError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid number of architectures"])
            }

            // Read all architecture headers at once (20 bytes each)
            let archDataSize = Int(header.numArchitectures) * 20
            guard let allArchData = try? fileHandle.read(upToCount: archDataSize),
                  allArchData.count == archDataSize else {
                throw NSError(domain: "LipoError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not read architecture headers"])
            }

            var offset = 0
            for _ in 0..<header.numArchitectures {
                let arch = allArchData[offset..<(offset + 20)].withUnsafeBytes { ptr -> FatArch in
                    FatArch(
                        cpuType: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                        cpuSubtype: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian,
                        offset: ptr.load(fromByteOffset: 8, as: UInt32.self).bigEndian,
                        size: ptr.load(fromByteOffset: 12, as: UInt32.self).bigEndian,
                        align: ptr.load(fromByteOffset: 16, as: UInt32.self).bigEndian
                    )
                }

                if arch.cpuType == 0x100000C {
                    armSize = arch.size
                } else if arch.cpuType == 0x01000007 {
                    intelSize = arch.size
                }
                offset += 20
            }
        } else {
            // For a lipo'd binary, assume the whole file is the slice.
            // Read bytes 4-8 to check CPU type
            try? fileHandle.seek(toOffset: 4)
            guard let cpuTypeData = try? fileHandle.read(upToCount: 4), cpuTypeData.count == 4 else {
                return (arm: 0, intel: 0, full: fullSize)
            }

            let cpuType = cpuTypeData.withUnsafeBytes {
                $0.load(as: UInt32.self).bigEndian
            }
            if cpuType == 0x100000C {
                armSize = fullSize
            } else if cpuType == 0x01000007 {
                intelSize = fullSize
            }
        }

        return (arm: armSize, intel: intelSize, full: fullSize)
    }
}



// Get size of files
public func totalSizeOnDisk(for paths: [URL]) -> (real: Int64, logical: Int64) {
    let fileManager = FileManager.default
    var totalAllocatedSize: Int64 = 0
    var totalFileSize: Int64 = 0

    for url in paths {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileSizeKey]
            if isDirectory.boolValue {
                // It's a directory, recurse into it
                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, errorHandler: nil) {
                    for case let fileURL as URL in enumerator {
                        do {
                            let fileAttributes = try fileURL.resourceValues(forKeys: Set(keys))
                            if let allocatedSize = fileAttributes.totalFileAllocatedSize {
                                totalAllocatedSize += Int64(allocatedSize)
                            }
                            if let fileSize = fileAttributes.fileSize {
                                totalFileSize += Int64(fileSize)
                            }
                        } catch {
                            print("Error getting file attributes for \(fileURL): \(error)")
                        }
                    }
                }
            } else {
                // It's a file
                do {
                    let fileAttributes = try url.resourceValues(forKeys: Set(keys))
                    if let allocatedSize = fileAttributes.totalFileAllocatedSize {
                        totalAllocatedSize += Int64(allocatedSize)
                    }
                    if let fileSize = fileAttributes.fileSize {
                        totalFileSize += Int64(fileSize)
                    }
                } catch {
                    print("Error getting file attributes for \(url): \(error)")
                }
            }
        }
    }

    return (real: totalAllocatedSize, logical: totalFileSize)
}



public func totalSizeOnDisk(for path: URL) -> (real: Int64, logical: Int64) {
    return totalSizeOnDisk(for: [path])
}
