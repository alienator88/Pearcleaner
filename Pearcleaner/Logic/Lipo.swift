//
//  Lipo.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/10/25.
//

import Foundation
//import AlinFoundation

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
public func thinAppBundle(at bundlePath: URL) -> (Bool, [String: UInt64]?) {
    let result = recursivelyThinBundle(at: bundlePath)
    return (result.success, result.sizes)
}

// Recursively thin all binaries in a bundle
func recursivelyThinBundle(at path: URL) -> (success: Bool, sizes: [String: UInt64]?) {
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
    
    
    for case let fileURL as URL in enumerator {
        // Skip directories early
        let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
        if resourceValues?.isDirectory == true { 
            continue 
        }
        
        if shouldThinFile(fileURL) {
            // Get file size before thinning
            if let preAttributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let preSize = preAttributes[.size] as? UInt64 {
                
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
            } else {
                skippedFiles.append(fileURL.path)
            }
        }
    }
    
    print("Bundle thinning complete:")
    print("  Processed: \(processedFiles.count) files")
    print("  Skipped: \(skippedFiles.count) files")
    
    let success = processedFiles.count > 0 || (processedFiles.count == 0 && skippedFiles.count >= 0)
    let sizes = totalPreSize > 0 ? ["pre": totalPreSize, "post": totalPostSize] : nil
    
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
    
    // For other files, check magic numbers
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { 
        return false 
    }
    
    if data.count < 4 { 
        return false 
    }
    
    let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
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
    
    do {
        let fileData = try Data(contentsOf: URL(fileURLWithPath: executablePath))
        
        // Check if file is a fat binary
        let FAT_MAGIC: UInt32 = 0xcafebabe
        let fatHeader = fileData.subdata(in: 0..<8).withUnsafeBytes { ptr in
            FatHeader(
                magic: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                numArchitectures: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian
            )
        }
        
        guard fatHeader.magic == FAT_MAGIC else {
            print("Mach-O Error: Not a universal binary, skipping thinning.")
            return false
        }
        
        var offset = 8
        var foundArch: FatArch?
        
        for _ in 0..<fatHeader.numArchitectures {
            let archData = fileData.subdata(in: offset..<(offset + 20)).withUnsafeBytes { ptr in
                FatArch(
                    cpuType: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                    cpuSubtype: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian,
                    offset: ptr.load(fromByteOffset: 8, as: UInt32.self).bigEndian,
                    size: ptr.load(fromByteOffset: 12, as: UInt32.self).bigEndian,
                    align: ptr.load(fromByteOffset: 16, as: UInt32.self).bigEndian
                )
            }
            
            let cpuType = archData.cpuType
            if (targetArch == "arm64" && cpuType == 0x100000C) || (targetArch == "x86_64" && cpuType == 0x01000007) {
                foundArch = archData
                break
            }
            
            offset += 20
        }
        
        guard let targetArchData = foundArch else {
            print("Mach-O Error: Target architecture \(targetArch) not found in binary.")
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
