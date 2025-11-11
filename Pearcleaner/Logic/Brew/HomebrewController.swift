//
//  HomebrewController.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import Foundation
import AlinFoundation

enum HomebrewError: Error, LocalizedError {
    case brewNotFound
    case commandFailed(String)
    case jsonParseError
    case packageNotFound

    var errorDescription: String? {
        switch self {
        case .brewNotFound:
            return "Homebrew not found. Please install Homebrew first."
        case .commandFailed(let message):
            return message.trimmingCharacters(in: .whitespacesAndNewlines)
        case .jsonParseError:
            return "Failed to parse JSON response from Homebrew API"
        case .packageNotFound:
            return "Package not found in Homebrew"
        }
    }
}

extension String {
    /// Strip all Homebrew revision suffixes and metadata from version string
    /// Used for both directory scan and API comparison to ensure consistent version matching
    /// Handles all common patterns: underscores, hyphens, commas, plus signs
    ///
    /// Keeps only alphanumeric characters and periods - strips from first suffix marker onward
    /// Then trims trailing non-alphanumeric characters (periods, etc.)
    ///
    /// Valid characters: digits (0-9), letters (a-z, A-Z), periods (.)
    /// Suffix markers: anything else (comma, plus, underscore, hyphen, etc.)
    ///
    /// Examples:
    ///   - "0.14.1,fc796f5b" → "0.14.1"
    ///   - "4.1.0+8404-main" → "4.1.0"
    ///   - "2.14.1_1" → "2.14.1"
    ///   - "8.27.2-4" → "8.27.2"
    ///   - "141.0.7390.122-1.1" → "141.0.7390.122"
    ///   - "1.0b5" → "1.0b5" (letters preserved)
    ///   - "1.2.3a" → "1.2.3a" (pre-release preserved)
    ///   - "v1.2.3" → "v1.2.3" (prefix preserved)
    ///   - "1.2." → "1.2" (trailing period removed)
    func stripBrewRevisionSuffix() -> String {
        var result = self

        // Find first character that's not alphanumeric or period (suffix marker)
        if let firstSuffixIndex = result.firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "." }) {
            result = String(result[..<firstSuffixIndex])
        }

        // Trim any trailing periods or other non-alphanumeric characters
        while let last = result.last, !last.isLetter && !last.isNumber {
            result.removeLast()
        }

        return result
    }
}

class HomebrewController: ObservableObject {
    static let shared = HomebrewController()
    private let brewPath: String
    let brewPrefix: String  // Public for use in HomebrewUpdateChecker placeholder paths
    private let logger = UpdaterDebugLogger.shared

    // Track running operations for cancellation
    // Must be accessed/modified on main thread for SwiftUI observation
    @MainActor @Published var isOperationRunning: Bool = false
    @MainActor private var runningProcess: Process?

    // Console output tracking
    @MainActor @Published var consoleEnabled: Bool = false
    @MainActor @Published var consoleOutput: String = ""

    private init() {
        // Determine paths based on architecture
        if isOSArm() {
            self.brewPath = "/opt/homebrew/bin/brew"
            self.brewPrefix = "/opt/homebrew"
        } else {
            self.brewPath = "/usr/local/bin/brew"
            self.brewPrefix = "/usr/local"
        }
    }

    // MARK: - Installation Check

    var isInstalled: Bool {
        return FileManager.default.fileExists(atPath: brewPath)
    }

    // MARK: - Helper Methods

    func getBrewPrefix() -> String {
        return brewPrefix
    }

    // MARK: - Shell Command Execution

    /// Checks if command output indicates authentication failure
    private func isAuthenticationFailure(_ output: String) -> Bool {
        let indicators = [
            "Sorry, try again",
            "incorrect password",
            "Authentication failure",
            "sudo: 3 incorrect password attempts",
            "sudo: no password was provided",
            "sudo: a password is required"
        ]
        return indicators.contains { output.lowercased().contains($0.lowercased()) }
    }

    /// Runs brew command with auto-retry on authentication failure
    func runBrewCommandWithRetry(_ arguments: [String], maxRetries: Int = 2) async throws -> (output: String, error: String) {
        var attemptCount = 0

        while attemptCount < maxRetries {
            let (output, error) = try await runBrewCommand(arguments)

            // Check for authentication failure
            let combinedOutput = output + error
            if isAuthenticationFailure(combinedOutput) {
                printOS("🔐 Authentication failed, invalidating cache and retrying (attempt \(attemptCount + 1)/\(maxRetries))")
                KeychainPasswordManager.shared.invalidateCache()
                attemptCount += 1

                if attemptCount < maxRetries {
                    continue  // Retry with fresh password
                } else {
                    // Max retries reached, return the failed output
                    printOS("❌ Authentication failed after \(maxRetries) attempts")
                    return (output, error)
                }
            }

            // Success or non-auth error
            return (output, error)
        }

        // This shouldn't be reached, but return empty as fallback
        return ("", "Max retries reached")
    }

    func runBrewCommand(_ arguments: [String]) async throws -> (output: String, error: String) {
        // Mark operation as running - explicitly trigger SwiftUI update
        await MainActor.run {
            objectWillChange.send()
            isOperationRunning = true
            runningProcess = nil  // Clear any stale process reference
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = arguments

        // Set up environment with SUDO_ASKPASS for password prompts during install/update
        var environment = ProcessInfo.processInfo.userEnvironment
        let askpassPath = "\(Bundle.main.bundlePath)/Contents/Resources/askpass.sh"
        environment["SUDO_ASKPASS"] = askpassPath
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Store process reference for cancellation
        await MainActor.run { runningProcess = process }

        try process.run()

        // Read pipes on background thread with console streaming
        let (outputData, errorData) = await withCheckedContinuation { continuation in
            Task.detached { [weak self] in
                var outputData = Data()
                var errorData = Data()

                let outputHandle = outputPipe.fileHandleForReading
                let errorHandle = errorPipe.fileHandleForReading

                // Read output with streaming to console
                while true {
                    let chunk = outputHandle.availableData
                    if chunk.isEmpty { break }
                    outputData.append(chunk)

                    // Stream to console if enabled - check dynamically to support mid-operation console opening
                    if let text = String(data: chunk, encoding: .utf8) {
                        await MainActor.run { [weak self] in
                            guard let self = self, self.consoleEnabled else { return }
                            self.consoleOutput += text
                        }
                    }
                }

                // Read error output
                errorData = errorHandle.readDataToEndOfFile()

                continuation.resume(returning: (outputData, errorData))
            }
        }

        process.waitUntilExit()

        // Clear running state - explicitly trigger SwiftUI update
        await MainActor.run {
            objectWillChange.send()
            isOperationRunning = false
            runningProcess = nil
        }

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        return (output, error)
    }

    /// Cancel the currently running Homebrew operation
    @MainActor func cancelOperation() {
        guard let process = runningProcess else { return }
        isOperationRunning = false
        process.terminate()
        runningProcess = nil
    }

    // MARK: - Package Loading

    /// Stream installed packages by scanning Cellar/Caskroom directories
    /// Returns minimal info: name + displayName + description + version + isPinned + tap + tapRbPath
    func streamInstalledPackages(
        cask: Bool,
        onPackageFound: @escaping (String, String?, String, String, Bool, String?, String?, Bool) -> Void  // (name, displayName, description, version, isPinned, tap, tapRbPath, installedOnRequest)
    ) async throws {
        let baseDir = cask ? "\(brewPrefix)/Caskroom" : "\(brewPrefix)/Cellar"

        logger.log(.homebrew, "🔍 Scanning for installed \(cask ? "casks" : "formulae") in \(baseDir)")

        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Loading installed \(cask ? "casks" : "formulae")...\n"
        }

        guard let packageDirs = try? FileManager.default.contentsOfDirectory(atPath: baseDir) else {
            logger.log(.homebrew, "⚠️ Could not read directory: \(baseDir)")
            return
        }

        let packageCount = packageDirs.filter { !$0.hasPrefix(".") }.count
        logger.log(.homebrew, "Found \(packageCount) \(cask ? "casks" : "formulae") to process")

        // Process concurrently, stream results as they complete
        var loadedCount = 0
        await withTaskGroup(of: (String, String?, String, String, Bool, String?, String?, Bool)?.self) { group in
            // Add all tasks
            for packageName in packageDirs where !packageName.hasPrefix(".") {
                group.addTask {
                    if cask {
                        // Casks are always considered installed on request
                        if let result = await self.getCaskNameDescVersionPin(name: packageName) {
                            return (result.0, result.1, result.2, result.3, result.4, result.5, result.6, true)
                        }
                        return nil
                    } else {
                        return await self.getFormulaNameDescVersionPin(name: packageName)
                    }
                }
            }

            // Collect results as they complete
            for await result in group {
                if let (name, displayName, desc, version, isPinned, tap, tapRbPath, installedOnRequest) = result {
                    onPackageFound(name, displayName, desc, version, isPinned, tap, tapRbPath, installedOnRequest)
                    loadedCount += 1
                }
            }
        }

        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Loaded \(loadedCount) \(cask ? "casks" : "formulae")\n"
        }
    }

    /// Load minimal package metadata (name, displayName, description, version) from local JWS files
    /// Much faster than API calls and works offline
    /// JWS files are already cached by Homebrew after `brew update`
    func loadMinimalPackageMetadata(cask: Bool) async throws -> [(name: String, displayName: String?, description: String?, version: String?, bundleVersion: String?)] {
        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Loading available \(cask ? "casks" : "formulae") metadata...\n"
        }

        let fileName = cask ? "cask.jws.json" : "formula.jws.json"
        let apiCachePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/Homebrew/api")
        let jwsFilePath = apiCachePath.appendingPathComponent(fileName).path

        guard FileManager.default.fileExists(atPath: jwsFilePath) else {
            throw HomebrewError.commandFailed("JWS file not found: \(fileName). Run 'brew update' first.")
        }

        // Read JWS file
        let jwsContent = try String(contentsOfFile: jwsFilePath, encoding: .utf8)

        // Parse JWS structure: {"payload": "json-string-array", "signatures": [...]}
        // Note: payload is NOT base64-encoded, it's a plain JSON string
        guard let jwsData = jwsContent.data(using: .utf8),
              let jwsJson = try JSONSerialization.jsonObject(with: jwsData) as? [String: Any],
              let payloadString = jwsJson["payload"] as? String,
              let payloadData = payloadString.data(using: .utf8),
              let payloadArray = try JSONSerialization.jsonObject(with: payloadData) as? [[String: Any]] else {
            throw HomebrewError.jsonParseError
        }

        var results: [(name: String, displayName: String?, description: String?, version: String?, bundleVersion: String?)] = []

        // Extract package metadata from array
        for packageDict in payloadArray {
            let name: String
            let displayName: String?
            let description = packageDict["desc"] as? String
            let version: String?
            let bundleVersion: String?

            if cask {
                // Casks: token is brew ID, name is array with display name
                guard let token = packageDict["token"] as? String else { continue }
                name = token
                let nameArray = packageDict["name"] as? [String]
                displayName = nameArray?.first
                version = packageDict["version"] as? String
                bundleVersion = packageDict["bundle_version"] as? String
            } else {
                // Formulae: name is brew ID (no separate display name)
                guard let formulaName = packageDict["name"] as? String else { continue }
                name = formulaName
                displayName = nil  // Formulae don't have separate display names
                version = (packageDict["versions"] as? [String: Any])?["stable"] as? String
                bundleVersion = nil  // Formulae don't have bundle versions
            }

            results.append((name: name, displayName: displayName, description: description, version: version, bundleVersion: bundleVersion))
        }

        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Loaded \(results.count) available \(cask ? "casks" : "formulae")\n"
        }

        return results
    }

    /// Load package names from text files (formula_names.txt or cask_names.txt)
    /// Returns array of package names only - no descriptions or other metadata
    /// Falls back to .before.txt files if current files don't exist (e.g., after brew update)
    func loadPackageNames(cask: Bool) async throws -> [String] {
        let fileName = cask ? "cask_names.txt" : "formula_names.txt"
        let beforeFileName = cask ? "cask_names.before.txt" : "formula_names.before.txt"
        let apiCachePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/Homebrew/api")

        // Try current file first
        let currentFilePath = apiCachePath.appendingPathComponent(fileName).path
        let beforeFilePath = apiCachePath.appendingPathComponent(beforeFileName).path

        // Determine which file to use
        let filePathToUse: String
        if FileManager.default.fileExists(atPath: currentFilePath) {
            filePathToUse = currentFilePath
        } else if FileManager.default.fileExists(atPath: beforeFilePath) {
            filePathToUse = beforeFilePath
        } else {
            throw HomebrewError.commandFailed("Neither \(fileName) nor \(beforeFileName) found")
        }

        // Read file content
        let content = try String(contentsOfFile: filePathToUse, encoding: .utf8)

        // Split by newlines and filter empty lines
        let names = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !names.isEmpty else {
            throw HomebrewError.commandFailed("Package names file is empty: \(filePathToUse)")
        }

        return names
    }

    /// Extract name, displayName, description, version, and pin status from formula
    func getFormulaNameDescVersionPin(name: String) async -> (String, String?, String, String, Bool, String?, String?, Bool)? {
        let cellarPath = "\(brewPrefix)/Cellar/\(name)"

        // Find latest version directory
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: cellarPath)
                .filter({ !$0.hasPrefix(".") }),
              let latestVersion = versions.sorted().last else {
            return nil
        }

        // Check if pinned (pin file exists)
        let pinPath = "\(brewPrefix)/var/homebrew/pinned/\(name)"
        let isPinned = FileManager.default.fileExists(atPath: pinPath)

        // Read INSTALL_RECEIPT.json for version and installed_on_request field
        // Use receipt as source of truth for ALL formulae (HEAD and regular)
        let receiptPath = "\(cellarPath)/\(latestVersion)/INSTALL_RECEIPT.json"
        var installedOnRequest = false  // Default to false if field missing
        var actualVersion = latestVersion  // Fallback to directory name

        if let receiptData = try? Data(contentsOf: URL(fileURLWithPath: receiptPath)),
           let receipt = try? JSONSerialization.jsonObject(with: receiptData) as? [String: Any] {
            installedOnRequest = receipt["installed_on_request"] as? Bool ?? false

            // Extract version from receipt (unified for HEAD and regular formulae)
            // Version is nested: source.versions.stable
            if let source = receipt["source"] as? [String: Any],
               let versions = source["versions"] as? [String: Any],
               let stableVersion = versions["stable"] as? String,
               !stableVersion.isEmpty {
                // Use receipt version and apply cleanup as safety measure
                actualVersion = stableVersion.stripBrewRevisionSuffix()
            } else {
                // Fallback: strip revision suffix from directory name
                actualVersion = latestVersion.stripBrewRevisionSuffix()
            }
        } else {
            // Fallback if receipt missing/corrupted: use directory name with cleanup
            actualVersion = latestVersion.stripBrewRevisionSuffix()
        }

        // actualVersion is now clean and ready to use (no additional stripping needed)
        let cleanedVersion = actualVersion

        // Read .rb file for description
        let rbPath = "\(cellarPath)/\(latestVersion)/.brew/\(name).rb"
        var desc = "No description available"
        if let rbContent = try? String(contentsOfFile: rbPath) {
            // Parse desc with regex: desc "..."
            let descRegex = /desc "([^"]+)"/
            if let match = rbContent.firstMatch(of: descRegex) {
                desc = String(match.1)
            }
        }

        // Don't load tap info during scan - will be lazy loaded during outdated check if needed
        let tap: String? = nil
        let tapRbPath: String? = nil

        // Formulae don't have separate display names
        let displayName: String? = nil

        return (name, displayName, desc, cleanedVersion, isPinned, tap, tapRbPath, installedOnRequest)
    }

    /// Get runtime dependencies for a formula from INSTALL_RECEIPT.json
    func getRuntimeDependencies(formulaName: String) -> [String] {
        let cellarPath = "\(brewPrefix)/Cellar/\(formulaName)"

        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: cellarPath)
                .filter({ !$0.hasPrefix(".") }),
              let latestVersion = versions.sorted().last else {
            return []
        }

        let receiptPath = "\(cellarPath)/\(latestVersion)/INSTALL_RECEIPT.json"
        guard let receiptData = try? Data(contentsOf: URL(fileURLWithPath: receiptPath)),
              let receipt = try? JSONSerialization.jsonObject(with: receiptData) as? [String: Any],
              let runtimeDeps = receipt["runtime_dependencies"] as? [[String: Any]] else {
            return []
        }

        var deps: [String] = []
        for dep in runtimeDeps {
            if let fullName = dep["full_name"] as? String {
                deps.append(fullName)
            }
        }
        return deps
    }

    /// Extract name, displayName, description, version, and pin status from cask
    private func getCaskNameDescVersionPin(name: String) async -> (String, String?, String, String, Bool, String?, String?)? {
        let caskroomPath = "\(brewPrefix)/Caskroom/\(name)"

        // Skip symlinks (like xcodes -> xcodes-app)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: caskroomPath),
           let fileType = attrs[.type] as? FileAttributeType,
           fileType == .typeSymbolicLink {
            return nil
        }

        // Use glob pattern to find the cask file: .metadata/*/*/Casks/<name>.*
        let metadataPath = "\(caskroomPath)/.metadata"
        let globPattern = "\(metadataPath)/*/*/Casks/\(name).*"

        var globResult = glob_t()
        defer { globfree(&globResult) }

        guard glob(globPattern, 0, nil, &globResult) == 0,
              globResult.gl_pathc > 0,
              let firstPath = globResult.gl_pathv[0],
              let caskFilePath = String(validatingUTF8: firstPath) else {
            return nil
        }

        // Extract version from path: .metadata/<version>/<timestamp>/Casks/...
        let pathComponents = caskFilePath.components(separatedBy: "/")
        var version: String? = nil
        if let metadataIndex = pathComponents.lastIndex(of: ".metadata"),
           metadataIndex + 1 < pathComponents.count {
            version = pathComponents[metadataIndex + 1]
        }

        guard let finalVersion = version else {
            return nil
        }

        // Strip revision suffix from version (e.g., "3.3.14_1" -> "3.3.14")
        let cleanedVersion = finalVersion.stripBrewRevisionSuffix()

        // Casks don't support pinning
        let isPinned = false

        // Read displayName and description from the cask file (.rb or .json)
        var displayName: String? = nil
        var desc = "No description available"
        if let fileContent = try? String(contentsOfFile: caskFilePath) {
            // Extract name (display name) - casks can have multiple names, take first
            let nameRegex = /name "([^"]+)"/
            if let match = fileContent.firstMatch(of: nameRegex) {
                displayName = String(match.1)
            }

            // Extract description
            let descRegex = /desc "([^"]+)"/
            if let match = fileContent.firstMatch(of: descRegex) {
                desc = String(match.1)
            }
        }

        // Don't load tap info during scan - will be lazy loaded during outdated check if needed
        let tap: String? = nil
        let tapRbPath: String? = nil

        return (name, displayName, desc, cleanedVersion, isPinned, tap, tapRbPath)
    }

    // MARK: - Search

    /// Fetch type-safe package details from Homebrew API
    /// Returns either FormulaDetails or CaskDetails wrapped in PackageDetailsType
    func getPackageDetailsTyped(name: String, cask: Bool) async throws -> PackageDetailsType {
        // First check Homebrew's local cache
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/Homebrew/api")

        let cacheFile = cask ?
            cacheDir.appendingPathComponent("cask/\(name).json") :
            cacheDir.appendingPathComponent("formula/\(name).json")

        let data: Data

        // Check local cache first (faster)
        if FileManager.default.fileExists(atPath: cacheFile.path) {
            data = try Data(contentsOf: cacheFile)
        } else {
            // Fetch from API
            let url = cask ?
                URL(string: "https://formulae.brew.sh/api/cask/\(name).json")! :
                URL(string: "https://formulae.brew.sh/api/formula/\(name).json")!

            (data, _) = try await URLSession.shared.data(from: url)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HomebrewError.jsonParseError
        }

        if cask {
            return .cask(try parseCaskDetails(json: json, name: name))
        } else {
            return .formula(try parseFormulaDetails(json: json, name: name))
        }
    }

    private func parseFormulaDetails(json: [String: Any], name: String) throws -> FormulaDetails {
        // Common fields
        let description = json["desc"] as? String
        let homepage = json["homepage"] as? String
        let license = json["license"] as? String
        let version = (json["versions"] as? [String: Any])?["stable"] as? String
        let caveats = json["caveats"] as? String
        let dependencies = (json["dependencies"] as? [String]) ?? []
        let conflicts = (json["conflicts_with"] as? [String]) ?? []
        let conflictsReasons = (json["conflicts_with_reasons"] as? [String]) ?? []
        let tap = json["tap"] as? String
        let fullName = json["full_name"] as? String
        let deprecated = (json["deprecated"] as? Bool) ?? false
        let deprecationDate = json["deprecation_date"] as? String
        let deprecationReason = json["deprecation_reason"] as? String
        let disabled = (json["disabled"] as? Bool) ?? false
        let disableDate = json["disable_date"] as? String
        let disableReason = json["disable_reason"] as? String

        // Formula-specific fields
        let kegOnly = json["keg_only"] as? Bool
        let kegOnlyReason: String?
        if let kegOnlyReasonDict = json["keg_only_reason"] as? [String: Any],
           let explanation = kegOnlyReasonDict["explanation"] as? String, !explanation.isEmpty {
            kegOnlyReason = explanation
        } else if let kegOnlyReasonDict = json["keg_only_reason"] as? [String: Any],
                  let reason = kegOnlyReasonDict["reason"] as? String {
            switch reason {
            case ":provided_by_macos":
                kegOnlyReason = "macOS already provides this software"
            case ":versioned_formula":
                kegOnlyReason = "This is a versioned formula"
            case ":shadowed_by_macos":
                kegOnlyReason = "Shadowed by macOS"
            default:
                kegOnlyReason = "Not symlinked to Homebrew prefix"
            }
        } else {
            kegOnlyReason = nil
        }

        let requirements = (json["requirements"] as? [String]) ?? []
        let buildDependencies = (json["build_dependencies"] as? [String]) ?? []
        let optionalDependencies = (json["optional_dependencies"] as? [String]) ?? []
        let recommendedDependencies = (json["recommended_dependencies"] as? [String]) ?? []
        let usesFromMacos = (json["uses_from_macos"] as? [Any])?.compactMap { item -> String? in
            if let str = item as? String {
                return str
            } else if let dict = item as? [String: Any], let key = dict.keys.first {
                // Handle {"bison": "build"} format - just show the name
                return key
            }
            return nil
        } ?? []
        let versionedFormulae = (json["versioned_formulae"] as? [String]) ?? []
        let aliases = (json["aliases"] as? [String]) ?? []

        // Service info (only if actually defined, not just null)
        let service: ServiceInfo?
        if let serviceDict = json["service"] as? [String: Any], !serviceDict.isEmpty {
            let run = (serviceDict["run"] as? [String]) ?? []
            let runType = serviceDict["run_type"] as? String
            let workingDir = serviceDict["working_dir"] as? String
            let keepAlive = (serviceDict["keep_alive"] as? [String: Any])?["always"] as? Bool

            // Only create ServiceInfo if there's actual data
            if !run.isEmpty || runType != nil || workingDir != nil || keepAlive != nil {
                service = ServiceInfo(run: run.isEmpty ? nil : run, runType: runType, workingDir: workingDir, keepAlive: keepAlive)
            } else {
                service = nil
            }
        } else {
            service = nil
        }

        // Replacement suggestions
        let deprecationReplacementFormula = json["deprecation_replacement_formula"] as? String
        let deprecationReplacementCask = json["deprecation_replacement_cask"] as? String
        let disableReplacementFormula = json["disable_replacement_formula"] as? String
        let disableReplacementCask = json["disable_replacement_cask"] as? String

        return FormulaDetails(
            name: name,
            description: description,
            homepage: homepage,
            license: license,
            version: version,
            dependencies: dependencies.isEmpty ? nil : dependencies,
            caveats: caveats,
            tap: tap,
            fullName: fullName,
            isDeprecated: deprecated,
            deprecationReason: deprecationReason,
            deprecationDate: deprecationDate,
            isDisabled: disabled,
            disableDate: disableDate,
            disableReason: disableReason,
            conflictsWith: conflicts.isEmpty ? nil : conflicts,
            conflictsWithReasons: conflictsReasons.isEmpty ? nil : conflictsReasons,
            isBottled: version != nil,
            isKegOnly: kegOnly,
            kegOnlyReason: kegOnlyReason,
            buildDependencies: buildDependencies.isEmpty ? nil : buildDependencies,
            optionalDependencies: optionalDependencies.isEmpty ? nil : optionalDependencies,
            recommendedDependencies: recommendedDependencies.isEmpty ? nil : recommendedDependencies,
            usesFromMacos: usesFromMacos.isEmpty ? nil : usesFromMacos,
            aliases: aliases.isEmpty ? nil : aliases,
            versionedFormulae: versionedFormulae.isEmpty ? nil : versionedFormulae,
            requirements: requirements.isEmpty ? nil : requirements.joined(separator: ", "),
            service: service,
            deprecationReplacementFormula: deprecationReplacementFormula,
            deprecationReplacementCask: deprecationReplacementCask,
            disableReplacementFormula: disableReplacementFormula,
            disableReplacementCask: disableReplacementCask
        )
    }

    private func parseCaskDetails(json: [String: Any], name: String) throws -> CaskDetails {
        // Common fields
        let description = json["desc"] as? String
        let homepage = json["homepage"] as? String
        let license = json["license"] as? String
        let version = json["version"] as? String
        let caveats = json["caveats"] as? String
        let dependencies = ((json["depends_on"] as? [String: Any])?["formula"] as? [String]) ?? []
        let conflicts = (json["conflicts_with"] as? [String]) ?? []
        let conflictsReasons = (json["conflicts_with_reasons"] as? [String]) ?? []
        let tap = json["tap"] as? String
        let fullName = (json["full_token"] as? String) ?? (json["token"] as? String)
        let deprecated = (json["deprecated"] as? Bool) ?? false
        let deprecationDate = json["deprecation_date"] as? String
        let deprecationReason = json["deprecation_reason"] as? String
        let disabled = (json["disabled"] as? Bool) ?? false
        let disableDate = json["disable_date"] as? String
        let disableReason = json["disable_reason"] as? String

        // Cask-specific fields
        let caskName = (json["name"] as? [String]) ?? []
        let autoUpdates = json["auto_updates"] as? Bool
        let artifacts = (json["artifacts"] as? [[String: Any]])?.compactMap { $0.keys.first }
        let url = json["url"] as? String
        let appcast = json["appcast"] as? String
        let bundleVersion = json["bundle_version"] as? String
        let bundleShortVersion = json["bundle_short_version"] as? String

        // System requirements
        let minimumMacOSVersion: String?
        if let dependsOn = json["depends_on"] as? [String: Any],
           let macosDict = dependsOn["macos"] as? [String: Any],
           let firstKey = macosDict.keys.first {
            let versionArray = macosDict[firstKey] as? [String] ?? []
            minimumMacOSVersion = "\(firstKey) \(versionArray.first ?? "")"
        } else {
            minimumMacOSVersion = nil
        }

        let architectureRequirement: ArchRequirement?
        if let dependsOn = json["depends_on"] as? [String: Any],
           let archArray = dependsOn["arch"] as? [String] {
            if archArray.contains("x86_64") && archArray.contains("arm64") {
                architectureRequirement = .universal
            } else if archArray.contains("x86_64") {
                architectureRequirement = .intel
            } else if archArray.contains("arm64") {
                architectureRequirement = .arm
            } else {
                architectureRequirement = nil
            }
        } else {
            architectureRequirement = nil
        }

        // Replacement suggestions
        let deprecationReplacementFormula = json["deprecation_replacement_formula"] as? String
        let deprecationReplacementCask = json["deprecation_replacement_cask"] as? String
        let disableReplacementFormula = json["disable_replacement_formula"] as? String
        let disableReplacementCask = json["disable_replacement_cask"] as? String

        return CaskDetails(
            name: name,
            description: description,
            homepage: homepage,
            license: license,
            version: version,
            dependencies: dependencies.isEmpty ? nil : dependencies,
            caveats: caveats,
            tap: tap,
            fullName: fullName,
            isDeprecated: deprecated,
            deprecationReason: deprecationReason,
            deprecationDate: deprecationDate,
            isDisabled: disabled,
            disableDate: disableDate,
            disableReason: disableReason,
            conflictsWith: conflicts.isEmpty ? nil : conflicts,
            conflictsWithReasons: conflictsReasons.isEmpty ? nil : conflictsReasons,
            caskName: caskName.isEmpty ? nil : caskName,
            autoUpdates: autoUpdates,
            artifacts: artifacts?.isEmpty == false ? artifacts : nil,
            url: url,
            appcast: appcast,
            minimumMacOSVersion: minimumMacOSVersion,
            architectureRequirement: architectureRequirement,
            bundleVersion: bundleVersion,
            bundleShortVersion: bundleShortVersion,
            deprecationReplacementFormula: deprecationReplacementFormula,
            deprecationReplacementCask: deprecationReplacementCask,
            disableReplacementFormula: disableReplacementFormula,
            disableReplacementCask: disableReplacementCask
        )
    }

    func getAnalytics(name: String, cask: Bool) async throws -> HomebrewAnalytics {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/Homebrew/api")

        let cacheFile = cask ?
            cacheDir.appendingPathComponent("cask/\(name).json") :
            cacheDir.appendingPathComponent("formula/\(name).json")

        let data: Data

        // Check local cache first (Homebrew's cache)
        if FileManager.default.fileExists(atPath: cacheFile.path) {
            data = try Data(contentsOf: cacheFile)
        } else {
            // Fetch from API (Homebrew will cache it automatically)
            let url = cask ?
                URL(string: "https://formulae.brew.sh/api/cask/\(name).json")! :
                URL(string: "https://formulae.brew.sh/api/formula/\(name).json")!

            (data, _) = try await URLSession.shared.data(from: url)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let analytics = json["analytics"] as? [String: Any] else {
            throw HomebrewError.jsonParseError
        }

        if cask {
            // Cask: simpler structure {"install": {"30d": {"name": 123}}}
            let install = analytics["install"] as? [String: Any]
            let install30d = (install?["30d"] as? [String: Int])?.values.first
            let install90d = (install?["90d"] as? [String: Int])?.values.first
            let install365d = (install?["365d"] as? [String: Int])?.values.first

            return HomebrewAnalytics(
                install30d: install30d,
                install90d: install90d,
                install365d: install365d
            )
        } else {
            // Formula: only fetch install counts (not install_on_request or build_error)
            let install = analytics["install"] as? [String: Any]
            let install30d = (install?["30d"] as? [String: Int])?.values.reduce(0, +)
            let install90d = (install?["90d"] as? [String: Int])?.values.reduce(0, +)
            let install365d = (install?["365d"] as? [String: Int])?.values.reduce(0, +)

            return HomebrewAnalytics(
                install30d: install30d,
                install90d: install90d,
                install365d: install365d
            )
        }
    }

    // MARK: - Package Management

    func installPackage(name: String, cask: Bool) async throws {
        logger.log(.homebrew, "📦 Installing package: \(name) (type: \(cask ? "cask" : "formula"))")

        var arguments = ["install"]
        if cask {
            arguments.append("--cask")
            arguments.append("--no-quarantine")
        } else {
            arguments.append("--formula")
        }
        arguments.append(name)

        do {
            let result = try await runBrewCommand(arguments)

            // Check for actual errors (not warnings)
            let combinedOutput = result.output + result.error
            if result.error.contains("Error:") && !combinedOutput.contains("was successfully installed") {
                logger.log(.homebrew, "❌ Install failed for \(name): \(result.error)")
                throw HomebrewError.commandFailed(result.error)
            }

            logger.log(.homebrew, "✓ Installed \(name) successfully")
        } catch {
            logger.log(.homebrew, "❌ Install failed for \(name): \(error.localizedDescription)")
            throw error
        }
    }

    func uninstallPackage(name: String) async throws {
        logger.log(.homebrew, "🗑️ Uninstalling package: \(name)")

        let arguments = ["uninstall", name]

        do {
            let result = try await runBrewCommand(arguments)

            if result.error.contains("Error") || result.error.contains("because it is required by") {
                logger.log(.homebrew, "❌ Uninstall failed for \(name): \(result.error)")
                throw HomebrewError.commandFailed(result.error)
            }

            logger.log(.homebrew, "✓ Uninstalled \(name) successfully")
        } catch {
            logger.log(.homebrew, "❌ Uninstall failed for \(name): \(error.localizedDescription)")
            throw error
        }
    }

    func pinPackage(name: String) async throws {
        let arguments = ["pin", name]
        let result = try await runBrewCommand(arguments)

        if !result.error.isEmpty && result.error.contains("Error") {
            throw HomebrewError.commandFailed(result.error)
        }
    }

    func unpinPackage(name: String) async throws {
        let arguments = ["unpin", name]
        let result = try await runBrewCommand(arguments)

        if !result.error.isEmpty && result.error.contains("Error") {
            throw HomebrewError.commandFailed(result.error)
        }
    }

    func upgradePackage(name: String) async throws {
        logger.log(.homebrew, "⬆️ Upgrading package: \(name)")

        let arguments = ["upgrade", name]

        do {
            let result = try await runBrewCommand(arguments)

            if result.error.contains("Error") {
                logger.log(.homebrew, "❌ Upgrade failed for \(name): \(result.error)")
                throw HomebrewError.commandFailed(result.error)
            }

            logger.log(.homebrew, "✓ Upgraded \(name) successfully")
        } catch {
            logger.log(.homebrew, "❌ Upgrade failed for \(name): \(error.localizedDescription)")
            throw error
        }
    }

    func upgradeAllPackages() async throws {
        let arguments = ["upgrade"]
        let result = try await runBrewCommand(arguments)

        if result.error.contains("Error") {
            throw HomebrewError.commandFailed(result.error)
        }
    }

    /// Outdated package information with versions
    struct HomebrewOutdatedPackage {
        let name: String
        let installedVersion: String
        let availableVersion: String
        let isPinned: Bool
        let isCask: Bool
    }

    /// Get outdated packages using hybrid approach: API for core packages, .rb file reading for tap packages
    /// Much faster than `brew outdated` (~3.5x speedup) for core packages, accurate for tap packages
    /// Returns only packages that have updates available
    func getOutdatedPackagesHybrid(formulae: [InstalledPackage], casks: [InstalledPackage]) async -> [HomebrewOutdatedPackage] {
        let allPackages = formulae + casks
        logger.log(.homebrew, "Starting Homebrew update check for \(allPackages.count) packages (\(formulae.count) formulae, \(casks.count) casks)")

        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Checking for outdated packages (\(allPackages.count) total)...\n"
        }

        // Step 1: Try to check ALL packages via API first (fast path)
        // Assume packages with tap == nil are core packages (most common case)
        logger.log(.homebrew, "Step 1: Checking packages via public API (fast path)")
        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Checking packages via API...\n"
        }
        let (coreOutdated, apiFailedPackages) = await checkCorePackagesViaAPI(allPackages)

        logger.log(.homebrew, "  API check complete: \(coreOutdated.count) outdated, \(apiFailedPackages.count) API failures (likely tap packages)")

        // Step 2: For packages where API failed, lazy-load tap info and check manually
        // This handles tap packages that don't exist in public API (typically 0-3 packages)
        if !apiFailedPackages.isEmpty {
            logger.log(.homebrew, "Step 2: Checking \(apiFailedPackages.count) tap packages manually")
            await MainActor.run { [weak self] in
                guard let self = self, self.consoleEnabled else { return }
                self.consoleOutput += "Checking \(apiFailedPackages.count) tap packages...\n"
            }
            let tapOutdated = await checkTapPackagesManually(apiFailedPackages)
            logger.log(.homebrew, "  Manual tap check complete: \(tapOutdated.count) outdated")

            let totalOutdated = coreOutdated.count + tapOutdated.count
            logger.log(.homebrew, "Found \(totalOutdated) Homebrew updates available")

            await MainActor.run { [weak self] in
                guard let self = self, self.consoleEnabled else { return }
                self.consoleOutput += "Found \(totalOutdated) outdated packages\n"
            }

            // Filter out Pearcleaner (has dedicated UI banner in Updater view)
            let allOutdated = coreOutdated + tapOutdated
            return allOutdated.filter { $0.name != "pearcleaner" }
        }

        logger.log(.homebrew, "Found \(coreOutdated.count) Homebrew updates available")

        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Found \(coreOutdated.count) outdated packages\n"
        }

        // Filter out Pearcleaner (has dedicated UI banner in Updater view)
        return coreOutdated.filter { $0.name != "pearcleaner" }
    }

    /// Check core Homebrew packages using public API (fast)
    /// Returns tuple: (outdatedPackages, apiFailedPackages)
    private func checkCorePackagesViaAPI(_ packages: [InstalledPackage]) async -> (outdated: [HomebrewOutdatedPackage], apiFailed: [InstalledPackage]) {
        // Fetch latest versions from API using parallel requests
        let latestVersions = await withTaskGroup(of: (String, String?, String?, Bool).self, returning: [String: (String, String?, Bool)].self) { group in
            for package in packages {
                group.addTask {
                    // Construct API URL based on package type
                    let urlString = package.isCask
                        ? "https://formulae.brew.sh/api/cask/\(package.name).json"
                        : "https://formulae.brew.sh/api/formula/\(package.name).json"

                    guard let url = URL(string: urlString) else {
                        return (package.name, nil, nil, package.isCask)
                    }

                    // Use cache policy to bypass HTTP cache (prevents stale API data after upgrades)
                    // Homebrew API returns Cache-Control: max-age=600 (10 minutes)
                    let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)

                    guard let (data, _) = try? await URLSession.shared.data(for: request),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        return (package.name, nil, nil, package.isCask)
                    }

                    // Extract version based on package type
                    let rawVersion: String? = package.isCask
                        ? json["version"] as? String
                        : (json["versions"] as? [String: Any])?["stable"] as? String

                    // Extract bundle version for casks (used as tiebreaker)
                    let bundleVersion: String? = package.isCask
                        ? json["bundle_version"] as? String
                        : nil

                    // Strip revision suffix from both formulae and cask API versions for consistent comparison
                    // This is defensive - ensures consistency even if Homebrew API format changes in future
                    // (Installed versions already have revision suffix stripped during scan - lines 296, 395)
                    //
                    // Background:
                    // - Formulae API: Stores revision in separate "revision" field (never in version string currently)
                    // - Cask API: Inconsistently includes/excludes revision in version string
                    // - Local directories: Always include revision suffix in directory name (both types)
                    //
                    // By stripping universally, we ensure consistent comparison regardless of API format changes
                    let version = rawVersion?.stripBrewRevisionSuffix()

                    return (package.name, version, bundleVersion, package.isCask)
                }
            }

            // Collect results into dictionary (version, bundleVersion, isCask)
            var results: [String: (String, String?, Bool)] = [:]
            for await (name, version, bundleVersion, isCask) in group {
                if let version = version {
                    results[name] = (version, bundleVersion, isCask)
                }
            }
            return results
        }

        // Track packages that failed API lookup and build outdated list
        var apiFailedPackages: [InstalledPackage] = []
        var outdatedPackages: [HomebrewOutdatedPackage] = []

        // Compare installed vs latest and build outdated package list
        for package in packages {
            guard let installedVersion = package.version else {
                continue  // No installed version
            }

            // For casks, use ACTUAL app version from AppState.sortedApps instead of stale Homebrew metadata
            // This eliminates false positives when apps auto-update via Sparkle but Homebrew record isn't synced
            let actualVersion: String
            let installedBundleVersion: String?
            if package.isCask {
                // Find matching app in sortedApps by cask name
                if let appInfo = await MainActor.run(body: { AppState.shared.sortedApps.first(where: { $0.cask == package.name }) }) {
                    actualVersion = appInfo.appVersion  // Use actual version from Info.plist (ground truth)
                    installedBundleVersion = appInfo.appBuildNumber  // CFBundleVersion for tiebreaker
                    logger.log(.homebrew, "  🔍 Using actual app version for \(package.name): \(actualVersion) (build: \(installedBundleVersion ?? "nil")) (Homebrew metadata: \(installedVersion))")
                } else {
                    actualVersion = installedVersion  // Fallback to Homebrew metadata if app not found
                    installedBundleVersion = nil
                    logger.log(.homebrew, "  ⚠️ App not found in sortedApps for cask \(package.name), using Homebrew metadata")
                }
            } else {
                actualVersion = installedVersion  // For formulae, use Homebrew metadata (no Info.plist)
                installedBundleVersion = nil
            }

            if let (latestVersion, apiBundleVersion, _) = latestVersions[package.name] {
                // API call succeeded - package exists in public API

                // Clean versions for semantic comparison (strip build numbers, "latest", etc.)
                let installedClean = actualVersion.stripBrewRevisionSuffix()
                let availableClean = latestVersion.stripBrewRevisionSuffix()

                // Use Version struct for semantic comparison (same logic as HomebrewUpdateChecker)
                let installed = Version(versionNumber: installedClean, buildNumber: nil)
                let available = Version(versionNumber: availableClean, buildNumber: nil)

                // Determine if update is available
                var isOutdated = false

                if !installed.isEmpty && !available.isEmpty {
                    if available > installed {
                        // Clear case: API version is newer
                        isOutdated = true
                    } else if available == installed && package.isCask {
                        // Versions are equal - use bundle version as tiebreaker
                        if let installedBundle = installedBundleVersion,
                           let apiBundle = apiBundleVersion {
                            let installedBundleVer = Version(versionNumber: installedBundle, buildNumber: nil)
                            let apiBundleVer = Version(versionNumber: apiBundle, buildNumber: nil)

                            if apiBundleVer > installedBundleVer {
                                isOutdated = true
                                logger.log(.homebrew, "  🔍 Version equal, using bundle version tiebreaker: \(installedBundle) → \(apiBundle)")
                            }
                        }
                    }
                }

                // Only mark outdated if update is available
                // This prevents false positives where app is actually newer than API (Sparkle updated ahead)
                if isOutdated {
                    logger.log(.homebrew, "  📦 UPDATE AVAILABLE: \(package.name) - \(actualVersion) → \(latestVersion) (\(package.isCask ? "cask" : "formula"))")
                    outdatedPackages.append(HomebrewOutdatedPackage(
                        name: package.name,
                        installedVersion: actualVersion,  // Use actual version for display
                        availableVersion: latestVersion,
                        isPinned: package.isPinned,
                        isCask: package.isCask
                    ))
                } else {
                    logger.log(.homebrew, "  ✓ Up to date: \(package.name) (actual: \(actualVersion), available: \(latestVersion))")
                }
            } else {
                // API call failed - likely a tap package
                logger.log(.homebrew, "  ⚠️ API lookup failed for \(package.name) - will check manually")
                apiFailedPackages.append(package)
            }
        }

        return (outdatedPackages, apiFailedPackages)
    }

    /// Check tap packages by reading their .rb files directly (accurate, like Homebrew does)
    /// Lazy-loads tap info from INSTALL_RECEIPT.json on-demand
    private func checkTapPackagesManually(_ packages: [InstalledPackage]) async -> [HomebrewOutdatedPackage] {
        var outdatedPackages: [HomebrewOutdatedPackage] = []

        for package in packages {
            logger.log(.homebrew, "  Checking tap package: \(package.name)")
            guard let installedVersion = package.version else {
                logger.log(.homebrew, "    ⚠️ Skipped - no installed version found")
                continue  // Can't check without installed version
            }

            // Lazy-load tap info from INSTALL_RECEIPT if not already cached
            var rbPath = package.tapRbPath
            if rbPath == nil {
                // Read INSTALL_RECEIPT.json to get tap .rb file path
                let receiptPath: String
                if package.isCask {
                    receiptPath = "\(brewPrefix)/Caskroom/\(package.name)/.metadata/INSTALL_RECEIPT.json"
                } else {
                    // For formulae, need to find the version directory
                    let cellarPath = "\(brewPrefix)/Cellar/\(package.name)"
                    guard let versions = try? FileManager.default.contentsOfDirectory(atPath: cellarPath)
                            .filter({ !$0.hasPrefix(".") }),
                          let latestVersion = versions.sorted().last else {
                        continue
                    }
                    receiptPath = "\(cellarPath)/\(latestVersion)/INSTALL_RECEIPT.json"
                }

                // Try to read tap rb path from INSTALL_RECEIPT
                if let receiptData = try? Data(contentsOf: URL(fileURLWithPath: receiptPath)),
                   let receipt = try? JSONSerialization.jsonObject(with: receiptData) as? [String: Any],
                   let source = receipt["source"] as? [String: Any],
                   let path = source["path"] as? String {
                    rbPath = path
                }
            }

            // If we still don't have an rb path, skip this package
            guard let finalRbPath = rbPath else {
                logger.log(.homebrew, "    ⚠️ Skipped - no .rb file path found")
                continue
            }

            logger.log(.homebrew, "    Reading .rb file: \(finalRbPath)")

            // Read the tap's .rb file
            guard let rbContent = try? String(contentsOfFile: finalRbPath) else {
                logger.log(.homebrew, "    ❌ Failed to read .rb file")
                continue  // Rb file not readable
            }

            // Parse version from .rb file using line-by-line search
            // Look for lines that ONLY contain: version "X.Y.Z"
            // This avoids matching comments or other occurrences
            var tapVersion: String?
            for line in rbContent.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Match standalone version declarations: version "X.Y.Z"
                // Pattern ensures it's on its own line (Ruby requirement)
                let versionRegex = /^version\s+"([^"]+)"$/
                if let match = trimmed.firstMatch(of: versionRegex) {
                    tapVersion = String(match.1).stripBrewRevisionSuffix()
                    break  // Found it, stop searching
                }
            }

            // If version not found, skip this package (don't show as outdated)
            guard let availableVersion = tapVersion else {
                logger.log(.homebrew, "    ⚠️ No standalone version line found - skipping")
                continue
            }

            logger.log(.homebrew, "    Tap version from .rb: \(availableVersion)")

            // Compare using semantic Version (not string comparison)
            let installedClean = installedVersion.stripBrewRevisionSuffix()
            let availableClean = availableVersion.stripBrewRevisionSuffix()

            logger.log(.homebrew, "    Comparing (cleaned): \(installedClean) vs \(availableClean)")

            // Use Version struct for semantic comparison
            let installed = Version(versionNumber: installedClean, buildNumber: nil)
            let available = Version(versionNumber: availableClean, buildNumber: nil)

            // Only add if truly outdated
            guard !installed.isEmpty && !available.isEmpty && available > installed else {
                logger.log(.homebrew, "    ✓ Up to date or invalid version")
                continue
            }

            logger.log(.homebrew, "    📦 UPDATE AVAILABLE: \(installedVersion) → \(availableVersion)")
            outdatedPackages.append(HomebrewOutdatedPackage(
                name: package.name,
                installedVersion: installedVersion,
                availableVersion: availableVersion,
                isPinned: package.isPinned,
                isCask: package.isCask
            ))
        }

        return outdatedPackages
    }

    // MARK: - Tap Management

    func loadTaps() async throws -> [HomebrewTapInfo] {
        let arguments = ["tap"]
        let result = try await runBrewCommand(arguments)

        let tapNames = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        return tapNames.map { name in
            let isOfficial = name.starts(with: "homebrew/")
            return HomebrewTapInfo(name: name, isOfficial: isOfficial)
        }
    }

    func addTap(name: String) async throws {
        let arguments = ["tap", name]
        let result = try await runBrewCommand(arguments)

        if result.error.contains("Error") {
            throw HomebrewError.commandFailed(result.error)
        }
    }

    func removeTap(name: String, force: Bool = false) async throws {
        var arguments = ["untap"]
        if force {
            arguments.append("--force")
        }
        arguments.append(name)

        let result = try await runBrewCommand(arguments)

        if !result.error.contains("Untapped") && result.error.contains("Error") {
            throw HomebrewError.commandFailed(result.error)
        }
    }

    // MARK: - Maintenance

    func getBrewVersion() async throws -> String {
        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Getting Homebrew version...\n"
        }

        // Use git directly for faster version check (avoids spawning brew process)
        // --abbrev=0 returns clean semantic version (e.g., "4.6.19") for consistent display
        // Works with both full clones and shallow clones
        let gitCommand = "git -C \(brewPrefix) describe --tags --abbrev=0 2>/dev/null"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", gitCommand]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus == 0 && !output.isEmpty {
            await MainActor.run { [weak self] in
                guard let self = self, self.consoleEnabled else { return }
                self.consoleOutput += "Homebrew version: \(output)\n"
            }
            return output  // Returns "4.6.19"
        }

        // Fallback to brew command if git fails
        let arguments = ["-v"]
        let result = try await runBrewCommand(arguments)
        let components = result.output.components(separatedBy: " ")
        if components.count >= 2 {
            let version = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            // Extract semantic version from potential full string (e.g., "4.6.19-22-ga6c4bc4" -> "4.6.19")
            if let match = version.range(of: #"^\d+\.\d+\.\d+"#, options: .regularExpression) {
                return String(version[match])
            }
            return version
        }
        return "Unknown"
    }

    func getLatestBrewVersionFromGitHub() async throws -> String {
        let url = URL(string: "https://api.github.com/repos/Homebrew/brew/releases/latest")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            throw HomebrewError.jsonParseError
        }
        return tagName
    }

    func checkForBrewUpdate() async throws -> (current: String, latest: String, updateAvailable: Bool) {
        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Checking for Homebrew updates...\n"
        }

        // Get current semantic version (e.g., "4.6.19")
        let currentVersion = try await getBrewVersion()

        // Get latest version from GitHub releases
        let latestVersion = try await getLatestBrewVersionFromGitHub()

        // Compare semantic versions
        let updateAvailable = compareSemanticVersions(current: currentVersion, latest: latestVersion)

        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            if updateAvailable {
                self.consoleOutput += "Update available: \(currentVersion) → \(latestVersion)\n"
            } else {
                self.consoleOutput += "Homebrew is up to date (\(currentVersion))\n"
            }
        }

        return (current: currentVersion, latest: latestVersion, updateAvailable: updateAvailable)
    }

    private func compareSemanticVersions(current: String, latest: String) -> Bool {
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }

        guard currentComponents.count >= 3, latestComponents.count >= 3 else {
            printOS("Brew version check - Semantic comparison failed: invalid version format. Current components: \(currentComponents.count), Latest components: \(latestComponents.count)")
            return false
        }

        for i in 0..<min(currentComponents.count, latestComponents.count) {
            if latestComponents[i] > currentComponents[i] {
                return true
            } else if latestComponents[i] < currentComponents[i] {
                return false
            }
        }

        return false
    }

    func updateBrew() async throws {
        let arguments = ["update", "-v"]
        let result = try await runBrewCommand(arguments)

        if result.error.contains("Error") {
            throw HomebrewError.commandFailed(result.error)
        }
    }

    func runDoctor() async throws -> String {
        let arguments = ["doctor"]
        let result = try await runBrewCommand(arguments)
        return result.output + result.error
    }

    func runCleanup(dryRun: Bool = false) async throws -> (bytes: Int64, formatted: String)? {
        // Collect all cleanable cache and log files (or calculate their size if dry-run)
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let cacheDir = homeDir.appendingPathComponent("Library/Caches/Homebrew")
        let cacheSubdirs = ["Cask", "api-source", "gh-actions-artifact", "cargo_cache", "go_cache", "go_mod_cache", "glide_home", "java_cache", "npm_cache", "pip_cache", "gclient_cache"]
        let logsDir = homeDir.appendingPathComponent("Library/Logs/Homebrew")
        let fileManager = FileManager.default

        var filesToDelete: [URL] = []
        var totalBytes: Int64 = 0

        // 1. Everything in downloads/ folder
        let downloadsDir = cacheDir.appendingPathComponent("downloads")
        if fileManager.fileExists(atPath: downloadsDir.path) {
            do {
                let downloadFiles = try fileManager.contentsOfDirectory(at: downloadsDir, includingPropertiesForKeys: nil, options: [])
                if dryRun {
                    for file in downloadFiles {
                        totalBytes += totalSizeOnDisk(for: file)
                    }
                } else {
                    filesToDelete.append(contentsOf: downloadFiles)
                }
            } catch {
                // Continue if we can't read downloads directory
            }
        }

        // 2. Additional cache subdirectories (emulate brew cleanup --prune=all)
        // brew's nested_cache? removes entire directories with FileUtils.rm_rf
        for subdirName in cacheSubdirs {
            let subdirURL = cacheDir.appendingPathComponent(subdirName)
            if fileManager.fileExists(atPath: subdirURL.path) {
                if dryRun {
                    totalBytes += totalSizeOnDisk(for: subdirURL)
                } else {
                    // Delete entire subdirectory (brew uses FileUtils.rm_rf on nested_cache directories)
                    await MainActor.run { [weak self] in
                        guard let self = self, self.consoleEnabled else { return }
                        self.consoleOutput += "Removing \(subdirName)/\n"
                    }
                    filesToDelete.append(subdirURL)
                }
            }
        }

        // 3. Non-directory files and versioned directories in root Homebrew cache folder
        if fileManager.fileExists(atPath: cacheDir.path) {
            do {
                let contents = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.isDirectoryKey], options: [])
                for itemURL in contents {
                    let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])

                    if resourceValues.isDirectory == false {
                        // Skip .cleaned file (Homebrew's periodic cleanup tracker)
                        if itemURL.lastPathComponent != ".cleaned" {
                            if dryRun {
                                totalBytes += totalSizeOnDisk(for: itemURL)
                            } else {
                                filesToDelete.append(itemURL)
                            }
                        }
                    } else if itemURL.lastPathComponent.contains("--") {
                        // Also remove directories with "--" (old formula/cask version caches, HEAD installs)
                        if dryRun {
                            totalBytes += totalSizeOnDisk(for: itemURL)
                        } else {
                            filesToDelete.append(itemURL)
                        }
                    }
                }
            } catch {
                // Continue if we can't read cache directory
            }
        }

        // 4. Everything in logs directory
        if fileManager.fileExists(atPath: logsDir.path) {
            if dryRun {
                totalBytes += totalSizeOnDisk(for: logsDir)
            } else {
                do {
                    let logFiles = try fileManager.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil, options: [])
                    filesToDelete.append(contentsOf: logFiles)
                } catch {
                    // Continue if we can't read logs directory
                }
            }
        }

        // Return results based on mode
        if dryRun {
            // Format as human-readable (must run on main thread - ByteCountFormatter is not thread-safe)
            let bytesToFormat = totalBytes
            let formatted = await MainActor.run {
                ByteCountFormatter.string(fromByteCount: bytesToFormat, countStyle: .file)
            }
            return (bytes: totalBytes, formatted: formatted)
        } else {
            // Move all files to Trash in a bundle
            if !filesToDelete.isEmpty {
                await MainActor.run { [weak self] in
                    guard let self = self, self.consoleEnabled else { return }
                    self.consoleOutput += "Cleaning \(filesToDelete.count) items...\n"
                }
                let _ = FileManagerUndo.shared.deleteFiles(at: filesToDelete, bundleName: "BrewCleanup")
                await MainActor.run { [weak self] in
                    guard let self = self, self.consoleEnabled else { return }
                    self.consoleOutput += "Cleanup complete\n"
                }
            } else {
                await MainActor.run { [weak self] in
                    guard let self = self, self.consoleEnabled else { return }
                    self.consoleOutput += "No files to clean\n"
                }
            }
            return nil
        }
    }

    func performFullCleanup() async throws {
        // Fast operation: delete cache and logs to Trash (blocks UI briefly ~50ms)
        _ = try await runCleanup()

        // Slow operation: run brew autoremove in background without blocking UI
        Task.detached(priority: .background) {
            let autoremoveArgs = ["autoremove"]
            _ = try? await HomebrewController.shared.runBrewCommand(autoremoveArgs)
        }
    }

    func getAnalyticsStatus() async throws -> Bool {
        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Checking analytics status...\n"
        }

        // Use git config directly for faster check (avoids spawning brew process)
        let gitCommand = "git -C \(brewPrefix) config --get homebrew.analyticsdisabled 2>/dev/null"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", gitCommand]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // If config key doesn't exist or is empty, analytics are enabled by default
        // If set to "true", analytics are disabled
        // If set to "false", analytics are enabled
        let analyticsEnabled: Bool
        if output.isEmpty {
            analyticsEnabled = true  // Analytics enabled by default
        } else {
            analyticsEnabled = output.lowercased() != "true"  // Return true if NOT disabled
        }

        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Analytics are \(analyticsEnabled ? "enabled" : "disabled")\n"
        }

        return analyticsEnabled
    }

    func setAnalyticsStatus(enabled: Bool) async throws {
        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Setting analytics to \(enabled ? "enabled" : "disabled")...\n"
        }

        // Use git config directly for faster toggle (avoids spawning brew process)
        let value = enabled ? "false" : "true"  // Inverted: "false" means NOT disabled (i.e., enabled)
        let gitCommand = "git -C \(brewPrefix) config --replace-all homebrew.analyticsdisabled \(value) 2>&1"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", gitCommand]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            await MainActor.run { [weak self] in
                guard let self = self, self.consoleEnabled else { return }
                self.consoleOutput += "Error: \(error)\n"
            }
            throw HomebrewError.commandFailed("Failed to set analytics status: \(error)")
        }

        await MainActor.run { [weak self] in
            guard let self = self, self.consoleEnabled else { return }
            self.consoleOutput += "Analytics status updated successfully\n"
        }
    }

    func calculateCacheSize() async -> (bytes: Int64, formatted: String) {
        // Wrapper around runCleanup with dry-run mode
        // Returns size of cleanable cache without actually deleting anything
        return try! await runCleanup(dryRun: true) ?? (0, "0 bytes")
    }

    func calculateFormulaSize(name: String, version: String) async -> (Int64, String) {
        // Calculate size of formula installation in Cellar directory
        // Path format: /opt/homebrew/Cellar/<formula>/<version>
        let cellarPath = "\(brewPrefix)/Cellar/\(name)/\(version)"
        let cellarURL = URL(fileURLWithPath: cellarPath)

        let fileManager = FileManager.default

        // Fast path: Try direct version match first (most formulae don't have revisions)
        var actualCellarURL = cellarURL
        if !fileManager.fileExists(atPath: cellarPath) {
            // Fallback: Search for version with revision suffix (e.g., "25.1.0_1")
            // Also handle HEAD installations (directory named "HEAD-abc1234" but version shows as "2025.10.22")
            let formulaBasePath = "\(brewPrefix)/Cellar/\(name)"
            if let versionDirs = try? fileManager.contentsOfDirectory(atPath: formulaBasePath) {
                // Find directory whose sanitized version matches input version
                // OR directory that starts with "HEAD" (for HEAD installations)
                if let matchingDir = versionDirs.first(where: {
                    $0.stripBrewRevisionSuffix() == version || $0.hasPrefix("HEAD")
                }) {
                    actualCellarURL = URL(fileURLWithPath: "\(formulaBasePath)/\(matchingDir)")
                } else {
                    return (0, "0 KB")
                }
            } else {
                return (0, "0 KB")
            }
        }

        let totalBytes = totalSizeOnDisk(for: actualCellarURL)

        // Format as human-readable (must run on main thread - ByteCountFormatter is not thread-safe)
        let bytesToFormat = totalBytes
        let formatted = await MainActor.run {
            ByteCountFormatter.string(fromByteCount: bytesToFormat, countStyle: .file)
        }

        return (totalBytes, formatted)
    }

    func calculateCaskSize(name: String) async -> (Int64, String) {
        // Special case for Pearcleaner (running app, not in sortedApps)
        if name == "pearcleaner" {
            let pearcleanerPath = URL(fileURLWithPath: "/Applications/Pearcleaner.app")
            guard FileManager.default.fileExists(atPath: pearcleanerPath.path) else {
                return (0, "0 KB")
            }

            let totalBytes = totalSizeOnDisk(for: pearcleanerPath)
            let bytesToFormat = totalBytes
            let formatted = await MainActor.run {
                ByteCountFormatter.string(fromByteCount: bytesToFormat, countStyle: .file)
            }
            return (totalBytes, formatted)
        }

        // For casks, get size from AppState.sortedApps (actual installed app)
        if let appInfo = await MainActor.run(body: { AppState.shared.sortedApps.first(where: { $0.cask == name }) }) {
            // If bundleSize is 0, calculate it now and update the AppInfo
            if appInfo.bundleSize == 0 {
                let calculatedSize = totalSizeOnDisk(for: appInfo.path)
                let formatted = await MainActor.run {
                    ByteCountFormatter.string(fromByteCount: calculatedSize, countStyle: .file)
                }

                // Update the AppInfo in sortedApps with calculated size
                await MainActor.run {
                    if let index = AppState.shared.sortedApps.firstIndex(where: { $0.path == appInfo.path }) {
                        var updatedAppInfo = AppState.shared.sortedApps[index]
                        updatedAppInfo.bundleSize = calculatedSize
                        AppState.shared.sortedApps[index] = updatedAppInfo
                    }
                }

                return (calculatedSize, formatted)
            }

            // bundleSize is already calculated, just format it
            let formatted = await MainActor.run {
                ByteCountFormatter.string(fromByteCount: appInfo.bundleSize, countStyle: .file)
            }
            return (appInfo.bundleSize, formatted)
        } else {
            // Fallback if app not found in sortedApps - find and calculate from Caskroom path
            let caskroomPath = "\(brewPrefix)/Caskroom/\(name)"
            let globPattern = "\(caskroomPath)/*/*.app"

            // Find the app symlink in Caskroom using glob
            var globResult = glob_t()
            defer { globfree(&globResult) }

            guard glob(globPattern, 0, nil, &globResult) == 0,
                  globResult.gl_pathc > 0,
                  let cPath = globResult.gl_pathv[0],
                  let symlinkPath = String(validatingUTF8: cPath) else {
                // No .app found - try PKG-only cask fallback
                return await calculatePKGOnlyCaskSize(caskName: name)
            }

            // Resolve symlink to get real path in /Applications
            let realPath = URL(fileURLWithPath: symlinkPath).resolvingSymlinksInPath()

            // Calculate size from disk
            let calculatedSize = totalSizeOnDisk(for: realPath)
            let formatted = await MainActor.run {
                ByteCountFormatter.string(fromByteCount: calculatedSize, countStyle: .file)
            }

            return (calculatedSize, formatted)
        }
    }

    /// Calculate size for PKG-only casks (no GUI app) by querying PKG receipts
    /// Used for Java runtimes, drivers, CLI tools, etc.
    private func calculatePKGOnlyCaskSize(caskName: String) async -> (Int64, String) {
        let caskroomPath = "\(brewPrefix)/Caskroom/\(caskName)"

        // Find cask JSON file in .metadata directory
        let globPattern = "\(caskroomPath)/.metadata/*/*/Casks/\(caskName).json"
        var globResult = glob_t()
        defer { globfree(&globResult) }

        guard glob(globPattern, 0, nil, &globResult) == 0,
              globResult.gl_pathc > 0,
              let cPath = globResult.gl_pathv[0],
              let jsonPath = String(validatingUTF8: cPath) else {
            return (0, "0 KB")
        }

        // Read and parse cask JSON
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let artifacts = json["artifacts"] as? [[String: Any]] else {
            return (0, "0 KB")
        }

        // Extract pkgutil identifiers from uninstall directives
        var pkgIdentifiers: [String] = []
        for artifact in artifacts {
            if let uninstalls = artifact["uninstall"] as? [[String: Any]] {
                for uninstall in uninstalls {
                    // Handle both string and array formats
                    if let pkgutilString = uninstall["pkgutil"] as? String {
                        pkgIdentifiers.append(pkgutilString)
                    } else if let pkgutilArray = uninstall["pkgutil"] as? [String] {
                        pkgIdentifiers.append(contentsOf: pkgutilArray)
                    }
                }
            }
        }

        guard !pkgIdentifiers.isEmpty else {
            return (0, "0 KB")
        }

        // Query PKG receipts and sum sizes
        let receipts = PKGManager.getAllPackages()
        var totalSize: Int64 = 0

        for identifier in pkgIdentifiers {
            if let receipt = receipts.first(where: { ($0.packageIdentifier() as? String) == identifier }),
               let bomInfo = PKGManager.getBOMInfo(for: receipt) {
                totalSize += bomInfo.totalSize
            }
        }

        guard totalSize > 0 else {
            return (0, "0 KB")
        }

        let bytesFormatted = totalSize
        let formatted = await MainActor.run {
            ByteCountFormatter.string(fromByteCount: bytesFormatted, countStyle: .file)
        }

        return (totalSize, formatted)
    }

    // MARK: - Tap Package Loading

    func getPackagesFromTap(_ tapName: String) async throws -> (formulae: [String], casks: [String]) {
        let tapPath = "\(brewPrefix)/Library/Taps/\(tapName.replacingOccurrences(of: "/", with: "/homebrew-"))"

        var formulae: [String] = []
        var casks: [String] = []

        // Load formulae - read directly from filesystem
        let formulaPath = "\(tapPath)/Formula"
        if FileManager.default.fileExists(atPath: formulaPath) {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: formulaPath) {
                for file in files where file.hasSuffix(".rb") {
                    let name = file.replacingOccurrences(of: ".rb", with: "")
                    formulae.append(name)
                }
            }
        }

        // Load casks - read directly from filesystem (recursively, since they're nested in letter directories)
        let caskPath = "\(tapPath)/Casks"
        if FileManager.default.fileExists(atPath: caskPath) {
            let caskFiles = try recursivelyFindCasks(in: caskPath)
            for file in caskFiles {
                let name = file.replacingOccurrences(of: ".rb", with: "")
                casks.append(name)
            }
        }

        // Sort alphabetically
        formulae.sort()
        casks.sort()

        return (formulae, casks)
    }

    // Helper to recursively find cask files
    private func recursivelyFindCasks(in directory: String) throws -> [String] {
        var caskNames: [String] = []

        guard let enumerator = FileManager.default.enumerator(atPath: directory) else {
            return []
        }

        for case let file as String in enumerator {
            if file.hasSuffix(".rb") {
                // Remove .rb extension and any parent directories (like "b/")
                let name = file.replacingOccurrences(of: ".rb", with: "")
                               .components(separatedBy: "/")
                               .last ?? file.replacingOccurrences(of: ".rb", with: "")
                caskNames.append(name)
            }
        }

        return caskNames
    }

    // Get full package info from brew info
    private func getPackageDetailsFromBrew(fullName: String, cask: Bool) async throws -> HomebrewSearchResult? {
        let arguments = ["info", "--json=v2", fullName]
        let result = try await runBrewCommand(arguments)

        guard let jsonData = result.output.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        let array = cask ? (json["casks"] as? [[String: Any]]) : (json["formulae"] as? [[String: Any]])
        guard let item = array?.first else {
            return nil
        }

        let name = cask ? (item["full_token"] as? String ?? "") : (item["full_name"] as? String ?? "")
        let desc = item["desc"] as? String
        let homepage = item["homepage"] as? String
        let license = item["license"] as? String
        let version: String? = cask ? (item["version"] as? String) : ((item["versions"] as? [String: Any])?["stable"] as? String)
        let dependencies: [String]
        if cask {
            let dependsOn = item["depends_on"] as? [String: Any]
            dependencies = (dependsOn?["formula"] as? [String]) ?? []
        } else {
            dependencies = (item["dependencies"] as? [String]) ?? []
        }
        let caveats = item["caveats"] as? String

        // Common fields
        let tap = item["tap"] as? String
        let _ = item["full_name"] as? String  // Unused, but keep for consistency
        let isDeprecated = (item["deprecated"] as? Bool) ?? false
        let deprecationReason = item["deprecation_reason"] as? String
        let isDisabled = (item["disabled"] as? Bool) ?? false
        let disableDate = item["disable_date"] as? String
        let conflictsWith = (item["conflicts_with"] as? [String]) ?? []
        let conflictsWithReasons = (item["conflicts_with_reasons"] as? [String]) ?? []

        // Formula-specific fields
        let isBottled = cask ? nil : ((item["versions"] as? [String: Any])?["bottle"] as? Bool ?? false)
        let isKegOnly = cask ? nil : (item["keg_only"] as? Bool ?? false)
        let kegOnlyReason: String?
        if !cask {
            if let kegOnlyReasonDict = item["keg_only_reason"] as? [String: Any],
               let explanation = kegOnlyReasonDict["explanation"] as? String, !explanation.isEmpty {
                kegOnlyReason = explanation
            } else if let kegOnlyReasonDict = item["keg_only_reason"] as? [String: Any],
                      let reason = kegOnlyReasonDict["reason"] as? String {
                switch reason {
                case ":provided_by_macos":
                    kegOnlyReason = "macOS already provides this software"
                case ":versioned_formula":
                    kegOnlyReason = "This is a versioned formula"
                case ":shadowed_by_macos":
                    kegOnlyReason = "Shadowed by macOS"
                default:
                    kegOnlyReason = "Not symlinked to Homebrew prefix"
                }
            } else {
                kegOnlyReason = nil
            }
        } else {
            kegOnlyReason = nil
        }
        let buildDependencies = cask ? nil : (item["build_dependencies"] as? [String])
        let aliases = cask ? nil : (item["aliases"] as? [String])
        let versionedFormulae = cask ? nil : (item["versioned_formulae"] as? [String])
        let requirements: String?
        if !cask {
            requirements = (item["requirements"] as? [[String: Any]])?.compactMap { req in
                if req["name"] as? String == "macos", let version = req["version"] as? String {
                    return "macOS >= \(version)"
                }
                return nil
            }.first
        } else {
            requirements = nil
        }

        // Cask-specific fields
        let caskName = cask ? (item["name"] as? [String]) : nil
        let autoUpdates = cask ? (item["auto_updates"] as? Bool) : nil
        let artifacts = cask ? (item["artifacts"] as? [[String: Any]])?.compactMap { artifact -> String? in
            if let appArray = artifact["app"] as? [String], let app = appArray.first {
                return "\(app) (App)"
            } else if let pkgArray = artifact["pkg"] as? [String], let pkg = pkgArray.first {
                return "\(pkg) (Pkg)"
            }
            return nil
        } : nil

        return HomebrewSearchResult(
            name: name,
            displayName: nil,  // Not loaded for tap packages
            description: desc,
            homepage: homepage,
            license: license,
            version: version,
            dependencies: dependencies.isEmpty ? nil : dependencies,
            caveats: caveats,
            tap: tap,
            fullName: fullName,
            isDeprecated: isDeprecated,
            deprecationReason: deprecationReason,
            deprecationDate: nil,  // Not available in JWS cache
            isDisabled: isDisabled,
            disableDate: disableDate,
            disableReason: nil,  // Not available in JWS cache
            conflictsWith: conflictsWith.isEmpty ? nil : conflictsWith,
            conflictsWithReasons: conflictsWithReasons.isEmpty ? nil : conflictsWithReasons,
            isBottled: isBottled,
            isKegOnly: isKegOnly,
            kegOnlyReason: kegOnlyReason,
            buildDependencies: buildDependencies,
            optionalDependencies: nil,  // Not available in JWS cache
            recommendedDependencies: nil,  // Not available in JWS cache
            usesFromMacos: nil,  // Not available in JWS cache
            aliases: aliases,
            versionedFormulae: versionedFormulae,
            requirements: requirements,
            caskName: caskName,
            autoUpdates: autoUpdates,
            artifacts: artifacts,
            url: nil,  // Not available in JWS cache
            appcast: nil  // Not available in JWS cache
        )
    }
}
