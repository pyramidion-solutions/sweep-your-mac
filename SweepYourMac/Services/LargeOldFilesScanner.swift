import Foundation

actor LargeOldFilesScanner {
    private let fileManager = FileManager.default

    enum FileCategory: String, CaseIterable, Identifiable {
        case downloads = "Downloads"
        case documents = "Documents"
        case desktop = "Desktop"
        case movies = "Movies"
        case music = "Music"
        case pictures = "Pictures"
        case other = "Other"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .downloads: return "arrow.down.circle.fill"
            case .documents: return "doc.fill"
            case .desktop: return "menubar.dock.rectangle"
            case .movies: return "film.fill"
            case .music: return "music.note"
            case .pictures: return "photo.fill"
            case .other: return "folder.fill"
            }
        }

        var color: String {
            switch self {
            case .downloads: return "blue"
            case .documents: return "orange"
            case .desktop: return "purple"
            case .movies: return "red"
            case .music: return "pink"
            case .pictures: return "green"
            case .other: return "gray"
            }
        }
    }

    enum FileType: String, CaseIterable {
        case video = "Videos"
        case image = "Images"
        case audio = "Audio"
        case archive = "Archives"
        case document = "Documents"
        case application = "Applications"
        case diskImage = "Disk Images"
        case other = "Other"

        var icon: String {
            switch self {
            case .video: return "film.fill"
            case .image: return "photo.fill"
            case .audio: return "music.note"
            case .archive: return "doc.zipper"
            case .document: return "doc.fill"
            case .application: return "app.fill"
            case .diskImage: return "opticaldiscdrive.fill"
            case .other: return "doc"
            }
        }

        var color: String {
            switch self {
            case .video: return "purple"
            case .image: return "green"
            case .audio: return "pink"
            case .archive: return "yellow"
            case .document: return "orange"
            case .application: return "red"
            case .diskImage: return "blue"
            case .other: return "gray"
            }
        }
    }

    struct LargeOldFile: Identifiable {
        let id = UUID()
        let path: String
        let name: String
        let size: Int64
        let category: FileCategory
        let fileType: FileType
        let lastAccessed: Date?
        let lastModified: Date?
        let creationDate: Date?

        var formattedSize: String {
            size.formattedBytes
        }

        var formattedLastAccessed: String {
            guard let date = lastAccessed else { return "Unknown" }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }

        var formattedLastModified: String {
            guard let date = lastModified else { return "Unknown" }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }

        var daysSinceAccessed: Int {
            guard let date = lastAccessed else { return 0 }
            return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        }

        var daysSinceModified: Int {
            guard let date = lastModified else { return 0 }
            return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        }

        var isLarge: Bool {
            size >= 100_000_000 // 100MB
        }

        var isVeryLarge: Bool {
            size >= 500_000_000 // 500MB
        }

        var isOld: Bool {
            daysSinceAccessed >= 180 // 6 months
        }

        var isVeryOld: Bool {
            daysSinceAccessed >= 365 // 1 year
        }
    }

    struct ScanResult {
        let files: [LargeOldFile]
        let totalSize: Int64
        let totalCount: Int
        let scanDuration: TimeInterval

        var formattedTotalSize: String {
            totalSize.formattedBytes
        }

        var byCategory: [FileCategory: [LargeOldFile]] {
            Dictionary(grouping: files, by: { $0.category })
        }

        var byType: [FileType: [LargeOldFile]] {
            Dictionary(grouping: files, by: { $0.fileType })
        }

        var categoryBreakdown: [(category: FileCategory, count: Int, size: Int64)] {
            byCategory.map { (category: $0.key, count: $0.value.count, size: $0.value.reduce(0) { $0 + $1.size }) }
                .sorted { $0.size > $1.size }
        }

        var typeBreakdown: [(type: FileType, count: Int, size: Int64)] {
            byType.map { (type: $0.key, count: $0.value.count, size: $0.value.reduce(0) { $0 + $1.size }) }
                .sorted { $0.size > $1.size }
        }

        var largeFilesSize: Int64 {
            files.filter { $0.isLarge }.reduce(0) { $0 + $1.size }
        }

        var oldFilesSize: Int64 {
            files.filter { $0.isOld }.reduce(0) { $0 + $1.size }
        }

        var veryOldFilesSize: Int64 {
            files.filter { $0.isVeryOld }.reduce(0) { $0 + $1.size }
        }
    }

    struct ScanOptions {
        var minSize: Int64 = 50_000_000 // 50MB default
        var minAge: Int = 90 // 90 days default
        var includeDownloads: Bool = true
        var includeDocuments: Bool = true
        var includeDesktop: Bool = true
        var includeMovies: Bool = true
        var includeMusic: Bool = true
        var includePictures: Bool = true
    }

    private var homeDirectory: String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    private func getScanPaths(options: ScanOptions) -> [(path: String, category: FileCategory)] {
        var paths: [(String, FileCategory)] = []

        if options.includeDownloads {
            paths.append(("\(homeDirectory)/Downloads", .downloads))
        }
        if options.includeDocuments {
            paths.append(("\(homeDirectory)/Documents", .documents))
        }
        if options.includeDesktop {
            paths.append(("\(homeDirectory)/Desktop", .desktop))
        }
        if options.includeMovies {
            paths.append(("\(homeDirectory)/Movies", .movies))
        }
        if options.includeMusic {
            paths.append(("\(homeDirectory)/Music", .music))
        }
        if options.includePictures {
            paths.append(("\(homeDirectory)/Pictures", .pictures))
        }

        return paths
    }

    func scan(options: ScanOptions = ScanOptions(), progressHandler: @escaping (String) -> Void) async -> ScanResult {
        let startTime = Date()
        var allFiles: [LargeOldFile] = []

        let paths = getScanPaths(options: options)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -options.minAge, to: Date()) ?? Date()

        for (path, category) in paths {
            await MainActor.run {
                progressHandler("Scanning \(category.rawValue)...")
            }

            guard fileManager.fileExists(atPath: path) else { continue }

            let files = await scanDirectory(
                at: path,
                category: category,
                minSize: options.minSize,
                cutoffDate: cutoffDate
            )
            allFiles.append(contentsOf: files)
        }

        // Sort by size descending
        allFiles.sort { $0.size > $1.size }

        let totalSize = allFiles.reduce(0) { $0 + $1.size }
        let duration = Date().timeIntervalSince(startTime)

        return ScanResult(
            files: allFiles,
            totalSize: totalSize,
            totalCount: allFiles.count,
            scanDuration: duration
        )
    }

    private func scanDirectory(
        at path: String,
        category: FileCategory,
        minSize: Int64,
        cutoffDate: Date
    ) async -> [LargeOldFile] {
        var files: [LargeOldFile] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentAccessDateKey,
                .contentModificationDateKey,
                .creationDateKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return files
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentAccessDateKey,
                .contentModificationDateKey,
                .creationDateKey
            ])

            // Skip directories
            if resourceValues?.isDirectory == true { continue }

            let size = Int64(resourceValues?.fileSize ?? 0)
            let lastAccessed = resourceValues?.contentAccessDate
            let lastModified = resourceValues?.contentModificationDate
            let creationDate = resourceValues?.creationDate

            // Check if file meets criteria (large OR old)
            let isLarge = size >= minSize
            let isOld = (lastAccessed ?? Date()) < cutoffDate

            guard isLarge || isOld else { continue }

            let fileType = determineFileType(for: fileURL)

            let file = LargeOldFile(
                path: fileURL.path,
                name: fileURL.lastPathComponent,
                size: size,
                category: category,
                fileType: fileType,
                lastAccessed: lastAccessed,
                lastModified: lastModified,
                creationDate: creationDate
            )

            files.append(file)
        }

        return files
    }

    private func determineFileType(for url: URL) -> FileType {
        let ext = url.pathExtension.lowercased()

        // Videos
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "3gp", "ts", "mts"]
        if videoExtensions.contains(ext) { return .video }

        // Images
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "svg", "raw", "cr2", "nef", "psd", "ai"]
        if imageExtensions.contains(ext) { return .image }

        // Audio
        let audioExtensions = ["mp3", "wav", "aac", "flac", "m4a", "wma", "ogg", "aiff", "alac"]
        if audioExtensions.contains(ext) { return .audio }

        // Archives
        let archiveExtensions = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "pkg"]
        if archiveExtensions.contains(ext) { return .archive }

        // Disk Images
        let diskImageExtensions = ["dmg", "iso", "img", "sparseimage", "sparsebundle"]
        if diskImageExtensions.contains(ext) { return .diskImage }

        // Applications
        if ext == "app" { return .application }

        // Documents
        let documentExtensions = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "odt", "ods", "odp", "pages", "numbers", "keynote", "md", "epub", "csv"]
        if documentExtensions.contains(ext) { return .document }

        return .other
    }

    func deleteFiles(_ files: [LargeOldFile], moveToTrash: Bool = true) async -> (deleted: Int, failed: Int, freedSpace: Int64) {
        let safeOps = SafeFileOperations()
        let home = fileManager.homeDirectoryForCurrentUser.path

        // Large old files are typically in user directories
        let allowedRoots = [
            "\(home)/Downloads",
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Movies",
            "\(home)/Music",
            "\(home)/Pictures",
            "\(home)/Library"
        ]

        var deleted = 0
        var failed = 0
        var freedSpace: Int64 = 0

        for file in files {
            // Validate path is not blocked
            guard !BlockedPathValidator.isBlocked(file.path) else {
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

            let result = await safeOps.deleteItem(at: file.path, options: options)
            if result.success {
                freedSpace += file.size
                deleted += 1
            } else {
                failed += 1
            }
        }

        return (deleted, failed, freedSpace)
    }
}
