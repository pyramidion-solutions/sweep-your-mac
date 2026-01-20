import SwiftUI

struct ApplicationLeftoversView: View {
    @EnvironmentObject private var viewModelStore: ViewModelStore

    var body: some View {
        ApplicationLeftoversContent(viewModel: viewModelStore.applicationLeftoversViewModel)
    }
}

private struct ApplicationLeftoversContent: View {
    @ObservedObject var viewModel: ApplicationLeftoversViewModel
    @EnvironmentObject private var diskSpaceManager: DiskSpaceManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            switch viewModel.state {
            case .idle:
                idleView
            case .scanning:
                scanningView
            case .completed:
                resultsView
            case .cancelled:
                cancelledView
            case .error(let message):
                errorView(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Application Leftovers")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Files left behind by uninstalled applications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if case .completed = viewModel.state {
                HStack(spacing: 12) {
                    if !viewModel.selectedLeftovers.isEmpty {
                        Text("\(viewModel.selectedLeftovers.count) selected (\(viewModel.formatSize(viewModel.selectedSize)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(action: { viewModel.scan() }) {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }

                    Button(action: { viewModel.showDeleteConfirmation = true }) {
                        Label("Remove Selected", systemImage: "trash")
                    }
                    .disabled(viewModel.selectedLeftovers.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding()
    }

    private var idleView: some View {
        VStack(spacing: 20) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("Find Application Leftovers")
                .font(.title2)
                .fontWeight(.medium)

            Text("Scan for files left behind by uninstalled applications.\nThis includes preferences, caches, and support files.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 8) {
                Text("Locations scanned:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(LeftoverType.allCases.filter { $0 != .other }, id: \.self) { type in
                    HStack(spacing: 8) {
                        Image(systemName: type.iconName)
                            .frame(width: 16)
                            .foregroundColor(.secondary)
                        Text("~/Library/\(type.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            Button(action: { viewModel.scan() }) {
                Label("Start Scan", systemImage: "magnifyingglass")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Scanning for leftovers...")
                .font(.headline)

            Text(viewModel.scanProgress)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

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

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Summary bar
            summaryBar

            Divider()

            if viewModel.leftovers.isEmpty {
                emptyResultsView
            } else {
                // Filter and sort bar
                filterBar

                Divider()

                // Results list
                leftoversList
            }
        }
        .alert("Remove Selected Leftovers?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                viewModel.removeSelected(moveToTrash: true)
            }
            Button("Delete Permanently", role: .destructive) {
                viewModel.removeSelected(moveToTrash: false)
            }
        } message: {
            Text("This will remove \(viewModel.selectedLeftovers.count) leftover(s) totaling \(viewModel.formatSize(viewModel.selectedSize)). This action may not be reversible.")
        }
        .alert("Cleanup Complete", isPresented: $viewModel.showDeletionResult) {
            Button("OK") {
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        } message: {
            Text("Successfully freed \(viewModel.lastFreedSpace.formattedBytes) by removing \(viewModel.lastDeletedCount) leftover(s).")
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 24) {
            LeftoversSummaryCard(
                title: "Total Leftovers",
                value: "\(viewModel.leftovers.count)",
                subtitle: "applications",
                icon: "app.badge.checkmark",
                color: .orange
            )

            LeftoversSummaryCard(
                title: "Total Size",
                value: viewModel.formatSize(viewModel.totalSize),
                subtitle: "recoverable",
                icon: "externaldrive",
                color: .blue
            )

            LeftoversSummaryCard(
                title: "Locations",
                value: "\(viewModel.totalLocations)",
                subtitle: "files/folders",
                icon: "folder",
                color: .purple
            )

            Spacer()
        }
        .padding()
    }

    private var filterBar: some View {
        HStack {
            // Filter by type
            Menu {
                Button("All Types") {
                    viewModel.selectedType = nil
                }
                Divider()
                ForEach(LeftoverType.allCases.filter { $0 != .other }, id: \.self) { type in
                    Button(type.rawValue) {
                        viewModel.selectedType = type
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(viewModel.selectedType?.rawValue ?? "All Types")
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 180)

            Spacer()

            // Sort options
            Picker("Sort by", selection: $viewModel.sortOrder) {
                Text("Size").tag(LeftoversSortOrder.size)
                Text("Name").tag(LeftoversSortOrder.name)
                Text("Locations").tag(LeftoversSortOrder.locations)
            }
            .pickerStyle(.segmented)
            .frame(width: 250)

            // Quick actions
            Menu {
                Button("Select All") {
                    viewModel.selectAll()
                }
                Button("Deselect All") {
                    viewModel.deselectAll()
                }
                Divider()
                Button("Select Large (>10 MB)") {
                    viewModel.selectLarge()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
    }

    private var leftoversList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredLeftovers) { leftover in
                    LeftoverRowView(
                        leftover: leftover,
                        isSelected: viewModel.selectedLeftovers.contains(leftover.id),
                        isExpanded: viewModel.expandedLeftovers.contains(leftover.id),
                        onToggleSelection: { viewModel.toggleSelection(leftover) },
                        onToggleExpanded: { viewModel.toggleExpanded(leftover) },
                        formatSize: viewModel.formatSize
                    )
                }
            }
            .padding()
        }
    }

    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("No Leftovers Found")
                .font(.title2)
                .fontWeight(.medium)

            Text("Your system appears clean of application leftovers.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Scan Error")
                .font(.title2)
                .fontWeight(.medium)

            Text(message)
                .foregroundColor(.secondary)

            Button("Try Again") {
                viewModel.scan()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LeftoverRowView: View {
    let leftover: AppLeftover
    let isSelected: Bool
    let isExpanded: Bool
    let onToggleSelection: () -> Void
    let onToggleExpanded: () -> Void
    let formatSize: (Int64) -> String

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Selection checkbox
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                // App icon placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.2))
                    Image(systemName: "app.fill")
                        .foregroundColor(.orange)
                }
                .frame(width: 36, height: 36)

                // App info
                VStack(alignment: .leading, spacing: 2) {
                    Text(leftover.appName)
                        .font(.headline)

                    HStack(spacing: 8) {
                        if let bundleId = leftover.bundleIdentifier {
                            Text(bundleId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("\(leftover.locations.count) location\(leftover.locations.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Spacer()

                // Size
                Text(formatSize(leftover.totalSize))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)

                // Expand button
                Button(action: onToggleExpanded) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
            .onHover { hovering in
                isHovered = hovering
            }

            // Expanded details
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.leading, 60)

                    ForEach(leftover.locations) { location in
                        HStack(spacing: 12) {
                            Image(systemName: location.type.iconName)
                                .frame(width: 20)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.type.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)

                                Text(location.path)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Text(formatSize(location.size))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: {
                                NSWorkspace.shared.selectFile(location.path, inFileViewerRootedAtPath: "")
                            }) {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .padding(.leading, 48)
                        .background(Color.gray.opacity(0.05))
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
}

struct LeftoversSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

enum LeftoversSortOrder {
    case size
    case name
    case locations
}

@MainActor
class ApplicationLeftoversViewModel: ObservableObject {
    enum State {
        case idle
        case scanning
        case completed
        case cancelled
        case error(String)
    }

    @Published var state: State = .idle
    @Published var scanProgress: String = ""
    @Published var leftovers: [AppLeftover] = []
    @Published var selectedLeftovers: Set<UUID> = []
    @Published var expandedLeftovers: Set<UUID> = []
    @Published var sortOrder: LeftoversSortOrder = .size
    @Published var selectedType: LeftoverType?
    @Published var showDeleteConfirmation = false
    @Published var showDeletionResult = false
    @Published var lastFreedSpace: Int64 = 0
    @Published var lastDeletedCount: Int = 0

    private let scanner = ApplicationLeftoversScanner()

    var totalSize: Int64 {
        leftovers.reduce(0) { $0 + $1.totalSize }
    }

    var totalLocations: Int {
        leftovers.reduce(0) { $0 + $1.locations.count }
    }

    var selectedSize: Int64 {
        leftovers.filter { selectedLeftovers.contains($0.id) }
            .reduce(0) { $0 + $1.totalSize }
    }

    var filteredLeftovers: [AppLeftover] {
        var result = leftovers

        // Filter by type
        if let type = selectedType {
            result = result.filter { leftover in
                leftover.locations.contains { $0.type == type }
            }
        }

        // Sort
        switch sortOrder {
        case .size:
            result.sort { $0.totalSize > $1.totalSize }
        case .name:
            result.sort { $0.appName.lowercased() < $1.appName.lowercased() }
        case .locations:
            result.sort { $0.locations.count > $1.locations.count }
        }

        return result
    }

    func scan() {
        state = .scanning
        selectedLeftovers.removeAll()
        expandedLeftovers.removeAll()

        Task {
            let result = await scanner.scan { progress in
                Task { @MainActor in
                    self.scanProgress = progress
                }
            }

            self.leftovers = result.leftovers
            self.state = .completed
        }
    }

    func toggleSelection(_ leftover: AppLeftover) {
        if selectedLeftovers.contains(leftover.id) {
            selectedLeftovers.remove(leftover.id)
        } else {
            selectedLeftovers.insert(leftover.id)
        }
    }

    func toggleExpanded(_ leftover: AppLeftover) {
        if expandedLeftovers.contains(leftover.id) {
            expandedLeftovers.remove(leftover.id)
        } else {
            expandedLeftovers.insert(leftover.id)
        }
    }

    func selectAll() {
        selectedLeftovers = Set(filteredLeftovers.map { $0.id })
    }

    func deselectAll() {
        selectedLeftovers.removeAll()
    }

    func selectLarge() {
        let largeThreshold: Int64 = 10_000_000 // 10 MB
        selectedLeftovers = Set(filteredLeftovers.filter { $0.totalSize >= largeThreshold }.map { $0.id })
    }

    func removeSelected(moveToTrash: Bool) {
        let toRemove = leftovers.filter { selectedLeftovers.contains($0.id) }
        let estimatedSize = toRemove.reduce(0) { $0 + $1.totalSize }

        Task {
            let result = await scanner.removeLeftovers(toRemove, moveToTrash: moveToTrash)

            // Show success feedback
            if result.success > 0 {
                lastFreedSpace = estimatedSize
                lastDeletedCount = result.success
                showDeletionResult = true
            }

            // Refresh the list
            self.scan()

            if result.failed > 0 {
                AppLogger.deletion.error("Failed to remove \(result.failed) application leftover items")
            }
        }
    }

    func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    ApplicationLeftoversView()
        .frame(width: 900, height: 600)
        .environmentObject(ViewModelStore())
        .environmentObject(DiskSpaceManager())
}
