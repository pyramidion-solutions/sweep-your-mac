import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var viewModelStore: ViewModelStore

    var body: some View {
        LogsContent(viewModel: viewModelStore.logsViewModel)
    }
}

private struct LogsContent: View {
    @ObservedObject var viewModel: LogsViewModel
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
        .navigationTitle("Logs")
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Logs")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("System and application log files")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if case .completed(let result) = viewModel.scanState {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.formattedTotalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("\(result.items.count) log locations")
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
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Click Scan to find log files")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Scans ~/Library/Logs, /Library/Logs, and crash reports")
                .font(.caption)
                .foregroundColor(.secondary)

            // Info box
            VStack(alignment: .leading, spacing: 8) {
                Label("Today's logs will not be deleted", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
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
    private func resultsView(result: CategoryScanResult) -> some View {
        VStack(spacing: 0) {
            // Today's logs warning
            if viewModel.todayLogsCount > 0 {
                todayLogsWarning
            }

            // Category summary
            categorySummaryView
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Selection bar
            selectionBar(result: result)
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Items list grouped by category
            List {
                ForEach(LogsScanner.LogCategory.allCases, id: \.self) { category in
                    if let items = viewModel.groupedByCategory[category], !items.isEmpty {
                        Section {
                            ForEach(items, id: \.id) { item in
                                LogItemRow(
                                    item: item,
                                    isSelected: viewModel.selectedItems.contains(item.id),
                                    onToggle: { viewModel.toggleSelection(item) }
                                )
                            }
                        } header: {
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                                Spacer()
                                Text(items.reduce(0) { $0 + $1.size }.formattedBytes)
                                    .foregroundColor(.secondary)
                            }
                            .font(.headline)
                        }
                    }
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

    private var todayLogsWarning: some View {
        HStack {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundColor(.orange)
            Text("\(viewModel.todayLogsCount) log locations from today will be skipped")
                .font(.caption)
            Spacer()
            Text("Today's logs are protected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
    }

    private var categorySummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log Categories")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(LogsScanner.LogCategory.allCases, id: \.self) { category in
                    if let items = viewModel.groupedByCategory[category], !items.isEmpty {
                        CategorySummaryCard(
                            category: category,
                            itemCount: items.count,
                            totalSize: items.reduce(0) { $0 + $1.size }
                        )
                    }
                }
            }
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

            Button(action: { viewModel.selectOldOnly() }) {
                Text("Select Old Only (>7 days)")
                    .font(.caption)
            }
            .buttonStyle(.link)

            Spacer()

            Text("Scanned in \(String(format: "%.1f", result.scanDuration))s")
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
                    .foregroundColor(.green)
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
        .alert("Clean Selected Logs?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task {
                    await viewModel.performDelete()
                }
            }
        } message: {
            Text("This will permanently delete \(viewModel.selectedItems.count) log location(s) totaling \(viewModel.selectedSize.formattedBytes). Today's logs are protected and will not be affected. This action cannot be undone.")
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

// MARK: - Category Summary Card
struct CategorySummaryCard: View {
    let category: LogsScanner.LogCategory
    let itemCount: Int
    let totalSize: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(categoryColor)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            HStack {
                Text("\(itemCount)")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(totalSize.formattedBytes)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var categoryColor: Color {
        switch category {
        case .userLogs: return .blue
        case .systemLogs: return .orange
        case .crashReports: return .red
        case .diagnosticReports: return .purple
        case .appLogs: return .green
        }
    }
}

// MARK: - Log Item Row
struct LogItemRow: View {
    let item: ScanResult
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            if !item.isReadOnly && !isToday {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: item.isReadOnly ? "lock.fill" : "clock.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }

            // Icon
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title3)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if isToday {
                        Text("Today")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }

                    if item.isReadOnly {
                        Text("System")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.secondary)
                            .cornerRadius(3)
                    }

                    SafetyBadge(level: item.safetyLevel)
                }

                Text(item.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
                        .foregroundColor(isToday ? .orange : .secondary)
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

    private var isToday: Bool {
        guard let date = item.lastModified else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private var iconName: String {
        let name = item.name.lowercased()
        if name.contains("crash") || name.contains("diagnostic") { return "exclamationmark.triangle" }
        if name.contains("error") { return "xmark.circle" }
        return "doc.text"
    }

    private var iconColor: Color {
        let name = item.name.lowercased()
        if name.contains("crash") { return .red }
        if name.contains("diagnostic") { return .purple }
        if name.contains("error") { return .orange }
        return .green
    }

    private func revealInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.path)
    }
}

// MARK: - View Model
@MainActor
class LogsViewModel: ObservableObject {
    @Published var scanState: ScanState = .idle
    @Published var selectedItems: Set<UUID> = []
    @Published var isDeleting = false
    @Published var groupedByCategory: [LogsScanner.LogCategory: [ScanResult]] = [:]
    @Published var todayLogsCount = 0
    @Published var showDeleteConfirmation = false
    @Published var showDeletionResult = false
    @Published var lastFreedSpace: Int64 = 0
    @Published var lastDeletedCount: Int = 0

    private let scanner = LogsScanner()
    private var scanResults: [ScanResult] = []

    var selectedSize: Int64 {
        scanResults
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    func scan() async {
        scanState = .scanning(progress: "Starting scan...")

        let result = await scanner.scan { [weak self] progress in
            Task { @MainActor in
                self?.scanState = .scanning(progress: progress)
            }
        }

        scanResults = result.items
        groupItems()
        countTodayLogs()

        // Pre-select items that are not from today and not read-only
        selectedItems = Set(result.items.filter { item in
            !item.isReadOnly &&
            item.safetyLevel == .safe &&
            !(item.lastModified.map { Calendar.current.isDateInToday($0) } ?? false)
        }.map { $0.id })

        scanState = .completed(result)
    }

    private func groupItems() {
        var groups: [LogsScanner.LogCategory: [ScanResult]] = [:]

        for item in scanResults {
            let category = determineCategory(for: item)
            if groups[category] == nil {
                groups[category] = []
            }
            groups[category]?.append(item)
        }

        groupedByCategory = groups
    }

    private func determineCategory(for item: ScanResult) -> LogsScanner.LogCategory {
        let path = item.path.lowercased()

        if path.contains("diagnosticreport") { return .diagnosticReports }
        if path.contains("crashreporter") || path.contains("crash") { return .crashReports }
        if path.starts(with: "/library/logs") { return .systemLogs }
        if path.contains("application support") { return .appLogs }

        // Check for known app logs
        let appNames = ["homebrew", "spotify", "jetbrains", "google", "adobe", "microsoft", "slack", "discord", "zoom"]
        for app in appNames {
            if path.contains(app) { return .appLogs }
        }

        return .userLogs
    }

    private func countTodayLogs() {
        todayLogsCount = scanResults.filter { item in
            item.lastModified.map { Calendar.current.isDateInToday($0) } ?? false
        }.count
    }

    func toggleSelection(_ item: ScanResult) {
        guard !item.isReadOnly else { return }
        guard !(item.lastModified.map { Calendar.current.isDateInToday($0) } ?? false) else { return }

        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    func selectAll() {
        selectedItems = Set(scanResults.filter { item in
            !item.isReadOnly &&
            !(item.lastModified.map { Calendar.current.isDateInToday($0) } ?? false)
        }.map { $0.id })
    }

    func selectNone() {
        selectedItems.removeAll()
    }

    func selectOldOnly() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        selectedItems = Set(scanResults.filter { item in
            !item.isReadOnly &&
            (item.lastModified.map { $0 < sevenDaysAgo } ?? true)
        }.map { $0.id })
    }

    func performDelete() async {
        isDeleting = true

        let itemsToDelete = scanResults.filter { selectedItems.contains($0.id) }
        let (deleted, _, freedSpace) = await scanner.deleteItems(itemsToDelete)

        isDeleting = false

        if deleted > 0 {
            lastFreedSpace = freedSpace
            lastDeletedCount = deleted
            showDeletionResult = true
        }

        await scan()
    }
}

#Preview {
    LogsView()
        .frame(width: 800, height: 600)
        .environmentObject(ViewModelStore())
        .environmentObject(DiskSpaceManager())
}
