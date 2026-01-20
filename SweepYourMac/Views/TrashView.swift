import SwiftUI

struct TrashView: View {
    @EnvironmentObject private var viewModelStore: ViewModelStore

    var body: some View {
        TrashContent(viewModel: viewModelStore.trashViewModel)
    }
}

private struct TrashContent: View {
    @ObservedObject var viewModel: TrashViewModel
    @EnvironmentObject private var diskSpaceManager: DiskSpaceManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            switch viewModel.scanState {
            case .idle:
                idleView
            case .scanning(let progress):
                scanningView(progress: progress)
            case .completed:
                if let summary = viewModel.trashSummary {
                    resultsView(summary: summary)
                } else {
                    idleView
                }
            case .cancelled:
                cancelledView
            case .error(let message):
                errorView(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Trash")
        .alert("Empty Trash", isPresented: $viewModel.showEmptyConfirmation) {
            Button("Empty Trash", role: .destructive) {
                Task {
                    await viewModel.emptyTrash()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete all items in the Trash?\n\nThis will free up \(viewModel.trashSummary?.formattedTotalSize ?? "0 bytes").\n\nThis action cannot be undone.")
        }
        .alert("Delete Selected", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSelected()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete \(viewModel.selectedItems.count) selected items?\n\nThis action cannot be undone.")
        }
        .alert("Deletion Error", isPresented: Binding(
            get: { viewModel.deletionError != nil },
            set: { if !$0 { viewModel.deletionError = nil } }
        )) {
            Button("OK") { viewModel.deletionError = nil }
        } message: {
            Text(viewModel.deletionError ?? "")
        }
        .alert("Cleanup Complete", isPresented: $viewModel.showDeletionResult) {
            Button("OK") {
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        } message: {
            if viewModel.lastDeletedCount > 0 {
                Text("Successfully freed \(viewModel.lastFreedSpace.formattedBytes) by removing \(viewModel.lastDeletedCount) item(s) from Trash.")
            } else {
                Text("Successfully freed \(viewModel.lastFreedSpace.formattedBytes) by emptying Trash.")
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trash")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Files waiting to be permanently deleted")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let summary = viewModel.trashSummary {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(summary.formattedTotalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("\(summary.totalItems) items (\(summary.totalFiles) files)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                scanButton

                if viewModel.trashSummary != nil && viewModel.trashSummary!.totalItems > 0 {
                    emptyTrashButton
                }
            }
        }
    }

    private var scanButton: some View {
        Button(action: {
            Task {
                await viewModel.scan()
            }
        }) {
            HStack(spacing: 6) {
                if viewModel.scanState.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: "magnifyingglass")
                }
                Text(viewModel.scanState.isScanning ? "Scanning..." : "Scan")
            }
            .frame(width: 100)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.scanState.isScanning)
    }

    private var emptyTrashButton: some View {
        Button(action: {
            viewModel.showEmptyConfirmation = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "trash.slash")
                Text("Empty Trash")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(viewModel.scanState.isScanning || viewModel.isDeleting)
    }

    // MARK: - Idle View
    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Click Scan to view Trash contents")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("See what's taking up space in your Trash")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scanning View
    private func scanningView(progress: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(progress)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cancelled View
    private var cancelledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Scan Cancelled")
                .font(.headline)
            Text("The scan was stopped before completion")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Scan Again") {
                Task {
                    await viewModel.scan()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results View
    private func resultsView(summary: TrashScanner.TrashSummary) -> some View {
        VStack(spacing: 0) {
            if summary.items.isEmpty {
                emptyTrashView
            } else {
                // Type breakdown
                typeBreakdownView(summary: summary)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()

                // Selection bar
                selectionBar(summary: summary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                Divider()

                // Items list
                List {
                    ForEach(summary.items, id: \.id) { item in
                        TrashItemRow(
                            item: item,
                            isSelected: viewModel.selectedItems.contains(item.id),
                            onToggle: { viewModel.toggleSelection(item) }
                        )
                    }
                }
                .listStyle(.inset)

                Divider()

                // Action bar
                actionBar
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }

    private var emptyTrashView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("Trash is Empty")
                .font(.headline)
            Text("No files waiting to be deleted")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func typeBreakdownView(summary: TrashScanner.TrashSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content Breakdown")
                .font(.headline)

            // Stacked bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(summary.typeBreakdown, id: \.type) { item in
                        let width = max(
                            CGFloat(item.size) / CGFloat(summary.totalSize) * geometry.size.width,
                            4
                        )
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorForType(item.type))
                            .frame(width: width)
                    }
                }
            }
            .frame(height: 20)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(6)

            // Legend
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(summary.typeBreakdown.prefix(8), id: \.type) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colorForType(item.type))
                            .frame(width: 8, height: 8)
                        Image(systemName: item.type.icon)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(item.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(item.size.formattedBytes)
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func colorForType(_ type: TrashScanner.TrashItem.FileType) -> Color {
        switch type.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "yellow": return .yellow
        case "red": return .red
        case "cyan": return .cyan
        default: return .gray
        }
    }

    private func selectionBar(summary: TrashScanner.TrashSummary) -> some View {
        HStack {
            Button(action: { viewModel.selectAll() }) {
                Text("Select All")
                    .font(.caption)
            }
            .buttonStyle(.link)

            Button(action: { viewModel.selectNone() }) {
                Text("Select None")
                    .font(.caption)
            }
            .buttonStyle(.link)

            Button(action: { viewModel.selectLargest() }) {
                Text("Select Largest")
                    .font(.caption)
            }
            .buttonStyle(.link)

            Spacer()

            Text("Scanned in \(String(format: "%.1f", summary.scanDuration))s")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var actionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected: \(viewModel.selectedItems.count) items")
                    .font(.subheadline)
                Text(viewModel.selectedSize.formattedBytes)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }

            Spacer()

            if viewModel.isDeleting {
                ProgressView()
                    .padding(.trailing, 8)
            }

            Button(action: {
                viewModel.showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Selected")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(viewModel.selectedItems.isEmpty || viewModel.isDeleting)
        }
    }

    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Error")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Try Again") {
                Task {
                    await viewModel.scan()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Trash Item Row
struct TrashItemRow: View {
    let item: TrashScanner.TrashItem
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // File type icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconBackgroundColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: item.fileType.icon)
                    .foregroundColor(iconBackgroundColor)
                    .font(.system(size: 14))
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if item.isDirectory && item.fileType != .application {
                        Text("\(item.itemCount) items")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }

                    Text(item.fileType.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(iconBackgroundColor.opacity(0.1))
                        .foregroundColor(iconBackgroundColor)
                        .cornerRadius(3)
                }

                if let originalPath = item.originalPath {
                    Text("From: \(originalPath)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.formattedSize)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundColor(item.size > 100_000_000 ? .orange : .primary)

                Text("Deleted \(item.formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Reveal in Finder button
            Button(action: { revealInFinder() }) {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var iconBackgroundColor: Color {
        switch item.fileType.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "yellow": return .yellow
        case "red": return .red
        case "cyan": return .cyan
        default: return .gray
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: item.url.deletingLastPathComponent().path)
    }
}

// MARK: - View Model
@MainActor
class TrashViewModel: ObservableObject {
    @Published var scanState: ScanState = .idle
    @Published var trashSummary: TrashScanner.TrashSummary?
    @Published var selectedItems: Set<UUID> = []
    @Published var isDeleting = false
    @Published var showEmptyConfirmation = false
    @Published var showDeleteConfirmation = false
    @Published var deletionError: String?
    @Published var showDeletionResult = false
    @Published var lastFreedSpace: Int64 = 0
    @Published var lastDeletedCount: Int = 0

    private let scanner = TrashScanner()

    var selectedSize: Int64 {
        guard let summary = trashSummary else { return 0 }
        return summary.items
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    func scan() async {
        scanState = .scanning(progress: "Starting scan...")

        let summary = await scanner.scan { [weak self] progress in
            Task { @MainActor in
                self?.scanState = .scanning(progress: progress)
            }
        }

        trashSummary = summary
        selectedItems.removeAll()

        scanState = .completed(CategoryScanResult(
            category: .trash,
            items: [],
            totalSize: summary.totalSize,
            scanDuration: summary.scanDuration
        ))
    }

    func toggleSelection(_ item: TrashScanner.TrashItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    func selectAll() {
        guard let summary = trashSummary else { return }
        selectedItems = Set(summary.items.map { $0.id })
    }

    func selectNone() {
        selectedItems.removeAll()
    }

    func selectLargest() {
        guard let summary = trashSummary else { return }
        // Select items larger than 100MB
        let largeItems = summary.items.filter { $0.size > 100_000_000 }
        if largeItems.isEmpty {
            // If no items > 100MB, select top 10 largest
            selectedItems = Set(summary.items.prefix(10).map { $0.id })
        } else {
            selectedItems = Set(largeItems.map { $0.id })
        }
    }

    func deleteSelected() async {
        guard let summary = trashSummary else { return }

        isDeleting = true
        deletionError = nil

        let itemsToDelete = summary.items.filter { selectedItems.contains($0.id) }
        let result = await scanner.deleteItems(itemsToDelete)

        AppLogger.deletion.info("Trash deletion: \(result.deleted) deleted, \(result.failed) failed, \(result.freedSpace) bytes freed")

        if result.failed > 0 {
            deletionError = "Failed to delete \(result.failed) item(s). They may be in use or protected."
        }

        if result.deleted > 0 {
            lastFreedSpace = result.freedSpace
            lastDeletedCount = result.deleted
            showDeletionResult = true
        }

        isDeleting = false
        await scan()
    }

    func emptyTrash() async {
        isDeleting = true
        deletionError = nil

        let result = await scanner.emptyTrash()

        AppLogger.deletion.info("Empty trash: success=\(result.success), \(result.freedSpace) bytes freed")

        if !result.success {
            deletionError = result.error ?? "Failed to empty trash. Some items may be in use or protected."
        } else if result.freedSpace > 0 {
            lastFreedSpace = result.freedSpace
            lastDeletedCount = 0  // Empty trash doesn't give item count
            showDeletionResult = true
        }

        isDeleting = false
        await scan()
    }
}

#Preview {
    TrashView()
        .frame(width: 800, height: 600)
        .environmentObject(ViewModelStore())
        .environmentObject(DiskSpaceManager())
}
