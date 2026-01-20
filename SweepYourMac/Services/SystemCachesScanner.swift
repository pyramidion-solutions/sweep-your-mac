import Foundation
import os.log

actor SystemCachesScanner {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sweepyourmac", category: "Scanner")
    private let fileManager = FileManager.default

    struct CacheLocation {
        let path: String
        let displayName: String
        let isReadOnly: Bool
        let safetyLevel: SafetyLevel
    }

    private var cacheLocations: [CacheLocation] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            CacheLocation(
                path: "\(home)/Library/Caches",
                displayName: "User Caches",
                isReadOnly: false,
                safetyLevel: .safe
            ),
            CacheLocation(
                path: "/Library/Caches",
                displayName: "System Caches",
                isReadOnly: false,
                safetyLevel: .caution
            ),
            CacheLocation(
                path: "/System/Library/Caches",
                displayName: "macOS System Caches",
                isReadOnly: true,
                safetyLevel: .risky
            )
        ]
    }

    func scan(progressHandler: @escaping (String) -> Void) async -> CategoryScanResult {
        let startTime = Date()
        var allItems: [ScanResult] = []

        for location in cacheLocations {
            await MainActor.run {
                progressHandler("Scanning \(location.displayName)...")
            }

            let items = await scanCacheDirectory(
                at: location.path,
                isReadOnly: location.isReadOnly,
                safetyLevel: location.safetyLevel
            )
            allItems.append(contentsOf: items)
        }

        // Sort by size descending
        allItems.sort { $0.size > $1.size }

        let totalSize = allItems.reduce(0) { $0 + $1.size }
        let duration = Date().timeIntervalSince(startTime)

        return CategoryScanResult(
            category: .systemCaches,
            items: allItems,
            totalSize: totalSize,
            scanDuration: duration
        )
    }

    private func scanCacheDirectory(
        at path: String,
        isReadOnly: Bool,
        safetyLevel: SafetyLevel
    ) async -> [ScanResult] {
        var results: [ScanResult] = []

        let url = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: path) else {
            return results
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            for itemURL in contents {
                let itemPath = itemURL.path
                let itemName = itemURL.lastPathComponent

                // Skip certain system items
                if shouldSkipItem(named: itemName) {
                    continue
                }

                let size = await calculateSize(at: itemPath)
                let itemCount = await countItems(at: itemPath)
                let lastModified = getLastModifiedDate(at: itemURL)

                // Determine safety level based on the item
                let itemSafetyLevel = determineSafetyLevel(
                    for: itemName,
                    baseSafetyLevel: safetyLevel
                )

                let result = ScanResult(
                    path: itemPath,
                    name: itemName,
                    size: size,
                    itemCount: itemCount,
                    lastModified: lastModified,
                    safetyLevel: itemSafetyLevel,
                    isReadOnly: isReadOnly,
                    isSelected: !isReadOnly && itemSafetyLevel == .safe
                )

                if size > 0 {
                    results.append(result)
                }
            }
        } catch {
            logger.warning("Failed to scan cache directory at \(path): \(error.localizedDescription)")
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
            // It might be a file, not a directory
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                return size
            }
            return 0
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == false {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
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
            return 1 // It's a single file
        }

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
               values.isDirectory == false {
                count += 1
            }
        }

        return count
    }

    private func getLastModifiedDate(at url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func shouldSkipItem(named name: String) -> Bool {
        // Skip items that shouldn't be touched
        let skipList = [
            "CloudKit",
            "com.apple.bird",
            "com.apple.metadata",
            ".DS_Store"
        ]
        return skipList.contains { name.hasPrefix($0) || name == $0 }
    }

    private func determineSafetyLevel(for itemName: String, baseSafetyLevel: SafetyLevel) -> SafetyLevel {
        // Some caches are safer to delete than others
        let safeCaches = [
            "com.apple.Safari",
            "Google",
            "Firefox",
            "com.microsoft.Edge",
            "BraveSoftware",
            "Homebrew",
            "pip",
            "yarn",
            "npm"
        ]

        let cautionCaches = [
            "com.apple.DeveloperTools",
            "com.apple.dt",
            "Xcode"
        ]

        for safe in safeCaches {
            if itemName.contains(safe) {
                return .safe
            }
        }

        for caution in cautionCaches {
            if itemName.contains(caution) {
                return .caution
            }
        }

        return baseSafetyLevel
    }

    func deleteItems(_ items: [ScanResult]) async -> (deleted: Int, failed: Int, freedSpace: Int64) {
        let safeOps = SafeFileOperations()
        let home = fileManager.homeDirectoryForCurrentUser.path

        // Define allowed roots for cache deletion
        let allowedRoots = [
            "\(home)/Library/Caches",
            "/Library/Caches"
        ]

        var totalDeleted = 0
        var totalFailed = 0
        var totalFreedSpace: Int64 = 0

        for item in items where !item.isReadOnly {
            // Validate path is not blocked before attempting deletion
            guard !BlockedPathValidator.isBlocked(item.path) else {
                totalFailed += 1
                continue
            }

            let options = DeletionOptions.withRoots(allowedRoots, checkInUse: true)

            // Check if item is a directory - if so, delete contents only
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Delete directory contents (not the directory itself)
                    let result = await safeOps.deleteContents(of: item.path, options: options)
                    if result.deleted > 0 {
                        totalDeleted += 1
                        totalFreedSpace += result.freedSpace
                    } else if result.failed > 0 {
                        totalFailed += 1
                    }
                } else {
                    // Delete single file
                    let result = await safeOps.deleteItem(at: item.path, options: options)
                    if result.success {
                        totalDeleted += 1
                        totalFreedSpace += result.freedBytes
                    } else {
                        totalFailed += 1
                    }
                }
            } else {
                totalFailed += 1
            }
        }

        return (totalDeleted, totalFailed, totalFreedSpace)
    }
}
