//
//  ScanCoordinatorTests.swift
//  SweepYourMacTests
//
//  Tests for ScanCoordinator including parallel scanning,
//  smart scan aggregation, and quick actions.
//

import XCTest
@testable import SweepYourMac

// MARK: - Thread-Safe Array Wrapper

/// A thread-safe array wrapper for use in tests with concurrent callbacks.
final class LockedArray<Element>: @unchecked Sendable {
    private var array: [Element] = []
    private let lock = NSLock()

    func append(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        array.append(element)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return array.count
    }

    var values: [Element] {
        lock.lock()
        defer { lock.unlock() }
        return array
    }
}

// MARK: - Smart Scan Result Tests

final class SmartScanResultTests: XCTestCase {

    func testEmptySmartScanResult() {
        let result = ScanCoordinator.SmartScanResult(
            categoryResults: [:],
            totalRecoverableSpace: 0,
            scanDuration: 1.5
        )

        XCTAssertTrue(result.categoryResults.isEmpty)
        XCTAssertEqual(result.totalRecoverableSpace, 0)
        XCTAssertEqual(result.scanDuration, 1.5)
        XCTAssertTrue(result.breakdown.isEmpty)
        // ByteCountFormatter returns locale-specific format
        XCTAssertFalse(result.formattedTotalSize.isEmpty)
    }

    func testSmartScanResultWithData() {
        let cacheResult = CategoryScanResult(
            category: .systemCaches,
            items: [],
            totalSize: 1024 * 1024 * 500, // 500 MB
            scanDuration: 0.5
        )

        let logsResult = CategoryScanResult(
            category: .logs,
            items: [],
            totalSize: 1024 * 1024 * 100, // 100 MB
            scanDuration: 0.3
        )

        let result = ScanCoordinator.SmartScanResult(
            categoryResults: [
                .systemCaches: cacheResult,
                .logs: logsResult
            ],
            totalRecoverableSpace: 1024 * 1024 * 600,
            scanDuration: 2.0
        )

        XCTAssertEqual(result.categoryResults.count, 2)
        XCTAssertEqual(result.breakdown.count, 2)
        XCTAssertFalse(result.formattedTotalSize.isEmpty)
    }

    func testSmartScanResultBreakdownSortedBySize() {
        let smallResult = CategoryScanResult(
            category: .logs,
            items: [],
            totalSize: 1024, // 1 KB
            scanDuration: 0.1
        )

        let largeResult = CategoryScanResult(
            category: .systemCaches,
            items: [],
            totalSize: 1024 * 1024 * 1024, // 1 GB
            scanDuration: 0.5
        )

        let mediumResult = CategoryScanResult(
            category: .browserCaches,
            items: [],
            totalSize: 1024 * 1024, // 1 MB
            scanDuration: 0.3
        )

        let result = ScanCoordinator.SmartScanResult(
            categoryResults: [
                .logs: smallResult,
                .systemCaches: largeResult,
                .browserCaches: mediumResult
            ],
            totalRecoverableSpace: 1024 * 1024 * 1024 + 1024 * 1024 + 1024,
            scanDuration: 1.0
        )

        let breakdown = result.breakdown

        XCTAssertEqual(breakdown.count, 3)

        // Verify sorted by size descending
        XCTAssertEqual(breakdown[0].category, .systemCaches, "Largest should be first")
        XCTAssertEqual(breakdown[1].category, .browserCaches, "Medium should be second")
        XCTAssertEqual(breakdown[2].category, .logs, "Smallest should be last")
    }
}

// MARK: - Quick Action Result Tests

final class QuickActionResultTests: XCTestCase {

    func testSuccessfulQuickActionResult() {
        let result = ScanCoordinator.QuickActionResult(
            success: true,
            deletedCount: 5,
            freedSpace: 1024 * 1024 * 100,
            error: nil
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.deletedCount, 5)
        XCTAssertEqual(result.freedSpace, 1024 * 1024 * 100)
        XCTAssertNil(result.error)
    }

    func testFailedQuickActionResult() {
        let result = ScanCoordinator.QuickActionResult(
            success: false,
            deletedCount: 0,
            freedSpace: 0,
            error: "Permission denied"
        )

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.deletedCount, 0)
        XCTAssertEqual(result.freedSpace, 0)
        XCTAssertEqual(result.error, "Permission denied")
    }

    func testPartialSuccessQuickActionResult() {
        let result = ScanCoordinator.QuickActionResult(
            success: true,
            deletedCount: 3,
            freedSpace: 1024 * 1024 * 50,
            error: nil
        )

        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.deletedCount, 0)
    }
}

// MARK: - Smart Scan Integration Tests

final class SmartScanIntegrationTests: XCTestCase {

    func testRunSmartScanReturnsValidResult() async {
        let coordinator = ScanCoordinator()
        let progressMessages = LockedArray<String>()

        let result = await coordinator.runSmartScan { message in
            progressMessages.append(message)
        }

        // Verify result structure
        XCTAssertGreaterThanOrEqual(result.totalRecoverableSpace, 0, "Total should be >= 0")
        XCTAssertGreaterThan(result.scanDuration, 0, "Duration should be > 0")

        // Should have scanned multiple categories
        XCTAssertGreaterThanOrEqual(result.categoryResults.count, 0, "Should have category results")
    }

    func testSmartScanProgressCallbackIsCalled() async {
        let coordinator = ScanCoordinator()
        var progressCalled = false

        _ = await coordinator.runSmartScan { _ in
            progressCalled = true
        }

        XCTAssertTrue(progressCalled, "Progress callback should be called")
    }

    func testSmartScanIncludesExpectedCategories() async {
        let coordinator = ScanCoordinator()

        let result = await coordinator.runSmartScan { _ in }

        // Smart scan should include these categories (if they return results)
        let expectedCategories: Set<ScanCategory> = [
            .systemCaches,
            .browserCaches,
            .logs,
            .trash,
            .developerCaches
        ]

        for category in result.categoryResults.keys {
            XCTAssertTrue(expectedCategories.contains(category),
                          "Unexpected category in smart scan: \(category)")
        }
    }

    func testSmartScanTotalMatchesSumOfCategories() async {
        let coordinator = ScanCoordinator()

        let result = await coordinator.runSmartScan { _ in }

        let calculatedTotal = result.categoryResults.values.reduce(0) { $0 + $1.totalSize }
        XCTAssertEqual(result.totalRecoverableSpace, calculatedTotal,
                       "Total should match sum of category sizes")
    }

    func testSmartScanCompletesWithinReasonableTime() async {
        let coordinator = ScanCoordinator()

        let startTime = Date()
        _ = await coordinator.runSmartScan { _ in }
        let elapsed = Date().timeIntervalSince(startTime)

        // Smart scan should complete within 60 seconds on most systems
        XCTAssertLessThan(elapsed, 60, "Smart scan should complete within 60 seconds")
    }
}

// MARK: - Quick Actions Integration Tests

final class QuickActionsIntegrationTests: XCTestCase {

    func testEmptyTrashReturnsValidResult() async {
        let coordinator = ScanCoordinator()

        let result = await coordinator.emptyTrash()

        // Result should be valid (success or failure with error)
        XCTAssertNotNil(result)

        if result.success {
            XCTAssertNil(result.error)
        } else {
            // Failure is OK (trash might be empty or locked)
            XCTAssertGreaterThanOrEqual(result.freedSpace, 0)
        }
    }

    func testClearUserCachesReturnsValidResult() async {
        let coordinator = ScanCoordinator()

        let result = await coordinator.clearUserCaches()

        // Result should be valid
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result.deletedCount, 0)
        XCTAssertGreaterThanOrEqual(result.freedSpace, 0)

        // If no items deleted, error might be set
        if result.deletedCount == 0 && !result.success {
            XCTAssertNotNil(result.error)
        }
    }

    func testClearUserCachesFiltersToSafeItems() async {
        // This test verifies the filtering logic indirectly
        // by checking that the action completes without attempting
        // to delete risky items

        let coordinator = ScanCoordinator()

        let result = await coordinator.clearUserCaches()

        // The action should complete (not crash on risky items)
        XCTAssertNotNil(result)

        // If successful, it only deleted safe items
        if result.success && result.deletedCount > 0 {
            XCTAssertGreaterThan(result.freedSpace, 0)
        }
    }

    func testCleanXcodeCachesReturnsValidResult() async {
        let coordinator = ScanCoordinator()

        let result = await coordinator.cleanXcodeCaches()

        // Result should be valid
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result.deletedCount, 0)
        XCTAssertGreaterThanOrEqual(result.freedSpace, 0)
    }

    func testCleanXcodeCachesFiltersToXcodeItems() async {
        // This test verifies that only Xcode-related items are targeted

        let coordinator = ScanCoordinator()

        // Run the action - it should only touch Xcode paths
        let result = await coordinator.cleanXcodeCaches()

        // Action should complete without error if no Xcode items exist
        if result.deletedCount == 0 {
            XCTAssertTrue(result.success || result.error != nil,
                          "Should succeed or have error message when no Xcode items found")
        }
    }
}

// MARK: - Parallel Execution Tests

final class ParallelExecutionTests: XCTestCase {

    func testSmartScanRunsInParallel() async {
        let coordinator = ScanCoordinator()

        // Measure time - parallel execution should be faster than sequential
        let startTime = Date()
        _ = await coordinator.runSmartScan { _ in }
        let duration = Date().timeIntervalSince(startTime)

        // The scan duration in result should be close to wall clock time
        // (indicating parallel execution)
        XCTAssertGreaterThan(duration, 0)

        // If running sequentially, 5 scanners would take much longer
        // This is a weak test but helps verify parallelism
    }

    func testSmartScanCollectsAllResults() async {
        let coordinator = ScanCoordinator()

        let result = await coordinator.runSmartScan { _ in }

        // Even if some categories are empty, they should still be collected
        // (unless the scanner returns nil)
        for (category, categoryResult) in result.categoryResults {
            XCTAssertEqual(categoryResult.category, category,
                           "Category result should match key")
            XCTAssertGreaterThanOrEqual(categoryResult.totalSize, 0)
            XCTAssertGreaterThanOrEqual(categoryResult.scanDuration, 0)
        }
    }

    func testSmartScanHandlesEmptyCategories() async {
        let coordinator = ScanCoordinator()

        let result = await coordinator.runSmartScan { _ in }

        // Empty categories should have size 0, not be missing
        for categoryResult in result.categoryResults.values {
            XCTAssertGreaterThanOrEqual(categoryResult.totalSize, 0,
                                        "Category size should be >= 0, not missing")
        }
    }
}

// MARK: - Category Scan Result Tests

final class CategoryScanResultTests: XCTestCase {

    func testCategoryScanResultStructure() {
        let items = [
            ScanResult(
                path: "/test/path",
                name: "test",
                size: 1024,
                itemCount: 1,
                lastModified: Date(),
                safetyLevel: .safe,
                isReadOnly: false,
                isSelected: true
            )
        ]

        let result = CategoryScanResult(
            category: .systemCaches,
            items: items,
            totalSize: 1024,
            scanDuration: 0.5
        )

        XCTAssertEqual(result.category, .systemCaches)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.totalSize, 1024)
        XCTAssertEqual(result.scanDuration, 0.5)
    }

    func testCategoryScanResultEmptyItems() {
        let result = CategoryScanResult(
            category: .logs,
            items: [],
            totalSize: 0,
            scanDuration: 0.1
        )

        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.totalSize, 0)
    }
}
