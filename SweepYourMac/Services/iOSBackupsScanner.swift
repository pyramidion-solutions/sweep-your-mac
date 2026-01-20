import Foundation

actor iOSBackupsScanner {
    private let fileManager = FileManager.default

    struct BackupInfo: Identifiable {
        let id = UUID()
        let path: String
        let folderName: String
        let deviceName: String
        let deviceModel: String
        let iOSVersion: String
        let lastBackupDate: Date?
        let size: Int64
        let fileCount: Int
        let isEncrypted: Bool
        let serialNumber: String?
        let productType: String?

        var formattedSize: String {
            size.formattedBytes
        }

        var formattedDate: String {
            guard let date = lastBackupDate else { return "Unknown" }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }

        var relativeDate: String {
            guard let date = lastBackupDate else { return "Unknown" }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }

        var ageInDays: Int {
            guard let date = lastBackupDate else { return 0 }
            return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        }

        var deviceIcon: String {
            let product = (productType ?? "").lowercased()
            if product.contains("ipad") { return "ipad" }
            if product.contains("ipod") { return "ipod" }
            return "iphone"
        }

        var displayModel: String {
            if !deviceModel.isEmpty && deviceModel != "Unknown" {
                return deviceModel
            }
            return productTypeToModel(productType ?? "")
        }
    }

    struct BackupsSummary {
        let backups: [BackupInfo]
        let totalSize: Int64
        let totalFiles: Int
        let scanDuration: TimeInterval

        var formattedTotalSize: String {
            totalSize.formattedBytes
        }

        var oldBackupsSize: Int64 {
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            return backups.filter { ($0.lastBackupDate ?? Date()) < thirtyDaysAgo }
                .reduce(0) { $0 + $1.size }
        }

        var deviceBreakdown: [(device: String, count: Int, size: Int64)] {
            var breakdown: [String: (count: Int, size: Int64)] = [:]
            for backup in backups {
                let key = backup.deviceName
                let current = breakdown[key] ?? (0, 0)
                breakdown[key] = (current.0 + 1, current.1 + backup.size)
            }
            return breakdown.map { (device: $0.key, count: $0.value.0, size: $0.value.1) }
                .sorted { $0.size > $1.size }
        }
    }

    private var backupsPath: String {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MobileSync/Backup")
            .path
    }

    func scan(progressHandler: @escaping (String) -> Void) async -> BackupsSummary {
        let startTime = Date()
        var backups: [BackupInfo] = []
        var totalFiles = 0

        await MainActor.run {
            progressHandler("Scanning iOS Backups...")
        }

        guard fileManager.fileExists(atPath: backupsPath) else {
            return BackupsSummary(backups: [], totalSize: 0, totalFiles: 0, scanDuration: 0)
        }

        let backupsURL = URL(fileURLWithPath: backupsPath)

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: backupsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for (index, itemURL) in contents.enumerated() {
                let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
                guard resourceValues?.isDirectory == true else { continue }

                await MainActor.run {
                    progressHandler("Scanning backup \(index + 1) of \(contents.count)...")
                }

                if let backupInfo = await parseBackup(at: itemURL) {
                    backups.append(backupInfo)
                    totalFiles += backupInfo.fileCount
                }
            }
        } catch {
            // Handle error silently
        }

        // Sort by date descending (most recent first)
        backups.sort { ($0.lastBackupDate ?? .distantPast) > ($1.lastBackupDate ?? .distantPast) }

        let totalSize = backups.reduce(0) { $0 + $1.size }
        let duration = Date().timeIntervalSince(startTime)

        return BackupsSummary(
            backups: backups,
            totalSize: totalSize,
            totalFiles: totalFiles,
            scanDuration: duration
        )
    }

    private func parseBackup(at url: URL) async -> BackupInfo? {
        let infoPlistURL = url.appendingPathComponent("Info.plist")

        guard fileManager.fileExists(atPath: infoPlistURL.path) else {
            // Not a valid iOS backup folder
            return nil
        }

        var deviceName = "Unknown Device"
        var deviceModel = "Unknown"
        var iOSVersion = "Unknown"
        var lastBackupDate: Date? = nil
        var isEncrypted = false
        var serialNumber: String? = nil
        var productType: String? = nil

        // Parse Info.plist
        if let plistData = try? Data(contentsOf: infoPlistURL),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {

            deviceName = plist["Device Name"] as? String ?? "Unknown Device"
            productType = plist["Product Type"] as? String
            serialNumber = plist["Serial Number"] as? String
            iOSVersion = plist["Product Version"] as? String ?? "Unknown"
            lastBackupDate = plist["Last Backup Date"] as? Date
            isEncrypted = plist["IsEncrypted"] as? Bool ?? false

            // Try to get a friendly model name
            if let productName = plist["Product Name"] as? String {
                deviceModel = productName
            } else if let pt = productType {
                deviceModel = productTypeToModel(pt)
            }
        }

        // Calculate size and file count
        let (size, fileCount) = await calculateDirectoryStats(at: url.path)

        return BackupInfo(
            path: url.path,
            folderName: url.lastPathComponent,
            deviceName: deviceName,
            deviceModel: deviceModel,
            iOSVersion: iOSVersion,
            lastBackupDate: lastBackupDate,
            size: size,
            fileCount: fileCount,
            isEncrypted: isEncrypted,
            serialNumber: serialNumber,
            productType: productType
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

    func deleteBackups(_ backups: [BackupInfo]) async -> (deleted: Int, failed: Int, freedSpace: Int64) {
        let safeOps = SafeFileOperations()
        let home = fileManager.homeDirectoryForCurrentUser.path

        // iOS backups are stored in a specific location
        let allowedRoots = [
            "\(home)/Library/Application Support/MobileSync/Backup"
        ]

        var deleted = 0
        var failed = 0
        var freedSpace: Int64 = 0

        for backup in backups {
            // Validate path is not blocked
            guard !BlockedPathValidator.isBlocked(backup.path) else {
                failed += 1
                continue
            }

            let options = DeletionOptions.withRoots(allowedRoots, checkInUse: false)
            let result = await safeOps.deleteItem(at: backup.path, options: options)

            if result.success {
                freedSpace += backup.size
                deleted += 1
            } else {
                failed += 1
            }
        }

        return (deleted, failed, freedSpace)
    }

    func getBackupsSize() async -> Int64 {
        let summary = await scan { _ in }
        return summary.totalSize
    }
}

// Helper function to convert product type to friendly model name
private func productTypeToModel(_ productType: String) -> String {
    let models: [String: String] = [
        // iPhones
        "iPhone1,1": "iPhone",
        "iPhone1,2": "iPhone 3G",
        "iPhone2,1": "iPhone 3GS",
        "iPhone3,1": "iPhone 4",
        "iPhone3,2": "iPhone 4",
        "iPhone3,3": "iPhone 4",
        "iPhone4,1": "iPhone 4S",
        "iPhone5,1": "iPhone 5",
        "iPhone5,2": "iPhone 5",
        "iPhone5,3": "iPhone 5c",
        "iPhone5,4": "iPhone 5c",
        "iPhone6,1": "iPhone 5s",
        "iPhone6,2": "iPhone 5s",
        "iPhone7,1": "iPhone 6 Plus",
        "iPhone7,2": "iPhone 6",
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE",
        "iPhone9,1": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus",
        "iPhone9,3": "iPhone 7",
        "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",
        "iPhone10,4": "iPhone 8",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd gen)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd gen)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",

        // iPads
        "iPad1,1": "iPad",
        "iPad2,1": "iPad 2",
        "iPad2,2": "iPad 2",
        "iPad2,3": "iPad 2",
        "iPad2,4": "iPad 2",
        "iPad2,5": "iPad mini",
        "iPad2,6": "iPad mini",
        "iPad2,7": "iPad mini",
        "iPad3,1": "iPad (3rd gen)",
        "iPad3,2": "iPad (3rd gen)",
        "iPad3,3": "iPad (3rd gen)",
        "iPad3,4": "iPad (4th gen)",
        "iPad3,5": "iPad (4th gen)",
        "iPad3,6": "iPad (4th gen)",
        "iPad4,1": "iPad Air",
        "iPad4,2": "iPad Air",
        "iPad4,3": "iPad Air",
        "iPad4,4": "iPad mini 2",
        "iPad4,5": "iPad mini 2",
        "iPad4,6": "iPad mini 2",
        "iPad4,7": "iPad mini 3",
        "iPad4,8": "iPad mini 3",
        "iPad4,9": "iPad mini 3",
        "iPad5,1": "iPad mini 4",
        "iPad5,2": "iPad mini 4",
        "iPad5,3": "iPad Air 2",
        "iPad5,4": "iPad Air 2",
        "iPad6,3": "iPad Pro 9.7\"",
        "iPad6,4": "iPad Pro 9.7\"",
        "iPad6,7": "iPad Pro 12.9\"",
        "iPad6,8": "iPad Pro 12.9\"",
        "iPad6,11": "iPad (5th gen)",
        "iPad6,12": "iPad (5th gen)",
        "iPad7,1": "iPad Pro 12.9\" (2nd gen)",
        "iPad7,2": "iPad Pro 12.9\" (2nd gen)",
        "iPad7,3": "iPad Pro 10.5\"",
        "iPad7,4": "iPad Pro 10.5\"",
        "iPad7,5": "iPad (6th gen)",
        "iPad7,6": "iPad (6th gen)",
        "iPad7,11": "iPad (7th gen)",
        "iPad7,12": "iPad (7th gen)",
        "iPad8,1": "iPad Pro 11\"",
        "iPad8,2": "iPad Pro 11\"",
        "iPad8,3": "iPad Pro 11\"",
        "iPad8,4": "iPad Pro 11\"",
        "iPad8,5": "iPad Pro 12.9\" (3rd gen)",
        "iPad8,6": "iPad Pro 12.9\" (3rd gen)",
        "iPad8,7": "iPad Pro 12.9\" (3rd gen)",
        "iPad8,8": "iPad Pro 12.9\" (3rd gen)",
        "iPad11,1": "iPad mini (5th gen)",
        "iPad11,2": "iPad mini (5th gen)",
        "iPad11,3": "iPad Air (3rd gen)",
        "iPad11,4": "iPad Air (3rd gen)",
        "iPad11,6": "iPad (8th gen)",
        "iPad11,7": "iPad (8th gen)",
        "iPad13,1": "iPad Air (4th gen)",
        "iPad13,2": "iPad Air (4th gen)",
        "iPad14,1": "iPad mini (6th gen)",
        "iPad14,2": "iPad mini (6th gen)",

        // iPod touch
        "iPod1,1": "iPod touch",
        "iPod2,1": "iPod touch (2nd gen)",
        "iPod3,1": "iPod touch (3rd gen)",
        "iPod4,1": "iPod touch (4th gen)",
        "iPod5,1": "iPod touch (5th gen)",
        "iPod7,1": "iPod touch (6th gen)",
        "iPod9,1": "iPod touch (7th gen)",
    ]

    return models[productType] ?? productType
}
