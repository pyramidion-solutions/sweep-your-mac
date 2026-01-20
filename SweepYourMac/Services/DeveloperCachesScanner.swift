import Foundation

actor DeveloperCachesScanner {
    private let fileManager = FileManager.default

    enum DeveloperTool: String, CaseIterable {
        case xcode = "Xcode"
        case simulator = "iOS Simulator"
        case gradle = "Gradle"
        case android = "Android"
        case flutter = "Flutter/Dart"
        case cocoapods = "CocoaPods"
        case cargo = "Rust/Cargo"
        case npm = "npm"
        case yarn = "Yarn"
        case homebrew = "Homebrew"
        case pip = "Python/pip"
        case cache = "General Cache"
        case nodeModules = "Node Modules"

        var icon: String {
            switch self {
            case .xcode: return "hammer.fill"
            case .simulator: return "iphone"
            case .gradle: return "g.circle.fill"
            case .android: return "android.logo"
            case .flutter: return "bird.fill"
            case .cocoapods: return "shippingbox.fill"
            case .cargo: return "gearshape.2.fill"
            case .npm, .yarn: return "shippingbox"
            case .homebrew: return "mug.fill"
            case .pip: return "snake"
            case .cache: return "folder.fill"
            case .nodeModules: return "folder.badge.gearshape"
            }
        }
    }

    struct DeveloperCacheLocation {
        let path: String
        let displayName: String
        let tool: DeveloperTool
        let safetyLevel: SafetyLevel
        let description: String
        let showVersions: Bool

        init(path: String, displayName: String, tool: DeveloperTool, safetyLevel: SafetyLevel = .safe, description: String = "", showVersions: Bool = false) {
            self.path = path
            self.displayName = displayName
            self.tool = tool
            self.safetyLevel = safetyLevel
            self.description = description
            self.showVersions = showVersions
        }
    }

    private var cacheLocations: [DeveloperCacheLocation] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            // Xcode
            DeveloperCacheLocation(
                path: "\(home)/Library/Developer/Xcode/DerivedData",
                displayName: "Xcode DerivedData",
                tool: .xcode,
                safetyLevel: .safe,
                description: "Build artifacts and indexes - safe to delete"
            ),
            DeveloperCacheLocation(
                path: "\(home)/Library/Developer/Xcode/Archives",
                displayName: "Xcode Archives",
                tool: .xcode,
                safetyLevel: .caution,
                description: "App archives for distribution - check before deleting",
                showVersions: true
            ),
            DeveloperCacheLocation(
                path: "\(home)/Library/Developer/Xcode/iOS DeviceSupport",
                displayName: "iOS Device Support",
                tool: .xcode,
                safetyLevel: .safe,
                description: "Debug symbols for connected iOS devices"
            ),
            DeveloperCacheLocation(
                path: "\(home)/Library/Developer/Xcode/watchOS DeviceSupport",
                displayName: "watchOS Device Support",
                tool: .xcode,
                safetyLevel: .safe,
                description: "Debug symbols for connected Apple Watches"
            ),
            DeveloperCacheLocation(
                path: "\(home)/Library/Developer/Xcode/tvOS DeviceSupport",
                displayName: "tvOS Device Support",
                tool: .xcode,
                safetyLevel: .safe,
                description: "Debug symbols for Apple TVs"
            ),

            // Simulators
            DeveloperCacheLocation(
                path: "\(home)/Library/Developer/CoreSimulator/Devices",
                displayName: "Simulator Devices",
                tool: .simulator,
                safetyLevel: .caution,
                description: "iOS Simulator data and apps"
            ),
            DeveloperCacheLocation(
                path: "\(home)/Library/Developer/CoreSimulator/Caches",
                displayName: "Simulator Caches",
                tool: .simulator,
                safetyLevel: .safe,
                description: "Simulator runtime caches"
            ),
            DeveloperCacheLocation(
                path: "/Library/Developer/CoreSimulator/Caches",
                displayName: "System Simulator Caches",
                tool: .simulator,
                safetyLevel: .safe,
                description: "System-level simulator caches"
            ),

            // Gradle (Android/Java)
            DeveloperCacheLocation(
                path: "\(home)/.gradle/caches",
                displayName: "Gradle Caches",
                tool: .gradle,
                safetyLevel: .safe,
                description: "Gradle build cache and dependencies"
            ),

            // Android
            DeveloperCacheLocation(
                path: "\(home)/.android/avd",
                displayName: "Android Virtual Devices",
                tool: .android,
                safetyLevel: .caution,
                description: "Android emulator images"
            ),
            DeveloperCacheLocation(
                path: "\(home)/.android/cache",
                displayName: "Android Cache",
                tool: .android,
                safetyLevel: .safe,
                description: "Android SDK cache"
            ),
            DeveloperCacheLocation(
                path: "\(home)/Library/Android/sdk/build-tools",
                displayName: "Android Build Tools",
                tool: .android,
                safetyLevel: .caution,
                description: "Android build tools - keep latest versions",
                showVersions: true
            ),
            DeveloperCacheLocation(
                path: "\(home)/Library/Android/sdk/system-images",
                displayName: "Android System Images",
                tool: .android,
                safetyLevel: .caution,
                description: "Emulator system images"
            ),

            // Flutter/Dart
            DeveloperCacheLocation(
                path: "\(home)/.pub-cache",
                displayName: "Dart Pub Cache",
                tool: .flutter,
                safetyLevel: .safe,
                description: "Dart/Flutter package cache"
            ),
            DeveloperCacheLocation(
                path: "\(home)/.dartServer",
                displayName: "Dart Server",
                tool: .flutter,
                safetyLevel: .safe,
                description: "Dart analysis server cache"
            ),
            DeveloperCacheLocation(
                path: "\(home)/fvm/versions",
                displayName: "Flutter Versions (FVM)",
                tool: .flutter,
                safetyLevel: .caution,
                description: "Flutter version manager - keep versions in use",
                showVersions: true
            ),

            // CocoaPods
            DeveloperCacheLocation(
                path: "\(home)/.cocoapods/repos",
                displayName: "CocoaPods Repos",
                tool: .cocoapods,
                safetyLevel: .safe,
                description: "CocoaPods spec repositories"
            ),
            DeveloperCacheLocation(
                path: "\(home)/Library/Caches/CocoaPods",
                displayName: "CocoaPods Cache",
                tool: .cocoapods,
                safetyLevel: .safe,
                description: "Downloaded pod archives"
            ),

            // Rust
            DeveloperCacheLocation(
                path: "\(home)/.cargo/registry",
                displayName: "Cargo Registry",
                tool: .cargo,
                safetyLevel: .safe,
                description: "Rust crate cache"
            ),
            DeveloperCacheLocation(
                path: "\(home)/.rustup/toolchains",
                displayName: "Rust Toolchains",
                tool: .cargo,
                safetyLevel: .caution,
                description: "Rust compiler versions - keep active toolchain",
                showVersions: true
            ),

            // Node.js
            DeveloperCacheLocation(
                path: "\(home)/.npm/_cacache",
                displayName: "npm Cache",
                tool: .npm,
                safetyLevel: .safe,
                description: "npm package cache"
            ),
            DeveloperCacheLocation(
                path: "\(home)/.yarn/cache",
                displayName: "Yarn Cache",
                tool: .yarn,
                safetyLevel: .safe,
                description: "Yarn package cache"
            ),

            // Homebrew
            DeveloperCacheLocation(
                path: "\(home)/Library/Caches/Homebrew",
                displayName: "Homebrew Cache",
                tool: .homebrew,
                safetyLevel: .safe,
                description: "Downloaded formula archives"
            ),

            // Python
            DeveloperCacheLocation(
                path: "\(home)/Library/Caches/pip",
                displayName: "pip Cache",
                tool: .pip,
                safetyLevel: .safe,
                description: "Python package cache"
            ),
            DeveloperCacheLocation(
                path: "\(home)/.cache/pip",
                displayName: "pip Cache (alt)",
                tool: .pip,
                safetyLevel: .safe,
                description: "Python package cache"
            ),

            // General cache
            DeveloperCacheLocation(
                path: "\(home)/.cache",
                displayName: "User Cache Directory",
                tool: .cache,
                safetyLevel: .safe,
                description: "General application caches"
            )
        ]
    }

    func scan(progressHandler: @escaping (String) -> Void) async -> CategoryScanResult {
        let startTime = Date()
        var allItems: [ScanResult] = []

        // Scan predefined locations
        for location in cacheLocations {
            await MainActor.run {
                progressHandler("Scanning \(location.displayName)...")
            }

            guard fileManager.fileExists(atPath: location.path) else {
                continue
            }

            if location.showVersions {
                // Scan subdirectories as separate items
                let items = await scanVersionedDirectory(location: location)
                allItems.append(contentsOf: items)
            } else {
                // Scan as single item
                if let item = await scanSingleLocation(location: location) {
                    allItems.append(item)
                }
            }
        }

        // Sort by size descending
        allItems.sort { $0.size > $1.size }

        let totalSize = allItems.reduce(0) { $0 + $1.size }
        let duration = Date().timeIntervalSince(startTime)

        return CategoryScanResult(
            category: .developerCaches,
            items: allItems,
            totalSize: totalSize,
            scanDuration: duration
        )
    }

    func scanForNodeModules(progressHandler: @escaping (String) -> Void) async -> [ScanResult] {
        await MainActor.run {
            progressHandler("Searching for node_modules folders...")
        }

        var results: [ScanResult] = []
        let home = fileManager.homeDirectoryForCurrentUser.path

        // Common locations to search for node_modules
        let searchPaths = [
            "\(home)/Projects",
            "\(home)/Developer",
            "\(home)/Code",
            "\(home)/Sites",
            "\(home)/workspace",
            "\(home)/repos",
            "\(home)/Documents"
        ]

        for searchPath in searchPaths {
            guard fileManager.fileExists(atPath: searchPath) else { continue }

            let nodeModulesResults = await findNodeModules(in: searchPath, progressHandler: progressHandler)
            results.append(contentsOf: nodeModulesResults)
        }

        return results.sorted { $0.size > $1.size }
    }

    private func findNodeModules(in basePath: String, progressHandler: @escaping (String) -> Void) async -> [ScanResult] {
        var results: [ScanResult] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: basePath),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return results
        }

        for case let url as URL in enumerator {
            let name = url.lastPathComponent

            // Skip nested node_modules
            if url.path.contains("node_modules/") && name == "node_modules" {
                continue
            }

            if name == "node_modules" {
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues?.isDirectory == true {
                    await MainActor.run {
                        progressHandler("Found: \(url.deletingLastPathComponent().lastPathComponent)/node_modules")
                    }

                    let size = await calculateSize(at: url.path)
                    let itemCount = await countItems(at: url.path)
                    let parentName = url.deletingLastPathComponent().lastPathComponent

                    let result = ScanResult(
                        path: url.path,
                        name: "\(parentName)/node_modules",
                        size: size,
                        itemCount: itemCount,
                        lastModified: getModificationDate(at: url),
                        safetyLevel: .safe,
                        isReadOnly: false,
                        isSelected: false
                    )

                    if size > 0 {
                        results.append(result)
                    }

                    // Don't descend into node_modules
                    enumerator.skipDescendants()
                }
            }
        }

        return results
    }

    private func scanSingleLocation(location: DeveloperCacheLocation) async -> ScanResult? {
        let size = await calculateSize(at: location.path)
        guard size > 0 else { return nil }

        let itemCount = await countItems(at: location.path)
        let lastModified = getModificationDate(at: URL(fileURLWithPath: location.path))

        return ScanResult(
            path: location.path,
            name: location.displayName,
            size: size,
            itemCount: itemCount,
            lastModified: lastModified,
            safetyLevel: location.safetyLevel,
            isReadOnly: false,
            isSelected: location.safetyLevel == .safe
        )
    }

    private func scanVersionedDirectory(location: DeveloperCacheLocation) async -> [ScanResult] {
        var results: [ScanResult] = []

        let url = URL(fileURLWithPath: location.path)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return results
        }

        for itemURL in contents {
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues?.isDirectory == true else { continue }

            let size = await calculateSize(at: itemURL.path)
            guard size > 0 else { continue }

            let itemCount = await countItems(at: itemURL.path)
            let lastModified = getModificationDate(at: itemURL)
            let itemName = "\(location.displayName)/\(itemURL.lastPathComponent)"

            let result = ScanResult(
                path: itemURL.path,
                name: itemName,
                size: size,
                itemCount: itemCount,
                lastModified: lastModified,
                safetyLevel: location.safetyLevel,
                isReadOnly: false,
                isSelected: false // Don't auto-select versioned items
            )

            results.append(result)
        }

        return results
    }

    private func calculateSize(at path: String) async -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                return size
            }
            return 0
        }

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               values.isDirectory == false {
                totalSize += Int64(values.fileSize ?? 0)
            }
        }

        return totalSize
    }

    private func countItems(at path: String) async -> Int {
        var count = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 1
        }

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
               values.isDirectory == false {
                count += 1
            }
        }

        return count
    }

    private func getModificationDate(at url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    func deleteItems(_ items: [ScanResult]) async -> (deleted: Int, failed: Int, freedSpace: Int64) {
        let safeOps = SafeFileOperations()
        let home = fileManager.homeDirectoryForCurrentUser.path

        // Developer caches can be in various locations
        let allowedRoots = [
            "\(home)/Library/Developer",
            "\(home)/Library/Caches",
            "\(home)/.npm",
            "\(home)/.cargo",
            "\(home)/.gradle",
            "\(home)/.m2",
            "\(home)/.cocoapods",
            "\(home)/.pub-cache",
            "\(home)/node_modules"
        ]

        var deleted = 0
        var failed = 0
        var freedSpace: Int64 = 0

        for item in items where !item.isReadOnly {
            // Validate path is not blocked
            guard !BlockedPathValidator.isBlocked(item.path) else {
                failed += 1
                continue
            }

            let options = DeletionOptions.withRoots(allowedRoots, checkInUse: false)
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // For directories, delete contents not the folder itself
                    // Exception: node_modules and versioned items - delete the whole folder
                    if item.name.contains("node_modules") ||
                       item.path.contains("DerivedData/") ||
                       item.path.contains("Archives/") ||
                       item.path.contains("DeviceSupport/") ||
                       item.path.contains("toolchains/") ||
                       item.path.contains("versions/") {
                        let result = await safeOps.deleteItem(at: item.path, options: options)
                        if result.success {
                            deleted += 1
                            freedSpace += result.freedBytes
                        } else {
                            failed += 1
                        }
                    } else {
                        let result = await safeOps.deleteContents(of: item.path, options: options)
                        if result.deleted > 0 {
                            deleted += 1
                            freedSpace += result.freedSpace
                        } else if result.failed > 0 {
                            failed += 1
                        }
                    }
                } else {
                    let result = await safeOps.deleteItem(at: item.path, options: options)
                    if result.success {
                        deleted += 1
                        freedSpace += result.freedBytes
                    } else {
                        failed += 1
                    }
                }
            } else {
                failed += 1
            }
        }

        return (deleted, failed, freedSpace)
    }

    // MARK: - Utility Commands

    func runXcodeCleanup() async -> String {
        // Clean Xcode derived data via xcrun
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "delete", "unavailable"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? "Cleanup completed"
        } catch {
            return "Failed to run cleanup: \(error.localizedDescription)"
        }
    }

    func getToolInfo(for tool: DeveloperTool) -> (installed: Bool, version: String?) {
        switch tool {
        case .xcode:
            return checkCommand("/usr/bin/xcodebuild", args: ["-version"])
        case .gradle:
            let home = fileManager.homeDirectoryForCurrentUser.path
            return (fileManager.fileExists(atPath: "\(home)/.gradle"), nil)
        case .android:
            let home = fileManager.homeDirectoryForCurrentUser.path
            return (fileManager.fileExists(atPath: "\(home)/Library/Android/sdk"), nil)
        case .flutter:
            return checkCommand("/usr/bin/which", args: ["flutter"])
        case .cocoapods:
            return checkCommand("/usr/bin/which", args: ["pod"])
        case .cargo:
            return checkCommand("/usr/bin/which", args: ["cargo"])
        case .npm:
            return checkCommand("/usr/bin/which", args: ["npm"])
        case .yarn:
            return checkCommand("/usr/bin/which", args: ["yarn"])
        case .homebrew:
            return checkCommand("/usr/bin/which", args: ["brew"])
        case .pip:
            return checkCommand("/usr/bin/which", args: ["pip3"])
        default:
            return (true, nil)
        }
    }

    private func checkCommand(_ path: String, args: [String]) -> (Bool, String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (true, output)
            }
        } catch {
            // Command not found or failed
        }

        return (false, nil)
    }
}
