//
//  HomebrewController.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import Foundation
import SwiftyJSON
import AlinFoundation
#if canImport(SwiftData)
import SwiftData
#endif

enum HomebrewError: Error {
    case brewNotFound
    case commandFailed(String)
    case jsonParseError
    case packageNotFound
}

class HomebrewController {
    static let shared = HomebrewController()
    private let brewPath: String
    private let brewPrefix: String

    // Preloaded cache
    private var cachedFormulaeData: JSON?
    private var cachedCasksData: JSON?

    // SwiftData context for package caching (macOS 14+)
    private var modelContext: Any?

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

    // MARK: - SwiftData Setup

    @available(macOS 14.0, *)
    @MainActor
    func setModelContext(container: Any) {
        guard let modelContainer = container as? ModelContainer else { return }
        self.modelContext = ModelContext(modelContainer)
    }

    // MARK: - Package Cache (SwiftData)

    @available(macOS 14.0, *)
    @MainActor
    func savePackagesToCache(formulae: [HomebrewSearchResult], casks: [HomebrewSearchResult]) async {
        guard let context = modelContext as? ModelContext else { return }

        do {
            // Clear existing cache
            try context.delete(model: CachedHomebrewPackage.self)

            // Save formulae
            for formula in formulae {
                let cached = CachedHomebrewPackage.from(formula, isCask: false)
                context.insert(cached)
            }

            // Save casks
            for cask in casks {
                let cached = CachedHomebrewPackage.from(cask, isCask: true)
                context.insert(cached)
            }

            try context.save()

            print("✅ Saved \(formulae.count) formulae and \(casks.count) casks to cache")
        } catch {
            printOS("Error saving packages to cache: \(error)")
        }
    }

    @available(macOS 14.0, *)
    @MainActor
    func loadPackagesFromCache() async -> (formulae: [HomebrewSearchResult], casks: [HomebrewSearchResult], cacheDate: Date?) {
        guard let context = modelContext as? ModelContext else {
            return ([], [], nil)
        }

        do {
            let descriptor = FetchDescriptor<CachedHomebrewPackage>()
            let cachedPackages = try context.fetch(descriptor)

            guard !cachedPackages.isEmpty else {
                return ([], [], nil)
            }

            let formulae = cachedPackages.filter { !$0.isCask }.map { $0.toSearchResult() }
            let casks = cachedPackages.filter { $0.isCask }.map { $0.toSearchResult() }

            // Get the most recent cache date
            let cacheDate = cachedPackages.map { $0.cachedAt }.max()

            return (formulae, casks, cacheDate)
        } catch {
            printOS("Error loading packages from cache: \(error)")
            return ([], [], nil)
        }
    }

    @available(macOS 14.0, *)
    @MainActor
    func getCacheAge() async -> TimeInterval? {
        guard let context = modelContext as? ModelContext else { return nil }

        let descriptor = FetchDescriptor<CachedHomebrewPackage>()
        guard let cachedPackages = try? context.fetch(descriptor),
              let mostRecent = cachedPackages.map({ $0.cachedAt }).max() else {
            return nil
        }

        return Date().timeIntervalSince(mostRecent)
    }

    @available(macOS 14.0, *)
    @MainActor
    func clearPackageCache() async {
        guard let context = modelContext as? ModelContext else { return }

        do {
            try context.delete(model: CachedHomebrewPackage.self)
            try context.save()
        } catch {
            printOS("Error clearing package cache: \(error)")
        }
    }

    // MARK: - Cache Preloading

    func preloadCache() async {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/Homebrew/api")

        // Preload formulae
        let formulaeFile = cacheDir.appendingPathComponent("formula.jws.json")
        if FileManager.default.fileExists(atPath: formulaeFile.path), cachedFormulaeData == nil {
            do {
                let jwsData = try Data(contentsOf: formulaeFile)
                let jwsJson = try JSON(data: jwsData)
                if let payloadString = jwsJson["payload"].string,
                   let payloadData = payloadString.data(using: .utf8) {
                    cachedFormulaeData = try JSON(data: payloadData)
                }
            } catch {
                printOS("Failed to preload formulae cache: \(error)")
            }
        }

        // Preload casks
        let casksFile = cacheDir.appendingPathComponent("cask.jws.json")
        if FileManager.default.fileExists(atPath: casksFile.path), cachedCasksData == nil {
            do {
                let jwsData = try Data(contentsOf: casksFile)
                let jwsJson = try JSON(data: jwsData)
                if let payloadString = jwsJson["payload"].string,
                   let payloadData = payloadString.data(using: .utf8) {
                    cachedCasksData = try JSON(data: payloadData)
                }
            } catch {
                printOS("Failed to preload casks cache: \(error)")
            }
        }
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
    /// Returns minimal info: name + description + version
    func streamInstalledPackages(
        cask: Bool,
        onPackageFound: @escaping (String, String, String) -> Void  // (name, description, version)
    ) async throws {
        let baseDir = cask ? "\(brewPrefix)/Caskroom" : "\(brewPrefix)/Cellar"

        guard let packageDirs = try? FileManager.default.contentsOfDirectory(atPath: baseDir) else {
            return
        }

        // Process concurrently, stream results as they complete
        await withTaskGroup(of: (String, String, String)?.self) { group in
            // Add all tasks
            for packageName in packageDirs where !packageName.hasPrefix(".") {
                group.addTask {
                    if cask {
                        return await self.getCaskNameDescVersion(name: packageName)
                    } else {
                        return await self.getFormulaNameDescVersion(name: packageName)
                    }
                }
            }

            // Collect results as they complete
            for await result in group {
                if let (name, desc, version) = result {
                    onPackageFound(name, desc, version)
                }
            }
        }
    }

    /// Extract name, description, and version from formula .rb file
    private func getFormulaNameDescVersion(name: String) async -> (String, String, String)? {
        let cellarPath = "\(brewPrefix)/Cellar/\(name)"

        // Find latest version directory
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: cellarPath)
                .filter({ !$0.hasPrefix(".") }),
              let latestVersion = versions.sorted().last else {
            return nil
        }

        // Read .rb file
        let rbPath = "\(cellarPath)/\(latestVersion)/.brew/\(name).rb"
        guard let rbContent = try? String(contentsOfFile: rbPath) else {
            return (name, "No description available", latestVersion)
        }

        // Parse desc with regex: desc "..."
        let descRegex = /desc "([^"]+)"/
        if let match = rbContent.firstMatch(of: descRegex) {
            return (name, String(match.1), latestVersion)
        }

        return (name, "No description available", latestVersion)
    }

    /// Extract name, description, and version from cask metadata file (.json or .rb)
    private func getCaskNameDescVersion(name: String) async -> (String, String, String)? {
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
        guard let metadataIndex = pathComponents.lastIndex(of: ".metadata"),
              metadataIndex + 1 < pathComponents.count else {
            return nil
        }
        let version = pathComponents[metadataIndex + 1]

        // Check file extension to determine how to parse
        if caskFilePath.hasSuffix(".json") {
            // Parse JSON file (regular cask)
            guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: caskFilePath)),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return (name, "No description available", version)
            }

            let desc = json["desc"] as? String ?? "No description available"
            return (name, desc, version)

        } else if caskFilePath.hasSuffix(".rb") {
            // Parse Ruby file (tap cask)
            guard let rbContent = try? String(contentsOfFile: caskFilePath) else {
                return (name, "No description available", version)
            }

            // Parse desc with regex: desc "..."
            let descRegex = /desc "([^"]+)"/
            let desc = rbContent.firstMatch(of: descRegex).map { String($0.1) } ?? "No description available"

            return (name, desc, version)

        } else {
            return (name, "No description available", version)
        }
    }

    func loadInstalledPackages() async throws -> (formulae: [HomebrewPackageInfo], casks: [HomebrewPackageInfo]) {
        // Run a single command to get both formulae and casks
        let arguments = ["info", "--json=v2", "--installed"]
        let result = try await runBrewCommand(arguments)

        guard let jsonData = result.output.data(using: .utf8) else {
            throw HomebrewError.jsonParseError
        }

        let json = try JSON(data: jsonData)
        var formulae: [HomebrewPackageInfo] = []
        var casks: [HomebrewPackageInfo] = []

        // Parse formulae
        for packageJson in json["formulae"].arrayValue {
            let name = packageJson["name"].stringValue

            // Skip if no installed versions
            guard !packageJson["installed"].arrayValue.isEmpty else {
                continue
            }

            let versions = packageJson["installed"].arrayValue.map { $0["version"].stringValue }

            // Get installation date from unix timestamp
            var installedOn: Date? = nil
            if let timeInterval = packageJson["installed"].arrayValue.first?["time"].double {
                installedOn = Date(timeIntervalSince1970: timeInterval)
            }

            let sizeInBytes: Int64? = nil
            let isPinned = packageJson["pinned"].boolValue
            let isOutdated = packageJson["outdated"].boolValue
            let description = packageJson["desc"].string
            let homepage = packageJson["homepage"].string
            let tap = packageJson["tap"].string

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

        // Parse casks
        for packageJson in json["casks"].arrayValue {
            let name = packageJson["token"].stringValue

            // Check if installed (string field for casks)
            guard !packageJson["installed"].stringValue.isEmpty else {
                continue
            }

            let version = packageJson["installed"].stringValue
            let versions = [version]

            // Get installation date from unix timestamp
            var installedOn: Date? = nil
            if let timeInterval = packageJson["installed_time"].double {
                installedOn = Date(timeIntervalSince1970: timeInterval)
            }

            let sizeInBytes: Int64? = nil
            let isPinned = false  // Casks don't support pinning
            let isOutdated = packageJson["outdated"].boolValue
            let description = packageJson["desc"].string
            let homepage = packageJson["homepage"].string
            let tap = packageJson["tap"].string

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

        return (formulae: formulae, casks: casks)
    }

    // MARK: - Search

    func searchPackages(query: String, cask: Bool) async throws -> [HomebrewSearchResult] {
        // Try to use preloaded cache first
        let payload: JSON?

        if cask {
            payload = cachedCasksData
        } else {
            payload = cachedFormulaeData
        }

        if let payload = payload {
            // Use preloaded cache - instant search!
            var results: [HomebrewSearchResult] = []
            for item in payload.arrayValue {
                let name = cask ? item["token"].stringValue : item["name"].stringValue

                // If query is empty, return all; otherwise filter
                if query.isEmpty || name.localizedCaseInsensitiveContains(query) {
                    let license = item["license"].string
                    let version = cask ? item["version"].string : item["versions"]["stable"].string
                    let dependencies = cask ? item["depends_on"]["formula"].arrayValue.map { $0.stringValue } : item["dependencies"].arrayValue.map { $0.stringValue }
                    let caveats = item["caveats"].string

                    // Common fields
                    let tap = item["tap"].string
                    let fullName = item["full_name"].string
                    let isDeprecated = item["deprecated"].bool ?? false
                    let deprecationReason = item["deprecation_reason"].string
                    let isDisabled = item["disabled"].bool ?? false
                    let disableDate = item["disable_date"].string
                    let conflictsWith = item["conflicts_with"].arrayValue.map { $0.stringValue }

                    // Formula-specific fields
                    let isBottled = cask ? nil : (item["versions"]["bottle"].bool ?? false)
                    let isKegOnly = cask ? nil : (item["keg_only"].bool ?? false)
                    let kegOnlyReason: String?
                    if !cask {
                        if let explanation = item["keg_only_reason"]["explanation"].string, !explanation.isEmpty {
                            kegOnlyReason = explanation
                        } else if let reason = item["keg_only_reason"]["reason"].string {
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
                    let buildDependencies = cask ? nil : item["build_dependencies"].arrayValue.map { $0.stringValue }
                    let aliases = cask ? nil : item["aliases"].arrayValue.map { $0.stringValue }
                    let versionedFormulae = cask ? nil : item["versioned_formulae"].arrayValue.map { $0.stringValue }
                    let requirements: String?
                    if !cask {
                        requirements = item["requirements"].arrayValue.compactMap { req in
                            if req["name"].string == "macos", let version = req["version"].string {
                                return "macOS >= \(version)"
                            }
                            return nil
                        }.first
                    } else {
                        requirements = nil
                    }

                    // Cask-specific fields
                    let caskName = cask ? item["name"].arrayValue.map { $0.stringValue } : nil
                    let autoUpdates = cask ? item["auto_updates"].bool : nil
                    let artifacts = cask ? item["artifacts"].arrayValue.compactMap { artifact -> String? in
                        if let app = artifact["app"].array?.first?.string {
                            return "\(app) (App)"
                        } else if let pkg = artifact["pkg"].array?.first?.string {
                            return "\(pkg) (Pkg)"
                        }
                        return nil
                    } : nil

                    results.append(HomebrewSearchResult(
                        name: name,
                        description: item["desc"].string,
                        homepage: item["homepage"].string,
                        license: license,
                        version: version,
                        dependencies: dependencies.isEmpty ? nil : dependencies,
                        caveats: caveats,
                        tap: tap,
                        fullName: fullName,
                        isDeprecated: isDeprecated,
                        deprecationReason: deprecationReason,
                        isDisabled: isDisabled,
                        disableDate: disableDate,
                        conflictsWith: conflictsWith.isEmpty ? nil : conflictsWith,
                        isBottled: isBottled,
                        isKegOnly: isKegOnly,
                        kegOnlyReason: kegOnlyReason,
                        buildDependencies: buildDependencies,
                        aliases: aliases,
                        versionedFormulae: versionedFormulae,
                        requirements: requirements,
                        caskName: caskName,
                        autoUpdates: autoUpdates,
                        artifacts: artifacts
                    ))
                }
            }

            return results
        }

        // If not preloaded, try to read from disk
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/Homebrew/api")

        let jwsFile = cask ?
            cacheDir.appendingPathComponent("cask.jws.json") :
            cacheDir.appendingPathComponent("formula.jws.json")

        if FileManager.default.fileExists(atPath: jwsFile.path) {
            do {
                // Read and parse the JWS file
                let jwsData = try Data(contentsOf: jwsFile)
                let jwsJson = try JSON(data: jwsData)

                // Extract and parse the payload (it's a JSON string inside the JSON)
                guard let payloadString = jwsJson["payload"].string,
                      let payloadData = payloadString.data(using: .utf8) else {
                    throw HomebrewError.jsonParseError
                }

                let diskPayload = try JSON(data: payloadData)

                // Filter packages by search query and extract details
                var results: [HomebrewSearchResult] = []
                for item in diskPayload.arrayValue {
                    let name = cask ? item["token"].stringValue : item["name"].stringValue

                    // If query is empty, return all; otherwise filter
                    if query.isEmpty || name.localizedCaseInsensitiveContains(query) {
                        let license = item["license"].string
                        let version = cask ? item["version"].string : item["versions"]["stable"].string
                        let dependencies = cask ? item["depends_on"]["formula"].arrayValue.map { $0.stringValue } : item["dependencies"].arrayValue.map { $0.stringValue }
                        let caveats = item["caveats"].string

                        // Common fields
                        let tap = item["tap"].string
                        let fullName = item["full_name"].string
                        let isDeprecated = item["deprecated"].bool ?? false
                        let deprecationReason = item["deprecation_reason"].string
                        let isDisabled = item["disabled"].bool ?? false
                        let disableDate = item["disable_date"].string
                        let conflictsWith = item["conflicts_with"].arrayValue.map { $0.stringValue }

                        // Formula-specific fields
                        let isBottled = cask ? nil : (item["versions"]["bottle"].bool ?? false)
                        let isKegOnly = cask ? nil : (item["keg_only"].bool ?? false)
                        let kegOnlyReason: String?
                        if !cask {
                            if let explanation = item["keg_only_reason"]["explanation"].string, !explanation.isEmpty {
                                kegOnlyReason = explanation
                            } else if let reason = item["keg_only_reason"]["reason"].string {
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
                        let buildDependencies = cask ? nil : item["build_dependencies"].arrayValue.map { $0.stringValue }
                        let aliases = cask ? nil : item["aliases"].arrayValue.map { $0.stringValue }
                        let versionedFormulae = cask ? nil : item["versioned_formulae"].arrayValue.map { $0.stringValue }
                        let requirements: String?
                        if !cask {
                            requirements = item["requirements"].arrayValue.compactMap { req in
                                if req["name"].string == "macos", let version = req["version"].string {
                                    return "macOS >= \(version)"
                                }
                                return nil
                            }.first
                        } else {
                            requirements = nil
                        }

                        // Cask-specific fields
                        let caskName = cask ? item["name"].arrayValue.map { $0.stringValue } : nil
                        let autoUpdates = cask ? item["auto_updates"].bool : nil
                        let artifacts = cask ? item["artifacts"].arrayValue.compactMap { artifact -> String? in
                            if let app = artifact["app"].array?.first?.string {
                                return "\(app) (App)"
                            } else if let pkg = artifact["pkg"].array?.first?.string {
                                return "\(pkg) (Pkg)"
                            }
                            return nil
                        } : nil

                        results.append(HomebrewSearchResult(
                            name: name,
                            description: item["desc"].string,
                            homepage: item["homepage"].string,
                            license: license,
                            version: version,
                            dependencies: dependencies.isEmpty ? nil : dependencies,
                            caveats: caveats,
                            tap: tap,
                            fullName: fullName,
                            isDeprecated: isDeprecated,
                            deprecationReason: deprecationReason,
                            isDisabled: isDisabled,
                            disableDate: disableDate,
                            conflictsWith: conflictsWith.isEmpty ? nil : conflictsWith,
                            isBottled: isBottled,
                            isKegOnly: isKegOnly,
                            kegOnlyReason: kegOnlyReason,
                            buildDependencies: buildDependencies,
                            aliases: aliases,
                            versionedFormulae: versionedFormulae,
                            requirements: requirements,
                            caskName: caskName,
                            autoUpdates: autoUpdates,
                            artifacts: artifacts
                        ))
                    }
                }

                return results
            } catch {
                // If reading from cache fails, fall through to API call
                printOS("Failed to read from cache, falling back to API: \(error)")
            }
        }

        // Fallback to API if cache doesn't exist or reading failed
        return try await searchPackagesFromAPI(query: query, cask: cask)
    }

    private func searchPackagesFromAPI(query: String, cask: Bool) async throws -> [HomebrewSearchResult] {
        let url = cask ?
            URL(string: "https://formulae.brew.sh/api/cask.json")! :
            URL(string: "https://formulae.brew.sh/api/formula.json")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSON(data: data)

        var results: [HomebrewSearchResult] = []
        for item in json.arrayValue {
            let name = cask ? item["token"].stringValue : item["name"].stringValue

            // If query is empty, return all; otherwise filter
            if query.isEmpty || name.localizedCaseInsensitiveContains(query) {
                let license = item["license"].string
                let version = cask ? item["version"].string : item["versions"]["stable"].string
                let dependencies = cask ? item["depends_on"]["formula"].arrayValue.map { $0.stringValue } : item["dependencies"].arrayValue.map { $0.stringValue }
                let caveats = item["caveats"].string

                // Common fields
                let tap = item["tap"].string
                let fullName = item["full_name"].string
                let isDeprecated = item["deprecated"].bool ?? false
                let deprecationReason = item["deprecation_reason"].string
                let isDisabled = item["disabled"].bool ?? false
                let disableDate = item["disable_date"].string
                let conflictsWith = item["conflicts_with"].arrayValue.map { $0.stringValue }

                // Formula-specific fields
                let isBottled = cask ? nil : (item["versions"]["bottle"].bool ?? false)
                let isKegOnly = cask ? nil : (item["keg_only"].bool ?? false)
                let kegOnlyReason: String?
                if !cask {
                    if let explanation = item["keg_only_reason"]["explanation"].string, !explanation.isEmpty {
                        kegOnlyReason = explanation
                    } else if let reason = item["keg_only_reason"]["reason"].string {
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
                let buildDependencies = cask ? nil : item["build_dependencies"].arrayValue.map { $0.stringValue }
                let aliases = cask ? nil : item["aliases"].arrayValue.map { $0.stringValue }
                let versionedFormulae = cask ? nil : item["versioned_formulae"].arrayValue.map { $0.stringValue }
                let requirements: String?
                if !cask {
                    requirements = item["requirements"].arrayValue.compactMap { req in
                        if req["name"].string == "macos", let version = req["version"].string {
                            return "macOS >= \(version)"
                        }
                        return nil
                    }.first
                } else {
                    requirements = nil
                }

                // Cask-specific fields
                let caskName = cask ? item["name"].arrayValue.map { $0.stringValue } : nil
                let autoUpdates = cask ? item["auto_updates"].bool : nil
                let artifacts = cask ? item["artifacts"].arrayValue.compactMap { artifact -> String? in
                    if let app = artifact["app"].array?.first?.string {
                        return "\(app) (App)"
                    } else if let pkg = artifact["pkg"].array?.first?.string {
                        return "\(pkg) (Pkg)"
                    }
                    return nil
                } : nil

                results.append(HomebrewSearchResult(
                    name: name,
                    description: item["desc"].string,
                    homepage: item["homepage"].string,
                    license: license,
                    version: version,
                    dependencies: dependencies.isEmpty ? nil : dependencies,
                    caveats: caveats,
                    tap: tap,
                    fullName: fullName,
                    isDeprecated: isDeprecated,
                    deprecationReason: deprecationReason,
                    isDisabled: isDisabled,
                    disableDate: disableDate,
                    conflictsWith: conflictsWith.isEmpty ? nil : conflictsWith,
                    isBottled: isBottled,
                    isKegOnly: isKegOnly,
                    kegOnlyReason: kegOnlyReason,
                    buildDependencies: buildDependencies,
                    aliases: aliases,
                    versionedFormulae: versionedFormulae,
                    requirements: requirements,
                    caskName: caskName,
                    autoUpdates: autoUpdates,
                    artifacts: artifacts
                ))
            }
        }

        return results
    }

    func getPackageDetails(name: String, cask: Bool) async throws -> (description: String?, homepage: String?) {
        // Try to read from Homebrew's cached .jws.json files first
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/Homebrew/api")

        let jwsFile = cask ?
            cacheDir.appendingPathComponent("cask.jws.json") :
            cacheDir.appendingPathComponent("formula.jws.json")

        if FileManager.default.fileExists(atPath: jwsFile.path) {
            do {
                let jwsData = try Data(contentsOf: jwsFile)
                let jwsJson = try JSON(data: jwsData)

                guard let payloadString = jwsJson["payload"].string,
                      let payloadData = payloadString.data(using: .utf8) else {
                    throw HomebrewError.jsonParseError
                }

                let payload = try JSON(data: payloadData)

                // Find the package in the payload
                for item in payload.arrayValue {
                    let itemName = cask ? item["token"].stringValue : item["name"].stringValue
                    if itemName == name {
                        return (description: item["desc"].string, homepage: item["homepage"].string)
                    }
                }
            } catch {
                // If reading from cache fails, fall through to API call
                printOS("Failed to read from cache, falling back to API: \(error)")
            }
        }

        // Fallback to API if cache doesn't exist or package not found
        let url = cask ?
            URL(string: "https://formulae.brew.sh/api/cask/\(name).json")! :
            URL(string: "https://formulae.brew.sh/api/formula/\(name).json")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSON(data: data)

        let description = json["desc"].string
        let homepage = json["homepage"].string

        return (description: description, homepage: homepage)
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

        let json = try JSON(data: data)
        let analytics = json["analytics"]

        if cask {
            // Cask: simpler structure {"install": {"30d": {"name": 123}}}
            let install30d = analytics["install"]["30d"].dictionary?.values.first?.int
            let install90d = analytics["install"]["90d"].dictionary?.values.first?.int
            let install365d = analytics["install"]["365d"].dictionary?.values.first?.int

            return HomebrewAnalytics(
                install30d: install30d,
                install90d: install90d,
                install365d: install365d,
                installOnRequest30d: nil,
                installOnRequest90d: nil,
                installOnRequest365d: nil,
                buildError30d: nil
            )
        } else {
            // Formula: full structure with install_on_request and build_error
            let install30d = analytics["install"]["30d"].dictionary?.values.reduce(0) { $0 + ($1.int ?? 0) }
            let install90d = analytics["install"]["90d"].dictionary?.values.reduce(0) { $0 + ($1.int ?? 0) }
            let install365d = analytics["install"]["365d"].dictionary?.values.reduce(0) { $0 + ($1.int ?? 0) }
            let installOnRequest30d = analytics["install_on_request"]["30d"].dictionary?.values.reduce(0) { $0 + ($1.int ?? 0) }
            let installOnRequest90d = analytics["install_on_request"]["90d"].dictionary?.values.reduce(0) { $0 + ($1.int ?? 0) }
            let installOnRequest365d = analytics["install_on_request"]["365d"].dictionary?.values.reduce(0) { $0 + ($1.int ?? 0) }
            let buildError30d = analytics["build_error"]["30d"].dictionary?.values.reduce(0) { $0 + ($1.int ?? 0) }

            return HomebrewAnalytics(
                install30d: install30d,
                install90d: install90d,
                install365d: install365d,
                installOnRequest30d: installOnRequest30d,
                installOnRequest90d: installOnRequest90d,
                installOnRequest365d: installOnRequest365d,
                buildError30d: buildError30d
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

    /// Get list of outdated package names from brew outdated
    func getOutdatedPackages() async throws -> Set<String> {
        let arguments = ["outdated", "--quiet"]
        let result = try await runBrewCommand(arguments)

        if result.error.contains("Error") {
            throw HomebrewError.commandFailed(result.error)
        }

        // Parse package names from output (one per line)
        let packageNames = result.output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return Set(packageNames)
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

    func removeTap(name: String) async throws {
        let arguments = ["untap", name]
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
        let json = try JSON(data: data)
        return json["tag_name"].stringValue
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

        guard let jsonData = result.output.data(using: .utf8) else {
            return nil
        }

        let json = try JSON(data: jsonData)
        let array = cask ? json["casks"].arrayValue : json["formulae"].arrayValue

        guard let item = array.first else {
            return nil
        }

        let name = cask ? item["full_token"].stringValue : item["full_name"].stringValue
        let desc = item["desc"].string
        let homepage = item["homepage"].string
        let license = item["license"].string
        let version = cask ? item["version"].string : item["versions"]["stable"].string
        let dependencies = cask ?
            item["depends_on"]["formula"].arrayValue.map { $0.stringValue } :
            item["dependencies"].arrayValue.map { $0.stringValue }
        let caveats = item["caveats"].string

        // Common fields
        let tap = item["tap"].string
        let fullName = item["full_name"].string
        let isDeprecated = item["deprecated"].bool ?? false
        let deprecationReason = item["deprecation_reason"].string
        let isDisabled = item["disabled"].bool ?? false
        let disableDate = item["disable_date"].string
        let conflictsWith = item["conflicts_with"].arrayValue.map { $0.stringValue }

        // Formula-specific fields
        let isBottled = cask ? nil : (item["versions"]["bottle"].bool ?? false)
        let isKegOnly = cask ? nil : (item["keg_only"].bool ?? false)
        let kegOnlyReason: String?
        if !cask {
            if let explanation = item["keg_only_reason"]["explanation"].string, !explanation.isEmpty {
                kegOnlyReason = explanation
            } else if let reason = item["keg_only_reason"]["reason"].string {
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
        let buildDependencies = cask ? nil : item["build_dependencies"].arrayValue.map { $0.stringValue }
        let aliases = cask ? nil : item["aliases"].arrayValue.map { $0.stringValue }
        let versionedFormulae = cask ? nil : item["versioned_formulae"].arrayValue.map { $0.stringValue }
        let requirements: String?
        if !cask {
            requirements = item["requirements"].arrayValue.compactMap { req in
                if req["name"].string == "macos", let version = req["version"].string {
                    return "macOS >= \(version)"
                }
                return nil
            }.first
        } else {
            requirements = nil
        }

        // Cask-specific fields
        let caskName = cask ? item["name"].arrayValue.map { $0.stringValue } : nil
        let autoUpdates = cask ? item["auto_updates"].bool : nil
        let artifacts = cask ? item["artifacts"].arrayValue.compactMap { artifact -> String? in
            if let app = artifact["app"].array?.first?.string {
                return "\(app) (App)"
            } else if let pkg = artifact["pkg"].array?.first?.string {
                return "\(pkg) (Pkg)"
            }
            return nil
        } : nil

        return HomebrewSearchResult(
            name: name,
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
            isDisabled: isDisabled,
            disableDate: disableDate,
            conflictsWith: conflictsWith.isEmpty ? nil : conflictsWith,
            isBottled: isBottled,
            isKegOnly: isKegOnly,
            kegOnlyReason: kegOnlyReason,
            buildDependencies: buildDependencies,
            aliases: aliases,
            versionedFormulae: versionedFormulae,
            requirements: requirements,
            caskName: caskName,
            autoUpdates: autoUpdates,
            artifacts: artifacts
        )
    }
}
