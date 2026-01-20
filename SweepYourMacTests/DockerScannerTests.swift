//
//  DockerScannerTests.swift
//  SweepYourMacTests
//
//  Tests for DockerScanner including size parsing, Docker detection,
//  and command injection prevention through ID validation.
//

import XCTest
@testable import SweepYourMac

// MARK: - Docker Size Parsing Tests

final class DockerSizeParsingTests: XCTestCase {

    // We can't directly test parseDockerSize since it's private,
    // but we test the DockerImage/Container size parsing through integration

    func testDockerImageDisplayName() {
        // Test dangling image
        let danglingImage = DockerScanner.DockerImage(
            id: "abc123",
            repository: "<none>",
            tag: "<none>",
            size: 1024,
            created: "2 weeks ago"
        )
        XCTAssertEqual(danglingImage.displayName, "Dangling image")

        // Test image with tag
        let taggedImage = DockerScanner.DockerImage(
            id: "def456",
            repository: "nginx",
            tag: "latest",
            size: 1024 * 1024,
            created: "3 days ago"
        )
        XCTAssertEqual(taggedImage.displayName, "nginx:latest")

        // Test image without tag
        let untaggedImage = DockerScanner.DockerImage(
            id: "ghi789",
            repository: "myimage",
            tag: "<none>",
            size: 2048,
            created: "1 week ago"
        )
        XCTAssertEqual(untaggedImage.displayName, "myimage")
    }

    func testDockerContainerRunningStatus() {
        let runningContainer = DockerScanner.DockerContainer(
            id: "abc123",
            name: "my-container",
            image: "nginx",
            status: "Up 2 hours",
            size: 1024
        )
        XCTAssertTrue(runningContainer.isRunning, "Container with 'Up' status should be running")

        let stoppedContainer = DockerScanner.DockerContainer(
            id: "def456",
            name: "stopped-container",
            image: "redis",
            status: "Exited (0) 3 hours ago",
            size: 2048
        )
        XCTAssertFalse(stoppedContainer.isRunning, "Exited container should not be running")

        let createdContainer = DockerScanner.DockerContainer(
            id: "ghi789",
            name: "created-container",
            image: "postgres",
            status: "Created",
            size: 512
        )
        XCTAssertFalse(createdContainer.isRunning, "Created container should not be running")
    }

    func testDockerComponentProperties() {
        // Test all components have valid properties
        for component in DockerScanner.DockerComponent.allCases {
            XCTAssertFalse(component.rawValue.isEmpty, "Component \(component) should have non-empty rawValue")
            XCTAssertFalse(component.icon.isEmpty, "Component \(component) should have an icon")
            XCTAssertFalse(component.description.isEmpty, "Component \(component) should have a description")
            XCTAssertFalse(component.color.isEmpty, "Component \(component) should have a color")
        }
    }

    func testDockerComponentCanClean() {
        // Disk image cannot be cleaned (requires Docker commands)
        XCTAssertFalse(DockerScanner.DockerComponent.diskImage.canClean)

        // These can be cleaned
        XCTAssertTrue(DockerScanner.DockerComponent.images.canClean)
        XCTAssertTrue(DockerScanner.DockerComponent.containers.canClean)
        XCTAssertTrue(DockerScanner.DockerComponent.volumes.canClean)
        XCTAssertTrue(DockerScanner.DockerComponent.buildCache.canClean)
        XCTAssertTrue(DockerScanner.DockerComponent.logs.canClean)

        // Other cannot be cleaned
        XCTAssertFalse(DockerScanner.DockerComponent.other.canClean)
    }

    func testFormattedSizes() {
        let image = DockerScanner.DockerImage(
            id: "abc",
            repository: "test",
            tag: "latest",
            size: 1024 * 1024 * 100, // 100 MB
            created: "1 day ago"
        )
        XCTAssertFalse(image.formattedSize.isEmpty, "Formatted size should not be empty")

        let container = DockerScanner.DockerContainer(
            id: "def",
            name: "test",
            image: "test",
            status: "Up",
            size: 1024 * 1024 * 50 // 50 MB
        )
        XCTAssertFalse(container.formattedSize.isEmpty)

        let volume = DockerScanner.DockerVolume(
            id: "vol1",
            name: "my-volume",
            driver: "local",
            size: 1024 * 1024 * 200 // 200 MB
        )
        XCTAssertFalse(volume.formattedSize.isEmpty)

        let cache = DockerScanner.DockerBuildCache(
            id: "cache1",
            cacheType: "regular",
            size: 1024 * 1024 * 25, // 25 MB
            inUse: false
        )
        XCTAssertFalse(cache.formattedSize.isEmpty)
    }
}

// MARK: - Docker Scan Result Tests

final class DockerScanResultTests: XCTestCase {

    func testEmptyScanResult() {
        let result = DockerScanner.DockerScanResult(
            isDockerInstalled: false,
            isDockerRunning: false,
            components: [],
            images: [],
            containers: [],
            volumes: [],
            buildCache: [],
            totalSize: 0,
            reclaimableSize: 0,
            scanDuration: 0.5
        )

        XCTAssertFalse(result.isDockerInstalled)
        XCTAssertFalse(result.isDockerRunning)
        XCTAssertTrue(result.components.isEmpty)
        XCTAssertEqual(result.totalSize, 0)
        // ByteCountFormatter returns locale-specific format, just verify it's not empty
        XCTAssertFalse(result.formattedTotalSize.isEmpty)
    }

    func testScanResultWithData() {
        let component = DockerScanner.ComponentInfo(
            component: .images,
            size: 1024 * 1024 * 500, // 500 MB
            itemCount: 5,
            details: "5 images"
        )

        let result = DockerScanner.DockerScanResult(
            isDockerInstalled: true,
            isDockerRunning: true,
            components: [component],
            images: [],
            containers: [],
            volumes: [],
            buildCache: [],
            totalSize: 1024 * 1024 * 500,
            reclaimableSize: 1024 * 1024 * 100,
            scanDuration: 2.5
        )

        XCTAssertTrue(result.isDockerInstalled)
        XCTAssertTrue(result.isDockerRunning)
        XCTAssertEqual(result.components.count, 1)
        XCTAssertFalse(result.formattedTotalSize.isEmpty)
        XCTAssertFalse(result.formattedReclaimableSize.isEmpty)
    }
}

// MARK: - Docker Scanner Integration Tests

final class DockerScannerIntegrationTests: XCTestCase {

    func testScanReturnsValidResult() async {
        let scanner = DockerScanner()
        var progressMessages: [String] = []

        let result = await scanner.scan { message in
            progressMessages.append(message)
        }

        // Scan should always return a valid result
        XCTAssertGreaterThanOrEqual(result.scanDuration, 0, "Scan duration should be >= 0")
        XCTAssertGreaterThanOrEqual(result.totalSize, 0, "Total size should be >= 0")
        XCTAssertGreaterThanOrEqual(result.reclaimableSize, 0, "Reclaimable size should be >= 0")

        // Progress handler should be called
        XCTAssertFalse(progressMessages.isEmpty, "Progress handler should be called at least once")
        XCTAssertTrue(progressMessages.first?.contains("Checking Docker") ?? false, "First message should check Docker installation")
    }

    func testScanWithDockerNotInstalled() async {
        // This test validates behavior when Docker is not installed
        // It may pass or fail depending on system state
        let scanner = DockerScanner()

        let result = await scanner.scan { _ in }

        if !result.isDockerInstalled {
            // If Docker is not installed, verify empty result
            XCTAssertFalse(result.isDockerRunning, "Docker can't be running if not installed")
            XCTAssertTrue(result.components.isEmpty, "No components if Docker not installed")
            XCTAssertTrue(result.images.isEmpty)
            XCTAssertTrue(result.containers.isEmpty)
            XCTAssertTrue(result.volumes.isEmpty)
            XCTAssertTrue(result.buildCache.isEmpty)
        }
    }

    func testRemoveImageRejectsInjection() async {
        let scanner = DockerScanner()

        // These should all return false due to validation failure
        let maliciousInputs = [
            "abc; rm -rf /",
            "$(whoami)",
            "`cat /etc/passwd`",
            "image | tee /tmp/evil",
            "image\nrm -rf /",
            "",
            "   "
        ]

        for input in maliciousInputs {
            let success = await scanner.removeImage(input)
            XCTAssertFalse(success, "Should reject malicious input: \(input)")
        }
    }

    func testRemoveContainerRejectsInjection() async {
        let scanner = DockerScanner()

        let maliciousInputs = [
            "container; rm -rf /",
            "$(cat /etc/shadow)",
            "`id`",
            ""
        ]

        for input in maliciousInputs {
            let success = await scanner.removeContainer(input)
            XCTAssertFalse(success, "Should reject malicious container ID: \(input)")
        }
    }

    func testRemoveVolumeRejectsInjection() async {
        let scanner = DockerScanner()

        let maliciousInputs = [
            "vol; rm -rf /",
            "-volume", // Leading special char
            ".volume",
            ""
        ]

        for input in maliciousInputs {
            let success = await scanner.removeVolume(input)
            XCTAssertFalse(success, "Should reject malicious volume name: \(input)")
        }
    }

    func testValidDockerIDsAccepted() async {
        // Note: These tests verify ID validation passes, but actual removal
        // will fail if Docker is not running or item doesn't exist
        let scanner = DockerScanner()

        // Valid IDs should pass validation (but may fail at Docker level)
        // We're testing that they don't get rejected by the validator

        // For actual removal, we'd need Docker running with these items
        // This test just verifies the validation layer doesn't block valid IDs

        // Test that validation passes for valid format (actual removal may still fail)
        // Using XCTAssertNoThrow on the validator directly
        XCTAssertNoThrow(try DockerIDValidator.validateImageID("nginx:latest"))
        XCTAssertNoThrow(try DockerIDValidator.validateContainerID("my-container"))
        XCTAssertNoThrow(try DockerIDValidator.validateVolumeName("my_volume"))
    }
}

// MARK: - Component Info Tests

final class ComponentInfoTests: XCTestCase {

    func testComponentInfoFormattedSize() {
        let info = DockerScanner.ComponentInfo(
            component: .images,
            size: 1024 * 1024 * 1024, // 1 GB
            itemCount: 10,
            details: "10 images"
        )

        XCTAssertEqual(info.component, .images)
        XCTAssertEqual(info.itemCount, 10)
        XCTAssertEqual(info.details, "10 images")
        XCTAssertFalse(info.formattedSize.isEmpty)

        // Each ComponentInfo should have unique ID
        let info2 = DockerScanner.ComponentInfo(
            component: .images,
            size: 1024,
            itemCount: 1,
            details: "1 image"
        )
        XCTAssertNotEqual(info.id, info2.id)
    }
}
