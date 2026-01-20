import Foundation

actor MailAttachmentsScanner {
    private let fileManager = FileManager.default

    enum AttachmentSource: String, CaseIterable, Identifiable {
        case mailApp = "Mail App"
        case mailDownloads = "Mail Downloads"
        case messages = "Messages"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .mailApp: return "envelope.fill"
            case .mailDownloads: return "arrow.down.circle.fill"
            case .messages: return "message.fill"
            }
        }

        var description: String {
            switch self {
            case .mailApp: return "Attachments embedded in Mail.app"
            case .mailDownloads: return "Downloaded mail attachments"
            case .messages: return "Attachments from Messages.app"
            }
        }

        var color: String {
            switch self {
            case .mailApp: return "blue"
            case .mailDownloads: return "green"
            case .messages: return "purple"
            }
        }
    }

    enum AttachmentType: String, CaseIterable {
        case image = "Images"
        case video = "Videos"
        case audio = "Audio"
        case document = "Documents"
        case archive = "Archives"
        case other = "Other"

        var icon: String {
            switch self {
            case .image: return "photo.fill"
            case .video: return "film.fill"
            case .audio: return "music.note"
            case .document: return "doc.fill"
            case .archive: return "doc.zipper"
            case .other: return "doc"
            }
        }

        var color: String {
            switch self {
            case .image: return "green"
            case .video: return "purple"
            case .audio: return "pink"
            case .document: return "orange"
            case .archive: return "yellow"
            case .other: return "gray"
            }
        }
    }

    struct AttachmentItem: Identifiable {
        let id = UUID()
        let path: String
        let name: String
        let size: Int64
        let source: AttachmentSource
        let type: AttachmentType
        let lastModified: Date?
        let parentFolder: String

        var formattedSize: String {
            size.formattedBytes
        }

        var formattedDate: String {
            guard let date = lastModified else { return "Unknown" }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }

        var ageInDays: Int {
            guard let date = lastModified else { return 0 }
            return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        }
    }

    struct AttachmentsSummary {
        let items: [AttachmentItem]
        let totalSize: Int64
        let totalCount: Int
        let scanDuration: TimeInterval

        var formattedTotalSize: String {
            totalSize.formattedBytes
        }

        var bySource: [AttachmentSource: [AttachmentItem]] {
            Dictionary(grouping: items, by: { $0.source })
        }

        var byType: [AttachmentType: [AttachmentItem]] {
            Dictionary(grouping: items, by: { $0.type })
        }

        var sourceBreakdown: [(source: AttachmentSource, count: Int, size: Int64)] {
            bySource.map { (source: $0.key, count: $0.value.count, size: $0.value.reduce(0) { $0 + $1.size }) }
                .sorted { $0.size > $1.size }
        }

        var typeBreakdown: [(type: AttachmentType, count: Int, size: Int64)] {
            byType.map { (type: $0.key, count: $0.value.count, size: $0.value.reduce(0) { $0 + $1.size }) }
                .sorted { $0.size > $1.size }
        }
    }

    private var homeDirectory: String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    private var scanLocations: [(path: String, source: AttachmentSource)] {
        [
            // Mail Downloads (sandboxed)
            ("\(homeDirectory)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads", .mailDownloads),
            // Legacy Mail Downloads
            ("\(homeDirectory)/Library/Mail Downloads", .mailDownloads),
            // Messages Attachments
            ("\(homeDirectory)/Library/Messages/Attachments", .messages),
            // Mail App data (V9, V10, etc.)
            ("\(homeDirectory)/Library/Mail", .mailApp)
        ]
    }

    func scan(progressHandler: @escaping (String) -> Void) async -> AttachmentsSummary {
        let startTime = Date()
        var allItems: [AttachmentItem] = []

        for location in scanLocations {
            await MainActor.run {
                progressHandler("Scanning \(location.source.rawValue)...")
            }

            guard fileManager.fileExists(atPath: location.path) else { continue }

            if location.source == .mailApp {
                // For Mail app, we need to find attachment folders within mailboxes
                let items = await scanMailAppAttachments(at: location.path)
                allItems.append(contentsOf: items)
            } else {
                let items = await scanDirectory(at: location.path, source: location.source)
                allItems.append(contentsOf: items)
            }
        }

        // Sort by size descending
        allItems.sort { $0.size > $1.size }

        let totalSize = allItems.reduce(0) { $0 + $1.size }
        let duration = Date().timeIntervalSince(startTime)

        return AttachmentsSummary(
            items: allItems,
            totalSize: totalSize,
            totalCount: allItems.count,
            scanDuration: duration
        )
    }

    private func scanMailAppAttachments(at basePath: String) async -> [AttachmentItem] {
        var items: [AttachmentItem] = []

        // Find all "Attachments" folders within Mail data
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: basePath),
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return items
        }

        var attachmentFolders: [URL] = []

        for case let url as URL in enumerator {
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
            if resourceValues?.isDirectory == true && url.lastPathComponent == "Attachments" {
                attachmentFolders.append(url)
            }
        }

        // Now scan each Attachments folder
        for folder in attachmentFolders {
            let folderItems = await scanDirectory(at: folder.path, source: .mailApp)
            items.append(contentsOf: folderItems)
        }

        return items
    }

    private func scanDirectory(at path: String, source: AttachmentSource) async -> [AttachmentItem] {
        var items: [AttachmentItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return items
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])

            // Skip directories
            if resourceValues?.isDirectory == true { continue }

            let size = Int64(resourceValues?.fileSize ?? 0)
            guard size > 0 else { continue }

            let lastModified = resourceValues?.contentModificationDate
            let attachmentType = determineType(for: fileURL)
            let parentFolder = fileURL.deletingLastPathComponent().lastPathComponent

            let item = AttachmentItem(
                path: fileURL.path,
                name: fileURL.lastPathComponent,
                size: size,
                source: source,
                type: attachmentType,
                lastModified: lastModified,
                parentFolder: parentFolder
            )

            items.append(item)
        }

        return items
    }

    private func determineType(for url: URL) -> AttachmentType {
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
        let documentExtensions = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "odt", "ods", "odp", "pages", "numbers", "keynote", "md", "epub", "csv"]
        if documentExtensions.contains(ext) { return .document }

        // Archives
        let archiveExtensions = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso", "pkg"]
        if archiveExtensions.contains(ext) { return .archive }

        return .other
    }

    func deleteItems(_ items: [AttachmentItem], moveToTrash: Bool = true) async -> (deleted: Int, failed: Int, freedSpace: Int64) {
        let safeOps = SafeFileOperations()
        let home = fileManager.homeDirectoryForCurrentUser.path

        // Mail attachments are in specific Library locations
        let allowedRoots = [
            "\(home)/Library/Mail",
            "\(home)/Library/Containers/com.apple.mail",
            "\(home)/Library/Messages",
            "\(home)/Library/Mail Downloads"
        ]

        var deleted = 0
        var failed = 0
        var freedSpace: Int64 = 0

        for item in items {
            // Validate path is not blocked
            guard !BlockedPathValidator.isBlocked(item.path) else {
                failed += 1
                continue
            }

            let options = DeletionOptions(
                checkInUse: false,
                validateSymlinks: true,
                allowedRoots: allowedRoots,
                moveToTrash: moveToTrash,
                skipTodaysFiles: false
            )

            let result = await safeOps.deleteItem(at: item.path, options: options)
            if result.success {
                freedSpace += item.size
                deleted += 1
            } else {
                failed += 1
            }
        }

        return (deleted, failed, freedSpace)
    }

    func getAttachmentsSize() async -> Int64 {
        let summary = await scan { _ in }
        return summary.totalSize
    }
}
