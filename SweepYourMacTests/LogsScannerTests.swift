//
//  LogsScannerTests.swift
//  SweepYourMacTests
//
//  Tests for LogsScanner including today's logs protection,
//  read-only system paths, and age calculation.
//

import XCTest
@testable import SweepYourMac

// MARK: - Log Category Tests

final class LogCategoryTests: XCTestCase {

    func testAllCategoriesHaveIcons() {
        for category in LogsScanner.LogCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category) should have an icon")
        }
    }

    func testAllCategoriesHaveDescriptions() {
        for category in LogsScanner.LogCategory.allCases {
            XCTAssertFalse(category.description.isEmpty, "\(category) should have a description")
        }
    }

    func testCategorySafetyLevels() {
        // User logs and app logs are safe
        XCTAssertEqual(LogsScanner.LogCategory.userLogs.safetyLevel, .safe)
        XCTAssertEqual(LogsScanner.LogCategory.appLogs.safetyLevel, .safe)
        XCTAssertEqual(LogsScanner.LogCategory.crashReports.safetyLevel, .safe)
        XCTAssertEqual(LogsScanner.LogCategory.diagnosticReports.safetyLevel, .safe)

        // System logs are caution level
        XCTAssertEqual(LogsScanner.LogCategory.systemLogs.safetyLevel, .caution)
    }

    func testCategoryCount() {
        // Verify we have all 5 categories
        XCTAssertEqual(LogsScanner.LogCategory.allCases.count, 5)
    }

    func testCategoryIdentifiable() {
        for category in LogsScanner.LogCategory.allCases {
            XCTAssertEqual(category.id, category.rawValue, "Category id should equal rawValue")
        }
    }
}

// MARK: - Log Location Tests

final class LogLocationTests: XCTestCase {

    func testLogLocationStructure() {
        let location = LogsScanner.LogLocation(
            path: "/test/path",
            displayName: "Test Logs",
            category: .userLogs,
            isSystemPath: false
        )

        XCTAssertEqual(location.path, "/test/path")
        XCTAssertEqual(location.displayName, "Test Logs")
        XCTAssertEqual(location.category, .userLogs)
        XCTAssertFalse(location.isSystemPath)
    }

    func testSystemPathLocation() {
        let systemLocation = LogsScanner.LogLocation(
            path: "/Library/Logs",
            displayName: "System Logs",
            category: .systemLogs,
            isSystemPath: true
        )

        XCTAssertTrue(systemLocation.isSystemPath)
        XCTAssertEqual(systemLocation.category, .systemLogs)
    }
}

// MARK: - Log Item Tests

final class LogItemTests: XCTestCase {

    func testLogItemAgeInDays() {
        // Test with a date 5 days ago
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())

        let item = LogsScanner.LogItem(
            path: "/test/path",
            name: "test.log",
            size: 1024,
            fileCount: 1,
            category: .userLogs,
            lastModified: fiveDaysAgo,
            isDirectory: false,
            isOlderThanOneDay: true
        )

        XCTAssertEqual(item.ageInDays, 5, "Age should be approximately 5 days")
    }

    func testLogItemTodayAge() {
        let item = LogsScanner.LogItem(
            path: "/test/path",
            name: "today.log",
            size: 1024,
            fileCount: 1,
            category: .userLogs,
            lastModified: Date(),
            isDirectory: false,
            isOlderThanOneDay: false
        )

        XCTAssertEqual(item.ageInDays, 0, "Today's logs should have age 0")
    }

    func testLogItemNilDate() {
        let item = LogsScanner.LogItem(
            path: "/test/path",
            name: "unknown.log",
            size: 1024,
            fileCount: 1,
            category: .userLogs,
            lastModified: nil,
            isDirectory: false,
            isOlderThanOneDay: true
        )

        XCTAssertEqual(item.ageInDays, 0, "Nil date should return age 0")
        XCTAssertEqual(item.formattedDate, "Unknown")
    }

    func testLogItemFormattedSize() {
        let item = LogsScanner.LogItem(
            path: "/test/path",
            name: "test.log",
            size: 1024 * 1024, // 1 MB
            fileCount: 1,
            category: .userLogs,
            lastModified: Date(),
            isDirectory: false,
            isOlderThanOneDay: false
        )

        XCTAssertFalse(item.formattedSize.isEmpty, "Formatted size should not be empty")
    }

    func testLogItemUniqueIdentifiers() {
        let item1 = LogsScanner.LogItem(
            path: "/test/path1",
            name: "test1.log",
            size: 1024,
            fileCount: 1,
            category: .userLogs,
            lastModified: Date(),
            isDirectory: false,
            isOlderThanOneDay: false
        )

        let item2 = LogsScanner.LogItem(
            path: "/test/path2",
            name: "test2.log",
            size: 1024,
            fileCount: 1,
            category: .userLogs,
            lastModified: Date(),
            isDirectory: false,
            isOlderThanOneDay: false
        )

        XCTAssertNotEqual(item1.id, item2.id, "Each LogItem should have unique ID")
    }
}

// MARK: - Today's Logs Protection Tests (CRITICAL SAFETY)

final class TodaysLogsProtectionTests: XCTestCase {

    func testTodaysLogsMarkedAsCaution() async {
        let scanner = LogsScanner()

        let result = await scanner.scan { _ in }

        // Check that today's logs have caution safety level
        for item in result.items {
            if let lastModified = item.lastModified,
               Calendar.current.isDateInToday(lastModified) {
                XCTAssertEqual(item.safetyLevel, .caution,
                               "Today's log '\(item.name)' should be marked as caution")
            }
        }
    }

    func testTodaysLogsNotSelectedByDefault() async {
        let scanner = LogsScanner()

        let result = await scanner.scan { _ in }

        // Check that today's logs are not selected
        for item in result.items {
            if let lastModified = item.lastModified,
               Calendar.current.isDateInToday(lastModified) {
                XCTAssertFalse(item.isSelected,
                               "Today's log '\(item.name)' should NOT be selected by default")
            }
        }
    }

    func testDeleteItemsSkipsTodaysLogs() async {
        let scanner = LogsScanner()

        // Create a scan result item that represents today's log
        let todaysItem = ScanResult(
            path: "/tmp/test-todays-log.log",
            name: "test-todays-log.log",
            size: 1024,
            itemCount: 1,
            lastModified: Date(), // Today
            safetyLevel: .caution,
            isReadOnly: false,
            isSelected: true // Even if selected
        )

        // Attempt to delete
        let result = await scanner.deleteItems([todaysItem])

        // Should fail because it's today's log
        XCTAssertEqual(result.deleted, 0, "Should not delete today's logs")
        XCTAssertEqual(result.failed, 1, "Today's log deletion should count as failed")
    }

    func testGetLogStatsSeparatesTodaysLogs() async {
        let scanner = LogsScanner()

        let stats = await scanner.getLogStats()

        // Total should equal old + today
        XCTAssertEqual(stats.totalSize, stats.oldLogsSize + stats.todayLogsSize,
                       "Total size should equal sum of old and today's logs")

        // All values should be non-negative
        XCTAssertGreaterThanOrEqual(stats.totalSize, 0)
        XCTAssertGreaterThanOrEqual(stats.oldLogsSize, 0)
        XCTAssertGreaterThanOrEqual(stats.todayLogsSize, 0)
    }
}

// MARK: - Read-Only System Paths Tests

final class ReadOnlySystemPathsTests: XCTestCase {

    func testSystemLogsMarkedAsReadOnly() async {
        let scanner = LogsScanner()

        let result = await scanner.scan { _ in }

        // Check items from /Library/Logs are read-only
        for item in result.items {
            if item.path.hasPrefix("/Library/Logs") && !item.path.contains(FileManager.default.homeDirectoryForCurrentUser.path) {
                XCTAssertTrue(item.isReadOnly,
                              "System log '\(item.name)' should be marked read-only")
            }
        }
    }

    func testReadOnlyItemsNotSelectedByDefault() async {
        let scanner = LogsScanner()

        let result = await scanner.scan { _ in }

        for item in result.items where item.isReadOnly {
            XCTAssertFalse(item.isSelected,
                           "Read-only item '\(item.name)' should NOT be selected by default")
        }
    }

    func testDeleteItemsSkipsReadOnlyItems() async {
        let scanner = LogsScanner()

        // Create a read-only item
        let readOnlyItem = ScanResult(
            path: "/Library/Logs/testlog.log",
            name: "testlog.log",
            size: 1024,
            itemCount: 1,
            lastModified: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
            safetyLevel: .caution,
            isReadOnly: true,
            isSelected: true
        )

        let result = await scanner.deleteItems([readOnlyItem])

        // Read-only items should be skipped (not counted as deleted or failed)
        // The deleteItems function filters out read-only items with `where !item.isReadOnly`
        XCTAssertEqual(result.deleted, 0, "Should not delete read-only items")
    }
}

// MARK: - Scan Integration Tests

final class LogsScannerIntegrationTests: XCTestCase {

    func testScanReturnsValidResult() async {
        let scanner = LogsScanner()
        var progressMessages: [String] = []

        let result = await scanner.scan { message in
            progressMessages.append(message)
        }

        // Verify result structure
        XCTAssertEqual(result.category, .logs, "Should return logs category")
        XCTAssertGreaterThanOrEqual(result.totalSize, 0, "Total size should be >= 0")
        XCTAssertGreaterThanOrEqual(result.scanDuration, 0, "Scan duration should be >= 0")
    }

    func testScanProgressCallbackIsCalled() async {
        let scanner = LogsScanner()
        var progressCalled = false

        _ = await scanner.scan { _ in
            progressCalled = true
        }

        XCTAssertTrue(progressCalled, "Progress callback should be called")
    }

    func testScanResultsSortedBySize() async {
        let scanner = LogsScanner()

        let result = await scanner.scan { _ in }

        // Verify items are sorted by size descending
        if result.items.count > 1 {
            for i in 0..<(result.items.count - 1) {
                XCTAssertGreaterThanOrEqual(result.items[i].size, result.items[i + 1].size,
                                            "Items should be sorted by size descending")
            }
        }
    }

    func testTotalSizeMatchesSumOfItems() async {
        let scanner = LogsScanner()

        let result = await scanner.scan { _ in }

        let calculatedTotal = result.items.reduce(0) { $0 + $1.size }
        XCTAssertEqual(result.totalSize, calculatedTotal,
                       "Total size should match sum of item sizes")
    }

    func testAllItemsHaveValidPaths() async {
        let scanner = LogsScanner()

        let result = await scanner.scan { _ in }

        for item in result.items {
            XCTAssertFalse(item.path.isEmpty, "Item path should not be empty")
            XCTAssertTrue(item.path.hasPrefix("/"), "Item path should be absolute")
        }
    }

    func testAllItemsHaveValidNames() async {
        let scanner = LogsScanner()

        let result = await scanner.scan { _ in }

        for item in result.items {
            XCTAssertFalse(item.name.isEmpty, "Item name should not be empty")
        }
    }
}

// MARK: - Delete Items Tests

final class LogsDeleteTests: XCTestCase {

    func testDeleteItemsWithEmptyList() async {
        let scanner = LogsScanner()

        let result = await scanner.deleteItems([])

        XCTAssertEqual(result.deleted, 0)
        XCTAssertEqual(result.failed, 0)
        XCTAssertEqual(result.freedSpace, 0)
    }

    func testDeleteItemsRejectsBlockedPaths() async {
        let scanner = LogsScanner()

        // Try to delete a blocked system path
        let blockedItem = ScanResult(
            path: "/System/Library/Logs/test.log",
            name: "test.log",
            size: 1000,
            itemCount: 1,
            lastModified: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
            safetyLevel: .risky,
            isReadOnly: false, // Even if not read-only
            isSelected: true
        )

        let result = await scanner.deleteItems([blockedItem])

        XCTAssertEqual(result.deleted, 0, "Should not delete blocked paths")
        XCTAssertEqual(result.failed, 1, "Blocked path should count as failed")
    }

    func testDeleteItemsHandlesNonexistentPaths() async {
        let scanner = LogsScanner()

        let nonexistentItem = ScanResult(
            path: "/nonexistent/path/log.log",
            name: "log.log",
            size: 1000,
            itemCount: 1,
            lastModified: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
            safetyLevel: .safe,
            isReadOnly: false,
            isSelected: true
        )

        let result = await scanner.deleteItems([nonexistentItem])

        XCTAssertEqual(result.deleted, 0)
        XCTAssertEqual(result.failed, 1, "Nonexistent path should count as failed")
    }
}

// MARK: - Safety Level Tests

final class LogsSafetyLevelTests: XCTestCase {

    func testUserLogsAreSafe() async {
        let scanner = LogsScanner()

        let result = await scanner.scan { _ in }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for item in result.items {
            // User logs (not system, not today's) should be safe
            if item.path.hasPrefix("\(home)/Library/Logs"),
               !item.isReadOnly,
               item.lastModified.map({ !Calendar.current.isDateInToday($0) }) ?? true {
                XCTAssertEqual(item.safetyLevel, .safe,
                               "Old user log '\(item.name)' should be safe")
            }
        }
    }

    func testOldLogsAreSelectedByDefault() async {
        let scanner = LogsScanner()
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        let result = await scanner.scan { _ in }

        for item in result.items {
            // Logs older than one day, non-system, non-today should be selected
            // The scanner uses "older than one day" (not just "not today") for selection
            let isOld = item.lastModified.map { $0 < oneDayAgo } ?? true
            let isToday = item.lastModified.map { Calendar.current.isDateInToday($0) } ?? false

            if !item.isReadOnly, isOld, !isToday {
                XCTAssertTrue(item.isSelected,
                              "Old user log '\(item.name)' should be selected by default")
            }
        }
    }
}
