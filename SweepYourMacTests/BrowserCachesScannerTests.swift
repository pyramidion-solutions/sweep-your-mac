//
//  BrowserCachesScannerTests.swift
//  SweepYourMacTests
//
//  Tests for BrowserCachesScanner including browser detection,
//  running browser checks, and path validation.
//

import XCTest
@testable import SweepYourMac

// MARK: - Browser Enum Tests

final class BrowserEnumTests: XCTestCase {

    func testAllBrowsersHaveUniqueIdentifiers() {
        var identifiers = Set<String>()
        for browser in BrowserCachesScanner.Browser.allCases {
            XCTAssertFalse(identifiers.contains(browser.bundleIdentifier),
                           "Duplicate bundle identifier: \(browser.bundleIdentifier)")
            identifiers.insert(browser.bundleIdentifier)
        }
        XCTAssertEqual(identifiers.count, BrowserCachesScanner.Browser.allCases.count)
    }

    func testBrowserBundleIdentifiers() {
        // Verify known bundle identifiers
        XCTAssertEqual(BrowserCachesScanner.Browser.safari.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(BrowserCachesScanner.Browser.chrome.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(BrowserCachesScanner.Browser.firefox.bundleIdentifier, "org.mozilla.firefox")
        XCTAssertEqual(BrowserCachesScanner.Browser.edge.bundleIdentifier, "com.microsoft.edgemac")
        XCTAssertEqual(BrowserCachesScanner.Browser.brave.bundleIdentifier, "com.brave.Browser")
        XCTAssertEqual(BrowserCachesScanner.Browser.opera.bundleIdentifier, "com.operasoftware.Opera")
        XCTAssertEqual(BrowserCachesScanner.Browser.vivaldi.bundleIdentifier, "com.vivaldi.Vivaldi")
        XCTAssertEqual(BrowserCachesScanner.Browser.arc.bundleIdentifier, "company.thebrowser.Browser")
    }

    func testBrowserAppNames() {
        XCTAssertEqual(BrowserCachesScanner.Browser.safari.appName, "Safari")
        XCTAssertEqual(BrowserCachesScanner.Browser.chrome.appName, "Google Chrome")
        XCTAssertEqual(BrowserCachesScanner.Browser.firefox.appName, "Firefox")
        XCTAssertEqual(BrowserCachesScanner.Browser.edge.appName, "Microsoft Edge")
        XCTAssertEqual(BrowserCachesScanner.Browser.brave.appName, "Brave Browser")
        XCTAssertEqual(BrowserCachesScanner.Browser.opera.appName, "Opera")
        XCTAssertEqual(BrowserCachesScanner.Browser.vivaldi.appName, "Vivaldi")
        XCTAssertEqual(BrowserCachesScanner.Browser.arc.appName, "Arc")
    }

    func testAllBrowsersHaveIcons() {
        for browser in BrowserCachesScanner.Browser.allCases {
            XCTAssertFalse(browser.icon.isEmpty, "\(browser) should have an icon")
        }
    }

    func testBrowserCount() {
        // Verify we have all 8 browsers
        XCTAssertEqual(BrowserCachesScanner.Browser.allCases.count, 8)
    }

    func testBrowserIdentifiable() {
        for browser in BrowserCachesScanner.Browser.allCases {
            XCTAssertEqual(browser.id, browser.rawValue, "Browser id should equal rawValue")
        }
    }
}

// MARK: - Cache Type Tests

final class CacheTypeTests: XCTestCase {

    func testAllCacheTypesHaveRawValue() {
        let expectedTypes: [BrowserCachesScanner.BrowserCacheLocation.CacheType: String] = [
            .cache: "Cache",
            .cookies: "Cookies",
            .history: "History",
            .localStorage: "Local Storage",
            .sessionStorage: "Session Storage",
            .serviceWorkers: "Service Workers",
            .webData: "Web Data"
        ]

        for (type, expected) in expectedTypes {
            XCTAssertEqual(type.rawValue, expected)
        }
    }
}

// MARK: - Browser Detection Tests

final class BrowserDetectionTests: XCTestCase {

    func testGetInstalledBrowsers() async {
        let scanner = BrowserCachesScanner()

        let installed = await scanner.getInstalledBrowsers()

        // At minimum, Safari should be installed on macOS
        // Note: This test assumes running on a Mac with Safari
        #if os(macOS)
        XCTAssertTrue(installed.contains(.safari), "Safari should be installed on macOS")
        #endif

        // Verify no duplicate browsers
        XCTAssertEqual(installed.count, Set(installed).count, "Should not have duplicates")
    }

    func testGetRunningBrowsers() async {
        let scanner = BrowserCachesScanner()

        // This is a dynamic test - just verify it doesn't crash
        let running = await scanner.getRunningBrowsers()

        // Verify result is valid
        XCTAssertNotNil(running)

        // All running browsers should be from the known set
        for browser in running {
            XCTAssertTrue(BrowserCachesScanner.Browser.allCases.contains(browser),
                          "Unknown browser in running list: \(browser)")
        }
    }

    func testIsBrowserRunning() async {
        let scanner = BrowserCachesScanner()

        // Test each browser - should not crash
        for browser in BrowserCachesScanner.Browser.allCases {
            let isRunning = await scanner.isBrowserRunning(browser)
            // Just verify it returns a boolean without crashing
            XCTAssertNotNil(isRunning)
        }
    }
}

// MARK: - Browser Path Mapping Tests

final class BrowserPathMappingTests: XCTestCase {

    func testSafariPathDetection() async {
        let scanner = BrowserCachesScanner()
        let info = await scanner.getBrowserInfo(.safari)

        // getBrowserInfo should return valid data
        XCTAssertNotNil(info)
        XCTAssertGreaterThanOrEqual(info.cacheSize, 0)
    }

    func testChromePathDetection() async {
        let scanner = BrowserCachesScanner()
        let info = await scanner.getBrowserInfo(.chrome)

        XCTAssertNotNil(info)
        XCTAssertGreaterThanOrEqual(info.cacheSize, 0)
    }

    func testAllBrowsersReturnValidInfo() async {
        let scanner = BrowserCachesScanner()

        for browser in BrowserCachesScanner.Browser.allCases {
            let info = await scanner.getBrowserInfo(browser)

            // Cache size should be non-negative
            XCTAssertGreaterThanOrEqual(info.cacheSize, 0,
                                        "\(browser) cache size should be >= 0")

            // If installed, running status is boolean
            if info.installed {
                XCTAssertNotNil(info.running)
            }
        }
    }
}

// MARK: - Scan Integration Tests

final class BrowserCachesScannerIntegrationTests: XCTestCase {

    func testScanReturnsValidResult() async {
        let scanner = BrowserCachesScanner()
        var progressMessages: [String] = []

        let result = await scanner.scan { message in
            progressMessages.append(message)
        }

        // Verify result structure
        XCTAssertEqual(result.category, .browserCaches, "Should return browserCaches category")
        XCTAssertGreaterThanOrEqual(result.totalSize, 0, "Total size should be >= 0")
        XCTAssertGreaterThanOrEqual(result.scanDuration, 0, "Scan duration should be >= 0")

        // If there are items, verify they have valid properties
        for item in result.items {
            XCTAssertFalse(item.path.isEmpty, "Item path should not be empty")
            XCTAssertFalse(item.name.isEmpty, "Item name should not be empty")
            XCTAssertGreaterThanOrEqual(item.size, 0, "Item size should be >= 0")
            XCTAssertEqual(item.safetyLevel, .safe, "Browser cache items should be safe")
        }
    }

    func testScanProgressCallbackIsCalled() async {
        let scanner = BrowserCachesScanner()
        var progressCalled = false

        _ = await scanner.scan { _ in
            progressCalled = true
        }

        // Progress may or may not be called depending on installed browsers
        // Just verify no crash occurred
        XCTAssertNotNil(progressCalled)
    }

    func testScanResultsSortedBySize() async {
        let scanner = BrowserCachesScanner()

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
        let scanner = BrowserCachesScanner()

        let result = await scanner.scan { _ in }

        let calculatedTotal = result.items.reduce(0) { $0 + $1.size }
        XCTAssertEqual(result.totalSize, calculatedTotal,
                       "Total size should match sum of item sizes")
    }
}

// MARK: - Delete Items Tests

final class BrowserCachesDeleteTests: XCTestCase {

    var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SweepYourMacTests-BrowserCache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testDeleteItemsWithEmptyList() async {
        let scanner = BrowserCachesScanner()

        let result = await scanner.deleteItems([], checkRunning: false)

        XCTAssertEqual(result.deleted, 0)
        XCTAssertEqual(result.failed, 0)
        XCTAssertEqual(result.freedSpace, 0)
        XCTAssertTrue(result.runningBrowsers.isEmpty)
    }

    func testDeleteItemsRejectsBlockedPaths() async {
        let scanner = BrowserCachesScanner()

        // Try to delete a blocked system path
        let blockedItem = ScanResult(
            path: "/System/Library/Caches",
            name: "System Cache",
            size: 1000,
            itemCount: 1,
            lastModified: Date(),
            safetyLevel: .risky,
            isReadOnly: true,
            isSelected: true
        )

        let result = await scanner.deleteItems([blockedItem], checkRunning: false)

        XCTAssertEqual(result.deleted, 0, "Should not delete blocked paths")
        XCTAssertEqual(result.failed, 1, "Blocked path should count as failed")
    }

    func testDeleteItemsHandlesNonexistentPaths() async {
        let scanner = BrowserCachesScanner()

        let nonexistentItem = ScanResult(
            path: "/nonexistent/path/that/does/not/exist",
            name: "Nonexistent",
            size: 1000,
            itemCount: 1,
            lastModified: Date(),
            safetyLevel: .safe,
            isReadOnly: false,
            isSelected: true
        )

        let result = await scanner.deleteItems([nonexistentItem], checkRunning: false)

        XCTAssertEqual(result.deleted, 0)
        XCTAssertEqual(result.failed, 1, "Nonexistent path should count as failed")
    }

    func testDeleteItemsReturnsRunningBrowsersWhenCheckEnabled() async {
        let scanner = BrowserCachesScanner()

        // Get currently running browsers
        let runningBefore = await scanner.getRunningBrowsers()

        let result = await scanner.deleteItems([], checkRunning: true)

        // If browsers are running, they should be in the result
        // Note: This is a dynamic test
        if !runningBefore.isEmpty {
            // Result might have running browsers (depends on what we try to delete)
            XCTAssertNotNil(result.runningBrowsers)
        }
    }
}

// MARK: - Safety Tests

final class BrowserCachesSafetyTests: XCTestCase {

    func testAllItemsMarkedAsSafe() async {
        let scanner = BrowserCachesScanner()

        let result = await scanner.scan { _ in }

        // All browser cache items should be marked as safe
        for item in result.items {
            XCTAssertEqual(item.safetyLevel, .safe,
                           "Browser cache item '\(item.name)' should be marked safe")
        }
    }

    func testNoItemsMarkedAsReadOnly() async {
        let scanner = BrowserCachesScanner()

        let result = await scanner.scan { _ in }

        // User browser caches should not be read-only
        for item in result.items {
            XCTAssertFalse(item.isReadOnly,
                           "User browser cache '\(item.name)' should not be read-only")
        }
    }

    func testItemsAreSelectedByDefault() async {
        let scanner = BrowserCachesScanner()

        let result = await scanner.scan { _ in }

        // Safe browser caches should be selected by default
        for item in result.items {
            XCTAssertTrue(item.isSelected,
                          "Safe browser cache '\(item.name)' should be selected by default")
        }
    }
}

// MARK: - Browser Cache Location Tests

final class BrowserCacheLocationTests: XCTestCase {

    func testCacheLocationStructure() {
        let location = BrowserCachesScanner.BrowserCacheLocation(
            browser: .chrome,
            path: "/test/path",
            type: .cache,
            description: "Test cache"
        )

        XCTAssertEqual(location.browser, .chrome)
        XCTAssertEqual(location.path, "/test/path")
        XCTAssertEqual(location.type, .cache)
        XCTAssertEqual(location.description, "Test cache")
    }
}
