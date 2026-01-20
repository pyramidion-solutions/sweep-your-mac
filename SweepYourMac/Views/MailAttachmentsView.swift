import SwiftUI

struct MailAttachmentsView: View {
    @EnvironmentObject private var viewModelStore: ViewModelStore

    var body: some View {
        MailAttachmentsContent(viewModel: viewModelStore.mailAttachmentsViewModel)
    }
}

private struct MailAttachmentsContent: View {
    @ObservedObject var viewModel: MailAttachmentsViewModel
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
        .navigationTitle("Mail Attachments")
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mail Attachments")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Attachments from Mail and Messages apps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if case .completed(let summary) = viewModel.scanState {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(summary.formattedTotalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("\(summary.totalCount) attachments")
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
            Image(systemName: "paperclip")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Click Scan to find mail attachments")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Scans Mail Downloads, Mail.app, and Messages attachments")
                .font(.caption)
                .foregroundColor(.secondary)

            // Warning box
            VStack(alignment: .leading, spacing: 8) {
                Label("Deleting attachments may affect your emails", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("Mail Downloads are safe to delete. Mail.app attachments may break email display.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
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
    private func resultsView(summary: MailAttachmentsScanner.AttachmentsSummary) -> some View {
        VStack(spacing: 0) {
            if summary.items.isEmpty {
                emptyStateView
            } else {
                // Summary section
                summarySection(summary: summary)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()

                // Filter and selection bar
                filterBar(summary: summary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                Divider()

                // Items list
                itemsList(summary: summary)

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
            Text("No attachments found")
                .font(.headline)
            Text("Your mail attachments folders are empty")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summarySection(summary: MailAttachmentsScanner.AttachmentsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Source breakdown
            Text("By Source")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(summary.sourceBreakdown, id: \.source) { item in
                    SourceCard(
                        source: item.source,
                        count: item.count,
                        size: item.size,
                        isSelected: viewModel.selectedSource == item.source || viewModel.selectedSource == nil,
                        onTap: {
                            if viewModel.selectedSource == item.source {
                                viewModel.selectedSource = nil
                            } else {
                                viewModel.selectedSource = item.source
                            }
                        }
                    )
                }
            }

            // Type breakdown
            Text("By Type")
                .font(.headline)
                .padding(.top, 8)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(summary.typeBreakdown, id: \.type) { item in
                    TypeChip(
                        type: item.type,
                        count: item.count,
                        size: item.size,
                        isSelected: viewModel.selectedType == item.type,
                        onTap: {
                            if viewModel.selectedType == item.type {
                                viewModel.selectedType = nil
                            } else {
                                viewModel.selectedType = item.type
                            }
                        }
                    )
                }
            }
        }
    }

    private func filterBar(summary: MailAttachmentsScanner.AttachmentsSummary) -> some View {
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

            Button(action: { viewModel.selectDownloadsOnly() }) {
                Text("Select Downloads Only")
                    .font(.caption)
            }
            .buttonStyle(.link)

            Button(action: { viewModel.selectLargeOnly() }) {
                Text("Select Large (>10MB)")
                    .font(.caption)
            }
            .buttonStyle(.link)

            if viewModel.selectedSource != nil || viewModel.selectedType != nil {
                Button(action: {
                    viewModel.selectedSource = nil
                    viewModel.selectedType = nil
                }) {
                    Label("Clear Filters", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }

            Spacer()

            Text("Scanned in \(String(format: "%.1f", summary.scanDuration))s")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func itemsList(summary: MailAttachmentsScanner.AttachmentsSummary) -> some View {
        List {
            ForEach(viewModel.filteredItems) { item in
                AttachmentItemRow(
                    item: item,
                    isSelected: viewModel.selectedItems.contains(item.id),
                    onToggle: { viewModel.toggleSelection(item) }
                )
            }
        }
        .listStyle(.inset)
    }

    private var actionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected: \(viewModel.selectedItems.count) attachments")
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
                    Text("Delete Selected")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(viewModel.selectedItems.isEmpty || viewModel.isDeleting)
        }
        .alert("Delete Attachments?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash") {
                Task {
                    await viewModel.deleteSelected(moveToTrash: true)
                }
            }
            Button("Delete Permanently", role: .destructive) {
                Task {
                    await viewModel.deleteSelected(moveToTrash: false)
                }
            }
        } message: {
            Text("Are you sure you want to delete \(viewModel.selectedItems.count) attachment(s) totaling \(viewModel.selectedSize.formattedBytes)? Moving to Trash allows recovery. This may affect how some emails display.")
        }
        .alert("Cleanup Complete", isPresented: $viewModel.showDeletionResult) {
            Button("OK") {
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        } message: {
            Text("Successfully freed \(viewModel.lastFreedSpace.formattedBytes) by removing \(viewModel.lastDeletedCount) attachment(s).")
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

// MARK: - Source Card
struct SourceCard: View {
    let source: MailAttachmentsScanner.AttachmentSource
    let count: Int
    let size: Int64
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: source.icon)
                        .foregroundColor(sourceColor)
                    Text(source.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("\(count)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(size.formattedBytes)
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? sourceColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? sourceColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var sourceColor: Color {
        switch source {
        case .mailApp: return .blue
        case .mailDownloads: return .green
        case .messages: return .purple
        }
    }
}

// MARK: - Type Chip
struct TypeChip: View {
    let type: MailAttachmentsScanner.AttachmentType
    let count: Int
    let size: Int64
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
        case .image: return .green
        case .video: return .purple
        case .audio: return .pink
        case .document: return .orange
        case .archive: return .yellow
        case .other: return .gray
        }
    }
}

// MARK: - Attachment Item Row
struct AttachmentItemRow: View {
    let item: MailAttachmentsScanner.AttachmentItem
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
            Image(systemName: item.type.icon)
                .font(.title2)
                .foregroundColor(typeColor)
                .frame(width: 28)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    SourceBadge(source: item.source)

                    if item.size > 10_000_000 { // > 10MB
                        Text("Large")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }
                }

                Text(item.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.formattedSize)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()

                Text(item.formattedDate)
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

    private var typeColor: Color {
        switch item.type {
        case .image: return .green
        case .video: return .purple
        case .audio: return .pink
        case .document: return .orange
        case .archive: return .yellow
        case .other: return .gray
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Source Badge
struct SourceBadge: View {
    let source: MailAttachmentsScanner.AttachmentSource

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: source.icon)
                .font(.caption2)
            Text(shortName)
                .font(.caption2)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(sourceColor.opacity(0.2))
        .foregroundColor(sourceColor)
        .cornerRadius(3)
    }

    private var shortName: String {
        switch source {
        case .mailApp: return "Mail"
        case .mailDownloads: return "Downloads"
        case .messages: return "Messages"
        }
    }

    private var sourceColor: Color {
        switch source {
        case .mailApp: return .blue
        case .mailDownloads: return .green
        case .messages: return .purple
        }
    }
}

// MARK: - Scan State
enum MailAttachmentsScanState {
    case idle
    case scanning(progress: String)
    case completed(MailAttachmentsScanner.AttachmentsSummary)
    case cancelled
    case error(String)

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}

// MARK: - View Model
@MainActor
class MailAttachmentsViewModel: ObservableObject {
    @Published var scanState: MailAttachmentsScanState = .idle
    @Published var selectedItems: Set<UUID> = []
    @Published var selectedSource: MailAttachmentsScanner.AttachmentSource? = nil
    @Published var selectedType: MailAttachmentsScanner.AttachmentType? = nil
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published var showDeletionResult = false
    @Published var lastFreedSpace: Int64 = 0
    @Published var lastDeletedCount: Int = 0

    private let scanner = MailAttachmentsScanner()
    private var allItems: [MailAttachmentsScanner.AttachmentItem] = []

    var filteredItems: [MailAttachmentsScanner.AttachmentItem] {
        allItems.filter { item in
            let sourceMatch = selectedSource == nil || item.source == selectedSource
            let typeMatch = selectedType == nil || item.type == selectedType
            return sourceMatch && typeMatch
        }
    }

    var selectedSize: Int64 {
        allItems
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

        allItems = summary.items
        selectedItems.removeAll()
        selectedSource = nil
        selectedType = nil
        scanState = .completed(summary)
    }

    func toggleSelection(_ item: MailAttachmentsScanner.AttachmentItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    func selectAll() {
        selectedItems = Set(filteredItems.map { $0.id })
    }

    func selectNone() {
        selectedItems.removeAll()
    }

    func selectDownloadsOnly() {
        selectedItems = Set(allItems.filter { $0.source == .mailDownloads }.map { $0.id })
    }

    func selectLargeOnly() {
        selectedItems = Set(allItems.filter { $0.size > 10_000_000 }.map { $0.id })
    }

    func deleteSelected(moveToTrash: Bool = true) async {
        isDeleting = true

        let itemsToDelete = allItems.filter { selectedItems.contains($0.id) }
        let (deleted, _, freedSpace) = await scanner.deleteItems(itemsToDelete, moveToTrash: moveToTrash)

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
    MailAttachmentsView()
        .frame(width: 900, height: 700)
        .environmentObject(ViewModelStore())
        .environmentObject(DiskSpaceManager())
}
