import Foundation
import AppKit

actor TrashScanner {
    private let fileManager = FileManager.default

    struct TrashItem: Identifiable {
        let id = UUID()
        let url: URL
        let name: String
        let size: Int64
        let itemCount: Int
        let dateDeleted: Date?
        let originalPath: String?
        let isDirectory: Bool
        let fileType: FileType

        enum FileType: String {
            case folder = "Folder"
            case image = "Image"
            case video = "Video"
            case audio = "Audio"
            case document = "Document"
            case archive = "Archive"
            case application = "Application"
            case code = "Code"
            case other = "Other"

            var icon: String {
                switch self {
                case .folder: return "folder.fill"
                case .image: return "photo.fill"
                case .video: return "film.fill"
                case .audio: return "music.note"
                case .document: return "doc.fill"
                case .archive: return "doc.zipper"
                case .application: return "app.fill"
                case .code: return "chevron.left.forwardslash.chevron.right"
                case .other: return "doc"
                }
            }

            var color: String {
                switch self {
                case .folder: return "blue"
                case .image: return "green"
                case .video: return "purple"
                case .audio: return "pink"
                case .document: return "orange"
                case .archive: return "yellow"
                case .application: return "red"
                case .code: return "cyan"
                case .other: return "gray"
                }
            }
        }

        var formattedSize: String {
            size.formattedBytes
        }

        var formattedDate: String {
            guard let date = dateDeleted else { return "Unknown" }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }
    }

    struct TrashSummary {
        let items: [TrashItem]
        let totalSize: Int64
        let totalItems: Int
        let totalFiles: Int
        let scanDuration: TimeInterval

        var formattedTotalSize: String {
            totalSize.formattedBytes
        }

        var byType: [TrashItem.FileType: [TrashItem]] {
            Dictionary(grouping: items, by: { $0.fileType })
        }

        var typeBreakdown: [(type: TrashItem.FileType, size: Int64, count: Int)] {
            byType.map { (type: $0.key, size: $0.value.reduce(0) { $0 + $1.size }, count: $0.value.count) }
                .sorted { $0.size > $1.size }
        }
    }

    private var trashURL: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
    }

    func scan(progressHandler: @escaping (String) -> Void) async -> TrashSummary {
        let startTime = Date()
        var items: [TrashItem] = []
        var totalFiles = 0

        await MainActor.run {
            progressHandler("Scanning Trash...")
        }

        guard fileManager.fileExists(atPath: trashURL.path) else {
            return TrashSummary(items: [], totalSize: 0, totalItems: 0, totalFiles: 0, scanDuration: 0)
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: trashURL,
                includingPropertiesForKeys: [
                    .fileSizeKey,
                    .isDirectoryKey,
                    .contentModificationDateKey,
                    .totalFileSizeKey,
                    .totalFileAllocatedSizeKey
                ],
                options: []
            )

            for (index, itemURL) in contents.enumerated() {
                if index % 10 == 0 {
                    await MainActor.run {
                        progressHandler("Scanning item \(index + 1) of \(contents.count)...")
                    }
                }

                let resourceValues = try? itemURL.resourceValues(forKeys: [
                    .isDirectoryKey,
                    .contentModificationDateKey
                ])

                let isDirectory = resourceValues?.isDirectory ?? false
                let dateDeleted = resourceValues?.contentModificationDate

                let size: Int64
                let itemCount: Int

                if isDirectory {
                    (size, itemCount) = await calculateDirectoryStats(at: itemURL.path)
                    totalFiles += itemCount
                } else {
                    size = await calculateSize(at: itemURL.path)
                    itemCount = 1
                    totalFiles += 1
                }

                let fileType = determineFileType(for: itemURL, isDirectory: isDirectory)
                let originalPath = getOriginalPath(for: itemURL)

                let item = TrashItem(
                    url: itemURL,
                    name: itemURL.lastPathComponent,
                    size: size,
                    itemCount: itemCount,
                    dateDeleted: dateDeleted,
                    originalPath: originalPath,
                    isDirectory: isDirectory,
                    fileType: fileType
                )

                items.append(item)
            }
        } catch {
            AppLogger.scanner.error("Failed to scan Trash contents: \(error.localizedDescription)")
        }

        // Sort by size descending
        items.sort { $0.size > $1.size }

        let totalSize = items.reduce(0) { $0 + $1.size }
        let duration = Date().timeIntervalSince(startTime)

        return TrashSummary(
            items: items,
            totalSize: totalSize,
            totalItems: items.count,
            totalFiles: totalFiles,
            scanDuration: duration
        )
    }

    private func calculateDirectoryStats(at path: String) async -> (size: Int64, count: Int) {
        var totalSize: Int64 = 0
        var fileCount = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return (0, 0)
        }

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) {
                if values.isDirectory == false {
                    totalSize += Int64(values.fileSize ?? 0)
                    fileCount += 1
                }
            }
        }

        return (totalSize, fileCount)
    }

    private func calculateSize(at path: String) async -> Int64 {
        if let attrs = try? fileManager.attributesOfItem(atPath: path),
           let size = attrs[.size] as? Int64 {
            return size
        }
        return 0
    }

    private func determineFileType(for url: URL, isDirectory: Bool) -> TrashItem.FileType {
        if isDirectory {
            // Check if it's an app bundle
            if url.pathExtension.lowercased() == "app" {
                return .application
            }
            return .folder
        }

        let ext = url.pathExtension.lowercased()

        // Images
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "svg", "ico", "raw", "cr2", "nef"]
        if imageExtensions.contains(ext) { return .image }

        // Videos
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "3gp"]
        if videoExtensions.contains(ext) { return .video }

        // Audio
        let audioExtensions = ["mp3", "wav", "aac", "flac", "m4a", "wma", "ogg", "aiff", "alac"]
        if audioExtensions.contains(ext) { return .audio }

        // Documents
        let documentExtensions = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "odt", "ods", "odp", "pages", "numbers", "keynote", "md", "epub"]
        if documentExtensions.contains(ext) { return .document }

        // Archives
        let archiveExtensions = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso", "pkg"]
        if archiveExtensions.contains(ext) { return .archive }

        // Code
        let codeExtensions = ["swift", "m", "h", "c", "cpp", "java", "py", "js", "ts", "html", "css", "json", "xml", "yaml", "yml", "rb", "php", "go", "rs", "kt", "scala", "sh", "bash", "zsh"]
        if codeExtensions.contains(ext) { return .code }

        // Applications
        if ext == "app" { return .application }

        return .other
    }

    private func getOriginalPath(for url: URL) -> String? {
        // Try to get the original path from extended attributes or .DS_Store
        // This is a simplified version - macOS stores this info in .Trashes metadata
        return nil
    }

    func emptyTrash() async -> (success: Bool, freedSpace: Int64, error: String?) {
        let summary = await scan { _ in }
        let totalSize = summary.totalSize
        let trashPath = trashURL

        do {
            // Manually delete contents of trash
            let contents = try fileManager.contentsOfDirectory(at: trashPath, includingPropertiesForKeys: nil)
            for item in contents {
                try fileManager.removeItem(at: item)
            }

            return (true, totalSize, nil)
        } catch {
            return (false, 0, error.localizedDescription)
        }
    }

    func deleteItems(_ items: [TrashItem]) async -> (deleted: Int, failed: Int, freedSpace: Int64) {
        let safeOps = SafeFileOperations()
        let home = fileManager.homeDirectoryForCurrentUser.path

        // Trash items are only in the user's Trash folder - this is a safe location
        let allowedRoots = [
            "\(home)/.Trash"
        ]

        var deleted = 0
        var failed = 0
        var freedSpace: Int64 = 0

        for item in items {
            // Items in Trash are inherently safe to delete permanently
            // But we still validate to prevent any edge cases
            let options = DeletionOptions(
                checkInUse: false,
                validateSymlinks: true,
                allowedRoots: allowedRoots,
                moveToTrash: false,  // Already in trash, delete permanently
                skipTodaysFiles: false
            )

            let result = await safeOps.deleteItem(at: item.url.path, options: options)
            if result.success {
                freedSpace += item.size
                deleted += 1
            } else {
                failed += 1
            }
        }

        return (deleted, failed, freedSpace)
    }

    func putBack(_ item: TrashItem) async -> Bool {
        // macOS doesn't have a simple API for "put back"
        // This would require reading the original path from .Trashes metadata
        // For now, we'll just reveal in Finder where user can manually put back
        return false
    }

    func getTrashSize() async -> Int64 {
        let summary = await scan { _ in }
        return summary.totalSize
    }
}
