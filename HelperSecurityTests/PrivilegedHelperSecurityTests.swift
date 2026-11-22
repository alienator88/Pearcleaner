import Foundation
import ObjectiveC
import XCTest
@testable import PearcleanerHelper

final class PrivilegedHelperSecurityTests: XCTestCase {
    func testTraversalAndMalformedPathsAreRejectedBeforeFilesystemAccess() {
        [
            "Applications/Example.app",
            "/Applications/../Library/Example.app",
            "/Applications/Example.app/../Other.app",
            "/Applications/\u{0}Example.app",
            "/" + String(repeating: "a", count: 1_025)
        ].forEach { XCTAssertFalse(PrivilegedBundleThinner.isStructurallyValidRequestPath($0), $0) }
    }

    func testShellMetacharactersAreTreatedAsLiteralPathCharacters() {
        [
            "/Applications/quote'and\"double.app",
            "/Applications/$(touch injected).app",
            "/Applications/semicolon;echo.app",
            "/Applications/space name.app"
        ].forEach { XCTAssertTrue(PrivilegedBundleThinner.isStructurallyValidRequestPath($0), $0) }
    }

    func testAllowlistAcceptsOnlyDirectApplicationsChildren() {
        XCTAssertTrue(PrivilegedBundleThinner.hasAllowedBundleLocation(URL(fileURLWithPath: "/Applications/Example.app")))
        XCTAssertFalse(PrivilegedBundleThinner.hasAllowedBundleLocation(URL(fileURLWithPath: "/Applications/Utilities/Example.app")))
        XCTAssertFalse(PrivilegedBundleThinner.hasAllowedBundleLocation(URL(fileURLWithPath: "/System/Applications/Example.app")))
        XCTAssertFalse(PrivilegedBundleThinner.hasAllowedBundleLocation(URL(fileURLWithPath: "/Applications/Example")))
    }

    func testSymlinkComponentsAreRejected() throws {
        // /var is itself a compatibility symlink to /private/var on macOS;
        // use the physical temp path so the control case contains no link.
        let directory = URL(fileURLWithPath: "/private/tmp", isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let link = directory.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        XCTAssertFalse(PrivilegedBundleThinner.hasNoSymlinkComponents(atPath: link.path))
        XCTAssertTrue(PrivilegedBundleThinner.hasNoSymlinkComponents(atPath: target.path))
    }

    func testRequirementRejectsInvalidBundleOrTeamComponents() {
        XCTAssertThrowsError(try CodesignCheck.clientRequirement(bundleIdentifier: "com.example.\"injected", teamIdentifier: "TEAMID"))
        XCTAssertThrowsError(try CodesignCheck.clientRequirement(bundleIdentifier: "com.example.app", teamIdentifier: "TEAM ID"))
        XCTAssertNoThrow(try CodesignCheck.clientRequirement(bundleIdentifier: "com.example.app", teamIdentifier: "TEAMID1234"))
    }

    func testUnpairedTestProcessFailsClosedAsAHelperClient() {
        let authorized: Bool
        do {
            authorized = try CodesignCheck.isAuthorizedClient(pid: getpid())
        } catch {
            authorized = false
        }
        XCTAssertFalse(authorized)
    }

    func testHelperOperationsAreSerialized() {
        let serialiser = HelperOperationSerialiser()
        let done = expectation(description: "all operations complete")
        done.expectedFulfillmentCount = 20
        let counter = ConcurrentCounter()

        for _ in 0..<20 {
            serialiser.execute {
                counter.begin()
                usleep(1_000)
                counter.end()
                done.fulfill()
            }
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(counter.maximumActive, 1)
    }
}

private final class ConcurrentCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private(set) var maximumActive = 0

    func begin() {
        lock.lock()
        active += 1
        maximumActive = max(maximumActive, active)
        lock.unlock()
    }

    func end() {
        lock.lock()
        active -= 1
        lock.unlock()
    }
}
