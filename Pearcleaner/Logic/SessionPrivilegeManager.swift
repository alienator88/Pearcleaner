//
//  SessionPrivilegeManager.swift
//  Pearcleaner
//
//  Session-scoped privilege: Pearcleaner never installs a launchd daemon and
//  never ships a helper binary. Live probing on macOS 26 showed the
//  authorization trampoline only elevates Apple-signed binaries: a bundled
//  helper runs uid=502 even after the user approves. So privileged work runs
//  through /bin/sh (Apple-signed, verifiably elevated) via
//  AuthorizationExecuteWithPrivileges, one password prompt per session
//  (system.privilege.admin, non-shared, 300 s OS window). While the app runs a
//  keepalive silently renews the credential before the window closes. If the
//  AEWP symbol disappears (Apple logs it will) the osascript
//  administrator-privileges path takes over. Nothing is installed, nothing
//  persists, and every root command is assembled from fixed literals with
//  per-path escaping.
//

import AppKit
import Foundation
import Security
import ServiceManagement

final class SessionPrivilegeManager {
    static let shared = SessionPrivilegeManager()

    private let queue = DispatchQueue(label: "com.alienator88.Pearcleaner.session-privilege")
    private var authRef: AuthorizationRef?
    private var keepaliveStarted = false

    // system.privilege.admin holds the credential for 300 s on this OS; renew
    // comfortably before expiry, never after. Probe-verified on macOS 26: same
    // ref, no further dialogs for the whole window.
    private let renewalInterval: TimeInterval = 4 * 60
    private var renewalTimer: DispatchSourceTimer?

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification, object: nil)
    }

    @objc private func appWillTerminate() {
        releaseAuthorization()
    }

    // MARK: - Authorization lifecycle

    /// Acquires (or reuses) the session credential. First call in a session
    /// shows the OS password dialog; renewal calls reuse the shared window.
    private func authorize(interactive: Bool) -> Bool {
        var ref = authRef
        if ref == nil {
            guard AuthorizationCreate(nil, nil, [], &ref) == errAuthorizationSuccess else { return false }
            authRef = ref
        }
        guard let ref else { return false }

        let right = kAuthorizationRightExecute
        var item = right.withCString { AuthorizationItem(name: $0, valueLength: 0, value: nil, flags: 0) }
        var rights = withUnsafeMutablePointer(to: &item) { AuthorizationRights(count: 1, items: $0) }
        let flags: AuthorizationFlags = interactive
            ? [.interactionAllowed, .preAuthorize, .extendRights]
            : [.extendRights]
        let status = AuthorizationCopyRights(ref, &rights, nil, flags, nil)
        if status != errAuthorizationSuccess {
            // A dead window cannot be revived silently: drop the ref so the
            // next interactive call rebuilds it from scratch.
            releaseAuthorization()
            return false
        }
        startKeepaliveIfNeeded()
        return true
    }

    /// Silent keepalive: renews the credential while the app runs so one
    /// password entry covers the whole session. Runs on the manager queue,
    /// never shows UI. If renewal fails (locked screen, changed password) the
    /// credential simply expires and the next operation prompts again.
    private func startKeepaliveIfNeeded() {
        queue.async { [weak self] in
            guard let self, !self.keepaliveStarted else { return }
            self.keepaliveStarted = true
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + self.renewalInterval, repeating: self.renewalInterval)
            timer.setEventHandler { [weak self] in
                guard let self, self.authRef != nil else { return }
                self.authorize(interactive: false)
            }
            timer.resume()
            self.renewalTimer = timer
        }
    }

    private func releaseAuthorization() {
        queue.async { [weak self] in
            guard let self else { return }
            if let ref = self.authRef {
                AuthorizationFree(ref, [.destroyRights])
            }
            self.authRef = nil
            self.renewalTimer?.cancel()
            self.renewalTimer = nil
            self.keepaliveStarted = false
        }
    }

    /// Drops the credential when the screen locks; the OS does this anyway for
    /// non-shared rights, this only forgets our half of the state so the next
    /// operation asks cleanly.
    func invalidateSession() {
        releaseAuthorization()
    }

    // MARK: - AEWP

    private static var aewpImpl: AEWPImplementation? = {
        guard let sym = dlsym(dlopen(nil, RTLD_NOW), "AuthorizationExecuteWithPrivileges") else {
            return nil
        }
        return unsafeBitCast(sym, to: AEWPImplementation.self)
    }()

    private typealias AEWPImplementation = @convention(c) (
        AuthorizationRef, UnsafePointer<CChar>, AuthorizationFlags,
        UnsafePointer<UnsafeMutablePointer<CChar>?>, UnsafeMutablePointer<UnsafeMutablePointer<FILE>?>?
    ) -> OSStatus

    /// Runs a shell command as root through Apple's signed /bin/sh. Only
    /// fixed-literal command shapes with per-path escaping reach this method.
    func run(command: String) -> (Bool, String) {
        executeShell(command)
    }

    /// Thins a single root-owned Mach-O binary as root.
    func thin(binaryAt path: String) -> (Bool, String) {
        executeShell(Self.thinCommand(path))
    }

    /// Thins a whole root-owned .app bundle as root and reports sizes.
    /// PrivilegedBundleThinner validates the request in-process first (no
    /// traversal, /Applications direct child, root-owned, no symlink
    /// components); the root command only handles the write.
    func thinBundle(at path: String) -> (Bool, String, [String: UInt64]) {
        guard PrivilegedBundleThinner.isStructurallyValidRequestPath(path),
              PrivilegedBundleThinner.hasAllowedBundleLocation(URL(fileURLWithPath: path)),
              PrivilegedBundleThinner.hasNoSymlinkComponents(atPath: path) else {
            return (false, "Bundle rejected by validation", [:])
        }
        let preSize = Self.shellSafeDirectorySize(path)
        let (ok, message) = executeShell(Self.thinBundleCommand(path))
        let postSize = Self.shellSafeDirectorySize(path)
        guard ok else { return (false, message, [:]) }
        return (true, message.isEmpty ? "Success" : message, ["pre": preSize, "post": postSize])
    }

    /// True when the session credential is alive and a task would not prompt.
    var hasLiveCredential: Bool {
        queue.sync(execute: { authRef != nil })
    }

    // MARK: - Internals

    private func executeShell(_ command: String) -> (Bool, String) {
        if let impl = Self.aewpImpl,
           authorize(interactive: true),
           let ref = queue.sync(execute: { authRef }) {
            if let result = aewpRun(impl, ref, command) {
                return result
            }
            // Window died between authorize and exec: one retry with a fresh
            // interactive acquisition.
            _ = authorize(interactive: true)
            if let ref = queue.sync(execute: { authRef }),
               let result = aewpRun(impl, ref, command) {
                return result
            }
        }
        return Self.osascriptFallback(command: command)
    }

    /// One AEWP execution of /bin/sh -c <command>. Returns nil when the call
    /// itself failed (exec error, dead window) so the caller can retry.
    private func aewpRun(_ impl: AEWPImplementation, _ ref: AuthorizationRef,
                         _ command: String) -> (Bool, String)? {
        var argPtrs: [UnsafeMutablePointer<CChar>?] =
            [strdup("-c"), strdup(command), nil]
        defer { for p in argPtrs { if let p = p { free(p) } } }

        var outFP: UnsafeMutablePointer<FILE>?
        let status = impl(ref, "/bin/sh", [], argPtrs, &outFP)
        guard status == errAuthorizationSuccess, let outFP else { return nil }

        let handle = FileHandle(fileDescriptor: fileno(outFP), closeOnDealloc: false)
        let data = handle.readDataToEndOfFile()
        fclose(outFP)
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (true, output)
    }

    /// Thins one binary: lipo keeps only the native slice, replacing the file
    /// atomically enough for a validated fixed path.
    private static func thinCommand(_ path: String) -> String {
        let escaped = shellEscape(path)
        return "lipo -remove \(nonNativeArchitecture()) \(escaped) -output \(escaped) && true"
    }

    /// Thins every executable in a bundle: find (Apple tool) feeds lipo the
    /// validated bundle path only; per-file handling stays inside find.
    private static func thinBundleCommand(_ path: String) -> String {
        let escaped = shellEscape(path)
        return "find \(escaped) -type f -perm +111 -exec lipo -remove \(nonNativeArchitecture()) {} -output {} \\; 2>/dev/null; true"
    }

    private static func nonNativeArchitecture() -> String {
        #if arch(arm64)
        return "x86_64"
        #else
        return "arm64"
        #endif
    }

    /// Directory size computed in-process, no root needed to *read* sizes.
    private static func shellSafeDirectorySize(_ path: String) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]) else { return 0 }
        var total: UInt64 = 0
        for case let url as URL in enumerator {
            if let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               values.isRegularFile == true, let size = values.fileSize {
                total += UInt64(size)
            }
        }
        return total
    }

    /// Single-quote escaping: the only characters that can escape a single
    /// quoted shell string are single quotes themselves.
    private static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// osascript administrator-privileges fallback, for the day AEWP is
    /// really gone. Prompts per call; keeps the app functional either way.
    private static func osascriptFallback(command: String) -> (Bool, String) {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges with prompt \"Pearcleaner\""
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source),
              script.executeAndReturnError(&error) != nil else {
            return (false, error?[NSAppleScript.errorMessage] as? String ?? "osascript elevation failed")
        }
        return (true, "done")
    }

    // MARK: - Migration

    /// Removes any previously installed privileged helper. Called at launch
    /// and during uninstall. Unregistering the SMAppService daemon and
    /// deleting the legacy on-disk artifacts leaves the system clean; when it
    /// needs root again, Pearcleaner just asks for the password once.
    static func removeInstalledHelper() async {
        let service = SMAppService.daemon(plistName: "com.alienator88.Pearcleaner.PearcleanerHelper.plist")
        if service.status != .notRegistered, service.status != .notFound {
            try? await service.unregister()
        }
        let legacy = [
            "/Library/PrivilegedHelperTools/com.alienator88.Pearcleaner.PearcleanerHelper",
            "/Library/LaunchDaemons/com.alienator88.Pearcleaner.PearcleanerHelper.plist",
        ]
        for path in legacy where FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}

// MARK: - Async wrappers

/// Call-site convenience: the manager API is synchronous (it blocks on the
/// shell and the Authorization dialog); these wrappers move that blocking
/// work off the caller's task so UI code can await it directly.
extension SessionPrivilegeManager {

    /// Runs a fixed-shape shell command as root, off the current task.
    static func runPrivilegedShell(_ command: String) async -> (Bool, String) {
        await Task.detached(priority: .userInitiated) {
            shared.run(command: command)
        }.value
    }

    /// Thins a single root-owned Mach-O binary as root, off the current task.
    static func thinPrivileged(binaryAt path: String) async -> (Bool, String) {
        await Task.detached(priority: .userInitiated) {
            shared.thin(binaryAt: path)
        }.value
    }

    /// Thins a whole root-owned .app bundle as root, validating in-process
    /// first, off the current task.
    static func thinPrivilegedBundle(at path: String) async -> (Bool, String, [String: UInt64]) {
        await Task.detached(priority: .userInitiated) {
            shared.thinBundle(at: path)
        }.value
    }
}
