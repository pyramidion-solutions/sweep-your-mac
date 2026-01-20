import Foundation

struct AppLeftover: Identifiable, Hashable {
    let id = UUID()
    let appName: String
    let bundleIdentifier: String?
    let locations: [LeftoverLocation]
    var totalSize: Int64 {
        locations.reduce(0) { $0 + $1.size }
    }
    var isSelected: Bool = false

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppLeftover, rhs: AppLeftover) -> Bool {
        lhs.id == rhs.id
    }
}

struct LeftoverLocation: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let type: LeftoverType
    let size: Int64

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LeftoverLocation, rhs: LeftoverLocation) -> Bool {
        lhs.id == rhs.id
    }
}

enum LeftoverType: String, CaseIterable {
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case savedState = "Saved State"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case logs = "Logs"
    case webKit = "WebKit"
    case other = "Other"

    var iconName: String {
        switch self {
        case .applicationSupport: return "folder.fill"
        case .caches: return "internaldrive"
        case .preferences: return "gearshape"
        case .savedState: return "clock.arrow.circlepath"
        case .containers: return "shippingbox"
        case .groupContainers: return "shippingbox.2"
        case .logs: return "doc.text"
        case .webKit: return "globe"
        case .other: return "questionmark.folder"
        }
    }
}

struct ApplicationLeftoversScanResult {
    let leftovers: [AppLeftover]
    let totalSize: Int64
    let scanDate: Date
}

actor ApplicationLeftoversScanner {
    private let fileManager = FileManager.default

    // Known system apps and Apple apps that should not be flagged as leftovers
    private let systemBundleIdentifiers: Set<String> = [
        "com.apple", "com.microsoft", "com.google.Chrome", "com.mozilla.firefox",
        "com.brave.Browser", "com.operasoftware", "com.vivaldi"
    ]

    // Common app name patterns to ignore (system/active apps)
    private let ignoredAppPatterns: Set<String> = [
        "apple", "finder", "safari", "mail", "messages", "facetime", "photos",
        "music", "podcasts", "news", "stocks", "home", "notes", "reminders",
        "calendar", "contacts", "maps", "weather", "clock", "calculator",
        "preview", "textedit", "font book", "migration assistant", "disk utility",
        "system preferences", "system settings", "terminal", "activity monitor",
        "console", "keychain access", "screenshot", "automator", "shortcuts"
    ]

    func scan(progressHandler: @escaping (String) -> Void) async -> ApplicationLeftoversScanResult {
        let homeDir = fileManager.homeDirectoryForCurrentUser.path

        // Get list of currently installed applications
        let installedApps = await getInstalledApplications()
        let installedBundleIds = Set(installedApps.compactMap { $0.bundleIdentifier?.lowercased() })
        let installedAppNames = Set(installedApps.map { $0.name.lowercased() })

        progressHandler("Found \(installedApps.count) installed applications")

        // Locations to scan for leftovers
        let scanLocations: [(path: String, type: LeftoverType)] = [
            ("\(homeDir)/Library/Application Support", .applicationSupport),
            ("\(homeDir)/Library/Caches", .caches),
            ("\(homeDir)/Library/Preferences", .preferences),
            ("\(homeDir)/Library/Saved Application State", .savedState),
            ("\(homeDir)/Library/Containers", .containers),
            ("\(homeDir)/Library/Group Containers", .groupContainers),
            ("\(homeDir)/Library/Logs", .logs),
            ("\(homeDir)/Library/WebKit", .webKit)
        ]

        var leftoversByApp: [String: [LeftoverLocation]] = [:]
        var bundleIdMap: [String: String] = [:] // Maps app name to bundle ID if found

        for (basePath, locationType) in scanLocations {
            progressHandler("Scanning \(locationType.rawValue)...")

            guard let contents = try? fileManager.contentsOfDirectory(atPath: basePath) else {
                continue
            }

            for item in contents {
                let itemPath = "\(basePath)/\(item)"
                let itemName = extractAppName(from: item)
                let itemNameLower = itemName.lowercased()

                // Skip if it's a system/ignored app
                if shouldIgnore(appName: itemNameLower, bundleId: item.lowercased()) {
                    continue
                }

                // Check if this appears to be from an uninstalled app
                let matchesInstalled = installedAppNames.contains(itemNameLower) ||
                    installedBundleIds.contains(item.lowercased()) ||
                    installedAppNames.contains(where: { itemNameLower.contains($0) || $0.contains(itemNameLower) })

                if !matchesInstalled {
                    let size = calculateDirectorySize(path: itemPath)
                    if size > 0 {
                        let location = LeftoverLocation(path: itemPath, type: locationType, size: size)

                        if leftoversByApp[itemName] == nil {
                            leftoversByApp[itemName] = []
                        }
                        leftoversByApp[itemName]?.append(location)

                        // Try to extract bundle ID
                        if item.contains(".") && !item.hasSuffix(".plist") {
                            bundleIdMap[itemName] = item
                        }
                    }
                }
            }
        }

        progressHandler("Processing results...")

        // Convert to AppLeftover array
        var leftovers: [AppLeftover] = leftoversByApp.map { (appName, locations) in
            AppLeftover(
                appName: appName,
                bundleIdentifier: bundleIdMap[appName],
                locations: locations.sorted { $0.size > $1.size }
            )
        }

        // Sort by total size descending
        leftovers.sort { $0.totalSize > $1.totalSize }

        // Filter out very small leftovers (< 1KB) to reduce noise
        leftovers = leftovers.filter { $0.totalSize >= 1024 }

        let totalSize = leftovers.reduce(0) { $0 + $1.totalSize }

        progressHandler("Found \(leftovers.count) application leftovers")

        return ApplicationLeftoversScanResult(
            leftovers: leftovers,
            totalSize: totalSize,
            scanDate: Date()
        )
    }

    private func getInstalledApplications() async -> [(name: String, bundleIdentifier: String?)] {
        var apps: [(name: String, bundleIdentifier: String?)] = []

        let appDirectories = [
            "/Applications",
            "/System/Applications",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]

        for directory in appDirectories {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
                continue
            }

            for item in contents where item.hasSuffix(".app") {
                let appName = item.replacingOccurrences(of: ".app", with: "")
                let plistPath = "\(directory)/\(item)/Contents/Info.plist"

                var bundleId: String?
                if let plistData = fileManager.contents(atPath: plistPath),
                   let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {
                    bundleId = plist["CFBundleIdentifier"] as? String
                }

                apps.append((name: appName, bundleIdentifier: bundleId))
            }
        }

        return apps
    }

    private func extractAppName(from identifier: String) -> String {
        var name = identifier

        // Remove common prefixes
        let prefixes = ["com.", "org.", "net.", "io.", "app.", "me.", "co."]
        for prefix in prefixes {
            if name.lowercased().hasPrefix(prefix) {
                name = String(name.dropFirst(prefix.count))
                break
            }
        }

        // Split by dots and take the meaningful part
        let parts = name.split(separator: ".")
        if parts.count >= 2 {
            // Usually format is "company.appname" or "company.appname.something"
            name = String(parts.dropFirst().first ?? parts.first ?? Substring(name))
        }

        // Remove .plist extension
        if name.hasSuffix(".plist") {
            name = String(name.dropLast(6))
        }

        // Remove savedState suffix
        if name.hasSuffix(".savedState") {
            name = String(name.dropLast(11))
        }

        // Convert camelCase or kebab-case to Title Case
        name = name
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        // Capitalize first letter of each word
        return name.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private func shouldIgnore(appName: String, bundleId: String) -> Bool {
        // Check against ignored patterns
        for pattern in ignoredAppPatterns {
            if appName.contains(pattern) {
                return true
            }
        }

        // Check against system bundle IDs
        for systemId in systemBundleIdentifiers {
            if bundleId.hasPrefix(systemId.lowercased()) {
                return true
            }
        }

        // Ignore very generic names that might cause false positives
        let genericNames = ["temp", "tmp", "cache", "data", "logs", "log", "preferences"]
        if genericNames.contains(appName) {
            return true
        }

        return false
    }

    private func calculateDirectorySize(path: String) -> Int64 {
        var totalSize: Int64 = 0

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return 0
        }

        if isDirectory.boolValue {
            guard let enumerator = fileManager.enumerator(atPath: path) else {
                return 0
            }

            while let file = enumerator.nextObject() as? String {
                let fullPath = "\(path)/\(file)"
                if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
                   let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
        } else {
            if let attributes = try? fileManager.attributesOfItem(atPath: path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize = fileSize
            }
        }

        return totalSize
    }

    func removeLeftovers(_ leftovers: [AppLeftover], moveToTrash: Bool) async -> (success: Int, failed: Int) {
        let safeOps = SafeFileOperations()
        let home = fileManager.homeDirectoryForCurrentUser.path

        // Application leftovers can be in various Library locations
        let allowedRoots = [
            "\(home)/Library/Application Support",
            "\(home)/Library/Caches",
            "\(home)/Library/Preferences",
            "\(home)/Library/Logs",
            "\(home)/Library/Containers",
            "\(home)/Library/Group Containers",
            "\(home)/Library/Saved Application State",
            "\(home)/Library/WebKit",
            "\(home)/Library/HTTPStorages",
            "\(home)/Library/Cookies"
        ]

        var successCount = 0
        var failedCount = 0

        for leftover in leftovers {
            for location in leftover.locations {
                // Validate path is not blocked
                guard !BlockedPathValidator.isBlocked(location.path) else {
                    failedCount += 1
                    continue
                }

                let options = DeletionOptions(
                    checkInUse: false,
                    validateSymlinks: true,
                    allowedRoots: allowedRoots,
                    moveToTrash: moveToTrash,
                    skipTodaysFiles: false
                )

                let result = await safeOps.deleteItem(at: location.path, options: options)
                if result.success {
                    successCount += 1
                } else {
                    failedCount += 1
                }
            }
        }

        return (successCount, failedCount)
    }
}
