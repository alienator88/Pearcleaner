import Darwin
import Foundation

/// The helper's complete mutation policy.  Keep this deliberately narrower than
/// the application's general-purpose, user-writable bundle thinning support.
enum PrivilegedBundleThinner {
    private static let applicationsDirectory = "/Applications"
    private static let maximumRequestPathBytes = 1024
    private static let maximumArchitectures: UInt32 = 32

    enum Failure: Error {
        case invalidRequest
        case outsideAllowedScope
        case symlink
        case notRootOwnedBundle
        case changedDuringOperation
        case unreadableBinary
    }

    static func thin(bundlePath: String) -> (succeeded: Bool, preSize: UInt64, postSize: UInt64) {
        guard let bundle = validatedBundle(at: bundlePath) else { return (false, 0, 0) }
        let preSize = directorySize(at: bundle.url)

        guard let enumerator = FileManager.default.enumerator(
            at: bundle.url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (false, 0, 0)
        }

        for case let fileURL as URL in enumerator {
            if isSymbolicLink(fileURL) {
                enumerator.skipDescendants()
                continue
            }
            guard !isDirectory(fileURL), bundleStillMatches(bundle) else { continue }
            try? thinBinary(at: fileURL, in: bundle)
        }

        guard bundleStillMatches(bundle) else { return (false, 0, 0) }
        return (true, preSize, directorySize(at: bundle.url))
    }

    private struct ValidatedBundle {
        let url: URL
        let device: dev_t
        let inode: ino_t
    }

    /// Reject lexical traversal and every symlink component before accepting a
    /// bundle.  Only direct children of /Applications are an approved root
    /// helper scope; /System/Applications is intentionally never mutable.
    private static func validatedBundle(at path: String) -> ValidatedBundle? {
        guard isStructurallyValidRequestPath(path) else { return nil }

        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard hasAllowedBundleLocation(url),
              hasNoSymlinkComponents(atPath: url.path), let status = lstat(url.path) else { return nil }

        let fileType = status.st_mode & S_IFMT
        guard fileType == S_IFDIR, status.st_uid == 0 else { return nil }
        return ValidatedBundle(url: url, device: status.st_dev, inode: status.st_ino)
    }

    private static func bundleStillMatches(_ bundle: ValidatedBundle) -> Bool {
        guard hasNoSymlinkComponents(atPath: bundle.url.path), let status = lstat(bundle.url.path) else { return false }
        return (status.st_mode & S_IFMT) == S_IFDIR && status.st_uid == 0 &&
            status.st_dev == bundle.device && status.st_ino == bundle.inode
    }

    /// Lexical checks performed before touching the filesystem.  A path may
    /// contain shell punctuation because it is never evaluated as a command.
    static func isStructurallyValidRequestPath(_ path: String) -> Bool {
        path.utf8.count <= maximumRequestPathBytes &&
            path.hasPrefix("/") &&
            !path.utf8.contains(0) &&
            !path.split(separator: "/").contains("..")
    }

    /// The helper only operates on application bundles directly below the
    /// system Applications directory; nested bundles and /System/Applications
    /// are intentionally outside its authority.
    static func hasAllowedBundleLocation(_ url: URL) -> Bool {
        url.deletingLastPathComponent().path == applicationsDirectory &&
            url.pathExtension.lowercased() == "app"
    }

    /// Exposed at module scope for focused tests; callers must still use
    /// `validatedBundle(at:)`, which applies ownership and allowlist checks.
    static func hasNoSymlinkComponents(atPath path: String) -> Bool {
        var current = ""
        for component in path.split(separator: "/") {
            current += "/\(component)"
            guard let status = lstat(current), (status.st_mode & S_IFMT) != S_IFLNK else { return false }
        }
        return true
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    /// Opens the target with O_NOFOLLOW and retains that descriptor through the
    /// final fstat and write.  A rename or replacement cannot redirect the
    /// privileged write to a different file after validation.
    private static func thinBinary(at url: URL, in bundle: ValidatedBundle) throws {
        guard bundleStillMatches(bundle) else { throw Failure.changedDuringOperation }
        let descriptor = open(url.path, O_RDWR | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw Failure.unreadableBinary }
        defer { close(descriptor) }

        guard let before = fstat(descriptor), (before.st_mode & S_IFMT) == S_IFREG,
              before.st_size > 0, before.st_size <= Int64(Int.max) else { throw Failure.unreadableBinary }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        let data = try handle.readToEnd() ?? Data()
        guard let slice = nativeArchitectureSlice(in: data), !slice.isEmpty else { return }

        guard let afterRead = fstat(descriptor), afterRead.st_dev == before.st_dev,
              afterRead.st_ino == before.st_ino, afterRead.st_size == before.st_size,
              bundleStillMatches(bundle) else { throw Failure.changedDuringOperation }

        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: slice)
        guard ftruncate(descriptor, off_t(slice.count)) == 0 else { throw Failure.unreadableBinary }
    }

    private static func nativeArchitectureSlice(in data: Data) -> Data? {
        guard data.count >= 8 else { return nil }
        let magic = data.uint32BE(at: 0)
        guard magic == 0xcafebabe else { return nil }
        let count = data.uint32BE(at: 4)
        guard count > 0, count <= maximumArchitectures,
              data.count >= 8 + Int(count) * 20 else { return nil }

#if arch(arm64)
        let nativeCPUType: UInt32 = 0x100000C
#else
        let nativeCPUType: UInt32 = 0x01000007
#endif
        for index in 0..<Int(count) {
            let offset = 8 + index * 20
            guard data.uint32BE(at: offset) == nativeCPUType else { continue }
            let sliceOffset = Int(data.uint32BE(at: offset + 8))
            let sliceSize = Int(data.uint32BE(at: offset + 12))
            guard sliceOffset >= 0, sliceSize > 0,
                  sliceOffset <= data.count - sliceSize else { return nil }
            return data.subdata(in: sliceOffset..<(sliceOffset + sliceSize))
        }
        return nil
    }

    private static func directorySize(at url: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return enumerator.reduce(into: UInt64(0)) { size, item in
            guard let fileURL = item as? URL,
                  let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return }
            size += UInt64(fileSize)
        }
    }

    private static func lstat(_ path: String) -> stat? {
        var status = stat()
        return Darwin.lstat(path, &status) == 0 ? status : nil
    }

    private static func fstat(_ descriptor: Int32) -> stat? {
        var status = stat()
        return Darwin.fstat(descriptor, &status) == 0 ? status : nil
    }
}

private extension Data {
    func uint32BE(at offset: Int) -> UInt32 {
        self[offset..<(offset + 4)].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
    }
}
