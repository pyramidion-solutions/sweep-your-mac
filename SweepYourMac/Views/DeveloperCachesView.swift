import SwiftUI

struct DeveloperCachesView: View {
    @EnvironmentObject private var viewModelStore: ViewModelStore

    var body: some View {
        DeveloperCachesContent(viewModel: viewModelStore.developerCachesViewModel)
    }
}

private struct DeveloperCachesContent: View {
    @ObservedObject var viewModel: DeveloperCachesViewModel
    @EnvironmentObject private var diskSpaceManager: DiskSpaceManager
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("Developer Tools").tag(0)
                Text("Node Modules").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content based on tab
            if selectedTab == 0 {
                developerToolsContent
            } else {
                nodeModulesContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Developer Caches")
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Developer Caches")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Build artifacts, simulators, and development tool caches")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if case .completed(let result) = viewModel.scanState {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.formattedTotalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("\(result.items.count) locations found")
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
                if selectedTab == 0 {
                    await viewModel.scan()
                } else {
                    await viewModel.scanNodeModules()
                }
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

    // MARK: - Developer Tools Content
    @ViewBuilder
    private var developerToolsContent: some View {
        switch viewModel.scanState {
        case .idle:
            idleView(message: "Click Scan to find developer caches", subtitle: "Scans Xcode, Simulators, Gradle, npm, Cargo, and more")
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

    // MARK: - Node Modules Content
    @ViewBuilder
    private var nodeModulesContent: some View {
        switch viewModel.nodeModulesScanState {
        case .idle:
            idleView(message: "Click Scan to find node_modules folders", subtitle: "Searches common project directories for Node.js dependencies")
        case .scanning(let progress):
            scanningView(progress: progress)
        case .completed(let result):
            nodeModulesResultsView(items: result.items)
        case .cancelled:
            cancelledView
        case .error(let message):
            errorView(message: message)
        }
    }

    // MARK: - Idle View
    private func idleView(message: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(subtitle)
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
                .multilineTextAlignment(.center)
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

            // Grouped items list
            List {
                ForEach(viewModel.groupedItems.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { tool in
                    if let items = viewModel.groupedItems[tool], !items.isEmpty {
                        Section {
                            ForEach(items, id: \.id) { item in
                                DeveloperCacheItemRow(
                                    item: item,
                                    isSelected: viewModel.selectedItems.contains(item.id),
                                    onToggle: { viewModel.toggleSelection(item) }
                                )
                            }
                        } header: {
                            HStack {
                                Image(systemName: tool.icon)
                                Text(tool.rawValue)
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

    // MARK: - Node Modules Results View
    private func nodeModulesResultsView(items: [ScanResult]) -> some View {
        VStack(spacing: 0) {
            // Selection bar
            HStack {
                Button(action: { viewModel.selectAllNodeModules() }) {
                    Text("Select All")
                        .font(.caption)
                }
                .buttonStyle(.link)

                Button(action: { viewModel.selectNoneNodeModules() }) {
                    Text("Select None")
                        .font(.caption)
                }
                .buttonStyle(.link)

                Spacer()

                Text("\(items.count) node_modules folders found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No node_modules folders found")
                        .font(.headline)
                    Text("Your project directories are clean!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items, id: \.id) { item in
                        DeveloperCacheItemRow(
                            item: item,
                            isSelected: viewModel.selectedNodeModules.contains(item.id),
                            onToggle: { viewModel.toggleNodeModuleSelection(item) }
                        )
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Action bar for node modules
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected: \(viewModel.selectedNodeModules.count) folders")
                        .font(.subheadline)
                    Text(viewModel.selectedNodeModulesSize.formattedBytes)
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
                    viewModel.showNodeModulesDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Selected")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(viewModel.selectedNodeModules.isEmpty || viewModel.isDeleting)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .alert("Delete Selected Node Modules?", isPresented: $viewModel.showNodeModulesDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.performNodeModulesDelete()
                }
            }
        } message: {
            Text("This will permanently delete \(viewModel.selectedNodeModules.count) node_modules folder(s) totaling \(viewModel.selectedNodeModulesSize.formattedBytes). You can restore them by running 'npm install' in each project. This action cannot be undone.")
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

    private var actionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected: \(viewModel.selectedItems.count) items")
                    .font(.subheadline)
                Text(viewModel.selectedSize.formattedBytes)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }

            Spacer()

            Button(action: {
                Task {
                    await viewModel.runXcodeCleanup()
                }
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Clean Simulators")
                }
            }
            .buttonStyle(.bordered)
            .help("Remove unavailable simulator devices")

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
        .alert("Clean Selected Developer Caches?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task {
                    await viewModel.performDelete()
                }
            }
        } message: {
            Text("This will permanently delete \(viewModel.selectedItems.count) item(s) totaling \(viewModel.selectedSize.formattedBytes). Build caches can be rebuilt but may take time. This action cannot be undone.")
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

// MARK: - Developer Cache Item Row
struct DeveloperCacheItemRow: View {
    let item: ScanResult
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

            // Icon based on safety
            Image(systemName: iconName)
                .foregroundColor(safetyColor)
                .font(.title3)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .fontWeight(.medium)
                        .lineLimit(1)

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
                    .foregroundColor(item.size > 1_000_000_000 ? .orange : .primary)

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

    private var iconName: String {
        if item.name.contains("DerivedData") { return "hammer.fill" }
        if item.name.contains("Archives") { return "archivebox.fill" }
        if item.name.contains("Simulator") || item.name.contains("Device") { return "iphone" }
        if item.name.contains("node_modules") { return "shippingbox.fill" }
        if item.name.contains("Gradle") { return "g.circle.fill" }
        if item.name.contains("Android") { return "a.circle.fill" }
        if item.name.contains("Flutter") || item.name.contains("Dart") || item.name.contains("pub") { return "bird.fill" }
        if item.name.contains("Cargo") || item.name.contains("Rust") { return "gearshape.2.fill" }
        if item.name.contains("npm") || item.name.contains("Yarn") { return "shippingbox" }
        if item.name.contains("Homebrew") { return "mug.fill" }
        if item.name.contains("pip") || item.name.contains("Python") { return "chevron.left.forwardslash.chevron.right" }
        if item.name.contains("CocoaPods") { return "shippingbox.fill" }
        return "folder.fill"
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
class DeveloperCachesViewModel: ObservableObject {
    @Published var scanState: ScanState = .idle
    @Published var nodeModulesScanState: ScanState = .idle
    @Published var selectedItems: Set<UUID> = []
    @Published var selectedNodeModules: Set<UUID> = []
    @Published var isDeleting = false
    @Published var groupedItems: [DeveloperCachesScanner.DeveloperTool: [ScanResult]] = [:]
    @Published var showDeleteConfirmation = false
    @Published var showNodeModulesDeleteConfirmation = false
    @Published var showDeletionResult = false
    @Published var lastFreedSpace: Int64 = 0
    @Published var lastDeletedCount: Int = 0

    private let scanner = DeveloperCachesScanner()
    private var scanResults: [ScanResult] = []
    private var nodeModulesResults: [ScanResult] = []

    var selectedSize: Int64 {
        scanResults
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    var selectedNodeModulesSize: Int64 {
        nodeModulesResults
            .filter { selectedNodeModules.contains($0.id) }
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

        // Pre-select safe items
        selectedItems = Set(result.items.filter { $0.safetyLevel == .safe && $0.isSelected }.map { $0.id })

        scanState = .completed(result)
    }

    func scanNodeModules() async {
        nodeModulesScanState = .scanning(progress: "Searching for node_modules...")

        let items = await scanner.scanForNodeModules { [weak self] progress in
            Task { @MainActor in
                self?.nodeModulesScanState = .scanning(progress: progress)
            }
        }

        nodeModulesResults = items
        selectedNodeModules.removeAll()

        let result = CategoryScanResult(
            category: .nodeModules,
            items: items,
            totalSize: items.reduce(0) { $0 + $1.size },
            scanDuration: 0
        )

        nodeModulesScanState = .completed(result)
    }

    private func groupItems() {
        var groups: [DeveloperCachesScanner.DeveloperTool: [ScanResult]] = [:]

        for item in scanResults {
            let tool = determineTool(for: item)
            if groups[tool] == nil {
                groups[tool] = []
            }
            groups[tool]?.append(item)
        }

        groupedItems = groups
    }

    private func determineTool(for item: ScanResult) -> DeveloperCachesScanner.DeveloperTool {
        let path = item.path.lowercased()
        let name = item.name.lowercased()

        if path.contains("xcode") || name.contains("xcode") { return .xcode }
        if path.contains("simulator") || path.contains("coresimulator") { return .simulator }
        if path.contains("gradle") { return .gradle }
        if path.contains("android") { return .android }
        if path.contains("flutter") || path.contains("dart") || path.contains("pub-cache") || path.contains("fvm") { return .flutter }
        if path.contains("cocoapods") { return .cocoapods }
        if path.contains("cargo") || path.contains("rustup") { return .cargo }
        if path.contains("npm") { return .npm }
        if path.contains("yarn") { return .yarn }
        if path.contains("homebrew") { return .homebrew }
        if path.contains("pip") { return .pip }
        return .cache
    }

    func toggleSelection(_ item: ScanResult) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    func toggleNodeModuleSelection(_ item: ScanResult) {
        if selectedNodeModules.contains(item.id) {
            selectedNodeModules.remove(item.id)
        } else {
            selectedNodeModules.insert(item.id)
        }
    }

    func selectAll() {
        selectedItems = Set(scanResults.map { $0.id })
    }

    func selectNone() {
        selectedItems.removeAll()
    }

    func selectSafe() {
        selectedItems = Set(scanResults.filter { $0.safetyLevel == .safe }.map { $0.id })
    }

    func selectAllNodeModules() {
        selectedNodeModules = Set(nodeModulesResults.map { $0.id })
    }

    func selectNoneNodeModules() {
        selectedNodeModules.removeAll()
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

    func performNodeModulesDelete() async {
        isDeleting = true

        let itemsToDelete = nodeModulesResults.filter { selectedNodeModules.contains($0.id) }
        let (deleted, _, freedSpace) = await scanner.deleteItems(itemsToDelete)

        isDeleting = false

        if deleted > 0 {
            lastFreedSpace = freedSpace
            lastDeletedCount = deleted
            showDeletionResult = true
        }

        await scanNodeModules()
    }

    func runXcodeCleanup() async {
        let _ = await scanner.runXcodeCleanup()
        await scan()
    }
}

#Preview {
    DeveloperCachesView()
        .frame(width: 900, height: 700)
        .environmentObject(ViewModelStore())
        .environmentObject(DiskSpaceManager())
}
