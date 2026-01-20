import Foundation

struct DiskSpace {
    let totalSpace: Int64
    let usedSpace: Int64
    let freeSpace: Int64

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }

    var freePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(freeSpace) / Double(totalSpace) * 100
    }

    static var empty: DiskSpace {
        DiskSpace(totalSpace: 0, usedSpace: 0, freeSpace: 0)
    }
}

struct StorageBreakdown: Identifiable {
    let id = UUID()
    let name: String
    let size: Int64
    let color: String
}

extension Int64 {
    var formattedBytes: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        return formatter.string(fromByteCount: self)
    }
}
