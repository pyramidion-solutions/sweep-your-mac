import Foundation

actor DockerScanner {
    private let fileManager = FileManager.default

    enum DockerComponent: String, CaseIterable, Identifiable {
        case diskImage = "Disk Image"
        case images = "Images"
        case containers = "Containers"
        case volumes = "Volumes"
        case buildCache = "Build Cache"
        case logs = "Logs"
        case other = "Other Data"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .diskImage: return "internaldrive.fill"
            case .images: return "shippingbox.fill"
            case .containers: return "cube.fill"
            case .volumes: return "externaldrive.fill"
            case .buildCache: return "hammer.fill"
            case .logs: return "doc.text.fill"
            case .other: return "folder.fill"
            }
        }

        var description: String {
            switch self {
            case .diskImage: return "Docker Desktop VM disk image"
            case .images: return "Downloaded and built Docker images"
            case .containers: return "Container filesystems"
            case .volumes: return "Persistent data volumes"
            case .buildCache: return "Image build cache layers"
            case .logs: return "Docker daemon and container logs"
            case .other: return "Other Docker data"
            }
        }

        var color: String {
            switch self {
            case .diskImage: return "blue"
            case .images: return "purple"
            case .containers: return "green"
            case .volumes: return "orange"
            case .buildCache: return "yellow"
            case .logs: return "gray"
            case .other: return "secondary"
            }
        }

        var canClean: Bool {
            switch self {
            case .diskImage: return false // Requires Docker commands
            case .images, .containers, .volumes, .buildCache: return true
            case .logs: return true
            case .other: return false
            }
        }
    }

    struct DockerImage: Identifiable {
        let id: String
        let repository: String
        let tag: String
        let size: Int64
        let created: String

        var displayName: String {
            if repository == "<none>" {
                return "Dangling image"
            }
            return tag == "<none>" ? repository : "\(repository):\(tag)"
        }

        var formattedSize: String {
            size.formattedBytes
        }
    }

    struct DockerContainer: Identifiable {
        let id: String
        let name: String
        let image: String
        let status: String
        let size: Int64

        var isRunning: Bool {
            status.lowercased().contains("up")
        }

        var formattedSize: String {
            size.formattedBytes
        }
    }

    struct DockerVolume: Identifiable {
        let id: String
        let name: String
        let driver: String
        let size: Int64

        var formattedSize: String {
            size.formattedBytes
        }
    }

    struct DockerBuildCache: Identifiable {
        let id: String
        let cacheType: String
        let size: Int64
        let inUse: Bool

        var formattedSize: String {
            size.formattedBytes
        }
    }

    struct ComponentInfo: Identifiable {
        let id = UUID()
        let component: DockerComponent
        let size: Int64
        let itemCount: Int
        let details: String

        var formattedSize: String {
            size.formattedBytes
        }
    }

    struct DockerScanResult {
        let isDockerInstalled: Bool
        let isDockerRunning: Bool
        let components: [ComponentInfo]
        let images: [DockerImage]
        let containers: [DockerContainer]
        let volumes: [DockerVolume]
        let buildCache: [DockerBuildCache]
        let totalSize: Int64
        let reclaimableSize: Int64
        let scanDuration: TimeInterval

        var formattedTotalSize: String {
            totalSize.formattedBytes
        }

        var formattedReclaimableSize: String {
            reclaimableSize.formattedBytes
        }
    }

    private var homeDirectory: String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    private var dockerDesktopPath: String {
        "\(homeDirectory)/Library/Containers/com.docker.docker"
    }

    private var dockerConfigPath: String {
        "\(homeDirectory)/.docker"
    }

    func scan(progressHandler: @escaping (String) -> Void) async -> DockerScanResult {
        let startTime = Date()
        var components: [ComponentInfo] = []
        var images: [DockerImage] = []
        var containers: [DockerContainer] = []
        var volumes: [DockerVolume] = []
        var buildCache: [DockerBuildCache] = []
        var totalSize: Int64 = 0
        var reclaimableSize: Int64 = 0

        await MainActor.run {
            progressHandler("Checking Docker installation...")
        }

        let isInstalled = isDockerInstalled()
        let isRunning = isInstalled ? await isDockerRunning() : false

        if !isInstalled {
            let duration = Date().timeIntervalSince(startTime)
            return DockerScanResult(
                isDockerInstalled: false,
                isDockerRunning: false,
                components: [],
                images: [],
                containers: [],
                volumes: [],
                buildCache: [],
                totalSize: 0,
                reclaimableSize: 0,
                scanDuration: duration
            )
        }

        // Scan disk image
        await MainActor.run {
            progressHandler("Scanning Docker disk image...")
        }
        if let diskImageInfo = await scanDiskImage() {
            components.append(diskImageInfo)
            totalSize += diskImageInfo.size
        }

        // If Docker is running, get detailed info
        if isRunning {
            await MainActor.run {
                progressHandler("Scanning Docker images...")
            }
            images = await getDockerImages()
            let imagesSize = images.reduce(0) { $0 + $1.size }
            if imagesSize > 0 {
                components.append(ComponentInfo(
                    component: .images,
                    size: imagesSize,
                    itemCount: images.count,
                    details: "\(images.count) images"
                ))
            }

            await MainActor.run {
                progressHandler("Scanning Docker containers...")
            }
            containers = await getDockerContainers()
            let containersSize = containers.reduce(0) { $0 + $1.size }
            if containersSize > 0 || !containers.isEmpty {
                components.append(ComponentInfo(
                    component: .containers,
                    size: containersSize,
                    itemCount: containers.count,
                    details: "\(containers.count) containers"
                ))
            }

            await MainActor.run {
                progressHandler("Scanning Docker volumes...")
            }
            volumes = await getDockerVolumes()
            let volumesSize = volumes.reduce(0) { $0 + $1.size }
            if volumesSize > 0 || !volumes.isEmpty {
                components.append(ComponentInfo(
                    component: .volumes,
                    size: volumesSize,
                    itemCount: volumes.count,
                    details: "\(volumes.count) volumes"
                ))
            }

            await MainActor.run {
                progressHandler("Scanning Docker build cache...")
            }
            buildCache = await getDockerBuildCache()
            let cacheSize = buildCache.reduce(0) { $0 + $1.size }
            let unusedCacheSize = buildCache.filter { !$0.inUse }.reduce(0) { $0 + $1.size }
            if cacheSize > 0 {
                components.append(ComponentInfo(
                    component: .buildCache,
                    size: cacheSize,
                    itemCount: buildCache.count,
                    details: "\(buildCache.count) cache entries"
                ))
                reclaimableSize += unusedCacheSize
            }

            // Calculate reclaimable from dangling images
            let danglingImagesSize = images.filter { $0.repository == "<none>" }.reduce(0) { $0 + $1.size }
            reclaimableSize += danglingImagesSize

            // Add stopped containers as reclaimable
            let stoppedContainersSize = containers.filter { !$0.isRunning }.reduce(0) { $0 + $1.size }
            reclaimableSize += stoppedContainersSize
        }

        // Scan Docker logs
        await MainActor.run {
            progressHandler("Scanning Docker logs...")
        }
        if let logsInfo = await scanDockerLogs() {
            components.append(logsInfo)
            totalSize += logsInfo.size
            reclaimableSize += logsInfo.size
        }

        // Sort by size
        components.sort { $0.size > $1.size }

        // Recalculate total from components (avoid double counting with disk image)
        if !isRunning {
            totalSize = components.reduce(0) { $0 + $1.size }
        }

        let duration = Date().timeIntervalSince(startTime)

        return DockerScanResult(
            isDockerInstalled: isInstalled,
            isDockerRunning: isRunning,
            components: components,
            images: images,
            containers: containers,
            volumes: volumes,
            buildCache: buildCache,
            totalSize: totalSize,
            reclaimableSize: reclaimableSize,
            scanDuration: duration
        )
    }

    private func isDockerInstalled() -> Bool {
        // Check for Docker Desktop
        if fileManager.fileExists(atPath: "/Applications/Docker.app") {
            return true
        }
        // Check for Docker data directory
        if fileManager.fileExists(atPath: dockerDesktopPath) {
            return true
        }
        // Check for docker CLI
        let dockerPath = "/usr/local/bin/docker"
        if fileManager.fileExists(atPath: dockerPath) {
            return true
        }
        return false
    }

    private func isDockerRunning() async -> Bool {
        let result = await runCommand("docker", arguments: ["info"])
        return result.exitCode == 0
    }

    private func scanDiskImage() async -> ComponentInfo? {
        let possiblePaths = [
            "\(dockerDesktopPath)/Data/vms/0/data/Docker.raw",
            "\(dockerDesktopPath)/Data/vms/0/Docker.raw",
            "\(dockerDesktopPath)/Data/docker.raw",
            "\(dockerDesktopPath)/Data/Docker.raw"
        ]

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                if let attrs = try? fileManager.attributesOfItem(atPath: path),
                   let size = attrs[.size] as? Int64 {
                    return ComponentInfo(
                        component: .diskImage,
                        size: size,
                        itemCount: 1,
                        details: URL(fileURLWithPath: path).lastPathComponent
                    )
                }
            }
        }

        // Try to find any .raw file in the Docker data directory
        let dataPath = "\(dockerDesktopPath)/Data"
        if let size = await calculateDirectorySize(at: dataPath) {
            return ComponentInfo(
                component: .diskImage,
                size: size,
                itemCount: 1,
                details: "Docker Desktop data"
            )
        }

        return nil
    }

    private func scanDockerLogs() async -> ComponentInfo? {
        var totalSize: Int64 = 0
        var fileCount = 0

        let logPaths = [
            "\(dockerDesktopPath)/Data/log",
            "\(homeDirectory)/.docker/logs"
        ]

        for path in logPaths {
            if let (size, count) = await calculateDirectorySizeAndCount(at: path) {
                totalSize += size
                fileCount += count
            }
        }

        if totalSize > 0 {
            return ComponentInfo(
                component: .logs,
                size: totalSize,
                itemCount: fileCount,
                details: "\(fileCount) log files"
            )
        }

        return nil
    }

    private func getDockerImages() async -> [DockerImage] {
        let result = await runCommand("docker", arguments: ["images", "--format", "{{.ID}}|{{.Repository}}|{{.Tag}}|{{.Size}}|{{.CreatedSince}}"])

        guard result.exitCode == 0 else { return [] }

        var images: [DockerImage] = []
        let lines = result.output.split(separator: "\n")

        for line in lines {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map { String($0) }
            guard parts.count >= 5 else { continue }

            let size = parseDockerSize(parts[3])
            let image = DockerImage(
                id: parts[0],
                repository: parts[1],
                tag: parts[2],
                size: size,
                created: parts[4]
            )
            images.append(image)
        }

        return images
    }

    private func getDockerContainers() async -> [DockerContainer] {
        let result = await runCommand("docker", arguments: ["ps", "-a", "--format", "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.Size}}"])

        guard result.exitCode == 0 else { return [] }

        var containers: [DockerContainer] = []
        let lines = result.output.split(separator: "\n")

        for line in lines {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map { String($0) }
            guard parts.count >= 5 else { continue }

            let size = parseDockerSize(parts[4])
            let container = DockerContainer(
                id: parts[0],
                name: parts[1],
                image: parts[2],
                status: parts[3],
                size: size
            )
            containers.append(container)
        }

        return containers
    }

    private func getDockerVolumes() async -> [DockerVolume] {
        let result = await runCommand("docker", arguments: ["volume", "ls", "--format", "{{.Name}}|{{.Driver}}"])

        guard result.exitCode == 0 else { return [] }

        var volumes: [DockerVolume] = []
        let lines = result.output.split(separator: "\n")

        for line in lines {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map { String($0) }
            guard parts.count >= 2 else { continue }

            // Get volume size using docker volume inspect
            let inspectResult = await runCommand("docker", arguments: ["system", "df", "-v", "--format", "{{.Name}}|{{.Size}}"])
            var size: Int64 = 0

            if inspectResult.exitCode == 0 {
                let volumeName = parts[0]
                for inspectLine in inspectResult.output.split(separator: "\n") {
                    if inspectLine.contains(volumeName) {
                        let inspectParts = inspectLine.split(separator: "|").map { String($0) }
                        if inspectParts.count >= 2 {
                            size = parseDockerSize(inspectParts[1])
                        }
                    }
                }
            }

            let volume = DockerVolume(
                id: parts[0],
                name: parts[0],
                driver: parts[1],
                size: size
            )
            volumes.append(volume)
        }

        return volumes
    }

    private func getDockerBuildCache() async -> [DockerBuildCache] {
        let result = await runCommand("docker", arguments: ["builder", "du", "--verbose"])

        guard result.exitCode == 0 else { return [] }

        var cacheItems: [DockerBuildCache] = []
        let lines = result.output.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Parse lines like: "abc123  100MB  true  regular"
            let parts = trimmed.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
            guard parts.count >= 3 else { continue }

            // Skip header line
            if parts[0].lowercased() == "id" { continue }

            let size = parseDockerSize(parts[1])
            let inUse = parts.count > 2 && parts[2].lowercased() == "true"
            let cacheType = parts.count > 3 ? parts[3] : "unknown"

            let cacheItem = DockerBuildCache(
                id: parts[0],
                cacheType: cacheType,
                size: size,
                inUse: inUse
            )
            cacheItems.append(cacheItem)
        }

        return cacheItems
    }

    private func parseDockerSize(_ sizeStr: String) -> Int64 {
        let cleaned = sizeStr.trimmingCharacters(in: .whitespaces).uppercased()

        // Handle formats like "1.5GB", "100MB", "50KB"
        let pattern = "([0-9.]+)\\s*(B|KB|MB|GB|TB)?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) else {
            return 0
        }

        guard let numberRange = Range(match.range(at: 1), in: cleaned) else { return 0 }
        let numberStr = String(cleaned[numberRange])
        guard let number = Double(numberStr) else { return 0 }

        var multiplier: Double = 1
        if let unitRange = Range(match.range(at: 2), in: cleaned) {
            let unit = String(cleaned[unitRange])
            switch unit {
            case "KB": multiplier = 1024
            case "MB": multiplier = 1024 * 1024
            case "GB": multiplier = 1024 * 1024 * 1024
            case "TB": multiplier = 1024 * 1024 * 1024 * 1024
            default: multiplier = 1
            }
        }

        return Int64(number * multiplier)
    }

    private func runCommand(_ command: String, arguments: [String]) async -> (output: String, exitCode: Int32) {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return (output, process.terminationStatus)
        } catch {
            AppLogger.scanner.error("Failed to run command \(command): \(error.localizedDescription)")
            return ("", -1)
        }
    }

    private func calculateDirectorySize(at path: String) async -> Int64? {
        guard fileManager.fileExists(atPath: path) else { return nil }

        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               values.isDirectory == false {
                totalSize += Int64(values.fileSize ?? 0)
            }
        }

        return totalSize
    }

    private func calculateDirectorySizeAndCount(at path: String) async -> (size: Int64, count: Int)? {
        guard fileManager.fileExists(atPath: path) else { return nil }

        var totalSize: Int64 = 0
        var fileCount = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               values.isDirectory == false {
                totalSize += Int64(values.fileSize ?? 0)
                fileCount += 1
            }
        }

        return (totalSize, fileCount)
    }

    // MARK: - Cleanup Actions

    func pruneSystem() async -> (success: Bool, freedSpace: String, error: String?) {
        let result = await runCommand("docker", arguments: ["system", "prune", "-f"])
        if result.exitCode == 0 {
            // Parse freed space from output
            let freedSpace = extractFreedSpace(from: result.output)
            return (true, freedSpace, nil)
        }
        return (false, "0B", result.output)
    }

    func pruneImages() async -> (success: Bool, freedSpace: String, error: String?) {
        let result = await runCommand("docker", arguments: ["image", "prune", "-a", "-f"])
        if result.exitCode == 0 {
            let freedSpace = extractFreedSpace(from: result.output)
            return (true, freedSpace, nil)
        }
        return (false, "0B", result.output)
    }

    func pruneContainers() async -> (success: Bool, freedSpace: String, error: String?) {
        let result = await runCommand("docker", arguments: ["container", "prune", "-f"])
        if result.exitCode == 0 {
            let freedSpace = extractFreedSpace(from: result.output)
            return (true, freedSpace, nil)
        }
        return (false, "0B", result.output)
    }

    func pruneVolumes() async -> (success: Bool, freedSpace: String, error: String?) {
        let result = await runCommand("docker", arguments: ["volume", "prune", "-f"])
        if result.exitCode == 0 {
            let freedSpace = extractFreedSpace(from: result.output)
            return (true, freedSpace, nil)
        }
        return (false, "0B", result.output)
    }

    func pruneBuildCache() async -> (success: Bool, freedSpace: String, error: String?) {
        let result = await runCommand("docker", arguments: ["builder", "prune", "-f"])
        if result.exitCode == 0 {
            let freedSpace = extractFreedSpace(from: result.output)
            return (true, freedSpace, nil)
        }
        return (false, "0B", result.output)
    }

    func removeImage(_ imageId: String) async -> Bool {
        // Validate image ID to prevent command injection
        do {
            try DockerIDValidator.validateImageID(imageId)
        } catch {
            AppLogger.deletion.error("Invalid Docker image ID '\(imageId)': \(error.localizedDescription)")
            return false
        }
        let result = await runCommand("docker", arguments: ["rmi", imageId])
        return result.exitCode == 0
    }

    func removeContainer(_ containerId: String) async -> Bool {
        // Validate container ID to prevent command injection
        do {
            try DockerIDValidator.validateContainerID(containerId)
        } catch {
            AppLogger.deletion.error("Invalid Docker container ID '\(containerId)': \(error.localizedDescription)")
            return false
        }
        let result = await runCommand("docker", arguments: ["rm", containerId])
        return result.exitCode == 0
    }

    func removeVolume(_ volumeName: String) async -> Bool {
        // Validate volume name to prevent command injection
        do {
            try DockerIDValidator.validateVolumeName(volumeName)
        } catch {
            AppLogger.deletion.error("Invalid Docker volume name '\(volumeName)': \(error.localizedDescription)")
            return false
        }
        let result = await runCommand("docker", arguments: ["volume", "rm", volumeName])
        return result.exitCode == 0
    }

    private func extractFreedSpace(from output: String) -> String {
        // Look for patterns like "Total reclaimed space: 1.5GB"
        let pattern = "reclaimed space:\\s*([0-9.]+\\s*[KMGT]?B)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
           let range = Range(match.range(at: 1), in: output) {
            return String(output[range])
        }
        return "0B"
    }
}
