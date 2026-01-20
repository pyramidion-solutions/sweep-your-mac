//
//  ScannerIntegrationTests.swift
//  SweepYourMacTests
//
//  Integration tests for scanner actors to verify they work correctly
//  in real-world scenarios.
//

import XCTest
@testable import SweepYourMac

// MARK: - SystemCachesScanner Tests

final class SystemCachesScannerTests: XCTestCase {

    func testScanReturnsResults() async {
        let scanner = SystemCachesScanner()

        let result = await scanner.scan { _ in }

        // Should find at least some caches (user caches always exist)
        XCTAssertEqual(result.category, .systemCaches, "Should return correct category")
        // Note: May be empty if running in sandboxed test environment
    }

    func testScanProgressCallbackIsCalled() async {
        let scanner = SystemCachesScanner()
        var progressCalled = false

        _ = await scanner.scan { progress in
            progressCalled = true
            XCTAssertFalse(progress.isEmpty, "Progress message should not be empty")
        }

        XCTAssertTrue(progressCalled, "Progress callback should be called at least once")
    }

    func testAllItemsHaveValidSafetyLevels() async {
        let scanner = SystemCachesScanner()

        let result = await scanner.scan { _ in }

        for item in result.items {
            XCTAssertTrue(
                [SafetyLevel.safe, .caution, .risky].contains(item.safetyLevel),
                "Item '\(item.name)' should have a valid safety level"
            )
        }
    }

    func testReadOnlyItemsMarkedCorrectly() async {
        let scanner = SystemCachesScanner()

        let result = await scanner.scan { _ in }

        // Items from /System should be marked as read-only
        let systemItems = result.items.filter { $0.path.hasPrefix("/System") }
        for item in systemItems {
            XCTAssertTrue(item.isReadOnly, "System items should be marked as read-only")
        }
    }
}

// MARK: - TrashScanner Tests

final class TrashScannerTests: XCTestCase {

    func testScanHandlesEmptyTrash() async {
        let scanner = TrashScanner()

        // This test verifies no crash on empty or non-existent trash
        let summary = await scanner.scan { _ in }

        XCTAssertGreaterThanOrEqual(summary.totalItems, 0, "Total items should be >= 0")
        XCTAssertGreaterThanOrEqual(summary.totalSize, 0, "Total size should be >= 0")
    }

    func testScanProgressCallbackIsCalled() async {
        let scanner = TrashScanner()
        var progressCalled = false

        _ = await scanner.scan { progress in
            progressCalled = true
        }

        XCTAssertTrue(progressCalled, "Progress callback should be called")
    }

    func testItemsHaveValidMetadata() async {
        let scanner = TrashScanner()

        let summary = await scanner.scan { _ in }

        for item in summary.items {
            XCTAssertFalse(item.name.isEmpty, "Item name should not be empty")
            XCTAssertGreaterThanOrEqual(item.size, 0, "Item size should be >= 0")
        }
    }
}

// MARK: - DiskSpaceManager Tests

final class DiskSpaceManagerTests: XCTestCase {

    @MainActor
    func testDiskSpaceCalculation() async {
        let manager = DiskSpaceManager()

        // Wait for initial load
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertGreaterThan(manager.diskSpace.totalSpace, 0, "Total space should be > 0")
        XCTAssertGreaterThanOrEqual(manager.diskSpace.freeSpace, 0, "Free space should be >= 0")
        XCTAssertGreaterThanOrEqual(manager.diskSpace.usedSpace, 0, "Used space should be >= 0")
    }

    @MainActor
    func testUsedPercentageIsValid() async {
        let manager = DiskSpaceManager()

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertGreaterThanOrEqual(manager.diskSpace.usedPercentage, 0, "Used percentage should be >= 0")
        XCTAssertLessThanOrEqual(manager.diskSpace.usedPercentage, 100, "Used percentage should be <= 100")
    }

    @MainActor
    func testFullDiskAccessCheck() {
        let manager = DiskSpaceManager()

        // This just verifies the method doesn't crash
        let hasAccess = manager.checkFullDiskAccess()
        XCTAssertNotNil(hasAccess, "Should return a boolean value")
    }
}
