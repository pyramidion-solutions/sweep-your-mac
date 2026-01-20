import SwiftUI

struct iOSBackupsView: View {
    @EnvironmentObject private var viewModelStore: ViewModelStore

    var body: some View {
        iOSBackupsContent(viewModel: viewModelStore.iOSBackupsVM)
    }
}

private struct iOSBackupsContent: View {
    @ObservedObject var viewModel: iOSBackupsViewModel
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
            case .completed(let summary):
                resultsView(summary: summary)
            case .cancelled:
                cancelledView
            case .error(let message):
                errorView(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("iOS Backups")
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("iOS Backups")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("iPhone, iPad, and iPod touch backups")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if case .completed(let summary) = viewModel.scanState {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(summary.formattedTotalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("\(summary.backups.count) backup\(summary.backups.count == 1 ? "" : "s")")
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
            Image(systemName: "iphone")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Click Scan to find iOS backups")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Scans ~/Library/Application Support/MobileSync/Backup")
                .font(.caption)
                .foregroundColor(.secondary)

            // Info box
            VStack(alignment: .leading, spacing: 8) {
                Label("iOS backups can be very large", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("Consider using iCloud backups to save local disk space")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    private func resultsView(summary: iOSBackupsScanner.BackupsSummary) -> some View {
        VStack(spacing: 0) {
            if summary.backups.isEmpty {
                emptyStateView
            } else {
                // Summary cards
                summaryCardsView(summary: summary)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()

                // Selection bar
                selectionBar(summary: summary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                Divider()

                // Backups list
                List {
                    ForEach(summary.backups) { backup in
                        BackupItemRow(
                            backup: backup,
                            isSelected: viewModel.selectedBackups.contains(backup.id),
                            onToggle: { viewModel.toggleSelection(backup) }
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

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("No iOS backups found")
                .font(.headline)
            Text("Your Mac doesn't have any local iOS device backups")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summaryCardsView(summary: iOSBackupsScanner.BackupsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Backup Summary")
                .font(.headline)

            HStack(spacing: 16) {
                // Total size card
                SummaryCard(
                    title: "Total Size",
                    value: summary.formattedTotalSize,
                    icon: "externaldrive.fill",
                    color: .orange
                )

                // Backup count card
                SummaryCard(
                    title: "Backups",
                    value: "\(summary.backups.count)",
                    icon: "iphone",
                    color: .blue
                )

                // Files card
                SummaryCard(
                    title: "Files",
                    value: formatNumber(summary.totalFiles),
                    icon: "doc.fill",
                    color: .green
                )

                // Old backups card
                if summary.oldBackupsSize > 0 {
                    SummaryCard(
                        title: "Old (>30 days)",
                        value: summary.oldBackupsSize.formattedBytes,
                        icon: "clock.fill",
                        color: .red
                    )
                }
            }

            // Device breakdown
            if summary.deviceBreakdown.count > 1 {
                Text("By Device")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(summary.deviceBreakdown, id: \.device) { item in
                        DeviceBreakdownCard(
                            deviceName: item.device,
                            count: item.count,
                            size: item.size
                        )
                    }
                }
            }
        }
    }

    private func selectionBar(summary: iOSBackupsScanner.BackupsSummary) -> some View {
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
                Text("Select Old Only (>30 days)")
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
                Text("Selected: \(viewModel.selectedBackups.count) backup\(viewModel.selectedBackups.count == 1 ? "" : "s")")
                    .font(.subheadline)
                Text(viewModel.selectedSize.formattedBytes)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
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
            .disabled(viewModel.selectedBackups.isEmpty || viewModel.isDeleting)
        }
        .alert("Delete Backups?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSelected()
                }
            }
        } message: {
            Text("Are you sure you want to permanently delete \(viewModel.selectedBackups.count) backup(s)? This action cannot be undone.")
        }
        .alert("Cleanup Complete", isPresented: $viewModel.showDeletionResult) {
            Button("OK") {
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        } message: {
            Text("Successfully freed \(viewModel.lastFreedSpace.formattedBytes) by removing \(viewModel.lastDeletedCount) backup(s).")
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

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Device Breakdown Card
struct DeviceBreakdownCard: View {
    let deviceName: String
    let count: Int
    let size: Int64

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(deviceName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(count) backup\(count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(size.formattedBytes)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Backup Item Row
struct BackupItemRow: View {
    let backup: iOSBackupsScanner.BackupInfo
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

            // Device icon
            Image(systemName: backup.deviceIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)

            // Device info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(backup.deviceName)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if backup.isEncrypted {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    if backup.ageInDays > 30 {
                        Text("Old")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(3)
                    }
                }

                HStack(spacing: 8) {
                    Text(backup.displayModel)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("iOS \(backup.iOSVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text(backup.formattedSize)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()

                HStack(spacing: 8) {
                    Text("\(formatNumber(backup.fileCount)) files")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(backup.relativeDate)
                        .font(.caption)
                        .foregroundColor(backup.ageInDays > 30 ? .orange : .secondary)
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
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: backup.path)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Scan State
enum iOSBackupsScanState {
    case idle
    case scanning(progress: String)
    case completed(iOSBackupsScanner.BackupsSummary)
    case cancelled
    case error(String)

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}

// MARK: - View Model
@MainActor
class iOSBackupsViewModel: ObservableObject {
    @Published var scanState: iOSBackupsScanState = .idle
    @Published var selectedBackups: Set<UUID> = []
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published var showDeletionResult = false
    @Published var lastFreedSpace: Int64 = 0
    @Published var lastDeletedCount: Int = 0

    private let scanner = iOSBackupsScanner()
    private var backups: [iOSBackupsScanner.BackupInfo] = []

    var selectedSize: Int64 {
        backups
            .filter { selectedBackups.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    func scan() async {
        scanState = .scanning(progress: "Starting scan...")

        let summary = await scanner.scan { [weak self] progress in
            Task { @MainActor in
                self?.scanState = .scanning(progress: progress)
            }
        }

        backups = summary.backups
        selectedBackups.removeAll()
        scanState = .completed(summary)
    }

    func toggleSelection(_ backup: iOSBackupsScanner.BackupInfo) {
        if selectedBackups.contains(backup.id) {
            selectedBackups.remove(backup.id)
        } else {
            selectedBackups.insert(backup.id)
        }
    }

    func selectAll() {
        selectedBackups = Set(backups.map { $0.id })
    }

    func selectNone() {
        selectedBackups.removeAll()
    }

    func selectOldOnly() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        selectedBackups = Set(backups.filter {
            ($0.lastBackupDate ?? Date()) < thirtyDaysAgo
        }.map { $0.id })
    }

    func deleteSelected() async {
        isDeleting = true

        let backupsToDelete = backups.filter { selectedBackups.contains($0.id) }
        let (deleted, _, freedSpace) = await scanner.deleteBackups(backupsToDelete)

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
    iOSBackupsView()
        .frame(width: 800, height: 600)
        .environmentObject(ViewModelStore())
        .environmentObject(DiskSpaceManager())
}
