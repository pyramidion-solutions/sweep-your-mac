//
//  ViewModelTests.swift
//  SweepYourMacTests
//
//  Tests for ViewModel state management and selection logic.
//

import XCTest
@testable import SweepYourMac

// MARK: - TrashViewModel Tests

@MainActor
final class TrashViewModelTests: XCTestCase {

    func testInitialState() {
        let viewModel = TrashViewModel()

        // Check scanState is idle by checking isScanning property
        XCTAssertFalse(viewModel.scanState.isScanning, "Initial state should not be scanning")
        XCTAssertNil(viewModel.trashSummary, "Trash summary should be nil initially")
        XCTAssertTrue(viewModel.selectedItems.isEmpty, "Selected items should be empty initially")
        XCTAssertFalse(viewModel.isDeleting, "Should not be deleting initially")
        XCTAssertNil(viewModel.deletionError, "Deletion error should be nil initially")
    }

    func testSelectAllAndSelectNone() async {
        let viewModel = TrashViewModel()

        // Perform a scan first
        await viewModel.scan()

        // If there are items, test selection
        if let summary = viewModel.trashSummary, !summary.items.isEmpty {
            viewModel.selectAll()
            XCTAssertEqual(
                viewModel.selectedItems.count,
                summary.items.count,
                "Select all should select all items"
            )

            viewModel.selectNone()
            XCTAssertTrue(viewModel.selectedItems.isEmpty, "Select none should clear selection")
        }
    }

    func testToggleSelection() async {
        let viewModel = TrashViewModel()

        await viewModel.scan()

        if let summary = viewModel.trashSummary, let firstItem = summary.items.first {
            // Toggle on
            viewModel.toggleSelection(firstItem)
            XCTAssertTrue(viewModel.selectedItems.contains(firstItem.id), "Item should be selected")

            // Toggle off
            viewModel.toggleSelection(firstItem)
            XCTAssertFalse(viewModel.selectedItems.contains(firstItem.id), "Item should be deselected")
        }
    }

    func testSelectedSizeCalculation() async {
        let viewModel = TrashViewModel()

        await viewModel.scan()

        if let summary = viewModel.trashSummary, !summary.items.isEmpty {
            viewModel.selectAll()
            XCTAssertEqual(
                viewModel.selectedSize,
                summary.totalSize,
                "Selected size should equal total size when all selected"
            )

            viewModel.selectNone()
            XCTAssertEqual(viewModel.selectedSize, 0, "Selected size should be 0 when nothing selected")
        }
    }

    func testScanStateTransitions() async {
        let viewModel = TrashViewModel()

        XCTAssertFalse(viewModel.scanState.isScanning, "Should start not scanning")

        // Perform scan
        await viewModel.scan()

        // After completion, should no longer be scanning
        XCTAssertFalse(viewModel.scanState.isScanning, "Should not be scanning after completion")
    }
}

// MARK: - PermissionManager Tests

@MainActor
final class PermissionManagerTests: XCTestCase {

    func testPermissionCheckDoesNotCrash() {
        let manager = PermissionManager()

        // Just verify it runs without crashing
        XCTAssertNotNil(manager.lastCheckTime, "Last check time should be set")
    }

    func testRefreshPermissions() {
        let manager = PermissionManager()

        let firstCheckTime = manager.lastCheckTime
        manager.checkPermissions()
        let secondCheckTime = manager.lastCheckTime

        XCTAssertNotNil(secondCheckTime, "Check time should be updated")
        if let first = firstCheckTime, let second = secondCheckTime {
            XCTAssertGreaterThanOrEqual(second, first, "Second check should be same time or later")
        }
    }
}

// MARK: - ViewModelStore Tests

@MainActor
final class ViewModelStoreTests: XCTestCase {

    func testLazyInitialization() {
        let store = ViewModelStore()

        // Access each ViewModel to trigger lazy initialization
        _ = store.systemCachesViewModel
        _ = store.browserCachesViewModel
        _ = store.trashViewModel

        // If we get here without crashing, the lazy initialization works
        XCTAssertNotNil(store.systemCachesViewModel)
        XCTAssertNotNil(store.browserCachesViewModel)
        XCTAssertNotNil(store.trashViewModel)
    }

    func testViewModelIdentity() {
        let store = ViewModelStore()

        // Access the same ViewModel twice
        let vm1 = store.systemCachesViewModel
        let vm2 = store.systemCachesViewModel

        // Should be the same instance
        XCTAssertTrue(vm1 === vm2, "Should return the same ViewModel instance")
    }
}
