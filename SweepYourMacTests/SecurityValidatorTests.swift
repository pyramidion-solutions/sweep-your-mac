//
//  SecurityValidatorTests.swift
//  SweepYourMacTests
//
//  Unit tests for security validators to prevent command injection,
//  symlink traversal, and unauthorized path access.
//

import XCTest
@testable import SweepYourMac

// MARK: - Docker ID Validator Tests

final class DockerIDValidatorTests: XCTestCase {

    // MARK: - Valid Image IDs

    func testValidShortImageID() {
        XCTAssertNoThrow(try DockerIDValidator.validateImageID("abc123def456"))
    }

    func testValidFullImageID() {
        // Full Docker image IDs are exactly 64 hex characters
        let fullID = "abc123def456abc123def456abc123def456abc123def456abc123def456abcd"
        XCTAssertNoThrow(try DockerIDValidator.validateImageID(fullID))
    }

    func testValidSha256ImageID() {
        // sha256: prefix followed by exactly 64 hex characters
        let sha256ID = "sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abcd"
        XCTAssertNoThrow(try DockerIDValidator.validateImageID(sha256ID))
    }

    func testValidImageName() {
        XCTAssertNoThrow(try DockerIDValidator.validateImageID("nginx"))
        XCTAssertNoThrow(try DockerIDValidator.validateImageID("nginx:latest"))
        XCTAssertNoThrow(try DockerIDValidator.validateImageID("myregistry/myimage:v1.0.0"))
    }

    // MARK: - Command Injection Attempts

    func testRejectsShellSemicolon() {
        XCTAssertThrowsError(try DockerIDValidator.validateImageID("abc; rm -rf /")) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }

    func testRejectsPipeCharacter() {
        XCTAssertThrowsError(try DockerIDValidator.validateImageID("abc | cat /etc/passwd")) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }

    func testRejectsBackticks() {
        XCTAssertThrowsError(try DockerIDValidator.validateImageID("`rm -rf /`")) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }

    func testRejectsDollarExpansion() {
        XCTAssertThrowsError(try DockerIDValidator.validateImageID("$(rm -rf /)")) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }

    func testRejectsAmpersand() {
        XCTAssertThrowsError(try DockerIDValidator.validateImageID("abc && rm -rf /")) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }

    func testRejectsNewline() {
        XCTAssertThrowsError(try DockerIDValidator.validateImageID("abc\nrm -rf /")) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }

    func testRejectsEmptyString() {
        XCTAssertThrowsError(try DockerIDValidator.validateImageID("")) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }

    // MARK: - Container ID Tests

    func testValidContainerID() {
        XCTAssertNoThrow(try DockerIDValidator.validateContainerID("abc123def456"))
        XCTAssertNoThrow(try DockerIDValidator.validateContainerID("my-container"))
        XCTAssertNoThrow(try DockerIDValidator.validateContainerID("my_container.name"))
    }

    func testContainerIDRejectsInjection() {
        XCTAssertThrowsError(try DockerIDValidator.validateContainerID("abc; rm -rf /"))
        XCTAssertThrowsError(try DockerIDValidator.validateContainerID("$(whoami)"))
    }

    // MARK: - Volume Name Tests

    func testValidVolumeName() {
        XCTAssertNoThrow(try DockerIDValidator.validateVolumeName("my-volume"))
        XCTAssertNoThrow(try DockerIDValidator.validateVolumeName("my_volume"))
        XCTAssertNoThrow(try DockerIDValidator.validateVolumeName("myvolume123"))
    }

    func testVolumeNameRejectsInjection() {
        XCTAssertThrowsError(try DockerIDValidator.validateVolumeName("abc; rm -rf /"))
        XCTAssertThrowsError(try DockerIDValidator.validateVolumeName(""))
    }

    func testVolumeNameRejectsLeadingSpecialChar() {
        XCTAssertThrowsError(try DockerIDValidator.validateVolumeName("-volume"))
        XCTAssertThrowsError(try DockerIDValidator.validateVolumeName(".volume"))
    }
}

// MARK: - Blocked Path Validator Tests

final class BlockedPathValidatorTests: XCTestCase {

    // MARK: - System Paths Should Be Blocked

    func testSystemPathBlocked() {
        XCTAssertTrue(BlockedPathValidator.isBlocked("/System"))
        XCTAssertTrue(BlockedPathValidator.isBlocked("/System/Library"))
        XCTAssertTrue(BlockedPathValidator.isBlocked("/System/Library/Caches"))
    }

    func testUsrPathBlocked() {
        XCTAssertTrue(BlockedPathValidator.isBlocked("/usr"))
        XCTAssertTrue(BlockedPathValidator.isBlocked("/usr/bin"))
        XCTAssertTrue(BlockedPathValidator.isBlocked("/usr/local"))
    }

    func testBinPathBlocked() {
        XCTAssertTrue(BlockedPathValidator.isBlocked("/bin"))
        XCTAssertTrue(BlockedPathValidator.isBlocked("/sbin"))
    }

    func testVarPathBlocked() {
        XCTAssertTrue(BlockedPathValidator.isBlocked("/var"))
        XCTAssertTrue(BlockedPathValidator.isBlocked("/private/var"))
    }

    func testRootPathBlocked() {
        XCTAssertTrue(BlockedPathValidator.isBlocked("/"))
    }

    func testApplicationsPathBlocked() {
        XCTAssertTrue(BlockedPathValidator.isBlocked("/Applications"))
    }

    func testLibraryRootBlocked() {
        XCTAssertTrue(BlockedPathValidator.isBlocked("/Library"))
    }

    func testUsersRootBlocked() {
        XCTAssertTrue(BlockedPathValidator.isBlocked("/Users"))
    }

    // MARK: - User Paths Should Be Allowed

    func testUserCacheAllowed() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertFalse(BlockedPathValidator.isBlocked("\(home)/Library/Caches"))
        XCTAssertFalse(BlockedPathValidator.isBlocked("\(home)/Library/Caches/com.example.app"))
    }

    func testUserLogsAllowed() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertFalse(BlockedPathValidator.isBlocked("\(home)/Library/Logs"))
    }

    func testUserDownloadsAllowed() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertFalse(BlockedPathValidator.isBlocked("\(home)/Downloads"))
    }

    func testLibraryCachesAllowed() {
        // /Library/Caches is allowed (not in blockedPrefixes, not exact match)
        XCTAssertFalse(BlockedPathValidator.isBlocked("/Library/Caches"))
    }

    // MARK: - Path Traversal Detection

    func testPathTraversalBlocked() {
        XCTAssertThrowsError(try BlockedPathValidator.validate("/Users/../System")) { error in
            guard case SecurityError.pathTraversal = error else {
                XCTFail("Expected pathTraversal error")
                return
            }
        }
    }

    func testPathTraversalInMiddleBlocked() {
        XCTAssertThrowsError(try BlockedPathValidator.validate("/home/user/../../../etc/passwd"))
    }

    func testPathTraversalAtEndBlocked() {
        XCTAssertThrowsError(try BlockedPathValidator.validate("/home/user/.."))
    }
}

// MARK: - Symlink Validator Tests

final class SymlinkValidatorTests: XCTestCase {

    var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    // MARK: - Regular File Tests

    func testRegularFileAllowed() throws {
        let filePath = tempDirectory.appendingPathComponent("regular_file.txt")
        try "test content".write(to: filePath, atomically: true, encoding: .utf8)

        XCTAssertNoThrow(try SymlinkValidator.validateNoEscape(
            at: filePath.path,
            allowedRoots: [tempDirectory.path]
        ))
    }

    func testRegularDirectoryAllowed() throws {
        let dirPath = tempDirectory.appendingPathComponent("regular_dir")
        try FileManager.default.createDirectory(at: dirPath, withIntermediateDirectories: true)

        XCTAssertNoThrow(try SymlinkValidator.validateNoEscape(
            at: dirPath.path,
            allowedRoots: [tempDirectory.path]
        ))
    }

    // MARK: - Symlink Detection Tests

    func testSymlinkWithinAllowedRootAllowed() throws {
        let targetPath = tempDirectory.appendingPathComponent("target.txt")
        try "target content".write(to: targetPath, atomically: true, encoding: .utf8)

        let symlinkPath = tempDirectory.appendingPathComponent("symlink.txt")
        try FileManager.default.createSymbolicLink(at: symlinkPath, withDestinationURL: targetPath)

        // Symlink within allowed root should be fine
        XCTAssertNoThrow(try SymlinkValidator.validateNoEscape(
            at: symlinkPath.path,
            allowedRoots: [tempDirectory.path]
        ))
    }

    func testSymlinkToSystemDetected() throws {
        let symlinkPath = tempDirectory.appendingPathComponent("malicious_link")

        // Create symlink pointing to /etc (outside allowed root)
        try FileManager.default.createSymbolicLink(
            at: symlinkPath,
            withDestinationURL: URL(fileURLWithPath: "/etc")
        )

        XCTAssertThrowsError(try SymlinkValidator.validateNoEscape(
            at: symlinkPath.path,
            allowedRoots: [tempDirectory.path]
        )) { error in
            guard case SecurityError.symlinkEscape = error else {
                XCTFail("Expected symlinkEscape error")
                return
            }
        }
    }

    func testNestedSymlinkDetected() throws {
        // Create a subdirectory
        let subDir = tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        // Create a symlink inside the subdirectory pointing outside
        let symlinkPath = subDir.appendingPathComponent("escape_link")
        try FileManager.default.createSymbolicLink(
            at: symlinkPath,
            withDestinationURL: URL(fileURLWithPath: "/usr")
        )

        // Validating the parent should catch the nested symlink
        XCTAssertThrowsError(try SymlinkValidator.validateNoEscape(
            at: subDir.path,
            allowedRoots: [tempDirectory.path]
        ))
    }

    // MARK: - checkSymlink Tests

    func testCheckSymlinkReturnsNilForRegularFile() throws {
        let filePath = tempDirectory.appendingPathComponent("file.txt")
        try "content".write(to: filePath, atomically: true, encoding: .utf8)

        let result = SymlinkValidator.checkSymlink(at: filePath.path, allowedRoots: [tempDirectory.path])
        XCTAssertNil(result, "Should return nil for non-symlink")
    }

    func testCheckSymlinkReturnsFalseForSafeSymlink() throws {
        let targetPath = tempDirectory.appendingPathComponent("target.txt")
        try "content".write(to: targetPath, atomically: true, encoding: .utf8)

        let symlinkPath = tempDirectory.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: symlinkPath, withDestinationURL: targetPath)

        let result = SymlinkValidator.checkSymlink(at: symlinkPath.path, allowedRoots: [tempDirectory.path])
        XCTAssertEqual(result, false, "Should return false for safe symlink")
    }

    func testCheckSymlinkReturnsTrueForEscapingSymlink() throws {
        let symlinkPath = tempDirectory.appendingPathComponent("escape.txt")
        try FileManager.default.createSymbolicLink(
            at: symlinkPath,
            withDestinationURL: URL(fileURLWithPath: "/etc/passwd")
        )

        let result = SymlinkValidator.checkSymlink(at: symlinkPath.path, allowedRoots: [tempDirectory.path])
        XCTAssertEqual(result, true, "Should return true for escaping symlink")
    }
}

// MARK: - Integration Tests

final class SecurityValidatorIntegrationTests: XCTestCase {

    func testCombinedValidationFlow() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let safePath = "\(home)/Library/Caches/com.example.safe"

        // Path should not be blocked
        XCTAssertFalse(BlockedPathValidator.isBlocked(safePath))

        // Create a temp directory to test symlink validation
        // (Testing the entire home directory would be too slow)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecurityValidatorTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a test file in the temp directory
        let testFile = tempDir.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        // Should pass symlink validation with appropriate roots
        XCTAssertNoThrow(try SymlinkValidator.validateNoEscape(
            at: tempDir.path,
            allowedRoots: [tempDir.path]
        ))
    }

    func testRealWorldAttackScenario() {
        // Simulate an attack where someone tries to inject a command via Docker
        let maliciousInputs = [
            "nginx; rm -rf /",
            "$(cat /etc/passwd)",
            "`whoami`",
            "image | tee /etc/passwd",
            "image\n rm -rf /",
            "image && cat /etc/shadow",
            "'; DROP TABLE users; --"
        ]

        for input in maliciousInputs {
            XCTAssertThrowsError(
                try DockerIDValidator.validateImageID(input),
                "Should reject malicious input: \(input)"
            )
        }
    }
}
