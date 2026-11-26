import Foundation

// MARK: - Development path catalog
//
// Declarative source of truth for the Development view cleanup knowledge.
// Adding a new tool is one entry in `allEnvironments`; the UI, search and
// rule filters pick it up without further code changes.

enum DevPathKind: String, CaseIterable {
    case cache            // re-downloadable or regenerable caches
    case logs             // log and crash reports
    case sessions         // agent/chat transcripts and session data
    case packages         // downloaded packages and artifacts
    case vmDisks          // VM images and disks (destructive to clean)
    case toolchains       // installed tool versions

    var title: String {
        switch self {
        case .cache: return String(localized: "Caches")
        case .logs: return String(localized: "Logs")
        case .sessions: return String(localized: "Sessions")
        case .packages: return String(localized: "Packages")
        case .vmDisks: return String(localized: "VM Disks")
        case .toolchains: return String(localized: "Toolchains")
        }
    }

    var icon: String {
        switch self {
        case .cache: return "tray.full"
        case .logs: return "doc.text"
        case .sessions: return "bubble.left.and.bubble.right"
        case .packages: return "shippingbox"
        case .vmDisks: return "externaldrive"
        case .toolchains: return "wrench.and.screwdriver"
        }
    }

    /// Whether cleaning this kind usually destroys meaningful user data.
    var isDestructive: Bool {
        switch self {
        case .vmDisks, .sessions: return true
        case .cache, .logs, .packages, .toolchains: return false
        }
    }
}

struct DevPathEntry: Identifiable, Hashable {
    let id: String          // raw path with ~ and wildcards, unique in the catalog
    let path: String
    let kind: DevPathKind

    init(_ path: String, _ kind: DevPathKind) {
        self.id = path
        self.path = path
        self.kind = kind
    }
}

struct DevEnvironment: Identifiable, Hashable {
    let id: String
    let name: String
    let entries: [DevPathEntry]

    init(name: String, entries: [DevPathEntry]) {
        self.id = name
        self.name = name
        self.entries = entries
    }
}

enum DevPathCatalog {

    static let allEnvironments: [DevEnvironment] = [
        DevEnvironment(name: "AI Agents", entries: [
            DevPathEntry("~/.codex/sessions/", .sessions),
            DevPathEntry("~/.codex/.tmp/", .cache),
            DevPathEntry("~/.codex/log/", .logs),
            DevPathEntry("~/.claude/projects/", .sessions),
            DevPathEntry("~/.claude/todos/", .sessions),
            DevPathEntry("~/.claude/shell-snapshots/", .sessions),
            DevPathEntry("~/.claude/statsig/", .cache),
            DevPathEntry("~/.claude/file-history/", .sessions),
            DevPathEntry("~/.cache/claude/", .cache),
            DevPathEntry("~/.cache/opencode/", .cache),
            DevPathEntry("~/.local/share/opencode/log/", .logs),
            DevPathEntry("~/.jcode/scratch/", .cache),
            DevPathEntry("~/.jcode/tmp/", .cache),
            DevPathEntry("~/.jcode/builds/", .cache),
            DevPathEntry("~/.jcode/logs/", .logs),
            DevPathEntry("~/.jcode/cache/", .cache),
            DevPathEntry("~/.jcode/reload-traces/", .cache),
            DevPathEntry("~/.cache/huggingface/hub/", .packages),
            DevPathEntry("~/Library/Application Support/Codex/component_crx_cache/", .cache),
            DevPathEntry("~/Library/Application Support/Codex/extensions_crx_cache/", .cache),
            DevPathEntry("~/Library/Application Support/Codex/GraphiteDawnCache/", .cache),
            DevPathEntry("~/Library/Application Support/Codex/Crashpad/", .logs),
            DevPathEntry("~/Library/Caches/Codex/", .cache),
            DevPathEntry("~/Library/Caches/com.openai.codex/", .cache),
            DevPathEntry("~/.gemini/tmp/", .cache)
        ]),
        DevEnvironment(name: "Android SDK", entries: [
            DevPathEntry("~/Library/Android/sdk/system-images/", .packages),
            DevPathEntry("~/Library/Android/sdk/build-tools/", .toolchains),
            DevPathEntry("~/Library/Android/sdk/platforms/", .packages),
            DevPathEntry("~/Library/Android/sdk/ndk/", .toolchains),
            DevPathEntry("~/Library/Android/sdk/temp/", .cache)
        ]),
        DevEnvironment(name: "Android Studio", entries: [
            DevPathEntry("~/.android/build-cache/", .cache),
            DevPathEntry("~/Library/Logs/AndroidStudio/", .logs),
            DevPathEntry("~/Library/Caches/Google/AndroidStudio*/", .cache)
        ]),
        DevEnvironment(name: "Bazel", entries: [
            DevPathEntry("~/.cache/bazel/", .cache),
            DevPathEntry("~/.bazelcache/", .cache)
        ]),
        DevEnvironment(name: "Cargo", entries: [
            DevPathEntry("~/.cargo/registry/", .packages),
            DevPathEntry("~/.cargo/git/", .packages)
        ]),
        DevEnvironment(name: "Carthage", entries: [
            DevPathEntry("~/Carthage/", .packages),
            DevPathEntry("~/Library/Caches/org.carthage.CarthageKit/", .cache)
        ]),
        DevEnvironment(name: "CocoaPods", entries: [
            DevPathEntry("~/Library/Caches/CocoaPods/", .cache),
            DevPathEntry("~/.cocoapods/repos/", .packages)
        ]),
        DevEnvironment(name: "Composer", entries: [
            DevPathEntry("~/.composer/cache/", .cache)
        ]),
        DevEnvironment(name: "Conda", entries: [
            DevPathEntry("~/anaconda3/pkgs/", .packages),
            DevPathEntry("~/miniconda3/pkgs/", .packages)
        ]),
        DevEnvironment(name: "Coursier", entries: [
            DevPathEntry("~/.cache/coursier/", .cache),
            DevPathEntry("~/.ivy2/cache/", .cache)
        ]),
        DevEnvironment(name: "Cursor", entries: [
            DevPathEntry("~/Library/Application Support/Cursor/Cache", .cache),
            DevPathEntry("~/Library/Application Support/Cursor/GPUCache", .cache),
            DevPathEntry("~/Library/Application Support/Cursor/CachedConfigurations", .cache),
            DevPathEntry("~/Library/Application Support/Cursor/CachedData", .cache),
            DevPathEntry("~/Library/Application Support/Cursor/CachedExtensionVSIXs", .cache),
            DevPathEntry("~/Library/Application Support/Cursor/CachedExtensions", .cache),
            DevPathEntry("~/Library/Application Support/Cursor/CachedProfilesData", .cache),
            DevPathEntry("~/Library/Application Support/Cursor/Code Cache", .cache),
            DevPathEntry("~/Library/Application Support/Cursor/Crashpad/", .logs),
            DevPathEntry("~/Library/Application Support/Cursor/component_crx_cache/", .cache),
            DevPathEntry("~/Library/Application Support/Cursor/User/workspaceStorage/", .cache)
        ]),
        DevEnvironment(name: "Deno", entries: [
            DevPathEntry("~/Library/Caches/deno", .cache),
            DevPathEntry("~/.deno/", .cache)
        ]),
        DevEnvironment(name: "Docker", entries: [
            DevPathEntry("~/.docker/cli-plugins/", .packages),
            DevPathEntry("~/.docker/buildx/", .cache),
            DevPathEntry("~/.colima/_store/", .cache),
            DevPathEntry("~/.colima/_templates/", .cache)
        ]),
        DevEnvironment(name: "Docker Desktop", entries: [
            DevPathEntry("~/Library/Containers/com.docker.docker/Data/log/", .logs),
            DevPathEntry("~/Library/Caches/com.docker.docker/", .cache),
            DevPathEntry("~/Library/Application Support/Docker Desktop/", .cache),
            DevPathEntry("~/Library/Logs/Docker Desktop/", .logs)
        ]),
        DevEnvironment(name: "Electron", entries: [
            DevPathEntry("~/Library/Caches/electron/", .cache),
            DevPathEntry("~/Library/Caches/electron-builder/", .cache),
            DevPathEntry("~/Library/Caches/node-gyp/", .cache),
            DevPathEntry("~/.electron-gyp/", .cache)
        ]),
        DevEnvironment(name: "Elixir", entries: [
            DevPathEntry("~/.mix/archives/", .packages),
            DevPathEntry("~/.cache/rebar3/", .cache),
            DevPathEntry("~/.cache/hex/", .cache)
        ]),
        DevEnvironment(name: "Go", entries: [
            DevPathEntry("~/Library/Caches/go-build/", .cache),
            DevPathEntry("~/go/pkg/mod/", .packages)
        ]),
        DevEnvironment(name: "Godot", entries: [
            DevPathEntry("~/Library/Caches/Godot/", .cache),
            DevPathEntry("~/Library/Application Support/Godot/export_templates/", .packages)
        ]),
        DevEnvironment(name: "Gradle", entries: [
            DevPathEntry("~/.gradle/caches/", .cache),
            DevPathEntry("~/.gradle/wrapper/dists/", .packages),
            DevPathEntry("~/.gradle/daemon/", .logs)
        ]),
        DevEnvironment(name: "Haskell Stack", entries: [
            DevPathEntry("~/.stack/snapshots/", .packages)
        ]),
        DevEnvironment(name: "Helm", entries: [
            DevPathEntry("~/Library/Caches/helm/", .cache)
        ]),
        DevEnvironment(name: "Homebrew", entries: [
            DevPathEntry("~/Library/Caches/Homebrew/", .cache)
        ]),
        DevEnvironment(name: "IntelliJ IDEA", entries: [
            DevPathEntry("~/Library/Caches/JetBrains/", .cache),
            DevPathEntry("~/Library/Logs/JetBrains/", .logs)
        ]),
        DevEnvironment(name: "JetBrains Toolbox", entries: [
            DevPathEntry("~/Library/Caches/JetBrains/Toolbox/", .cache),
            DevPathEntry("~/Library/Logs/JetBrains/Toolbox/", .logs)
        ]),
        DevEnvironment(name: "Julia", entries: [
            DevPathEntry("~/.julia/compiled/", .cache)
        ]),
        DevEnvironment(name: "LLM Models", entries: [
            DevPathEntry("~/.ollama/models/", .packages),
            DevPathEntry("~/.cache/lm-studio/", .packages)
        ]),
        DevEnvironment(name: "Maven", entries: [
            DevPathEntry("~/.m2/repository/", .packages)
        ]),
        DevEnvironment(name: "Mise", entries: [
            DevPathEntry("~/.cache/mise/", .cache)
        ]),
        DevEnvironment(name: "Nix", entries: [
            DevPathEntry("~/.cache/nix/", .cache)
        ]),
        DevEnvironment(name: "Node", entries: [
            DevPathEntry("~/.npm/", .cache),
            DevPathEntry("~/Library/Caches/node/", .cache)
        ]),
        DevEnvironment(name: "NuGet", entries: [
            DevPathEntry("~/.nuget/packages/", .packages)
        ]),
        DevEnvironment(name: "OrbStack", entries: [
            DevPathEntry("~/.orbstack/cache/", .cache),
            DevPathEntry("~/.orbstack/backup/", .vmDisks)
        ]),
        DevEnvironment(name: "Playwright", entries: [
            DevPathEntry("~/Library/Caches/ms-playwright/", .packages),
            DevPathEntry("~/.cache/ms-playwright-go/", .packages)
        ]),
        DevEnvironment(name: "Pnpm", entries: [
            DevPathEntry("~/Library/pnpm/store/", .packages),
            DevPathEntry("~/Library/Caches/pnpm/", .cache)
        ]),
        DevEnvironment(name: "Puppeteer", entries: [
            DevPathEntry("~/.cache/puppeteer/", .packages)
        ]),
        DevEnvironment(name: "Pip", entries: [
            DevPathEntry("~/Library/Caches/pip/", .cache)
        ]),
        DevEnvironment(name: "Poetry", entries: [
            DevPathEntry("~/Library/Caches/pypoetry/", .cache),
            DevPathEntry("~/Library/Application Support/pypoetry/", .cache)
        ]),
        DevEnvironment(name: "Pre-commit", entries: [
            DevPathEntry("~/Library/Caches/pre-commit/", .cache),
            DevPathEntry("~/.cache/pre-commit/", .cache)
        ]),
        DevEnvironment(name: "Pub", entries: [
            DevPathEntry("~/.pub-cache/hosted/", .packages),
            DevPathEntry("~/Library/Caches/flutter_engine/", .cache)
        ]),
        DevEnvironment(name: "Pyenv", entries: [
            DevPathEntry("~/.pyenv/cache/", .cache)
        ]),
        DevEnvironment(name: "Qt", entries: [
            DevPathEntry("~/Library/Caches/QtProject/", .cache)
        ]),
        DevEnvironment(name: "Rancher Desktop", entries: [
            DevPathEntry("~/Library/Caches/rancher-desktop/", .cache),
            DevPathEntry("~/Library/Logs/rancher-desktop/", .logs),
            DevPathEntry("~/.rd/cache/", .cache)
        ]),
        DevEnvironment(name: "Ruby Gems", entries: [
            DevPathEntry("~/.gem/ruby/*/cache/", .cache)
        ]),
        DevEnvironment(name: "Rust", entries: [
            DevPathEntry("~/Library/Caches/Mozilla.sccache/", .cache)
        ]),
        DevEnvironment(name: "Sublime Text", entries: [
            DevPathEntry("~/Library/Caches/Sublime Text/", .cache),
            DevPathEntry("~/Library/Application Support/Sublime Text/Cache/", .cache)
        ]),
        DevEnvironment(name: "Swift", entries: [
            DevPathEntry("~/Library/Caches/org.swift.swiftpm/", .cache),
            DevPathEntry("~/Library/Caches/swift-build/", .cache),
            DevPathEntry("~/Library/org.swift.swiftpm/", .cache)
        ]),
        DevEnvironment(name: "Terraform", entries: [
            DevPathEntry("~/.terraform.d/plugin-cache/", .cache),
            DevPathEntry("~/Library/Caches/terraform/", .cache)
        ]),
        DevEnvironment(name: "Toolchains", entries: [
            DevPathEntry("~/.rustup/toolchains/", .toolchains),
            DevPathEntry("~/.pyenv/versions/", .toolchains),
            DevPathEntry("~/.nvm/versions/node/", .toolchains),
            DevPathEntry("~/.local/share/mise/", .toolchains),
            DevPathEntry("~/.asdf/", .toolchains)
        ]),
        DevEnvironment(name: "Unity", entries: [
            DevPathEntry("~/Library/Unity/cache/", .cache),
            DevPathEntry("~/Library/Application Support/UnityHub/cache/", .cache),
            DevPathEntry("~/Library/Application Support/UnityHub/logs/", .logs)
        ]),
        DevEnvironment(name: "Uv", entries: [
            DevPathEntry("~/.cache/uv/", .cache)
        ]),
        DevEnvironment(name: "Vagrant", entries: [
            DevPathEntry("~/.vagrant.d/boxes/", .vmDisks)
        ]),
        DevEnvironment(name: "VirtualBox", entries: [
            DevPathEntry("~/Library/Caches/VirtualBox/", .cache),
            DevPathEntry("~/Library/VirtualBox/Logs/", .logs)
        ]),
        DevEnvironment(name: "VS Code", entries: [
            DevPathEntry("~/Library/Application Support/Code/Cache", .cache),
            DevPathEntry("~/Library/Application Support/Code/GPUCache", .cache),
            DevPathEntry("~/Library/Application Support/Code/CachedConfigurations", .cache),
            DevPathEntry("~/Library/Application Support/Code/CachedData", .cache),
            DevPathEntry("~/Library/Application Support/Code/CachedExtensionVSIXs", .cache),
            DevPathEntry("~/Library/Application Support/Code/CachedExtensions", .cache),
            DevPathEntry("~/Library/Application Support/Code/CachedProfilesData", .cache),
            DevPathEntry("~/Library/Application Support/Code/Code Cache", .cache),
            DevPathEntry("~/Library/Application Support/Code/Crashpad/", .logs),
            DevPathEntry("~/Library/Application Support/Code/component_crx_cache/", .cache),
            DevPathEntry("~/Library/Application Support/Code/User/workspaceStorage/", .cache)
        ]),
        DevEnvironment(name: "Xcode", entries: [
            DevPathEntry("~/Library/Caches/com.apple.dt.xcodebuild/", .cache),
            DevPathEntry("~/Library/Caches/com.apple.dt.Xcode.sourcecontrol.Git/", .cache),
            DevPathEntry("~/Library/Developer/CoreSimulator/Devices/", .vmDisks),
            DevPathEntry("~/Library/Developer/DeveloperDiskImages/", .vmDisks),
            DevPathEntry("~/Library/Developer/Xcode/Archives/", .packages),
            DevPathEntry("~/Library/Developer/Xcode/DerivedData/", .cache),
            DevPathEntry("~/Library/Developer/Xcode/DocumentationCache/", .cache),
            DevPathEntry("~/Library/Developer/Xcode/iOS DeviceSupport/", .packages),
            DevPathEntry("~/Library/Developer/Xcode/tvOS DeviceSupport/", .packages),
            DevPathEntry("~/Library/Developer/Xcode/watchOS DeviceSupport/", .packages),
            DevPathEntry("~/Library/Developer/Xcode/macOS DeviceSupport/", .packages),
            DevPathEntry("~/Library/Developer/Xcode/Products/", .packages)
        ]),
        DevEnvironment(name: "Yarn", entries: [
            DevPathEntry("~/.cache/yarn/", .cache),
            DevPathEntry("~/.yarn-cache/", .cache),
            DevPathEntry("~/.yarn/global/", .packages)
        ]),
        DevEnvironment(name: "Zed", entries: [
            DevPathEntry("~/Library/Caches/Zed/", .cache),
            DevPathEntry("~/Library/Application Support/Zed/node/cache/", .cache)
        ]),
        DevEnvironment(name: "Zig", entries: [
            DevPathEntry("~/.cache/zig/", .cache)
        ])
    ]

    /// Environments sorted by name, ready for display.
    static var environments: [DevEnvironment] {
        allEnvironments.sorted { $0.name < $1.name }
    }
}

// MARK: - Rule-based filters
//
// A filter rule answers one predicate over an entry. Rules compose through
// DevPathFilterEngine; adding a rule is a new conformance, removing one is
// deleting its registration line.

protocol DevPathRule {
    /// Unique key used for toggles and persistence.
    var id: String { get }
    var title: String { get }
    /// True when the entry passes the rule.
    func matches(_ entry: DevPathEntry) -> Bool
}

struct KindRule: DevPathRule {
    let kind: DevPathKind

    var id: String { "kind.\(kind.rawValue)" }
    var title: String { kind.title }

    func matches(_ entry: DevPathEntry) -> Bool {
        entry.kind == kind
    }
}

struct SearchRule: DevPathRule {
    let term: String

    var id: String { "search" }
    var title: String { String(localized: "Search") }

    func matches(_ entry: DevPathEntry) -> Bool {
        term.isEmpty || entry.path.localizedCaseInsensitiveContains(term)
    }
}

struct DevPathFilterEngine {
    let rules: [DevPathRule]

    /// All rules must pass (AND composition).
    func apply(to entries: [DevPathEntry]) -> [DevPathEntry] {
        guard !rules.isEmpty else { return entries }
        return entries.filter { entry in
            rules.allSatisfy { $0.matches(entry) }
        }
    }

    /// Default rule set for the Development view.
    static func defaultRules(searchTerm: String) -> [DevPathRule] {
        [SearchRule(term: searchTerm)]
    }
}

// MARK: - Compatibility facade
//
// PathLibrary keeps its public shape (PathEnv list) so existing views do
// not change; it now only projects the declarative catalog.

struct PathLibrary {
    static func getPaths() -> [PathEnv] {
        DevPathCatalog.environments.map { environment in
            PathEnv(
                name: environment.name,
                paths: environment.entries.map(\.path).sorted()
            )
        }
    }

    /// Catalog lookup for views that need entry metadata (kinds, rules).
    static func entries(for environmentName: String) -> [DevPathEntry] {
        DevPathCatalog.environments
            .first { $0.name == environmentName }?
            .entries ?? []
    }
}
