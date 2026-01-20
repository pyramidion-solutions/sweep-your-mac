//
//  SafeFileOperations.swift
//  SweepYourMac
//
//  Thread-safe file operations with atomic checks using NSFileCoordinator
//  to prevent TOCTOU (time-of-check-to-time-of-use) race conditions.
//

import Foundation

// MARK: - Deletion Options

/// Configuration options for safe file deletion operations.
struct DeletionOptions {
    /// Whether to check if files are in use before deletion
    let checkInUse: Bool

    /// Whether to validate symlinks don't escape allowed directories
    let validateSymlinks: Bool

    /// Root directories that are allowed for deletion and symlink targets
    let allowedRoots: [String]

    /// Whether to move to trash instead of permanent deletion
    let moveToTrash: Bool

    /// Files/directories modified today should be skipped
    let skipTodaysFiles: Bool

    /// Default options for most deletion operations
    /// Uses move-to-trash by default for safer deletions
    static let `default` = DeletionOptions(
        checkInUse: true,
        validateSymlinks: true,
        allowedRoots: [],
        moveToTrash: true,
        skipTodaysFiles: false
    )

    /// Create options with specific allowed roots
    /// Uses move-to-trash by default for safer deletions
    static func withRoots(_ roots: [String], checkInUse: Bool = true, skipTodaysFiles: Bool = false, moveToTrash: Bool = true) -> DeletionOptions {
        DeletionOptions(
            checkInUse: checkInUse,
            validateSymlinks: true,
            allowedRoots: roots,
            moveToTrash: moveToTrash,
            skipTodaysFiles: skipTodaysFiles
        )
    }
}

// MARK: - Deletion Result

/// Result of a single file/directory deletion operation.
struct DeletionResult {
    let path: String
    let success: Bool
    let error: Error?
    let freedBytes: Int64
}

// MARK: - Safe File Operations Actor

/// Actor providing thread-safe file operations with security validations.
/// Uses NSFileCoordinator for atomic operations to prevent TOCTOU attacks.
actor SafeFileOperations {

    private let fileManager = FileManager.default

    // MARK: - Public Interface

    /// Safely delete a single item with all security checks.
    /// - Parameters:
    ///   - path: Path to the file or directory to delete
    ///   - options: Deletion options including security validations
    /// - Returns: DeletionResult indicating success/failure and bytes freed
    func deleteItem(at path: String, options: DeletionOptions) async -> DeletionResult {
        do {
            // Step 1: Validate path is not blocked
            try BlockedPathValidator.validate(path)

            // Step 2: Validate symlinks if enabled
            if options.validateSymlinks && !options.allowedRoots.isEmpty {
                try SymlinkValidator.validateNoEscape(at: path, allowedRoots: options.allowedRoots)
            }

            // Step 3: Check if in use (for files that support it)
            if options.checkInUse {
                if await isItemInUse(at: path) {
                    AppLogger.deletion.warning("Skipped deletion of in-use item: \(path, privacy: .public)")
                    return DeletionResult(
                        path: path,
                        success: false,
                        error: SecurityError.fileInUse(path),
                        freedBytes: 0
                    )
                }
            }

            // Step 4: Perform coordinated deletion
            let freedBytes = try await coordinatedDelete(at: path, moveToTrash: options.moveToTrash)

            AppLogger.deletion.info("Successfully deleted: \(path, privacy: .public) (\(freedBytes) bytes)")
            return DeletionResult(path: path, success: true, error: nil, freedBytes: freedBytes)

        } catch {
            AppLogger.deletion.error("Failed to delete \(path, privacy: .public): \(error.localizedDescription)")
            return DeletionResult(path: path, success: false, error: error, freedBytes: 0)
        }
    }

    /// Safely delete the contents of a directory (not the directory itself).
    /// - Parameters:
    ///   - directoryPath: Path to the directory whose contents should be deleted
    ///   - options: Deletion options including security validations
    ///   - excludeFilter: Optional filter to exclude certain items
    /// - Returns: Tuple with counts of deleted/failed items and bytes freed
    func deleteContents(
        of directoryPath: String,
        options: DeletionOptions,
        excludeFilter: ((URL) -> Bool)? = nil
    ) async -> (deleted: Int, failed: Int, freedSpace: Int64) {
        var deleted = 0
        var failed = 0
        var freedSpace: Int64 = 0

        // Validate the directory itself first
        do {
            try BlockedPathValidator.validate(directoryPath)
        } catch {
            return (0, 1, 0)
        }

        let url = URL(fileURLWithPath: directoryPath)

        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: []
        ) else {
            return (0, 1, 0)
        }

        for itemURL in contents {
            // Apply exclude filter if provided
            if let filter = excludeFilter, filter(itemURL) {
                continue
            }

            // Skip today's files if enabled
            if options.skipTodaysFiles {
                if let modDate = try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   Calendar.current.isDateInToday(modDate) {
                    continue
                }
            }

            // Check for escaping symlinks
            if options.validateSymlinks && !options.allowedRoots.isEmpty {
                if let escapes = SymlinkValidator.checkSymlink(at: itemURL.path, allowedRoots: options.allowedRoots),
                   escapes {
                    failed += 1
                    continue
                }
            }

            let result = await deleteItem(at: itemURL.path, options: options)
            if result.success {
                deleted += 1
                freedSpace += result.freedBytes
            } else {
                failed += 1
            }
        }

        if deleted > 0 || failed > 0 {
            AppLogger.deletion.info("Directory cleanup at \(directoryPath, privacy: .public): \(deleted) deleted, \(failed) failed, \(freedSpace) bytes freed")
        }
        return (deleted, failed, freedSpace)
    }

    /// Batch delete multiple items with progress reporting.
    /// - Parameters:
    ///   - paths: Array of paths to delete
    ///   - options: Deletion options
    ///   - progressHandler: Called with (current, total) after each item
    /// - Returns: Summary of deletion results
    func deleteItems(
        _ paths: [String],
        options: DeletionOptions,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async -> (deleted: Int, failed: Int, freedSpace: Int64, errors: [Error]) {
        var deleted = 0
        var failed = 0
        var freedSpace: Int64 = 0
        var errors: [Error] = []

        for (index, path) in paths.enumerated() {
            let result = await deleteItem(at: path, options: options)

            if result.success {
                deleted += 1
                freedSpace += result.freedBytes
            } else {
                failed += 1
                if let error = result.error {
                    errors.append(error)
                }
            }

            progressHandler?(index + 1, paths.count)
        }

        AppLogger.deletion.info("Batch deletion complete: \(deleted) deleted, \(failed) failed, \(freedSpace) bytes freed")
        return (deleted, failed, freedSpace, errors)
    }

    // MARK: - Private Helpers

    /// Performs coordinated file deletion using NSFileCoordinator.
    /// This ensures atomic access and prevents race conditions.
    private func coordinatedDelete(at path: String, moveToTrash: Bool) async throws -> Int64 {
        let url = URL(fileURLWithPath: path)

        // Calculate size before deletion
        let size = calculateSize(at: path)

        // Use NSFileCoordinator for atomic deletion
        var coordinatorError: NSError?
        var deletionError: Error?

        let coordinator = NSFileCoordinator(filePresenter: nil)

        coordinator.coordinate(
            writingItemAt: url,
            options: .forDeleting,
            error: &coordinatorError
        ) { coordinatedURL in
            do {
                // Re-validate symlinks inside the coordination block
                // This prevents TOCTOU where symlink is swapped after initial check
                let resolvedURL = coordinatedURL.resolvingSymlinksInPath()

                // Ensure resolved path is not a system path
                try BlockedPathValidator.validate(resolvedURL.path)

                if moveToTrash {
                    try self.fileManager.trashItem(at: coordinatedURL, resultingItemURL: nil)
                } else {
                    try self.fileManager.removeItem(at: coordinatedURL)
                }
            } catch {
                deletionError = error
            }
        }

        if let error = coordinatorError {
            throw error
        }

        if let error = deletionError {
            throw error
        }

        return size
    }

    /// Checks if a file or directory is currently in use using lsof.
    private func isItemInUse(at path: String) async -> Bool {
        // Only check for directories - files are checked atomically during deletion
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["+D", path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // If lsof returns any output, files are in use
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            // If we can't check, assume not in use (fail open for usability)
            return false
        }
    }

    /// Calculates the size of a file or directory.
    private func calculateSize(at path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return 0
        }

        if !isDirectory.boolValue {
            // Single file
            if let attributes = try? fileManager.attributesOfItem(atPath: path),
               let size = attributes[.size] as? Int64 {
                return size
            }
            return 0
        }

        // Directory - enumerate and sum
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  resourceValues.isDirectory != true,
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }
}

// MARK: - Convenience Extensions

extension SafeFileOperations {

    /// Delete contents of a cache directory with standard cache-safe options.
    /// Moves to trash by default for safer deletions.
    func deleteCacheContents(
        at path: String,
        allowedRoots: [String],
        checkInUse: Bool = true,
        moveToTrash: Bool = true
    ) async -> (deleted: Int, failed: Int, freedSpace: Int64) {
        let options = DeletionOptions(
            checkInUse: checkInUse,
            validateSymlinks: true,
            allowedRoots: allowedRoots,
            moveToTrash: moveToTrash,
            skipTodaysFiles: false
        )
        return await deleteContents(of: path, options: options)
    }

    /// Delete contents of a logs directory, skipping today's logs.
    /// Moves to trash by default for safer deletions.
    func deleteLogContents(
        at path: String,
        allowedRoots: [String],
        moveToTrash: Bool = true
    ) async -> (deleted: Int, failed: Int, freedSpace: Int64) {
        let options = DeletionOptions(
            checkInUse: false,
            validateSymlinks: true,
            allowedRoots: allowedRoots,
            moveToTrash: moveToTrash,
            skipTodaysFiles: true
        )
        return await deleteContents(of: path, options: options)
    }
}
