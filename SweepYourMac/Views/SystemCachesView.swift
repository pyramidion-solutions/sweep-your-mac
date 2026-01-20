import SwiftUI

struct SystemCachesView: View {
    @EnvironmentObject private var viewModelStore: ViewModelStore

    var body: some View {
        SystemCachesContent(viewModel: viewModelStore.systemCachesViewModel)
    }
}

private struct SystemCachesContent: View {
    @ObservedObject var viewModel: SystemCachesViewModel
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
            case .completed(let result):
                resultsView(result: result)
            case .cancelled:
                cancelledView
            case .error(let message):
                errorView(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("System Caches")
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Caches")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Temporary files created by macOS and applications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if case .completed(let result) = viewModel.scanState {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.formattedTotalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("\(result.items.count) items found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            scanButton
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

    // MARK: - Idle View
    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "internaldrive")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Click Scan to find system caches")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Scans ~/Library/Caches, /Library/Caches, and /System/Library/Caches")
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
            Button("Cancel") {
                viewModel.cancelScan()
            }
            .buttonStyle(.bordered)
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
    private func resultsView(result: CategoryScanResult) -> some View {
        VStack(spacing: 0) {
            // Selection bar
            selectionBar(result: result)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Items list
            List {
                ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                    CacheItemRow(
                        item: item,
                        isSelected: viewModel.selectedItems.contains(item.id),
                        onToggle: { viewModel.toggleSelection(item) }
                    )
                }
            }
            .listStyle(.inset)

            Divider()

            // Action bar
            actionBar(result: result)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
        }
        .alert("Clean Selected Caches?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task {
                    await viewModel.performDelete()
                }
            }
        } message: {
            Text("This will permanently delete \(viewModel.selectedItems.count) cache folder(s) totaling \(viewModel.selectedSize.formattedBytes). Caches will be rebuilt automatically when needed, but this action cannot be undone.")
        }
        .alert("Cleanup Complete", isPresented: $viewModel.showDeletionResult) {
            Button("OK") {
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        } message: {
            Text("Successfully freed \(viewModel.lastFreedSpace.formattedBytes) by cleaning \(viewModel.lastDeletedCount) item(s).")
        }
        .alert("Disk Space Critically Low", isPresented: $viewModel.showDiskFullAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your disk has less than 100 MB of free space. Please free up some space before scanning to ensure stable operation.")
        }
    }

    private func selectionBar(result: CategoryScanResult) -> some View {
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

            Button(action: { viewModel.selectSafe() }) {
                Text("Select Safe Only")
                    .font(.caption)
            }
            .buttonStyle(.link)

            Spacer()

            Text("Scanned in \(String(format: "%.1f", result.scanDuration))s")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func actionBar(result: CategoryScanResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected: \(viewModel.selectedItems.count) items")
                    .font(.subheadline)
                Text(viewModel.selectedSize.formattedBytes)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
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
                    Text("Clean Selected")
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

// MARK: - Cache Item Row
struct CacheItemRow: View {
    let item: ScanResult
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            if !item.isReadOnly {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }

            // Icon
            Image(systemName: item.isReadOnly ? "folder.badge.minus" : "folder.fill")
                .foregroundColor(safetyColor)
                .font(.title3)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    SafetyBadge(level: item.safetyLevel)

                    if item.isReadOnly {
                        Text("Read Only")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(3)
                    }
                }

                HStack(spacing: 12) {
                    Text(item.path)
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

                HStack(spacing: 8) {
                    Text("\(item.itemCount) files")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(item.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

    private var safetyColor: Color {
        switch item.safetyLevel {
        case .safe: return .green
        case .caution: return .orange
        case .risky: return .red
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.path)
    }
}

// MARK: - View Model
@MainActor
class SystemCachesViewModel: ObservableObject {
    @Published var scanState: ScanState = .idle
    @Published var selectedItems: Set<UUID> = []
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published var showDeletionResult = false
    @Published var showDiskFullAlert = false
    @Published var lastFreedSpace: Int64 = 0
    @Published var lastDeletedCount: Int = 0

    private let scanner = SystemCachesScanner()
    private var scanResults: [ScanResult] = []
    private var currentScanTask: Task<Void, Never>?

    var selectedSize: Int64 {
        scanResults
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    /// Scan timeout of 5 minutes
    private static let scanTimeoutNanoseconds: UInt64 = 5 * 60 * 1_000_000_000

    func scan() async {
        // Check for critically low disk space before scanning
        if DiskSpaceManager().isDiskSpaceCriticallyLow() {
            showDiskFullAlert = true
            return
        }

        // Cancel any existing scan
        currentScanTask?.cancel()

        scanState = .scanning(progress: "Starting scan...")

        currentScanTask = Task {
            // Run scan with timeout
            let scanResult: CategoryScanResult? = await withTaskGroup(of: CategoryScanResult?.self) { group in
                // Scan task
                group.addTask {
                    return await self.scanner.scan { [weak self] progress in
                        Task { @MainActor in
                            guard let self = self, !Task.isCancelled else { return }
                            self.scanState = .scanning(progress: progress)
                        }
                    }
                }

                // Timeout task
                group.addTask {
                    try? await Task.sleep(nanoseconds: Self.scanTimeoutNanoseconds)
                    return nil // Signals timeout
                }

                // Return first completed result
                if let firstResult = await group.next() {
                    group.cancelAll()
                    return firstResult
                }
                return nil
            }

            // Check if cancelled
            guard !Task.isCancelled else {
                await MainActor.run {
                    self.scanState = .cancelled
                }
                return
            }

            // Check for timeout (nil result)
            guard let result = scanResult else {
                await MainActor.run {
                    self.scanState = .error("Scan timed out after 5 minutes. Try scanning a smaller category or cancel unresponsive scans.")
                }
                return
            }

            scanResults = result.items

            // Pre-select safe, non-read-only items
            selectedItems = Set(result.items.filter { !$0.isReadOnly && $0.safetyLevel == .safe }.map { $0.id })

            scanState = .completed(result)
        }

        await currentScanTask?.value
    }

    func cancelScan() {
        currentScanTask?.cancel()
        scanState = .cancelled
    }

    func toggleSelection(_ item: ScanResult) {
        guard !item.isReadOnly else { return }
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    func selectAll() {
        selectedItems = Set(scanResults.filter { !$0.isReadOnly }.map { $0.id })
    }

    func selectNone() {
        selectedItems.removeAll()
    }

    func selectSafe() {
        selectedItems = Set(scanResults.filter { !$0.isReadOnly && $0.safetyLevel == .safe }.map { $0.id })
    }

    func performDelete() async {
        isDeleting = true

        let itemsToDelete = scanResults.filter { selectedItems.contains($0.id) }
        let (deleted, failed, freedSpace) = await scanner.deleteItems(itemsToDelete)

        isDeleting = false

        // Show result and rescan
        if deleted > 0 {
            lastFreedSpace = freedSpace
            lastDeletedCount = deleted
            showDeletionResult = true
            await scan()
        }
    }
}

#Preview {
    SystemCachesView()
        .frame(width: 800, height: 600)
        .environmentObject(ViewModelStore())
        .environmentObject(DiskSpaceManager())
}
