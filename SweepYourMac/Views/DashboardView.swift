import SwiftUI

struct DashboardView: View {
    @ObservedObject var diskSpaceManager: DiskSpaceManager
    @Binding var selectedCategory: ScanCategory?
    @StateObject private var permissionManager = PermissionManager()
    @State private var isScanning = false
    @State private var recoverableSpace: Int64 = 0
    @State private var scanProgress: String = ""
    @State private var showQuickActionResult = false
    @State private var quickActionMessage = ""
    @State private var isPerformingQuickAction = false

    private let scanCoordinator = ScanCoordinator()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Permission Banner (shows if Full Disk Access not granted)
                PermissionBannerView(permissionManager: permissionManager)

                // Header
                headerSection

                // Disk Space Overview
                diskSpaceCard

                // Storage Breakdown
                storageBreakdownCard

                // Quick Actions
                quickActionsSection

                // Category Cards
                categoryCardsSection
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await diskSpaceManager.refreshDiskSpace()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(diskSpaceManager.isLoading)
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Storage Overview")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Analyze and clean up your Mac's storage")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Disk Space Card
    private var diskSpaceCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 40) {
                // Storage Ring Chart
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: CGFloat(diskSpaceManager.diskSpace.usedPercentage / 100))
                        .stroke(
                            diskSpaceManager.diskSpace.usedPercentage > 90 ? Color.red :
                            diskSpaceManager.diskSpace.usedPercentage > 75 ? Color.orange :
                            Color.blue,
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: diskSpaceManager.diskSpace.usedPercentage)

                    VStack(spacing: 2) {
                        Text("\(Int(diskSpaceManager.diskSpace.usedPercentage))%")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Stats
                VStack(alignment: .leading, spacing: 12) {
                    storageStatRow(
                        label: "Total",
                        value: diskSpaceManager.diskSpace.totalSpace.formattedBytes,
                        color: .primary
                    )
                    storageStatRow(
                        label: "Used",
                        value: diskSpaceManager.diskSpace.usedSpace.formattedBytes,
                        color: .blue
                    )
                    storageStatRow(
                        label: "Available",
                        value: diskSpaceManager.diskSpace.freeSpace.formattedBytes,
                        color: .green
                    )
                }

                Spacer()

                // Smart Scan Button
                VStack(spacing: 8) {
                    Button(action: startSmartScan) {
                        HStack {
                            if isScanning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text(isScanning ? "Scanning..." : "Smart Scan")
                        }
                        .frame(width: 140)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isScanning)

                    if isScanning && !scanProgress.isEmpty {
                        Text(scanProgress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if recoverableSpace > 0 {
                        Text("~\(recoverableSpace.formattedBytes) recoverable")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()

            if diskSpaceManager.isLoading {
                ProgressView("Loading disk information...")
            }

            if let error = diskSpaceManager.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func storageStatRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .frame(width: 180)
    }

    // MARK: - Storage Breakdown Card
    private var storageBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Breakdown")
                .font(.headline)

            if diskSpaceManager.storageBreakdown.isEmpty {
                HStack {
                    Spacer()
                    if diskSpaceManager.isCalculatingBreakdown {
                        ProgressView()
                        Text("Calculating storage breakdown...")
                            .foregroundColor(.secondary)
                    } else {
                        Text("No data available")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
            } else {
                // Stacked Bar
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(diskSpaceManager.storageBreakdown) { item in
                            let width = max(
                                CGFloat(item.size) / CGFloat(diskSpaceManager.diskSpace.totalSpace) * geometry.size.width,
                                4
                            )
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorForName(item.color))
                                .frame(width: width)
                        }
                    }
                }
                .frame(height: 24)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)

                // Legend
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(diskSpaceManager.storageBreakdown) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colorForName(item.color))
                                .frame(width: 8, height: 8)
                            Text(item.name)
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
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Empty Trash",
                    icon: "trash",
                    color: .red,
                    isLoading: isPerformingQuickAction
                ) {
                    emptyTrash()
                }

                QuickActionButton(
                    title: "Clear Caches",
                    icon: "folder.badge.minus",
                    color: .blue,
                    isLoading: isPerformingQuickAction
                ) {
                    clearCaches()
                }

                QuickActionButton(
                    title: "Clean Xcode",
                    icon: "hammer",
                    color: .purple,
                    isLoading: isPerformingQuickAction
                ) {
                    cleanXcode()
                }

                QuickActionButton(
                    title: "Find Large Files",
                    icon: "doc.badge.ellipsis",
                    color: .orange,
                    isLoading: false
                ) {
                    findLargeFiles()
                }
            }
        }
        .alert("Quick Action", isPresented: $showQuickActionResult) {
            Button("OK") { }
        } message: {
            Text(quickActionMessage)
        }
    }

    // MARK: - Category Cards
    private var categoryCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan Categories")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ScanCategory.allCases) { category in
                    CategoryCard(category: category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    // MARK: - Actions
    private func startSmartScan() {
        isScanning = true
        scanProgress = "Starting scan..."

        Task {
            let result = await scanCoordinator.runSmartScan { progress in
                Task { @MainActor in
                    scanProgress = progress
                }
            }

            await MainActor.run {
                recoverableSpace = result.totalRecoverableSpace
                isScanning = false
                scanProgress = ""
            }
        }
    }

    private func emptyTrash() {
        isPerformingQuickAction = true
        Task {
            let result = await scanCoordinator.emptyTrash()
            await MainActor.run {
                isPerformingQuickAction = false
                if result.success && result.freedSpace > 0 {
                    quickActionMessage = "Successfully freed \(result.freedSpace.formattedBytes) by emptying Trash."
                } else if result.success {
                    quickActionMessage = "Trash is already empty."
                } else {
                    quickActionMessage = "Failed to empty Trash: \(result.error ?? "Unknown error")"
                }
                showQuickActionResult = true
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        }
    }

    private func clearCaches() {
        isPerformingQuickAction = true
        Task {
            let result = await scanCoordinator.clearUserCaches()
            await MainActor.run {
                isPerformingQuickAction = false
                if result.success && result.freedSpace > 0 {
                    quickActionMessage = "Successfully freed \(result.freedSpace.formattedBytes) by clearing \(result.deletedCount) cache(s)."
                } else if result.success {
                    quickActionMessage = "No caches to clear."
                } else {
                    quickActionMessage = "Failed to clear caches: \(result.error ?? "Unknown error")"
                }
                showQuickActionResult = true
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        }
    }

    private func cleanXcode() {
        isPerformingQuickAction = true
        Task {
            let result = await scanCoordinator.cleanXcodeCaches()
            await MainActor.run {
                isPerformingQuickAction = false
                if result.success && result.freedSpace > 0 {
                    quickActionMessage = "Successfully freed \(result.freedSpace.formattedBytes) by cleaning Xcode caches."
                } else if result.success {
                    quickActionMessage = "No Xcode caches to clean."
                } else {
                    quickActionMessage = "Failed to clean Xcode: \(result.error ?? "Unknown error")"
                }
                showQuickActionResult = true
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        }
    }

    private func findLargeFiles() {
        selectedCategory = .largeOldFiles
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: ScanCategory
    let onTap: () -> Void
    @State private var size: Int64? = nil
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.iconName)
                    .font(.title2)
                    .foregroundColor(safetyColor)
                Spacer()
                SafetyBadge(level: category.safetyLevel)
            }

            Text(category.displayName)
                .font(.headline)

            Text(category.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Spacer()

            if let size = size {
                Text(size.formattedBytes)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(size > 1_000_000_000 ? .orange : .primary)
            } else {
                Text("Not scanned")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(height: 160)
        .background(isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.8) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? safetyColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
    }

    private var safetyColor: Color {
        switch category.safetyLevel {
        case .safe: return .green
        case .caution: return .yellow
        case .risky: return .red
        }
    }
}

// MARK: - Safety Badge
struct SafetyBadge: View {
    let level: SafetyLevel

    var body: some View {
        Text(level.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch level {
        case .safe: return .green.opacity(0.2)
        case .caution: return .yellow.opacity(0.2)
        case .risky: return .red.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch level {
        case .safe: return .green
        case .caution: return .orange
        case .risky: return .red
        }
    }
}

#Preview {
    DashboardView(diskSpaceManager: DiskSpaceManager(), selectedCategory: .constant(nil))
        .frame(width: 800, height: 600)
}
