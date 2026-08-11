import XCTest
@testable import Pearcleaner

final class LaunchModeTests: XCTestCase {
    private let appExecutable = "/Applications/Pearcleaner.app/Contents/MacOS/Pearcleaner"

    func testFinderLaunchUsesGUIMode() {
        XCTAssertEqual(launchMode(arguments: [appExecutable], environment: [:]), .gui)
    }

    func testTerminalDerivedLaunchWithoutCommandUsesGUIMode() {
        XCTAssertEqual(launchMode(arguments: [appExecutable], environment: ["TERM": "xterm-256color"]), .gui)
    }

    func testLaunchServicesArgumentsUseGUIMode() {
        let arguments = [
            appExecutable,
            "-psn_0_12345",
            "-NSDocumentRevisionsDebugMode",
            "YES",
            "-AppleTextDirection",
            "NO",
            "-AppleLanguages",
            "(en)",
        ]

        XCTAssertEqual(launchMode(arguments: arguments, environment: ["TERM": "xterm"]), .gui)
    }

    func testConfiguredCLIPathWithoutCommandUsesCLIMode() {
        XCTAssertEqual(launchMode(arguments: ["/usr/local/bin/pear"], environment: [:]), .cli)
    }

    func testCLIBasenameWithoutCommandUsesCLIMode() {
        XCTAssertEqual(launchMode(arguments: ["pear"], environment: [:]), .cli)
    }

    func testSupportedSubcommandsUseCLIMode() {
        let subcommands = [
            "list",
            "list-orphaned",
            "uninstall",
            "uninstall-all",
            "remove-orphaned",
            "helper",
            "ask-password",
        ]

        for subcommand in subcommands {
            XCTAssertEqual(
                launchMode(arguments: [appExecutable, subcommand], environment: [:]),
                .cli,
                "Expected \(subcommand) to select CLI mode"
            )
            XCTAssertEqual(
                launchMode(arguments: [appExecutable, subcommand], environment: ["TERM": "xterm"]),
                .cli,
                "Expected \(subcommand) to select CLI mode with TERM set"
            )
        }
    }

    func testSupportedOptionUsesCLIMode() {
        XCTAssertEqual(launchMode(arguments: [appExecutable, "--help"], environment: [:]), .cli)
    }

    func testUnrelatedGUIFlagUsesGUIMode() {
        XCTAssertEqual(launchMode(arguments: [appExecutable, "--unrelated"], environment: [:]), .gui)
    }
}
