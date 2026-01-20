import Foundation

actor LogsScanner {
    private let fileManager = FileManager.default

    enum LogCategory: String, CaseIterable, Identifiable {
        case userLogs = "User Logs"
        case systemLogs = "System Logs"
        case crashReports = "Crash Reports"
        case diagnosticReports = "Diagnostic Reports"
        case appLogs = "Application Logs"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .userLogs: return "doc.text"
            case .systemLogs: return "gearshape.2"
            case .crashReports: return "exclamationmark.triangle"
            case .diagnosticReports: return "waveform.path.ecg"
            case .appLogs: return "app.badge"
            }
        }

        var description: String {
            switch self {
            case .userLogs: return "Logs from user applications"
            case .systemLogs: return "macOS system logs"
            case .crashReports: return "Application crash reports"
            case .diagnosticReports: return "System diagnostic reports"
            case .appLogs: return "Logs stored in Application Support"
            }
        }

        var safetyLevel: SafetyLevel {
            switch self {
            case .userLogs, .appLogs: return .safe
            case .systemLogs: return .caution
            case .crashReports, .diagnosticReports: return .safe
            }
        }
    }

    struct LogLocation {
        let path: String
        let displayName: String
        let category: LogCategory
        let isSystemPath: Bool

        init(path: String, displayName: String, category: LogCategory, isSystemPath: Bool = false) {
            self.path = path
            self.displayName = displayName
            self.category = category
            self.isSystemPath = isSystemPath
        }
    }

    struct LogItem: Identifiable {
        let id = UUID()
        let path: String
        let name: String
        let size: Int64
        let fileCount: Int
        let category: LogCategory
        let lastModified: Date?
        let isDirectory: Bool
        let isOlderThanOneDay: Bool

        var formattedSize: String {
            size.formattedBytes
        }

        var formattedDate: String {
            guard let date = lastModified else { return "Unknown" }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }

        var ageInDays: Int {
            guard let date = lastModified else { return 0 }
            return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        }
    }

    private var logLocations: [LogLocation] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            // User logs
            LogLocation(
                path: "\(home)/Library/Logs",
                displayName: "User Logs",
                category: .userLogs
            ),

            // System logs (requires elevated permissions for some)
            LogLocation(
                path: "/Library/Logs",
                displayName: "System Logs",
                category: .systemLogs,
                isSystemPath: true
            ),

            // Crash reports
            LogLocation(
                path: "\(home)/Library/Logs/DiagnosticReports",
                displayName: "User Diagnostic Reports",
                category: .diagnosticReports
            ),
            LogLocation(
                path: "/Library/Logs/DiagnosticReports",
                displayName: "System Diagnostic Reports",
                category: .diagnosticReports,
                isSystemPath: true
            ),

            // Crash reporter
            LogLocation(
                path: "\(home)/Library/Application Support/CrashReporter",
                displayName: "Crash Reporter Data",
                category: .crashReports
            ),

            // Common app log locations
            LogLocation(
                path: "\(home)/Library/Logs/Homebrew",
                displayName: "Homebrew Logs",
                category: .appLogs
            ),
            LogLocation(
                path: "\(home)/Library/Logs/Spotify",
                displayName: "Spotify Logs",
                category: .appLogs
            ),
            LogLocation(
                path: "\(home)/Library/Logs/JetBrains",
                displayName: "JetBrains Logs",
                category: .appLogs
            ),
            LogLocation(
                path: "\(home)/Library/Logs/Google",
                displayName: "Google Logs",
                category: .appLogs
            ),
            LogLocation(
                path: "\(home)/Library/Logs/Adobe",
                displayName: "Adobe Logs",
                category: .appLogs
            ),
            LogLocation(
                path: "\(home)/Library/Logs/Microsoft",
                displayName: "Microsoft Logs",
                category: .appLogs
            )
        ]
    }

    func scan(progressHandler: @escaping (String) -> Void) async -> CategoryScanResult {
        let startTime = Date()
        var allItems: [ScanResult] = []
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        // First scan predefined locations
        for location in logLocations {
            await MainActor.run {
                progressHandler("Scanning \(location.displayName)...")
            }

            guard fileManager.fileExists(atPath: location.path) else { continue }

            // Scan subdirectories/files within the log location
            let items = await scanLogDirectory(
                at: location.path,
                category: location.category,
                isSystemPath: location.isSystemPath,
                oneDayAgo: oneDayAgo
            )
            allItems.append(contentsOf: items)
        }

        // Also scan ~/Library/Logs for any app-specific folders we didn't explicitly list
        let userLogsPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs").path
        let additionalItems = await scanForAdditionalLogs(
            at: userLogsPath,
            oneDayAgo: oneDayAgo
        )
        allItems.append(contentsOf: additionalItems)

        // Sort by size descending
        allItems.sort { $0.size > $1.size }

        let totalSize = allItems.reduce(0) { $0 + $1.size }
        let duration = Date().timeIntervalSince(startTime)

        return CategoryScanResult(
            category: .logs,
            items: allItems,
            totalSize: totalSize,
            scanDuration: duration
        )
    }

    private func scanLogDirectory(
        at path: String,
        category: LogCategory,
        isSystemPath: Bool,
        oneDayAgo: Date
    ) async -> [ScanResult] {
        var results: [ScanResult] = []

        let url = URL(fileURLWithPath: path)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            // If we can't enumerate, treat the whole directory as one item
            let size = await calculateSize(at: path)
            if size > 0 {
                let lastModified = getModificationDate(at: url)
                let isOld = lastModified.map { $0 < oneDayAgo } ?? true

                let result = ScanResult(
                    path: path,
                    name: url.lastPathComponent,
                    size: size,
                    itemCount: await countFiles(at: path),
                    lastModified: lastModified,
                    safetyLevel: category.safetyLevel,
                    isReadOnly: isSystemPath,
                    isSelected: isOld && !isSystemPath
                )
                results.append(result)
            }
            return results
        }

        for itemURL in contents {
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            let isDirectory = resourceValues?.isDirectory ?? false
            let lastModified = resourceValues?.contentModificationDate

            let size = await calculateSize(at: itemURL.path)
            guard size > 0 else { continue }

            let fileCount = isDirectory ? await countFiles(at: itemURL.path) : 1
            let isOld = lastModified.map { $0 < oneDayAgo } ?? true

            // Skip today's logs per spec safety rules
            let isToday = lastModified.map { Calendar.current.isDateInToday($0) } ?? false

            let result = ScanResult(
                path: itemURL.path,
                name: itemURL.lastPathComponent,
                size: size,
                itemCount: fileCount,
                lastModified: lastModified,
                safetyLevel: isToday ? .caution : category.safetyLevel,
                isReadOnly: isSystemPath,
                isSelected: isOld && !isSystemPath && !isToday
            )

            results.append(result)
        }

        return results
    }

    private func scanForAdditionalLogs(at basePath: String, oneDayAgo: Date) async -> [ScanResult] {
        var results: [ScanResult] = []

        // Get list of already scanned paths
        let knownPaths = Set(logLocations.map { $0.path })

        let url = URL(fileURLWithPath: basePath)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return results
        }

        for itemURL in contents {
            // Skip if already scanned
            if knownPaths.contains(itemURL.path) { continue }

            // Skip DiagnosticReports as it's handled separately
            if itemURL.lastPathComponent == "DiagnosticReports" { continue }

            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            let isDirectory = resourceValues?.isDirectory ?? false
            let lastModified = resourceValues?.contentModificationDate

            let size = await calculateSize(at: itemURL.path)
            guard size > 1024 else { continue } // Skip very small items

            let fileCount = isDirectory ? await countFiles(at: itemURL.path) : 1
            let isOld = lastModified.map { $0 < oneDayAgo } ?? true
            let isToday = lastModified.map { Calendar.current.isDateInToday($0) } ?? false

            let result = ScanResult(
                path: itemURL.path,
                name: itemURL.lastPathComponent,
                size: size,
                itemCount: fileCount,
                lastModified: lastModified,
                safetyLevel: isToday ? .caution : .safe,
                isReadOnly: false,
                isSelected: isOld && !isToday
            )

            results.append(result)
        }

        return results
    }

    private func calculateSize(at path: String) async -> Int64 {
        var totalSize: Int64 = 0

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return 0
        }

        if !isDirectory.boolValue {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                return size
            }
            return 0
        }

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
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

    private func countFiles(at path: String) async -> Int {
        var count = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [],
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

        return max(count, 1)
    }

    private func getModificationDate(at url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    func deleteItems(_ items: [ScanResult]) async -> (deleted: Int, failed: Int, freedSpace: Int64) {
        let safeOps = SafeFileOperations()
        let home = fileManager.homeDirectoryForCurrentUser.path

        // Logs can be in user or system locations
        let allowedRoots = [
            "\(home)/Library/Logs",
            "/Library/Logs"
        ]

        var deleted = 0
        var failed = 0
        var freedSpace: Int64 = 0

        for item in items where !item.isReadOnly {
            // Skip today's logs
            if let lastModified = item.lastModified,
               Calendar.current.isDateInToday(lastModified) {
                failed += 1
                continue
            }

            // Validate path is not blocked
            guard !BlockedPathValidator.isBlocked(item.path) else {
                failed += 1
                continue
            }

            // Use options that skip today's files
            let options = DeletionOptions(
                checkInUse: false,
                validateSymlinks: true,
                allowedRoots: allowedRoots,
                moveToTrash: false,
                skipTodaysFiles: true
            )

            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Delete contents, not the folder itself
                    let result = await safeOps.deleteContents(of: item.path, options: options)
                    if result.deleted > 0 {
                        deleted += 1
                        freedSpace += result.freedSpace
                    } else if result.failed > 0 {
                        failed += 1
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

    func getLogStats() async -> (totalSize: Int64, oldLogsSize: Int64, todayLogsSize: Int64) {
        let result = await scan { _ in }
        let today = Date()

        var oldSize: Int64 = 0
        var todaySize: Int64 = 0

        for item in result.items {
            if let lastModified = item.lastModified,
               Calendar.current.isDateInToday(lastModified) {
                todaySize += item.size
            } else {
                oldSize += item.size
            }
        }

        return (result.totalSize, oldSize, todaySize)
    }
}
