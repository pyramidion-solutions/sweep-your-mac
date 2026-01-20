import SwiftUI

struct BrowserCachesView: View {
    @EnvironmentObject private var viewModelStore: ViewModelStore

    var body: some View {
        BrowserCachesContent(viewModel: viewModelStore.browserCachesViewModel)
    }
}

private struct BrowserCachesContent: View {
    @ObservedObject var viewModel: BrowserCachesViewModel
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
        .navigationTitle("Browser Caches")
        .alert("Browsers Running", isPresented: $viewModel.showRunningBrowsersAlert) {
            Button("Clean Anyway") {
                Task {
                    await viewModel.deleteSelected(force: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The following browsers are running and their caches cannot be fully cleaned:\n\n\(viewModel.runningBrowsersMessage)\n\nClose these browsers first for best results, or click 'Clean Anyway' to clean what's possible.")
        }
        .alert("Cleanup Complete", isPresented: $viewModel.showDeletionResult) {
            Button("OK") {
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        } message: {
            Text("Successfully freed \(viewModel.lastFreedSpace.formattedBytes) by cleaning \(viewModel.lastDeletedCount) browser cache(s).")
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Browser Caches")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Cached data from web browsers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Installed browsers indicators
            if !viewModel.installedBrowsers.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.installedBrowsers).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { browser in
                        BrowserIndicator(browser: browser, isRunning: viewModel.runningBrowsers.contains(browser))
                    }
                }
                .padding(.horizontal)
            }

            if case .completed(let result) = viewModel.scanState {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.formattedTotalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("\(result.items.count) cache locations")
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
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Click Scan to find browser caches")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Supports Safari, Chrome, Firefox, Edge, Brave, Opera, Vivaldi, and Arc")
                .font(.caption)
                .foregroundColor(.secondary)

            if !viewModel.installedBrowsers.isEmpty {
                VStack(spacing: 8) {
                    Text("Detected browsers:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        ForEach(Array(viewModel.installedBrowsers).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { browser in
                            HStack(spacing: 4) {
                                Image(systemName: browser.icon)
                                Text(browser.rawValue)
                            }
                            .font(.caption)
                            .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await viewModel.detectBrowsers()
        }
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
            // Warning for running browsers
            if !viewModel.runningBrowsers.isEmpty {
                runningBrowsersWarning
            }

            // Selection bar
            selectionBar(result: result)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Grouped by browser
            List {
                ForEach(viewModel.groupedByBrowser.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { browser in
                    if let items = viewModel.groupedByBrowser[browser], !items.isEmpty {
                        Section {
                            ForEach(items, id: \.id) { item in
                                BrowserCacheItemRow(
                                    item: item,
                                    browser: browser,
                                    isSelected: viewModel.selectedItems.contains(item.id),
                                    isRunning: viewModel.runningBrowsers.contains(browser),
                                    onToggle: { viewModel.toggleSelection(item) }
                                )
                            }
                        } header: {
                            HStack {
                                Image(systemName: browser.icon)
                                Text(browser.rawValue)
                                if viewModel.runningBrowsers.contains(browser) {
                                    Image(systemName: "play.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
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

    private var runningBrowsersWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Some browsers are running: \(viewModel.runningBrowsers.map { $0.rawValue }.joined(separator: ", "))")
                .font(.caption)
            Spacer()
            Text("Close them for complete cleanup")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
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
                    .foregroundColor(.blue)
            }

            Spacer()

            if viewModel.isDeleting {
                ProgressView()
                    .padding(.trailing, 8)
            }

            Button(action: {
                Task {
                    await viewModel.deleteSelected(force: false)
                }
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

// MARK: - Browser Indicator
struct BrowserIndicator: View {
    let browser: BrowserCachesScanner.Browser
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: browser.icon)
                .font(.caption)
            if isRunning {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
        .help("\(browser.rawValue)\(isRunning ? " (Running)" : "")")
    }
}

// MARK: - Browser Cache Item Row
struct BrowserCacheItemRow: View {
    let item: ScanResult
    let browser: BrowserCachesScanner.Browser
    let isSelected: Bool
    let isRunning: Bool
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

            // Browser icon
            Image(systemName: browser.icon)
                .foregroundColor(.blue)
                .font(.title3)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(cacheTypeName)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if isRunning {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Running")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                    }

                    SafetyBadge(level: .safe)
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

    private var cacheTypeName: String {
        // Extract cache type from item name
        if item.name.contains("Cache") { return "Browser Cache" }
        if item.name.contains("Local Storage") { return "Local Storage" }
        if item.name.contains("Service Worker") { return "Service Workers" }
        return item.name.components(separatedBy: " - ").last ?? item.name
    }

    private func revealInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.path)
    }
}

// MARK: - View Model
@MainActor
class BrowserCachesViewModel: ObservableObject {
    @Published var scanState: ScanState = .idle
    @Published var selectedItems: Set<UUID> = []
    @Published var isDeleting = false
    @Published var installedBrowsers: Set<BrowserCachesScanner.Browser> = []
    @Published var runningBrowsers: Set<BrowserCachesScanner.Browser> = []
    @Published var groupedByBrowser: [BrowserCachesScanner.Browser: [ScanResult]] = [:]
    @Published var showRunningBrowsersAlert = false
    @Published var runningBrowsersMessage = ""
    @Published var showDeletionResult = false
    @Published var lastFreedSpace: Int64 = 0
    @Published var lastDeletedCount: Int = 0

    private let scanner = BrowserCachesScanner()
    private var scanResults: [ScanResult] = []

    var selectedSize: Int64 {
        scanResults
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    func detectBrowsers() async {
        installedBrowsers = await scanner.getInstalledBrowsers()
        updateRunningBrowsers()
    }

    private func updateRunningBrowsers() {
        runningBrowsers = Set(BrowserCachesScanner.Browser.allCases.filter { browser in
            let runningApps = NSWorkspace.shared.runningApplications
            return runningApps.contains { $0.bundleIdentifier == browser.bundleIdentifier }
        })
    }

    func scan() async {
        scanState = .scanning(progress: "Starting scan...")
        updateRunningBrowsers()

        let result = await scanner.scan { [weak self] progress in
            Task { @MainActor in
                self?.scanState = .scanning(progress: progress)
            }
        }

        scanResults = result.items
        installedBrowsers = await scanner.getInstalledBrowsers()
        groupItems()

        // Pre-select all items
        selectedItems = Set(result.items.map { $0.id })

        scanState = .completed(result)
    }

    private func groupItems() {
        var groups: [BrowserCachesScanner.Browser: [ScanResult]] = [:]

        for item in scanResults {
            if let browser = getBrowserForItem(item) {
                if groups[browser] == nil {
                    groups[browser] = []
                }
                groups[browser]?.append(item)
            }
        }

        groupedByBrowser = groups
    }

    private func getBrowserForItem(_ item: ScanResult) -> BrowserCachesScanner.Browser? {
        let path = item.path.lowercased()

        if path.contains("safari") { return .safari }
        if path.contains("google") || path.contains("chrome") { return .chrome }
        if path.contains("firefox") || path.contains("mozilla") { return .firefox }
        if path.contains("microsoft") || path.contains("edge") { return .edge }
        if path.contains("brave") { return .brave }
        if path.contains("opera") { return .opera }
        if path.contains("vivaldi") { return .vivaldi }
        if path.contains("arc") || path.contains("thebrowser") { return .arc }

        return nil
    }

    func toggleSelection(_ item: ScanResult) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    func selectAll() {
        selectedItems = Set(scanResults.map { $0.id })
    }

    func selectNone() {
        selectedItems.removeAll()
    }

    func deleteSelected(force: Bool) async {
        updateRunningBrowsers()

        let itemsToDelete = scanResults.filter { selectedItems.contains($0.id) }

        // Check for running browsers if not forcing
        if !force {
            let affectedRunning = itemsToDelete.compactMap { item -> BrowserCachesScanner.Browser? in
                guard let browser = getBrowserForItem(item) else { return nil }
                return runningBrowsers.contains(browser) ? browser : nil
            }

            let uniqueRunning = Set(affectedRunning)
            if !uniqueRunning.isEmpty {
                runningBrowsersMessage = uniqueRunning.map { $0.rawValue }.sorted().joined(separator: ", ")
                showRunningBrowsersAlert = true
                return
            }
        }

        isDeleting = true

        let (deleted, _, freedSpace, _) = await scanner.deleteItems(itemsToDelete, checkRunning: !force)

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
    BrowserCachesView()
        .frame(width: 800, height: 600)
        .environmentObject(ViewModelStore())
        .environmentObject(DiskSpaceManager())
}
