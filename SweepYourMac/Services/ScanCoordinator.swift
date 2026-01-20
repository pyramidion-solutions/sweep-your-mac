import Foundation

/// Coordinates scanning across multiple categories for Smart Scan functionality.
actor ScanCoordinator {

    // MARK: - Types

    struct SmartScanResult {
        let categoryResults: [ScanCategory: CategoryScanResult]
        let totalRecoverableSpace: Int64
        let scanDuration: TimeInterval

        var breakdown: [(category: ScanCategory, size: Int64)] {
            categoryResults.map { ($0.key, $0.value.totalSize) }
                .sorted { $0.size > $1.size }
        }

        var formattedTotalSize: String {
            totalRecoverableSpace.formattedBytes
        }
    }

    struct QuickActionResult {
        let success: Bool
        let deletedCount: Int
        let freedSpace: Int64
        let error: String?
    }

    // MARK: - Scanners

    private let systemCachesScanner = SystemCachesScanner()
    private let browserCachesScanner = BrowserCachesScanner()
    private let logsScanner = LogsScanner()
    private let trashScanner = TrashScanner()
    private let developerCachesScanner = DeveloperCachesScanner()

    // MARK: - Smart Scan

    /// Runs a smart scan across the most impactful categories in parallel.
    /// Focuses on safe-to-clean categories: System Caches, Browser Caches, Logs, and Trash.
    func runSmartScan(progressHandler: @escaping @Sendable (String) -> Void) async -> SmartScanResult {
        let startTime = Date()
        var results: [ScanCategory: CategoryScanResult] = [:]

        await withTaskGroup(of: (ScanCategory, CategoryScanResult?).self) { group in
            // System Caches
            group.addTask {
                await progressHandler("Scanning system caches...")
                let result = await self.systemCachesScanner.scan { _ in }
                return (.systemCaches, result)
            }

            // Browser Caches
            group.addTask {
                await progressHandler("Scanning browser caches...")
                let result = await self.browserCachesScanner.scan { _ in }
                return (.browserCaches, result)
            }

            // Logs
            group.addTask {
                await progressHandler("Scanning logs...")
                let result = await self.logsScanner.scan { _ in }
                return (.logs, result)
            }

            // Trash
            group.addTask {
                await progressHandler("Scanning trash...")
                let summary = await self.trashScanner.scan { _ in }
                let result = CategoryScanResult(
                    category: .trash,
                    items: [],
                    totalSize: summary.totalSize,
                    scanDuration: summary.scanDuration
                )
                return (.trash, result)
            }

            // Developer Caches
            group.addTask {
                await progressHandler("Scanning developer caches...")
                let result = await self.developerCachesScanner.scan { _ in }
                return (.developerCaches, result)
            }

            // Collect results
            for await (category, result) in group {
                if let result = result {
                    results[category] = result
                }
            }
        }

        await progressHandler("Scan complete!")

        let totalSize = results.values.reduce(0) { $0 + $1.totalSize }
        let duration = Date().timeIntervalSince(startTime)

        return SmartScanResult(
            categoryResults: results,
            totalRecoverableSpace: totalSize,
            scanDuration: duration
        )
    }

    // MARK: - Quick Actions

    /// Empties the user's trash.
    func emptyTrash() async -> QuickActionResult {
        let result = await trashScanner.emptyTrash()
        return QuickActionResult(
            success: result.success,
            deletedCount: result.success ? 1 : 0,
            freedSpace: result.freedSpace,
            error: result.error
        )
    }

    /// Clears user cache folder (~/Library/Caches).
    func clearUserCaches() async -> QuickActionResult {
        // Scan first to get items
        let scanResult = await systemCachesScanner.scan { _ in }

        // Filter to only user caches (safe items, not read-only)
        let userCacheItems = scanResult.items.filter {
            $0.safetyLevel == .safe && !$0.isReadOnly
        }

        guard !userCacheItems.isEmpty else {
            return QuickActionResult(
                success: true,
                deletedCount: 0,
                freedSpace: 0,
                error: nil
            )
        }

        let (deleted, _, freedSpace) = await systemCachesScanner.deleteItems(userCacheItems)

        return QuickActionResult(
            success: deleted > 0,
            deletedCount: deleted,
            freedSpace: freedSpace,
            error: deleted == 0 ? "No items could be deleted" : nil
        )
    }

    /// Cleans Xcode derived data and caches.
    func cleanXcodeCaches() async -> QuickActionResult {
        let scanResult = await developerCachesScanner.scan { _ in }

        // Filter to Xcode-related items only
        let xcodeItems = scanResult.items.filter { item in
            let path = item.path.lowercased()
            return path.contains("xcode") || path.contains("deriveddata")
        }

        guard !xcodeItems.isEmpty else {
            return QuickActionResult(
                success: true,
                deletedCount: 0,
                freedSpace: 0,
                error: nil
            )
        }

        let (deleted, _, freedSpace) = await developerCachesScanner.deleteItems(xcodeItems)

        return QuickActionResult(
            success: deleted > 0,
            deletedCount: deleted,
            freedSpace: freedSpace,
            error: deleted == 0 ? "No items could be deleted" : nil
        )
    }
}
