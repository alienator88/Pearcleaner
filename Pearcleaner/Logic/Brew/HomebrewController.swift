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
    /// Strip Homebrew revision suffix from version string
    /// Examples: "2.14.1_1" -> "2.14.1", "3.3.14_2" -> "3.3.14"
    /// Used during directory scan to normalize versions for API comparison
    func stripBrewRevisionSuffix() -> String {
        if let underscoreIndex = self.lastIndex(of: "_"),
           let afterUnderscore = self[self.index(after: underscoreIndex)...].first,
           afterUnderscore.isNumber {
            return String(self[..<underscoreIndex])
        }
        return self
    }

    /// Strip commit hash and revision suffix from Homebrew version for display purposes
    /// Examples:
    /// - "0.14.1,fc796f5b140d2dc2d21015e56b70c0c1567a2fd7" -> "0.14.1"
    /// - "2.14.1_1" -> "2.14.1"
    /// - "3.3.14_2" -> "3.3.14"
    /// Note: Only use for UI display, not for logic/comparisons
    func cleanBrewVersionForDisplay() -> String {
        var cleaned = self

        // Strip commit hash (after comma)
        if let commaIndex = cleaned.firstIndex(of: ",") {
            cleaned = String(cleaned[..<commaIndex])
        }

        // Strip revision suffix (e.g., _1, _2)
        cleaned = cleaned.stripBrewRevisionSuffix()

        return cleaned
    }
}

class HomebrewController {
    static let shared = HomebrewController()
    private let brewPath: String
    let brewPrefix: String  // Public for use in HomebrewUpdateChecker placeholder paths
    private let logger = UpdaterDebugLogger.shared

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

    func runBrewCommand(_ arguments: [String]) async throws -> (output: String, error: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.userEnvironment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        // Read pipes on background thread to avoid deadlock with large output
        let (outputData, errorData) = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let outData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (outData, errData))
            }
        }

        process.waitUntilExit()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        return (output, error)
    }

    // MARK: - Package Loading

    /// Stream installed packages by scanning Cellar/Caskroom directories
    /// Returns minimal info: name + displayName + description + version + isPinned + tap + tapRbPath
    func streamInstalledPackages(
        cask: Bool,
        onPackageFound: @escaping (String, String?, String, String, Bool, String?, String?) -> Void  // (name, displayName, description, version, isPinned, tap, tapRbPath)
    ) async throws {
        let baseDir = cask ? "\(brewPrefix)/Caskroom" : "\(brewPrefix)/Cellar"

        guard let packageDirs = try? FileManager.default.contentsOfDirectory(atPath: baseDir) else {
            return
        }

        // Process concurrently, stream results as they complete
        await withTaskGroup(of: (String, String?, String, String, Bool, String?, String?)?.self) { group in
            // Add all tasks
            for packageName in packageDirs where !packageName.hasPrefix(".") {
                group.addTask {
                    if cask {
                        return await self.getCaskNameDescVersionPin(name: packageName)
                    } else {
                        return await self.getFormulaNameDescVersionPin(name: packageName)
                    }
                }
            }

            // Collect results as they complete
            for await result in group {
                if let (name, displayName, desc, version, isPinned, tap, tapRbPath) = result {
                    onPackageFound(name, displayName, desc, version, isPinned, tap, tapRbPath)
                }
            }
        }
    }

    /// Load minimal package metadata (name, displayName, description, version) from local JWS files
    /// Much faster than API calls and works offline
    /// JWS files are already cached by Homebrew after `brew update`
    func loadMinimalPackageMetadata(cask: Bool) async throws -> [(name: String, displayName: String?, description: String?, version: String?)] {
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

        var results: [(name: String, displayName: String?, description: String?, version: String?)] = []

        // Extract package metadata from array
        for packageDict in payloadArray {
            let name: String
            let displayName: String?
            let description = packageDict["desc"] as? String
            let version: String?

            if cask {
                // Casks: token is brew ID, name is array with display name
                guard let token = packageDict["token"] as? String else { continue }
                name = token
                let nameArray = packageDict["name"] as? [String]
                displayName = nameArray?.first
                version = packageDict["version"] as? String
            } else {
                // Formulae: name is brew ID (no separate display name)
                guard let formulaName = packageDict["name"] as? String else { continue }
                name = formulaName
                displayName = nil  // Formulae don't have separate display names
                version = (packageDict["versions"] as? [String: Any])?["stable"] as? String
            }

            results.append((name: name, displayName: displayName, description: description, version: version))
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
    func getFormulaNameDescVersionPin(name: String) async -> (String, String?, String, String, Bool, String?, String?)? {
        let cellarPath = "\(brewPrefix)/Cellar/\(name)"

        // Find latest version directory
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: cellarPath)
                .filter({ !$0.hasPrefix(".") }),
              let latestVersion = versions.sorted().last else {
            return nil
        }

        // Strip revision suffix from version (e.g., "2.14.1_1" -> "2.14.1")
        // This ensures version matches what API returns
        let cleanedVersion = latestVersion.stripBrewRevisionSuffix()

        // Check if pinned (pin file exists)
        let pinPath = "\(brewPrefix)/var/homebrew/pinned/\(name)"
        let isPinned = FileManager.default.fileExists(atPath: pinPath)

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

        return (name, displayName, desc, cleanedVersion, isPinned, tap, tapRbPath)
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

    func loadInstalledPackages() async throws -> (formulae: [HomebrewPackageInfo], casks: [HomebrewPackageInfo]) {
        // Run a single command to get both formulae and casks
        let arguments = ["info", "--json=v2", "--installed"]
        let result = try await runBrewCommand(arguments)

        guard let jsonData = result.output.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw HomebrewError.jsonParseError
        }

        var formulae: [HomebrewPackageInfo] = []
        var casks: [HomebrewPackageInfo] = []

        // Parse formulae
        if let formulaeArray = json["formulae"] as? [[String: Any]] {
            for packageJson in formulaeArray {
                guard let name = packageJson["name"] as? String else { continue }

                // Skip if no installed versions
                guard let installedArray = packageJson["installed"] as? [[String: Any]],
                      !installedArray.isEmpty else {
                    continue
                }

                let versions = installedArray.compactMap { $0["version"] as? String }

                // Get installation date from unix timestamp
                var installedOn: Date? = nil
                if let timeInterval = installedArray.first?["time"] as? Double {
                    installedOn = Date(timeIntervalSince1970: timeInterval)
                }

                let sizeInBytes: Int64? = nil
                let isPinned = (packageJson["pinned"] as? Bool) ?? false
                let isOutdated = (packageJson["outdated"] as? Bool) ?? false
                let description = packageJson["desc"] as? String
                let homepage = packageJson["homepage"] as? String
                let tap = packageJson["tap"] as? String

                // Calculate Cellar path and file count
                var installedPath: String? = nil
                var fileCount: Int? = nil
                if let firstVersion = versions.first {
                    let cellarPath = "\(brewPrefix)/Cellar/\(name)/\(firstVersion)"
                    installedPath = cellarPath

                    // Count files in Cellar directory
                    if let enumerator = FileManager.default.enumerator(atPath: cellarPath) {
                        var count = 0
                        while enumerator.nextObject() != nil {
                            count += 1
                        }
                        fileCount = count
                    }
                }

                let package = HomebrewPackageInfo(
                    name: name,
                    isCask: false,
                    installedOn: installedOn,
                    versions: versions,
                    sizeInBytes: sizeInBytes,
                    isPinned: isPinned,
                    isOutdated: isOutdated,
                    description: description,
                    homepage: homepage,
                    tap: tap,
                    installedPath: installedPath,
                    fileCount: fileCount
                )
                formulae.append(package)
            }
        }

        // Parse casks
        if let casksArray = json["casks"] as? [[String: Any]] {
            for packageJson in casksArray {
                guard let name = packageJson["token"] as? String else { continue }

                // Check if installed (string field for casks)
                guard let installed = packageJson["installed"] as? String, !installed.isEmpty else {
                    continue
                }

                let version = installed
                let versions = [version]

                // Get installation date from unix timestamp
                var installedOn: Date? = nil
                if let timeInterval = packageJson["installed_time"] as? Double {
                    installedOn = Date(timeIntervalSince1970: timeInterval)
                }

                let sizeInBytes: Int64? = nil
                let isPinned = false  // Casks don't support pinning
                let isOutdated = (packageJson["outdated"] as? Bool) ?? false
                let description = packageJson["desc"] as? String
                let homepage = packageJson["homepage"] as? String
                let tap = packageJson["tap"] as? String

                // Calculate Caskroom path and file count
                var installedPath: String? = nil
                var fileCount: Int? = nil
                if let firstVersion = versions.first {
                    let caskroomPath = "\(brewPrefix)/Caskroom/\(name)/\(firstVersion)"
                    installedPath = caskroomPath

                    // Count files in Caskroom directory
                    if let enumerator = FileManager.default.enumerator(atPath: caskroomPath) {
                        var count = 0
                        while enumerator.nextObject() != nil {
                            count += 1
                        }
                        fileCount = count
                    }
                }

                let package = HomebrewPackageInfo(
                    name: name,
                    isCask: true,
                    installedOn: installedOn,
                    versions: versions,
                    sizeInBytes: sizeInBytes,
                    isPinned: isPinned,
                    isOutdated: isOutdated,
                    description: description,
                    homepage: homepage,
                    tap: tap,
                    installedPath: installedPath,
                    fileCount: fileCount
                )
                casks.append(package)
            }
        }

        return (formulae: formulae, casks: casks)
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
        var arguments = ["install"]
        if cask {
            arguments.append("--cask")
            arguments.append("--no-quarantine")
        }
        arguments.append(name)

        let result = try await runBrewCommand(arguments)

        // Check for actual errors (not warnings)
        let combinedOutput = result.output + result.error
        if result.error.contains("Error:") && !combinedOutput.contains("was successfully installed") {
            throw HomebrewError.commandFailed(result.error)
        }
    }

    func uninstallPackage(name: String) async throws {
        let arguments = ["uninstall", name]
        let result = try await runBrewCommand(arguments)

        if result.error.contains("Error") || result.error.contains("because it is required by") {
            throw HomebrewError.commandFailed(result.error)
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
        let arguments = ["upgrade", name]
        let result = try await runBrewCommand(arguments)

        if result.error.contains("Error") {
            throw HomebrewError.commandFailed(result.error)
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

        // Step 1: Try to check ALL packages via API first (fast path)
        // Assume packages with tap == nil are core packages (most common case)
        logger.log(.homebrew, "Step 1: Checking packages via public API (fast path)")
        let (coreOutdated, apiFailedPackages) = await checkCorePackagesViaAPI(allPackages)

        logger.log(.homebrew, "  API check complete: \(coreOutdated.count) outdated, \(apiFailedPackages.count) API failures (likely tap packages)")

        // Step 2: For packages where API failed, lazy-load tap info and check manually
        // This handles tap packages that don't exist in public API (typically 0-3 packages)
        if !apiFailedPackages.isEmpty {
            logger.log(.homebrew, "Step 2: Checking \(apiFailedPackages.count) tap packages manually")
            let tapOutdated = await checkTapPackagesManually(apiFailedPackages)
            logger.log(.homebrew, "  Manual tap check complete: \(tapOutdated.count) outdated")

            let totalOutdated = coreOutdated.count + tapOutdated.count
            logger.log(.homebrew, "Found \(totalOutdated) Homebrew updates available")

            // Filter out Pearcleaner (has dedicated UI banner in Updater view)
            let allOutdated = coreOutdated + tapOutdated
            return allOutdated.filter { $0.name != "pearcleaner" }
        }

        logger.log(.homebrew, "Found \(coreOutdated.count) Homebrew updates available")

        // Filter out Pearcleaner (has dedicated UI banner in Updater view)
        return coreOutdated.filter { $0.name != "pearcleaner" }
    }

    /// Check core Homebrew packages using public API (fast)
    /// Returns tuple: (outdatedPackages, apiFailedPackages)
    private func checkCorePackagesViaAPI(_ packages: [InstalledPackage]) async -> (outdated: [HomebrewOutdatedPackage], apiFailed: [InstalledPackage]) {
        // Fetch latest versions from API using parallel requests
        let latestVersions = await withTaskGroup(of: (String, String?, Bool).self, returning: [String: (String, Bool)].self) { group in
            for package in packages {
                group.addTask {
                    // Construct API URL based on package type
                    let urlString = package.isCask
                        ? "https://formulae.brew.sh/api/cask/\(package.name).json"
                        : "https://formulae.brew.sh/api/formula/\(package.name).json"

                    guard let url = URL(string: urlString),
                          let (data, _) = try? await URLSession.shared.data(from: url),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        return (package.name, nil, package.isCask)
                    }

                    // Extract version based on package type
                    let version: String? = package.isCask
                        ? json["version"] as? String
                        : (json["versions"] as? [String: Any])?["stable"] as? String

                    return (package.name, version, package.isCask)
                }
            }

            // Collect results into dictionary
            var results: [String: (String, Bool)] = [:]
            for await (name, version, isCask) in group {
                if let version = version {
                    results[name] = (version, isCask)
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

            if let (latestVersion, _) = latestVersions[package.name] {
                // API call succeeded - package exists in public API
                // Check if versions differ
                if installedVersion != latestVersion {
                    logger.log(.homebrew, "  📦 UPDATE AVAILABLE: \(package.name) - \(installedVersion) → \(latestVersion) (\(package.isCask ? "cask" : "formula"))")
                    outdatedPackages.append(HomebrewOutdatedPackage(
                        name: package.name,
                        installedVersion: installedVersion,
                        availableVersion: latestVersion,
                        isPinned: package.isPinned,
                        isCask: package.isCask
                    ))
                } else {
                    logger.log(.homebrew, "  ✓ Up to date: \(package.name) (\(installedVersion))")
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

            // Parse version from .rb file using regex
            let versionRegex = /version "([^"]+)"/
            guard let match = rbContent.firstMatch(of: versionRegex) else {
                logger.log(.homebrew, "    ⚠️ No version found in .rb file")
                continue  // No version found in .rb file
            }

            let tapVersion = String(match.1).stripBrewRevisionSuffix()
            logger.log(.homebrew, "    Comparing: Installed \(installedVersion) vs Tap \(tapVersion)")

            // Compare versions
            if installedVersion != tapVersion {
                logger.log(.homebrew, "    📦 UPDATE AVAILABLE: \(installedVersion) → \(tapVersion)")
                outdatedPackages.append(HomebrewOutdatedPackage(
                    name: package.name,
                    installedVersion: installedVersion,
                    availableVersion: tapVersion,
                    isPinned: package.isPinned,
                    isCask: package.isCask
                ))
            } else {
                logger.log(.homebrew, "    ✓ Up to date")
            }
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
        let arguments = ["-v"]
        let result = try await runBrewCommand(arguments)

        // Extract version number from output like "Homebrew 4.0.15"
        let components = result.output.components(separatedBy: " ")
        if components.count >= 2 {
            return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getSemanticBrewVersion() async throws -> String {
        let fullVersion = try await getBrewVersion()
        // Extract just the semantic version (e.g., "4.6.15" from "4.6.15-34-g01d792b")
        if let match = fullVersion.range(of: #"^\d+\.\d+\.\d+"#, options: .regularExpression) {
            return String(fullVersion[match])
        }
        return fullVersion
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
        let currentVersion = try await getBrewVersion()

        // Check if version has commit hash suffix (e.g., "4.6.16-29-g20fa199")
        // If not, skip git check even if git repo exists (portable installation)
        let hasCommitSuffix = currentVersion.range(of: #"-\d+-g[a-f0-9]+"#, options: .regularExpression) != nil

        if hasCommitSuffix {
            // Try git-based check for git installations with commit suffixes
            do {
                let updateAvailable = try await isBrewBehindRemote()
                return (current: currentVersion, latest: "", updateAvailable: updateAvailable)
            } catch {
                printOS("Brew version check - Git-based check failed: \(error.localizedDescription). Falling back to semantic version comparison.")
            }
        }

        // Fallback: semantic version comparison (for portable installations)
        do {
            let latestVersion = try await getLatestBrewVersionFromGitHub()
            let currentSemantic = try await getSemanticBrewVersion()
            let updateAvailable = compareSemanticVersions(current: currentSemantic, latest: latestVersion)
            return (current: currentVersion, latest: latestVersion, updateAvailable: updateAvailable)
        } catch {
            printOS("Brew version check - Semantic version comparison failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func isBrewBehindRemote() async throws -> Bool {
        // Find the Homebrew git repository path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["--repository"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let repoPath = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !repoPath.isEmpty else {
            printOS("Brew version check - Git check failed: brew --repository returned empty path")
            throw HomebrewError.commandFailed("Not a git repository")
        }

        // Verify it's actually a git repo
        let checkGitProcess = Process()
        checkGitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        checkGitProcess.arguments = ["-C", repoPath, "rev-parse", "--git-dir"]
        checkGitProcess.standardOutput = Pipe()
        let checkGitErrorPipe = Pipe()
        checkGitProcess.standardError = checkGitErrorPipe

        try checkGitProcess.run()
        checkGitProcess.waitUntilExit()

        guard checkGitProcess.terminationStatus == 0 else {
            let errorData = checkGitErrorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            printOS("Brew version check - Git check failed: git rev-parse failed with status \(checkGitProcess.terminationStatus), error: \(errorOutput)")
            throw HomebrewError.commandFailed("Not a git repository")
        }

        // Fetch latest from remote (doesn't update local files, just refs)
        let fetchProcess = Process()
        fetchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        fetchProcess.arguments = ["-C", repoPath, "fetch", "--quiet", "origin"]
        fetchProcess.standardOutput = Pipe()
        let fetchErrorPipe = Pipe()
        fetchProcess.standardError = fetchErrorPipe

        try? fetchProcess.run()
        fetchProcess.waitUntilExit()

        if fetchProcess.terminationStatus != 0 {
            let errorData = fetchErrorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            printOS("Brew version check - Git fetch warning: failed with status \(fetchProcess.terminationStatus), error: \(errorOutput)")
        }

        // Compare local HEAD with remote origin/master (or origin/HEAD)
        let compareProcess = Process()
        compareProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        compareProcess.arguments = ["-C", repoPath, "rev-list", "--count", "HEAD..origin/master"]

        let comparePipe = Pipe()
        compareProcess.standardOutput = comparePipe
        let compareErrorPipe = Pipe()
        compareProcess.standardError = compareErrorPipe

        try compareProcess.run()
        compareProcess.waitUntilExit()

        if compareProcess.terminationStatus != 0 {
            let errorData = compareErrorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            printOS("Brew version check - Git compare failed: rev-list failed with status \(compareProcess.terminationStatus), error: \(errorOutput)")
        }

        let compareData = comparePipe.fileHandleForReading.readDataToEndOfFile()
        let commitsBehind = String(data: compareData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"

        return Int(commitsBehind) ?? 0 > 0
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
        let arguments = ["update"]
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

    func getDownloadsCacheSize() async throws -> Int64 {
        // Run cleanup in dry-run mode to see what would be freed
        let arguments = ["cleanup", "--dry-run", "--scrub", "--prune=all"]
        let result = try await runBrewCommand(arguments)

        let output = result.output + result.error

        // Parse the output for "This operation would free approximately X"
        // Example: "This operation would free approximately 5.1MB of disk space."
        if let match = output.range(of: #"would free approximately ([0-9.]+)(MB|GB|KB)"#, options: .regularExpression) {
            let matchString = String(output[match])

            // Extract number and unit
            let pattern = #"([0-9.]+)(MB|GB|KB)"#
            if let valueMatch = matchString.range(of: pattern, options: .regularExpression) {
                let valueString = String(matchString[valueMatch])
                let components = valueString.components(separatedBy: CharacterSet.letters)

                if let sizeValue = Double(components[0]) {
                    let unit = valueString.replacingOccurrences(of: String(sizeValue), with: "")

                    // Convert to bytes
                    switch unit {
                    case "KB":
                        return Int64(sizeValue * 1024)
                    case "MB":
                        return Int64(sizeValue * 1024 * 1024)
                    case "GB":
                        return Int64(sizeValue * 1024 * 1024 * 1024)
                    default:
                        return 0
                    }
                }
            }
        }

        return 0
    }

    func runCleanup() async throws {
        let arguments = ["cleanup"]
        let result = try await runBrewCommand(arguments)

        if result.error.contains("Error") {
            throw HomebrewError.commandFailed(result.error)
        }
    }

    func performFullCleanup() async throws {
        // Run autoremove first to remove orphaned dependencies
        let autoremoveArgs = ["autoremove"]
        _ = try await runBrewCommand(autoremoveArgs)

        // Then run cleanup with scrub to remove old versions and all cache files (including latest versions)
        let cleanupArgs = ["cleanup", "--scrub", "--prune=all"]
        let result = try await runBrewCommand(cleanupArgs)

        if result.error.contains("Error") && !result.error.contains("Warning") {
            throw HomebrewError.commandFailed(result.error)
        }
    }

    func getAnalyticsStatus() async throws -> Bool {
        let arguments = ["analytics"]
        let result = try await runBrewCommand(arguments)

        // Check for both possible messages
        return result.output.contains("analytics are enabled") ||
               result.output.contains("Analytics are enabled")
    }

    func setAnalyticsStatus(enabled: Bool) async throws {
        let arguments = ["analytics", enabled ? "on" : "off"]
        let result = try await runBrewCommand(arguments)

        if result.error.contains("Error") {
            throw HomebrewError.commandFailed(result.error)
        }
    }

    // MARK: - Tap Package Loading

    func getPackagesFromTap(_ tapName: String) async throws -> (formulae: [HomebrewSearchResult], casks: [HomebrewSearchResult]) {
        let tapPath = "\(brewPrefix)/Library/Taps/\(tapName.replacingOccurrences(of: "/", with: "/homebrew-"))"

        var formulae: [HomebrewSearchResult] = []
        var casks: [HomebrewSearchResult] = []

        // Load formulae
        let formulaPath = "\(tapPath)/Formula"
        if FileManager.default.fileExists(atPath: formulaPath) {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: formulaPath) {
                for file in files where file.hasSuffix(".rb") {
                    let name = file.replacingOccurrences(of: ".rb", with: "")
                    let fullName = "\(tapName)/\(name)"

                    // Get details from brew info
                    if let details = try? await getPackageDetailsFromBrew(fullName: fullName, cask: false) {
                        formulae.append(details)
                    }
                }
            }
        }

        // Load casks (recursively, since they're nested in letter directories)
        let caskPath = "\(tapPath)/Casks"
        if FileManager.default.fileExists(atPath: caskPath) {
            let caskFiles = try recursivelyFindCasks(in: caskPath)
            for file in caskFiles {
                let name = file.replacingOccurrences(of: ".rb", with: "")
                let fullName = "\(tapName)/\(name)"

                // Get details from brew info
                if let details = try? await getPackageDetailsFromBrew(fullName: fullName, cask: true) {
                    casks.append(details)
                }
            }
        }

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
