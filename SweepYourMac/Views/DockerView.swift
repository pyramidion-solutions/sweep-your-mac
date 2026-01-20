import SwiftUI

struct DockerView: View {
    @EnvironmentObject private var viewModelStore: ViewModelStore

    var body: some View {
        DockerContent(viewModel: viewModelStore.dockerViewModel)
    }
}

private struct DockerContent: View {
    @ObservedObject var viewModel: DockerViewModel
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
        .navigationTitle("Docker")
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Docker")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Docker images, containers, volumes, and build cache")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if case .completed(let result) = viewModel.scanState {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.formattedTotalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(result.isDockerRunning ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(result.isDockerRunning ? "Docker Running" : "Docker Stopped")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Click Scan to analyze Docker usage")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Scans Docker Desktop data, images, containers, volumes, and build cache")
                .font(.caption)
                .foregroundColor(.secondary)

            // Info box
            VStack(alignment: .leading, spacing: 8) {
                Label("Docker must be running for full analysis", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("Basic disk usage can be scanned even when Docker is stopped")
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
    private func resultsView(result: DockerScanner.DockerScanResult) -> some View {
        VStack(spacing: 0) {
            if !result.isDockerInstalled {
                notInstalledView
            } else {
                // Summary cards
                summarySection(result: result)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()

                // Tabs for different views
                TabView(selection: $viewModel.selectedTab) {
                    overviewTab(result: result)
                        .tabItem {
                            Label("Overview", systemImage: "chart.pie")
                        }
                        .tag(0)

                    if result.isDockerRunning {
                        imagesTab(result: result)
                            .tabItem {
                                Label("Images", systemImage: "shippingbox.fill")
                            }
                            .tag(1)

                        containersTab(result: result)
                            .tabItem {
                                Label("Containers", systemImage: "cube.fill")
                            }
                            .tag(2)

                        volumesTab(result: result)
                            .tabItem {
                                Label("Volumes", systemImage: "externaldrive.fill")
                            }
                            .tag(3)
                    }
                }
                .padding(.top, 8)

                Divider()

                // Action bar
                actionBar(result: result)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }

    private var notInstalledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Docker is not installed")
                .font(.headline)
            Text("Install Docker Desktop to manage containers and images")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let dockerURL = URL(string: "https://www.docker.com/products/docker-desktop/") {
                Link(destination: dockerURL) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Get Docker Desktop")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summarySection(result: DockerScanner.DockerScanResult) -> some View {
        HStack(spacing: 16) {
            // Total size card
            DockerStatCard(
                title: "Total Size",
                value: result.formattedTotalSize,
                subtitle: "Docker data",
                icon: "shippingbox",
                color: .cyan
            )

            // Reclaimable card
            DockerStatCard(
                title: "Reclaimable",
                value: result.formattedReclaimableSize,
                subtitle: "Can be cleaned",
                icon: "trash",
                color: .green
            )

            // Images count
            DockerStatCard(
                title: "Images",
                value: "\(result.images.count)",
                subtitle: result.images.reduce(0) { $0 + $1.size }.formattedBytes,
                icon: "shippingbox.fill",
                color: .purple
            )

            // Containers count
            DockerStatCard(
                title: "Containers",
                value: "\(result.containers.count)",
                subtitle: "\(result.containers.filter { $0.isRunning }.count) running",
                icon: "cube.fill",
                color: .blue
            )

            // Volumes count
            DockerStatCard(
                title: "Volumes",
                value: "\(result.volumes.count)",
                subtitle: result.volumes.reduce(0) { $0 + $1.size }.formattedBytes,
                icon: "externaldrive.fill",
                color: .orange
            )
        }
    }

    private func overviewTab(result: DockerScanner.DockerScanResult) -> some View {
        List {
            Section("Components") {
                ForEach(result.components) { component in
                    DockerComponentRow(component: component)
                }
            }

            if !result.isDockerRunning {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("Docker is not running")
                                .fontWeight(.medium)
                            Text("Start Docker Desktop for detailed analysis and cleanup options")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.inset)
    }

    private func imagesTab(result: DockerScanner.DockerScanResult) -> some View {
        List {
            if result.images.isEmpty {
                Text("No images found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(result.images) { image in
                    DockerImageRow(image: image, onRemove: {
                        Task {
                            await viewModel.removeImage(image.id)
                        }
                    })
                }
            }
        }
        .listStyle(.inset)
    }

    private func containersTab(result: DockerScanner.DockerScanResult) -> some View {
        List {
            if result.containers.isEmpty {
                Text("No containers found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(result.containers) { container in
                    DockerContainerRow(container: container, onRemove: {
                        Task {
                            await viewModel.removeContainer(container.id)
                        }
                    })
                }
            }
        }
        .listStyle(.inset)
    }

    private func volumesTab(result: DockerScanner.DockerScanResult) -> some View {
        List {
            if result.volumes.isEmpty {
                Text("No volumes found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(result.volumes) { volume in
                    DockerVolumeRow(volume: volume, onRemove: {
                        Task {
                            await viewModel.removeVolume(volume.name)
                        }
                    })
                }
            }
        }
        .listStyle(.inset)
    }

    private func actionBar(result: DockerScanner.DockerScanResult) -> some View {
        HStack {
            if result.isDockerRunning {
                Text("Quick Actions:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Prune System") {
                    viewModel.showPruneConfirmation = true
                    viewModel.pruneAction = .system
                }
                .buttonStyle(.bordered)

                Button("Prune Images") {
                    viewModel.showPruneConfirmation = true
                    viewModel.pruneAction = .images
                }
                .buttonStyle(.bordered)

                Button("Prune Build Cache") {
                    viewModel.showPruneConfirmation = true
                    viewModel.pruneAction = .buildCache
                }
                .buttonStyle(.bordered)

                Button("Prune Containers") {
                    viewModel.showPruneConfirmation = true
                    viewModel.pruneAction = .containers
                }
                .buttonStyle(.bordered)

                Button("Prune Volumes") {
                    viewModel.showPruneConfirmation = true
                    viewModel.pruneAction = .volumes
                }
                .buttonStyle(.bordered)
            } else {
                Label("Start Docker for cleanup options", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if viewModel.isPruning {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
                Text("Cleaning...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Scanned in \(String(format: "%.1f", result.scanDuration))s")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .alert("Prune Docker?", isPresented: $viewModel.showPruneConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Prune", role: .destructive) {
                Task {
                    await viewModel.executePrune()
                }
            }
        } message: {
            Text(viewModel.pruneAction.confirmationMessage)
        }
        .alert("Prune Complete", isPresented: $viewModel.showPruneResult) {
            Button("OK") {
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        } message: {
            Text(viewModel.pruneResultMessage)
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

// MARK: - Docker Stat Card
struct DockerStatCard: View {
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

// MARK: - Docker Component Row
struct DockerComponentRow: View {
    let component: DockerScanner.ComponentInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: component.component.icon)
                .font(.title2)
                .foregroundColor(componentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(component.component.rawValue)
                    .fontWeight(.medium)
                Text(component.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(component.formattedSize)
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var componentColor: Color {
        switch component.component {
        case .diskImage: return .blue
        case .images: return .purple
        case .containers: return .green
        case .volumes: return .orange
        case .buildCache: return .yellow
        case .logs: return .gray
        case .other: return .secondary
        }
    }
}

// MARK: - Docker Image Row
struct DockerImageRow: View {
    let image: DockerScanner.DockerImage
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundColor(image.repository == "<none>" ? .orange : .purple)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(image.displayName)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if image.repository == "<none>" {
                        Text("Dangling")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }
                }

                Text("Created \(image.created) • \(image.id.prefix(12))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(image.formattedSize)
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Docker Container Row
struct DockerContainerRow: View {
    let container: DockerScanner.DockerContainer
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube.fill")
                .font(.title2)
                .foregroundColor(container.isRunning ? .green : .gray)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(container.name)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if container.isRunning {
                        Text("Running")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(3)
                    }
                }

                Text("\(container.image) • \(container.id.prefix(12))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(container.formattedSize)
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .opacity(isHovered && !container.isRunning ? 1 : 0)
            .disabled(container.isRunning)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Docker Volume Row
struct DockerVolumeRow: View {
    let volume: DockerScanner.DockerVolume
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(volume.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("Driver: \(volume.driver)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(volume.formattedSize)
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Prune Action
enum PruneAction {
    case system
    case images
    case containers
    case volumes
    case buildCache

    var confirmationMessage: String {
        switch self {
        case .system:
            return "This will remove all stopped containers, unused networks, dangling images, and build cache."
        case .images:
            return "This will remove all unused images, not just dangling ones."
        case .containers:
            return "This will remove all stopped containers."
        case .volumes:
            return "This will remove all unused volumes. Warning: This may delete important data!"
        case .buildCache:
            return "This will remove all build cache."
        }
    }
}

// MARK: - Scan State
enum DockerScanState {
    case idle
    case scanning(progress: String)
    case completed(DockerScanner.DockerScanResult)
    case cancelled
    case error(String)

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}

// MARK: - View Model
@MainActor
class DockerViewModel: ObservableObject {
    @Published var scanState: DockerScanState = .idle
    @Published var selectedTab = 0
    @Published var isPruning = false
    @Published var showPruneConfirmation = false
    @Published var showPruneResult = false
    @Published var pruneAction: PruneAction = .system
    @Published var pruneResultMessage = ""

    private let scanner = DockerScanner()

    func scan() async {
        scanState = .scanning(progress: "Starting scan...")

        let result = await scanner.scan { [weak self] progress in
            Task { @MainActor in
                self?.scanState = .scanning(progress: progress)
            }
        }

        scanState = .completed(result)
    }

    func executePrune() async {
        isPruning = true

        let result: (success: Bool, freedSpace: String, error: String?)

        switch pruneAction {
        case .system:
            result = await scanner.pruneSystem()
        case .images:
            result = await scanner.pruneImages()
        case .containers:
            result = await scanner.pruneContainers()
        case .volumes:
            result = await scanner.pruneVolumes()
        case .buildCache:
            result = await scanner.pruneBuildCache()
        }

        isPruning = false

        if result.success {
            pruneResultMessage = "Successfully freed \(result.freedSpace)"
        } else {
            pruneResultMessage = "Prune failed: \(result.error ?? "Unknown error")"
        }

        showPruneResult = true
        await scan()
    }

    func removeImage(_ imageId: String) async {
        let _ = await scanner.removeImage(imageId)
        await scan()
    }

    func removeContainer(_ containerId: String) async {
        let _ = await scanner.removeContainer(containerId)
        await scan()
    }

    func removeVolume(_ volumeName: String) async {
        let _ = await scanner.removeVolume(volumeName)
        await scan()
    }
}

#Preview {
    DockerView()
        .frame(width: 900, height: 700)
        .environmentObject(ViewModelStore())
        .environmentObject(DiskSpaceManager())
}
