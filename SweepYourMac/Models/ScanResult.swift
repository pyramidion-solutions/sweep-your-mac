import Foundation

struct ScanResult: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let itemCount: Int
    let lastModified: Date?
    let safetyLevel: SafetyLevel
    let isReadOnly: Bool
    var isSelected: Bool = true

    var formattedSize: String {
        size.formattedBytes
    }

    var formattedDate: String {
        guard let date = lastModified else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScanResult, rhs: ScanResult) -> Bool {
        lhs.id == rhs.id
    }
}

struct CategoryScanResult {
    let category: ScanCategory
    let items: [ScanResult]
    let totalSize: Int64
    let scanDuration: TimeInterval

    var formattedTotalSize: String {
        totalSize.formattedBytes
    }

    var selectableItems: [ScanResult] {
        items.filter { !$0.isReadOnly }
    }

    var selectedSize: Int64 {
        items.filter { $0.isSelected && !$0.isReadOnly }.reduce(0) { $0 + $1.size }
    }
}

enum ScanState {
    case idle
    case scanning(progress: String)
    case completed(CategoryScanResult)
    case cancelled
    case error(String)

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}
