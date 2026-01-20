import Foundation
import Combine
import os.log

@MainActor
class DiskSpaceManager: ObservableObject {
    @Published var diskSpace: DiskSpace = .empty
    @Published var isLoading: Bool = true  // Start as true to show loading immediately
    @Published var error: String?
    @Published var storageBreakdown: [StorageBreakdown] = []
    @Published var isCalculatingBreakdown: Bool = false  // Separate flag for breakdown

    private let fileManager = FileManager.default
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sweepyourmac", category: "DiskSpace")

    init() {
        Task {
            await refreshDiskSpace()
        }
    }

    func refreshDiskSpace() async {
        isLoading = true
        error = nil

        do {
            // Phase 1: Quick disk space lookup (fast)
            let space = try getDiskSpace()
            self.diskSpace = space
            isLoading = false  // UI can render basic stats now

            // Phase 2: Expensive breakdown calculation (in background)
            await calculateStorageBreakdownInBackground()
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func calculateStorageBreakdownInBackground() async {
        isCalculatingBreakdown = true
        await calculateStorageBreakdown()
        isCalculatingBreakdown = false
    }

    private func getDiskSpace() throws -> DiskSpace {
        let volumeURL = URL(fileURLWithPath: "/")

        let resourceKeys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]

        let values = try volumeURL.resourceValues(forKeys: resourceKeys)

        guard let totalCapacity = values.volumeTotalCapacity else {
            throw DiskSpaceError.unableToReadDiskSpace
        }

        let availableCapacity: Int64
        if let importantUsage = values.volumeAvailableCapacityForImportantUsage {
            availableCapacity = importantUsage
        } else if let regularCapacity = values.volumeAvailableCapacity {
            availableCapacity = Int64(regularCapacity)
        } else {
            throw DiskSpaceError.unableToReadDiskSpace
        }

        let total = Int64(totalCapacity)
        let free = availableCapacity
        let used = total - free

        return DiskSpace(totalSpace: total, usedSpace: used, freeSpace: free)
    }

    private func calculateStorageBreakdown() async {
        let homeDir = fileManager.homeDirectoryForCurrentUser.path

        // Define directories to scan
        let directories: [(path: String, name: String, color: String)] = [
            ("/Applications", "Applications", "blue"),
            ("\(homeDir)/Documents", "Documents", "purple"),
            ("\(homeDir)/Downloads", "Downloads", "orange"),
            ("\(homeDir)/Library", "Library", "yellow"),
            ("\(homeDir)/Desktop", "Desktop", "green")
        ]

        // Calculate all in parallel using TaskGroup
        var breakdown: [StorageBreakdown] = []

        await withTaskGroup(of: StorageBreakdown?.self) { group in
            for (path, name, color) in directories {
                group.addTask {
                    let size = await self.calculateDirectorySize(path)
                    if size > 0 {
                        return StorageBreakdown(name: name, size: size, color: color)
                    }
                    return nil
                }
            }

            for await result in group {
                if let item = result {
                    breakdown.append(item)
                }
            }
        }

        storageBreakdown = breakdown.sorted { $0.size > $1.size }
    }

    func calculateDirectorySize(_ path: String) async -> Int64 {
        let pathCopy = path
        return await Task.detached(priority: .userInitiated) {
            Self.calculateDirectorySizeSync(pathCopy)
        }.value
    }

    nonisolated private static func calculateDirectorySizeSync(_ path: String) -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == false {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                Self.logger.debug("Cannot read size for \(fileURL.path): \(error.localizedDescription)")
                continue
            }
        }

        return totalSize
    }

    func getFolderSize(at path: String) async -> Int64 {
        return await calculateDirectorySize(path)
    }

    func checkFullDiskAccess() -> Bool {
        let testPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mail").path
        return fileManager.isReadableFile(atPath: testPath)
    }

    /// Returns available disk space in bytes, or nil if unable to determine
    nonisolated func getAvailableSpace() -> Int64? {
        let volumeURL = URL(fileURLWithPath: "/")
        let resourceKeys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey]

        guard let values = try? volumeURL.resourceValues(forKeys: resourceKeys),
              let available = values.volumeAvailableCapacityForImportantUsage else {
            return nil
        }
        return available
    }

    /// Checks if disk space is critically low (less than threshold bytes)
    /// Default threshold is 100MB
    nonisolated func isDiskSpaceCriticallyLow(threshold: Int64 = 100 * 1024 * 1024) -> Bool {
        guard let available = getAvailableSpace() else { return false }
        return available < threshold
    }
}

enum DiskSpaceError: Error, LocalizedError {
    case unableToReadDiskSpace
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .unableToReadDiskSpace:
            return "Unable to read disk space information"
        case .accessDenied:
            return "Access denied. Please grant Full Disk Access in System Settings."
        }
    }
}
