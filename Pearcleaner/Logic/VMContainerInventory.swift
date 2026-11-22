//
//  VMContainerInventory.swift
//  Pearcleaner
//
//  Lists VM and container runtime disk artifacts with real item names and
//  sizes: docker images/containers/volumes, colima and lima VMs, OrbStack
//  machines, UTM bundles, minikube profiles. Read-only; cleanup is offered
//  through each tool's own CLI after confirmation in the UI.
//

import Foundation

struct VMContainerGroup: Identifiable {
    enum Section: String, CaseIterable, Identifiable {
        case images = "Images"
        case containers = "Containers"
        case volumes = "Volumes"
        case buildCache = "Build Cache"
        case machines = "VMs"

        var id: String { rawValue }

        var title: String { rawValue }
    }

    let id = UUID()
    let tool: String
    let toolIcon: String
    let backend: String
    let items: [Item]
    let note: String?

    struct Item: Identifiable {
        enum Safety {
            case cache          // re-downloadable, no data loss
            case destructive    // user data inside, irreversible
        }

        let id = UUID()
        let kind: Section
        let name: String
        let detail: String?
        let sizeBytes: Int64
        let provisionedBytes: Int64?
        let isRunning: Bool
        let safety: Safety
        let tool: String
        let deleteCommand: [String]?     // CLI path + args, nil = not supported
        let stopCommand: [String]?        // CLI to stop a running item, nil = not supported
        let hostPath: String?            // on-disk artifact backing this item

        var badge: String {
            switch kind {
            case .images: return "img"
            case .containers: return "ctr"
            case .volumes: return "vol"
            case .buildCache: return "bld"
            case .machines: return "vm"
            }
        }
    }
}

struct VMContainerInventory {
    let groups: [VMContainerGroup]

    var totalBytes: Int64 {
        groups.flatMap { $0.items }.filter { $0.kind != .buildCache }.reduce(0) { $0 + $1.sizeBytes }
    }
}

enum VMContainerScanner {
    static func scan() -> VMContainerInventory {
        var groups: [VMContainerGroup] = []
        let home = NSHomeDirectory()

        groups.append(contentsOf: scanDocker(home: home))
        groups.append(contentsOf: scanColima(home: home))
        groups.append(contentsOf: scanLima(home: home))
        if let group = scanOrbStack(home: home) { groups.append(group) }
        if let group = scanUTM(home: home) { groups.append(group) }
        if let group = scanMinikube(home: home) { groups.append(group) }

        return VMContainerInventory(groups: groups)
    }

    // MARK: - Docker (works against any backend: desktop, colima, orbstack, rancher)

    private struct DockerDfJSON: Decodable {
        struct ImageEntry: Decodable {
            let Repository: String?
            let Tag: String?
            let ID: String?
            let Size: String?
        }
        struct ContainerEntry: Decodable {
            let Names: String?
            let Image: String?
            let Size: String?
        }
        struct VolumeEntry: Decodable {
            let Name: String?
            let Size: String?
        }
        struct BuildCacheEntry: Decodable {
            let ID: String?
            let Size: String?
        }
        let Images: [ImageEntry]?
        let Containers: [ContainerEntry]?
        let Volumes: [VolumeEntry]?
        let BuildCache: [BuildCacheEntry]?
    }

    private static func scanDocker(home: String) -> [VMContainerGroup] {
        guard let docker = DevEnvProcess.which("docker") else { return [] }

        // Identify the backend from the active context so the header is honest
        // (a bare docker CLI usually fronts colima or orbstack, not Docker Desktop).
        var backend = "Docker"
        if let contextOut = DevEnvProcess.run(docker, ["context", "show"], timeout: 5) {
            let ctx = contextOut.trimmingCharacters(in: .whitespacesAndNewlines)
            if ctx.contains("colima") { backend = "colima" }
            else if ctx.contains("orbstack") { backend = "OrbStack" }
            else if ctx.contains("rancher") { backend = "Rancher Desktop" }
        }

        guard let json = DevEnvProcess.run(docker, ["system", "df", "-v", "--format", "json"], timeout: 15),
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(DockerDfJSON.self, from: data) else {
            return [VMContainerGroup(tool: "Docker", toolIcon: "docker", backend: backend, items: [], note: "daemon not running or not installed")]
        }

        var items: [VMContainerGroup.Item] = []

        // `system df` does not report container state; `docker ps` lists only
        // running containers, so a hit means the container is up.
        var runningContainers: Set<String> = []
        if let psOut = DevEnvProcess.run(docker, ["ps", "--format", "{{.Names}}"], timeout: 10) {
            runningContainers = Set(psOut.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
        }

        for image in decoded.Images ?? [] {
            let name = [image.Repository ?? "<none>", image.Tag ?? "<none>"].joined(separator: ":")
            items.append(VMContainerGroup.Item(
                kind: .images,
                name: name,
                detail: image.ID.map { String($0.prefix(12)) },
                sizeBytes: DevEnvProcess.parseSizeString(image.Size ?? "") ?? 0,
                provisionedBytes: nil,
                isRunning: false,
                safety: .cache,
                tool: "docker",
                deleteCommand: [docker, "rmi", name],
                stopCommand: nil,
                hostPath: nil
            ))
        }

        for container in decoded.Containers ?? [] {
            let containerName = container.Names?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? "container"
            let isRunning = runningContainers.contains(containerName)
            items.append(VMContainerGroup.Item(
                kind: .containers,
                name: containerName,
                detail: container.Image,
                sizeBytes: DevEnvProcess.parseSizeString(container.Size ?? "") ?? 0,
                provisionedBytes: nil,
                isRunning: isRunning,
                safety: .destructive,
                tool: "docker",
                deleteCommand: [docker, "rm", "-f", container.Names ?? ""],
                stopCommand: isRunning ? [docker, "stop", containerName] : nil,
                hostPath: nil
            ))
        }

        for volume in decoded.Volumes ?? [] {
            items.append(VMContainerGroup.Item(
                kind: .volumes,
                name: volume.Name ?? "volume",
                detail: nil,
                sizeBytes: DevEnvProcess.parseSizeString(volume.Size ?? "") ?? 0,
                provisionedBytes: nil,
                isRunning: false,
                safety: .destructive,
                tool: "docker",
                deleteCommand: [docker, "volume", "rm", volume.Name ?? ""],
                stopCommand: nil,
                hostPath: nil
            ))
        }

        for cache in decoded.BuildCache ?? [] {
            items.append(VMContainerGroup.Item(
                kind: .buildCache,
                name: cache.ID ?? "build cache",
                detail: nil,
                sizeBytes: DevEnvProcess.parseSizeString(cache.Size ?? "") ?? 0,
                provisionedBytes: nil,
                isRunning: false,
                safety: .cache,
                tool: "docker",
                deleteCommand: [docker, "builder", "prune", "-f"],
                stopCommand: nil,
                hostPath: nil
            ))
        }

        // The VM disk holds every docker artifact. Colima/OrbStack sections show
        // that disk; Docker Desktop's Docker.raw would too, but only when present.
        var note: String?
        if items.isEmpty { note = "no docker content on this machine" }

        return [VMContainerGroup(tool: "Docker", toolIcon: "docker", backend: backend, items: items, note: note)]
    }

    // MARK: - Colima

    private struct ColimaJSON: Decodable {
        let name: String?
        let status: String?
        let arch: String?
        let runtime: String?
        let disk: Int?      // provisioned bytes, not on-disk usage
        let memory: Int?
    }

    private static func scanColima(home: String) -> [VMContainerGroup] {
        let colimaHome = "\(home)/.colima"
        guard FileManager.default.fileExists(atPath: colimaHome),
              let colima = DevEnvProcess.which("colima") else { return [] }

        guard let json = DevEnvProcess.run(colima, ["list", "--json"], timeout: 10) else {
            return [filesystemFallbackColima(home: home, tool: "Colima", cliPath: colima)]
        }

        // colima list --json prints one object per line.
        var items: [VMContainerGroup.Item] = []
        for line in json.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let vm = try? JSONDecoder().decode(ColimaJSON.self, from: data) else { continue }
            let name = vm.name ?? "colima"
            // colima reuses the fixed lima instance dir "_lima/colima" regardless of profile name.
            let diskPath = colimaDiskPath(colimaHome: colimaHome, profile: name)
            let actual = sparseFileSize(at: diskPath)
            items.append(VMContainerGroup.Item(
                kind: .machines,
                name: name,
                detail: "\(vm.status ?? "unknown") \(middling(vm.runtime))",
                sizeBytes: actual,
                provisionedBytes: vm.disk.map(Int64.init),
                isRunning: (vm.status?.lowercased() == "running"),
                safety: .destructive,
                tool: "colima",
                deleteCommand: [colima, "delete", name, "--force"],
                stopCommand: (vm.status?.lowercased() == "running") ? [colima, "stop", name] : nil,
                hostPath: diskPath
            ))
        }

        return [VMContainerGroup(tool: "Colima", toolIcon: "cpu", backend: "QEMU/VZ via lima", items: items, note: items.isEmpty ? "no instances" : nil)]
    }

    /// colima 0.5+ stores every profile's lima instance under the same "colima"
    /// dir. Fall back to a profile-named dir for forks or custom LIMA_HOME setups.
    private static func colimaDiskPath(colimaHome: String, profile: String) -> String {
        let fixed = "\(colimaHome)/_lima/colima/disk"
        if FileManager.default.fileExists(atPath: fixed) { return fixed }
        return "\(colimaHome)/_lima/\(profile)/disk"
    }

    /// Old colima layouts (pre-0.5) kept disks under ~/.lima/colima. When the
    /// CLI is missing or fails, list what is on disk instead of hiding it.
    private static func filesystemFallbackColima(home: String, tool: String, cliPath: String?) -> VMContainerGroup {
        var items: [VMContainerGroup.Item] = []
        let limaRoot = "\(home)/.colima/_lima"
        if let profiles = try? FileManager.default.contentsOfDirectory(atPath: limaRoot) {
            for profile in profiles where !profile.hasPrefix("_") {
                let diskPath = "\(limaRoot)/\(profile)/disk"
                if FileManager.default.fileExists(atPath: diskPath) {
                    items.append(VMContainerGroup.Item(
                        kind: .machines,
                        name: profile,
                        detail: "stopped (CLI unavailable)",
                        sizeBytes: fileSize(at: diskPath),
                        provisionedBytes: nil,
                        isRunning: false,
                        safety: .destructive,
                        tool: "colima",
                        deleteCommand: nil,
                        stopCommand: nil,
                        hostPath: diskPath
                    ))
                }
            }
        }
        return VMContainerGroup(tool: tool, toolIcon: "cpu", backend: "QEMU/VZ via lima", items: items, note: nil)
    }

    // MARK: - Lima

    private struct LimaJSON: Decodable {
        let name: String?
        let status: String?
        let dir: String?
        let vmType: String?
        let disk: Int?
    }

    private static func scanLima(home: String) -> [VMContainerGroup] {
        let limaHome = "\(home)/.lima"
        guard FileManager.default.fileExists(atPath: limaHome),
              let limactl = DevEnvProcess.which("limactl") else { return [] }

        guard let json = DevEnvProcess.run(limactl, ["list", "--json"], timeout: 10) else {
            return [filesystemFallbackLima(home: home)]
        }

        var items: [VMContainerGroup.Item] = []
        for line in json.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let vm = try? JSONDecoder().decode(LimaJSON.self, from: data) else { continue }
            let name = vm.name ?? "lima"
            let diskPath = vm.dir.map { "\($0)/disk" } ?? "\(limaHome)/\(name)/disk"
            items.append(VMContainerGroup.Item(
                kind: .machines,
                name: name,
                detail: "\(vm.status ?? "unknown") \(middling(vm.vmType))",
                sizeBytes: sparseFileSize(at: diskPath),
                provisionedBytes: vm.disk.map(Int64.init),
                isRunning: (vm.status?.lowercased() == "running"),
                safety: .destructive,
                tool: "lima",
                deleteCommand: [limactl, "delete", name, "--force"],
                stopCommand: (vm.status?.lowercased() == "running") ? [limactl, "stop", name] : nil,
                hostPath: diskPath
            ))
        }

        return [VMContainerGroup(tool: "Lima", toolIcon: "pc", backend: "QEMU/VZ", items: items, note: items.isEmpty ? "no instances" : nil)]
    }

    private static func filesystemFallbackLima(home: String) -> VMContainerGroup {
        var items: [VMContainerGroup.Item] = []
        let limaRoot = "\(home)/.lima"
        if let instances = try? FileManager.default.contentsOfDirectory(atPath: limaRoot) {
            for instance in instances where !instance.hasPrefix("_") {
                let diskPath = "\(limaRoot)/\(instance)/disk"
                if FileManager.default.fileExists(atPath: diskPath) {
                    items.append(VMContainerGroup.Item(
                        kind: .machines,
                        name: instance,
                        detail: "stopped (CLI unavailable)",
                        sizeBytes: fileSize(at: diskPath),
                        provisionedBytes: nil,
                        isRunning: false,
                        safety: .destructive,
                        tool: "lima",
                        deleteCommand: nil,
                        stopCommand: nil,
                        hostPath: diskPath
                    ))
                }
            }
        }
        return VMContainerGroup(tool: "Lima", toolIcon: "pc", backend: "QEMU/VZ", items: items, note: nil)
    }

    // MARK: - OrbStack

    private static func scanOrbStack(home: String) -> VMContainerGroup? {
        let orbHome = "\(home)/.orbstack"
        guard FileManager.default.fileExists(atPath: orbHome) else { return nil }

        var items: [VMContainerGroup.Item] = []
        var note: String? = nil

        if let orbctl = DevEnvProcess.which("orbctl"),
           let output = DevEnvProcess.run(orbctl, ["list"], timeout: 10) {
            for line in output.split(separator: "\n").map(String.init) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                items.append(VMContainerGroup.Item(
                    kind: .machines,
                    name: trimmed,
                    detail: "Linux machine",
                    sizeBytes: 0,
                    provisionedBytes: nil,
                    isRunning: false,
                    safety: .destructive,
                    tool: "orbstack",
                    deleteCommand: [orbctl, "delete", "-f", trimmed],
                    stopCommand: [orbctl, "stop", trimmed],
                    hostPath: nil
                ))
            }
            if items.isEmpty { note = "no machines" }
        } else {
            note = "run OrbStack to list machines"
        }

        return VMContainerGroup(tool: "OrbStack", toolIcon: "shippingbox", backend: "OrbStack VM", items: items, note: note)
    }

    // MARK: - UTM

    private static func scanUTM(home: String) -> VMContainerGroup? {
        let documentsPath = "\(home)/Library/Containers/com.utmapp.UTM/Data/Documents"
        guard FileManager.default.fileExists(atPath: documentsPath) else { return nil }

        var items: [VMContainerGroup.Item] = []
        if let bundles = try? FileManager.default.contentsOfDirectory(atPath: documentsPath) {
            for bundle in bundles where bundle.hasSuffix(".utm") {
                let bundlePath = "\(documentsPath)/\(bundle)"
                let name = String(bundle.dropLast(4))
                items.append(VMContainerGroup.Item(
                    kind: .machines,
                    name: name,
                    detail: "guest OS and disk in bundle",
                    sizeBytes: directorySize(at: bundlePath),
                    provisionedBytes: nil,
                    isRunning: false,
                    safety: .destructive,
                    tool: "utm",
                    deleteCommand: nil,   // utmctl needs the app running; the UI offers a Trash action instead
                    stopCommand: nil,
                    hostPath: bundlePath
                ))
            }
        }

        return VMContainerGroup(tool: "UTM", toolIcon: "display", backend: "QEMU/Apple Virtualization", items: items, note: items.isEmpty ? "no VMs" : nil)
    }

    // MARK: - minikube

    private static func scanMinikube(home: String) -> VMContainerGroup? {
        let mkHome = "\(home)/.minikube"
        guard FileManager.default.fileExists(atPath: mkHome),
              let minikube = DevEnvProcess.which("minikube") else { return nil }

        var items: [VMContainerGroup.Item] = []
        if let json = DevEnvProcess.run(minikube, ["profile", "list", "-o", "json"], timeout: 15),
           let data = json.data(using: .utf8) {
            struct ProfileList: Decodable {
                struct Profile: Decodable {
                    let Name: String?
                    let Status: String?
                }
                let valid: [Profile]?
                let invalid: [Profile]?
            }
            if let decoded = try? JSONDecoder().decode(ProfileList.self, from: data) {
                for profile in (decoded.valid ?? []) + (decoded.invalid ?? []) {
                    let name = profile.Name ?? "minikube"
                    let profilePath = "\(mkHome)/profiles/\(name)"
                    items.append(VMContainerGroup.Item(
                        kind: .machines,
                        name: name,
                        detail: profile.Status,
                        sizeBytes: directorySize(at: profilePath),
                        provisionedBytes: nil,
                        isRunning: (profile.Status?.lowercased() == "running"),
                        safety: .destructive,
                        tool: "minikube",
                        deleteCommand: [minikube, "delete", "-p", name],
                        stopCommand: (profile.Status?.lowercased() == "running") ? [minikube, "stop", "-p", name] : nil,
                        hostPath: profilePath
                    ))
                }
            }
        }

        if items.isEmpty {
            // Cache dir is re-downloadable and often the biggest artifact.
            let cachePath = "\(mkHome)/cache"
            let cacheSize = directorySize(at: cachePath)
            if cacheSize > 0 {
                items.append(VMContainerGroup.Item(
                    kind: .buildCache,
                    name: "image and ISO cache",
                    detail: "re-downloadable",
                    sizeBytes: cacheSize,
                    provisionedBytes: nil,
                    isRunning: false,
                    safety: .cache,
                    tool: "minikube",
                    deleteCommand: nil,
                    stopCommand: nil,
                    hostPath: cachePath
                ))
            }
        }

        return VMContainerGroup(tool: "minikube", toolIcon: "gauge", backend: "QEMU/HyperKit/Docker", items: items, note: items.isEmpty ? "no profiles" : nil)
    }

    // MARK: - Helpers

    private static func middling(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        return "(\(value))"
    }

    /// On-disk bytes for sparse files (VM disks): logical size vastly overstates
    /// real usage, st_blocks*512 counts allocated blocks instead.
    private static func sparseFileSize(at path: String) -> Int64 {
        var st = stat()
        guard stat(path, &st) == 0 else { return 0 }
        let physical = Int64(st.st_blocks) * 512
        return physical > 0 ? physical : fileSize(at: path)
    }

    private static func fileSize(at path: String) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber else { return 0 }
        return size.int64Value
    }

    static func directorySize(at path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  values.isDirectory != true,
                  let fileSize = values.fileSize else { continue }
            total += Int64(fileSize)
        }
        return total
    }
}