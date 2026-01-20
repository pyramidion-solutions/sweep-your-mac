import SwiftUI

struct LargeOldFilesView: View {
    @EnvironmentObject private var viewModelStore: ViewModelStore

    var body: some View {
        LargeOldFilesContent(viewModel: viewModelStore.largeOldFilesViewModel)
    }
}

private struct LargeOldFilesContent: View {
    @ObservedObject var viewModel: LargeOldFilesViewModel
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
        .navigationTitle("Large & Old Files")
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Large & Old Files")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Find large files and files you haven't used in a while")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if case .completed(let result) = viewModel.scanState {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.formattedTotalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text("\(result.totalCount) files found")
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
            Image(systemName: "doc.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Click Scan to find large and old files")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Scans Downloads, Documents, Desktop, Movies, Music, and Pictures")
                .font(.caption)
                .foregroundColor(.secondary)

            // Options
            VStack(alignment: .leading, spacing: 12) {
                Text("Scan Options")
                    .font(.headline)

                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Minimum Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.minSizeOption) {
                            Text("10 MB").tag(MinSizeOption.mb10)
                            Text("50 MB").tag(MinSizeOption.mb50)
                            Text("100 MB").tag(MinSizeOption.mb100)
                            Text("500 MB").tag(MinSizeOption.mb500)
                            Text("1 GB").tag(MinSizeOption.gb1)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                    }

                    VStack(alignment: .leading) {
                        Text("Minimum Age")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.minAgeOption) {
                            Text("30 days").tag(MinAgeOption.days30)
                            Text("90 days").tag(MinAgeOption.days90)
                            Text("6 months").tag(MinAgeOption.months6)
                            Text("1 year").tag(MinAgeOption.year1)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 280)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Info box
            VStack(alignment: .leading, spacing: 8) {
                Label("Files are moved to Trash by default", systemImage: "info.circle")
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
    private func resultsView(result: LargeOldFilesScanner.ScanResult) -> some View {
        VStack(spacing: 0) {
            if result.files.isEmpty {
                emptyStateView
            } else {
                // Summary section
                summarySection(result: result)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()

                // Filter bar
                filterBar(result: result)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                Divider()

                // Files list
                filesList

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
            Text("No large or old files found")
                .font(.headline)
            Text("Your files are well-organized!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summarySection(result: LargeOldFilesScanner.ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stats row
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Found",
                    value: result.formattedTotalSize,
                    subtitle: "\(result.totalCount) files",
                    icon: "doc.badge.clock",
                    color: .purple
                )

                StatCard(
                    title: "Large Files",
                    value: result.largeFilesSize.formattedBytes,
                    subtitle: ">100 MB",
                    icon: "arrow.up.circle.fill",
                    color: .orange
                )

                StatCard(
                    title: "Old Files",
                    value: result.oldFilesSize.formattedBytes,
                    subtitle: ">6 months",
                    icon: "clock.fill",
                    color: .blue
                )

                StatCard(
                    title: "Very Old",
                    value: result.veryOldFilesSize.formattedBytes,
                    subtitle: ">1 year",
                    icon: "clock.badge.exclamationmark",
                    color: .red
                )
            }

            // Category and type filters
            HStack(spacing: 20) {
                // Category chips
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        ForEach(result.categoryBreakdown.prefix(6), id: \.category) { item in
                            CategoryChip(
                                category: item.category,
                                count: item.count,
                                isSelected: viewModel.selectedCategory == item.category,
                                onTap: {
                                    viewModel.selectedCategory = viewModel.selectedCategory == item.category ? nil : item.category
                                }
                            )
                        }
                    }
                }

                Spacer()

                // Type chips
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        ForEach(result.typeBreakdown.prefix(6), id: \.type) { item in
                            FileTypeChip(
                                type: item.type,
                                count: item.count,
                                isSelected: viewModel.selectedType == item.type,
                                onTap: {
                                    viewModel.selectedType = viewModel.selectedType == item.type ? nil : item.type
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private func filterBar(result: LargeOldFilesScanner.ScanResult) -> some View {
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

            Button(action: { viewModel.selectVeryLarge() }) {
                Text("Select Very Large (>500MB)")
                    .font(.caption)
            }
            .buttonStyle(.link)

            Button(action: { viewModel.selectVeryOld() }) {
                Text("Select Very Old (>1 year)")
                    .font(.caption)
            }
            .buttonStyle(.link)

            if viewModel.selectedCategory != nil || viewModel.selectedType != nil {
                Button(action: {
                    viewModel.selectedCategory = nil
                    viewModel.selectedType = nil
                }) {
                    Label("Clear Filters", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }

            Spacer()

            // Sort options
            Picker("Sort", selection: $viewModel.sortOption) {
                Text("Size").tag(SortOption.size)
                Text("Age").tag(SortOption.age)
                Text("Name").tag(SortOption.name)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            Text("Scanned in \(String(format: "%.1f", result.scanDuration))s")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var filesList: some View {
        List {
            ForEach(viewModel.sortedFilteredFiles) { file in
                LargeOldFileRow(
                    file: file,
                    isSelected: viewModel.selectedFiles.contains(file.id),
                    onToggle: { viewModel.toggleSelection(file) }
                )
            }
        }
        .listStyle(.inset)
    }

    private var actionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected: \(viewModel.selectedFiles.count) files")
                    .font(.subheadline)
                Text(viewModel.selectedSize.formattedBytes)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
            }

            Spacer()

            Toggle("Move to Trash", isOn: $viewModel.moveToTrash)
                .toggleStyle(.checkbox)
                .font(.caption)

            if viewModel.isDeleting {
                ProgressView()
                    .padding(.trailing, 8)
            }

            Button(action: {
                viewModel.showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: viewModel.moveToTrash ? "trash" : "xmark.circle")
                    Text(viewModel.moveToTrash ? "Move to Trash" : "Delete Permanently")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.moveToTrash ? .orange : .red)
            .disabled(viewModel.selectedFiles.isEmpty || viewModel.isDeleting)
        }
        .alert(viewModel.moveToTrash ? "Move to Trash?" : "Delete Permanently?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(viewModel.moveToTrash ? "Move to Trash" : "Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSelected()
                }
            }
        } message: {
            if viewModel.moveToTrash {
                Text("Move \(viewModel.selectedFiles.count) file(s) to Trash? You can restore them later if needed.")
            } else {
                Text("Permanently delete \(viewModel.selectedFiles.count) file(s)? This action cannot be undone.")
            }
        }
        .alert("Cleanup Complete", isPresented: $viewModel.showDeletionResult) {
            Button("OK") {
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        } message: {
            Text("Successfully freed \(viewModel.lastFreedSpace.formattedBytes) by removing \(viewModel.lastDeletedCount) file(s).")
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

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
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

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: LargeOldFilesScanner.FileCategory
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption2)
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? categoryColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? categoryColor : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? categoryColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
        switch category {
        case .downloads: return .blue
        case .documents: return .orange
        case .desktop: return .purple
        case .movies: return .red
        case .music: return .pink
        case .pictures: return .green
        case .other: return .gray
        }
    }
}

// MARK: - File Type Chip
struct FileTypeChip: View {
    let type: LargeOldFilesScanner.FileType
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.caption2)
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? typeColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? typeColor : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? typeColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var typeColor: Color {
        switch type {
        case .video: return .purple
        case .image: return .green
        case .audio: return .pink
        case .archive: return .yellow
        case .document: return .orange
        case .application: return .red
        case .diskImage: return .blue
        case .other: return .gray
        }
    }
}

// MARK: - Large Old File Row
struct LargeOldFileRow: View {
    let file: LargeOldFilesScanner.LargeOldFile
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

            // Type icon
            Image(systemName: file.fileType.icon)
                .font(.title2)
                .foregroundColor(typeColor)
                .frame(width: 28)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(file.name)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if file.isVeryLarge {
                        Text("Very Large")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    } else if file.isLarge {
                        Text("Large")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.yellow.opacity(0.2))
                            .foregroundColor(.yellow)
                            .cornerRadius(3)
                    }

                    if file.isVeryOld {
                        Text(">1 year")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(3)
                    } else if file.isOld {
                        Text(">6 months")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: file.category.icon)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(file.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(file.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text(file.formattedSize)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()

                HStack(spacing: 4) {
                    Text("Accessed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(file.formattedLastAccessed)
                        .font(.caption)
                        .foregroundColor(file.isVeryOld ? .red : (file.isOld ? .orange : .secondary))
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

    private var typeColor: Color {
        switch file.fileType {
        case .video: return .purple
        case .image: return .green
        case .audio: return .pink
        case .archive: return .yellow
        case .document: return .orange
        case .application: return .red
        case .diskImage: return .blue
        case .other: return .gray
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Options Enums
enum MinSizeOption: Int {
    case mb10 = 10_000_000
    case mb50 = 50_000_000
    case mb100 = 100_000_000
    case mb500 = 500_000_000
    case gb1 = 1_000_000_000
}

enum MinAgeOption: Int {
    case days30 = 30
    case days90 = 90
    case months6 = 180
    case year1 = 365
}

enum SortOption {
    case size
    case age
    case name
}

// MARK: - Scan State
enum LargeOldFilesScanState {
    case idle
    case scanning(progress: String)
    case completed(LargeOldFilesScanner.ScanResult)
    case cancelled
    case error(String)

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}

// MARK: - View Model
@MainActor
class LargeOldFilesViewModel: ObservableObject {
    @Published var scanState: LargeOldFilesScanState = .idle
    @Published var selectedFiles: Set<UUID> = []
    @Published var selectedCategory: LargeOldFilesScanner.FileCategory? = nil
    @Published var selectedType: LargeOldFilesScanner.FileType? = nil
    @Published var sortOption: SortOption = .size
    @Published var minSizeOption: MinSizeOption = .mb50
    @Published var minAgeOption: MinAgeOption = .days90
    @Published var moveToTrash: Bool = true
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published var showDeletionResult = false
    @Published var lastFreedSpace: Int64 = 0
    @Published var lastDeletedCount: Int = 0

    private let scanner = LargeOldFilesScanner()
    private var allFiles: [LargeOldFilesScanner.LargeOldFile] = []

    var filteredFiles: [LargeOldFilesScanner.LargeOldFile] {
        allFiles.filter { file in
            let categoryMatch = selectedCategory == nil || file.category == selectedCategory
            let typeMatch = selectedType == nil || file.fileType == selectedType
            return categoryMatch && typeMatch
        }
    }

    var sortedFilteredFiles: [LargeOldFilesScanner.LargeOldFile] {
        switch sortOption {
        case .size:
            return filteredFiles.sorted { $0.size > $1.size }
        case .age:
            return filteredFiles.sorted { $0.daysSinceAccessed > $1.daysSinceAccessed }
        case .name:
            return filteredFiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var selectedSize: Int64 {
        allFiles
            .filter { selectedFiles.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    func scan() async {
        scanState = .scanning(progress: "Starting scan...")

        var options = LargeOldFilesScanner.ScanOptions()
        options.minSize = Int64(minSizeOption.rawValue)
        options.minAge = minAgeOption.rawValue

        let result = await scanner.scan(options: options) { [weak self] progress in
            Task { @MainActor in
                self?.scanState = .scanning(progress: progress)
            }
        }

        allFiles = result.files
        selectedFiles.removeAll()
        selectedCategory = nil
        selectedType = nil
        scanState = .completed(result)
    }

    func toggleSelection(_ file: LargeOldFilesScanner.LargeOldFile) {
        if selectedFiles.contains(file.id) {
            selectedFiles.remove(file.id)
        } else {
            selectedFiles.insert(file.id)
        }
    }

    func selectAll() {
        selectedFiles = Set(filteredFiles.map { $0.id })
    }

    func selectNone() {
        selectedFiles.removeAll()
    }

    func selectVeryLarge() {
        selectedFiles = Set(allFiles.filter { $0.isVeryLarge }.map { $0.id })
    }

    func selectVeryOld() {
        selectedFiles = Set(allFiles.filter { $0.isVeryOld }.map { $0.id })
    }

    func deleteSelected() async {
        isDeleting = true

        let filesToDelete = allFiles.filter { selectedFiles.contains($0.id) }
        let (deleted, _, freedSpace) = await scanner.deleteFiles(filesToDelete, moveToTrash: moveToTrash)

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
    LargeOldFilesView()
        .frame(width: 1000, height: 700)
        .environmentObject(ViewModelStore())
        .environmentObject(DiskSpaceManager())
}
