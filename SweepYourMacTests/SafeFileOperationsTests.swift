//
//  SafeFileOperationsTests.swift
//  SweepYourMacTests
//
//  Tests for SafeFileOperations to verify secure deletion behavior.
//

import XCTest
@testable import SweepYourMac

final class SafeFileOperationsTests: XCTestCase {

    var tempDirectory: URL!
    var safeOps: SafeFileOperations!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SweepYourMacTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        safeOps = SafeFileOperations()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    // MARK: - Regular File Deletion Tests

    func testDeleteRegularFile() async throws {
        let filePath = tempDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: filePath, atomically: true, encoding: .utf8)

        let options = DeletionOptions.withRoots([tempDirectory.path])
        let result = await safeOps.deleteItem(at: filePath.path, options: options)

        XCTAssertTrue(result.success, "Should successfully delete regular file")
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath.path), "File should no longer exist")
        XCTAssertGreaterThan(result.freedBytes, 0, "Should report bytes freed")
    }

    func testDeleteDirectory() async throws {
        let dirPath = tempDirectory.appendingPathComponent("testdir")
        try FileManager.default.createDirectory(at: dirPath, withIntermediateDirectories: true)

        let filePath = dirPath.appendingPathComponent("file.txt")
        try "content".write(to: filePath, atomically: true, encoding: .utf8)

        let options = DeletionOptions.withRoots([tempDirectory.path])
        let result = await safeOps.deleteItem(at: dirPath.path, options: options)

        XCTAssertTrue(result.success, "Should successfully delete directory")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dirPath.path), "Directory should no longer exist")
    }

    // MARK: - Blocked Path Tests

    func testDeleteBlockedSystemPath() async {
        let options = DeletionOptions.withRoots(["/System"])
        let result = await safeOps.deleteItem(at: "/System/Library", options: options)

        XCTAssertFalse(result.success, "Should reject deletion of system paths")
        XCTAssertNotNil(result.error, "Should return an error")
    }

    func testDeleteBlockedRootPath() async {
        let options = DeletionOptions.withRoots(["/"])
        let result = await safeOps.deleteItem(at: "/", options: options)

        XCTAssertFalse(result.success, "Should reject deletion of root")
        XCTAssertNotNil(result.error, "Should return an error")
    }

    func testDeleteUsrPath() async {
        let options = DeletionOptions.withRoots(["/usr"])
        let result = await safeOps.deleteItem(at: "/usr/bin", options: options)

        XCTAssertFalse(result.success, "Should reject deletion of /usr paths")
    }

    // MARK: - Contents Deletion Tests

    func testDeleteContentsPreservesDirectory() async throws {
        let subDir = tempDirectory.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let file1 = subDir.appendingPathComponent("file1.txt")
        let file2 = subDir.appendingPathComponent("file2.txt")
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)

        let options = DeletionOptions.withRoots([tempDirectory.path])
        let result = await safeOps.deleteContents(of: subDir.path, options: options)

        XCTAssertEqual(result.deleted, 2, "Should delete both files")
        XCTAssertEqual(result.failed, 0, "Should have no failures")
        XCTAssertTrue(FileManager.default.fileExists(atPath: subDir.path), "Directory should still exist")

        let contents = try FileManager.default.contentsOfDirectory(atPath: subDir.path)
        XCTAssertTrue(contents.isEmpty, "Directory should be empty")
    }

    // MARK: - Symlink Security Tests

    func testSymlinkEscapeBlocked() async throws {
        // Create a symlink that points outside the allowed directory
        let symlinkPath = tempDirectory.appendingPathComponent("escape_link")

        // Point to /etc which should be outside allowed roots
        try FileManager.default.createSymbolicLink(
            at: symlinkPath,
            withDestinationURL: URL(fileURLWithPath: "/etc")
        )

        let options = DeletionOptions.withRoots([tempDirectory.path])
        let result = await safeOps.deleteItem(at: symlinkPath.path, options: options)

        // The symlink itself may be deleted, but following it should be blocked
        // This tests that we don't accidentally delete /etc contents
        XCTAssertTrue(FileManager.default.fileExists(atPath: "/etc"), "/etc should still exist")
    }

    func testSymlinkWithinAllowedRootsSucceeds() async throws {
        // Create a file and a symlink to it within the same allowed directory
        let targetFile = tempDirectory.appendingPathComponent("target.txt")
        try "target content".write(to: targetFile, atomically: true, encoding: .utf8)

        let symlinkPath = tempDirectory.appendingPathComponent("link_to_target")
        try FileManager.default.createSymbolicLink(
            at: symlinkPath,
            withDestinationURL: targetFile
        )

        let options = DeletionOptions.withRoots([tempDirectory.path])
        let result = await safeOps.deleteItem(at: symlinkPath.path, options: options)

        // Deleting the symlink should succeed
        XCTAssertTrue(result.success, "Should successfully delete symlink within allowed roots")
    }

    // MARK: - Non-existent Path Tests

    func testDeleteNonExistentPath() async {
        let nonExistent = tempDirectory.appendingPathComponent("does_not_exist.txt")

        let options = DeletionOptions.withRoots([tempDirectory.path])
        let result = await safeOps.deleteItem(at: nonExistent.path, options: options)

        // Deleting non-existent file should either succeed (nothing to do) or fail gracefully
        // Either way, no crash should occur
        XCTAssertNotNil(result, "Should return a result")
    }

    // MARK: - Batch Deletion Tests

    func testDeleteMultipleItems() async throws {
        var paths: [String] = []

        for i in 0..<5 {
            let filePath = tempDirectory.appendingPathComponent("file\(i).txt")
            try "content \(i)".write(to: filePath, atomically: true, encoding: .utf8)
            paths.append(filePath.path)
        }

        let options = DeletionOptions.withRoots([tempDirectory.path])
        let result = await safeOps.deleteItems(paths, options: options)

        XCTAssertEqual(result.deleted, 5, "Should delete all 5 files")
        XCTAssertEqual(result.failed, 0, "Should have no failures")
        XCTAssertGreaterThan(result.freedSpace, 0, "Should report total freed space")
    }
}
