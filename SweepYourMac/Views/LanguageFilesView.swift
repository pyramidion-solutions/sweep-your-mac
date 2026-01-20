import SwiftUI

struct LanguageFilesView: View {
    @EnvironmentObject private var viewModelStore: ViewModelStore

    var body: some View {
        LanguageFilesContent(viewModel: viewModelStore.languageFilesViewModel)
    }
}

private struct LanguageFilesContent: View {
    @ObservedObject var viewModel: LanguageFilesViewModel
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
                Text("Language Files")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Unused language localizations in applications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if case .completed = viewModel.state {
                HStack(spacing: 12) {
                    if !viewModel.selectedLanguages.isEmpty {
                        Text("\(viewModel.selectedLanguages.count) selected (\(viewModel.formatSize(viewModel.selectedSize)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(action: { viewModel.scan() }) {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }

                    Button(action: { viewModel.showDeleteConfirmation = true }) {
                        Label("Remove Selected", systemImage: "trash")
                    }
                    .disabled(viewModel.selectedLanguages.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding()
    }

    private var idleView: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe.americas")
                .font(.system(size: 64))
                .foregroundColor(.cyan)

            Text("Find Unused Language Files")
                .font(.title2)
                .fontWeight(.medium)

            Text("Applications often include localizations for many languages.\nRemoving unused languages can free up significant disk space.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 450)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Your system languages will be preserved")
                        .font(.caption)
                }
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Base resources are never removed")
                        .font(.caption)
                }
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Removing languages may affect app updates")
                        .font(.caption)
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

            Text("Scanning for language files...")
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

            if viewModel.languages.isEmpty {
                emptyResultsView
            } else {
                // Filter bar
                filterBar

                Divider()

                // Results list
                languagesList
            }
        }
        .alert("Remove Selected Languages?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                viewModel.removeSelected()
            }
        } message: {
            Text("This will permanently remove \(viewModel.selectedLanguages.count) language(s) totaling \(viewModel.formatSize(viewModel.selectedSize)). This may affect application updates and reinstallation may be required to restore them.")
        }
        .alert("Cleanup Complete", isPresented: $viewModel.showDeletionResult) {
            Button("OK") {
                Task {
                    await diskSpaceManager.refreshDiskSpace()
                }
            }
        } message: {
            Text("Successfully freed \(viewModel.lastFreedSpace.formattedBytes) by removing \(viewModel.lastDeletedCount) language(s).")
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 24) {
            LanguageSummaryCard(
                title: "Total Languages",
                value: "\(viewModel.languages.count)",
                subtitle: "found",
                icon: "globe",
                color: .cyan
            )

            LanguageSummaryCard(
                title: "Total Size",
                value: viewModel.formatSize(viewModel.totalSize),
                subtitle: "in localizations",
                icon: "doc.text",
                color: .blue
            )

            LanguageSummaryCard(
                title: "Removable",
                value: viewModel.formatSize(viewModel.removableSize),
                subtitle: "potential savings",
                icon: "arrow.down.circle",
                color: .green
            )

            LanguageSummaryCard(
                title: "System Languages",
                value: "\(viewModel.systemLanguages.count)",
                subtitle: "protected",
                icon: "lock.shield",
                color: .purple
            )

            Spacer()
        }
        .padding()
    }

    private var filterBar: some View {
        HStack {
            // Filter
            Picker("Show", selection: $viewModel.filter) {
                Text("All Languages").tag(LanguageFilter.all)
                Text("Removable Only").tag(LanguageFilter.removable)
                Text("System Languages").tag(LanguageFilter.system)
            }
            .pickerStyle(.segmented)
            .frame(width: 350)

            Spacer()

            // Sort
            Picker("Sort by", selection: $viewModel.sortOrder) {
                Text("Size").tag(LanguageSortOrder.size)
                Text("Name").tag(LanguageSortOrder.name)
                Text("Apps").tag(LanguageSortOrder.appCount)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            // Quick actions
            Menu {
                Button("Select All Removable") {
                    viewModel.selectAllRemovable()
                }
                Button("Deselect All") {
                    viewModel.deselectAll()
                }
                Divider()
                Button("Select Large (>50 MB)") {
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

    private var languagesList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredLanguages) { language in
                    LanguageRowView(
                        language: language,
                        isSelected: viewModel.selectedLanguages.contains(language.id),
                        isExpanded: viewModel.expandedLanguages.contains(language.id),
                        onToggleSelection: { viewModel.toggleSelection(language) },
                        onToggleExpanded: { viewModel.toggleExpanded(language) },
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

            Text("No Language Files Found")
                .font(.title2)
                .fontWeight(.medium)

            Text("No removable language localizations were found in your applications.")
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

struct LanguageRowView: View {
    let language: LanguageInfo
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
                // Selection checkbox (disabled for system languages)
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(language.isSystemLanguage || language.code == "Base")
                .opacity(language.isSystemLanguage || language.code == "Base" ? 0.4 : 1)

                // Language icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(language.isSystemLanguage ? Color.green.opacity(0.2) : Color.cyan.opacity(0.2))
                    Text(languageFlag(for: language.code))
                        .font(.title2)
                }
                .frame(width: 40, height: 40)

                // Language info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(language.displayName)
                            .font(.headline)

                        if language.isSystemLanguage {
                            Label("System", systemImage: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }

                        if language.code == "Base" {
                            Label("Required", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(language.code)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text("\(language.appCount) app\(language.appCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Size
                Text(formatSize(language.totalSize))
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
                        .padding(.leading, 64)

                    ForEach(language.locations.prefix(20)) { location in
                        HStack(spacing: 12) {
                            Image(systemName: "app.fill")
                                .frame(width: 20)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.appName)
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
                        .padding(.vertical, 6)
                        .padding(.leading, 52)
                        .background(Color.gray.opacity(0.05))
                    }

                    if language.locations.count > 20 {
                        Text("... and \(language.locations.count - 20) more locations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
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

    private func languageFlag(for code: String) -> String {
        // Map some common language codes to flag emojis
        let flagMap: [String: String] = [
            "en": "🇺🇸", "en-GB": "🇬🇧", "en-AU": "🇦🇺",
            "es": "🇪🇸", "es-419": "🇲🇽",
            "fr": "🇫🇷", "fr-CA": "🇨🇦",
            "de": "🇩🇪",
            "it": "🇮🇹",
            "pt": "🇵🇹", "pt-BR": "🇧🇷",
            "nl": "🇳🇱",
            "sv": "🇸🇪",
            "da": "🇩🇰",
            "fi": "🇫🇮",
            "nb": "🇳🇴", "no": "🇳🇴",
            "pl": "🇵🇱",
            "tr": "🇹🇷",
            "ru": "🇷🇺",
            "uk": "🇺🇦",
            "ar": "🇸🇦",
            "he": "🇮🇱",
            "hi": "🇮🇳",
            "th": "🇹🇭",
            "vi": "🇻🇳",
            "id": "🇮🇩",
            "ms": "🇲🇾",
            "zh-Hans": "🇨🇳", "zh-Hant": "🇹🇼", "zh-HK": "🇭🇰",
            "ja": "🇯🇵",
            "ko": "🇰🇷",
            "el": "🇬🇷",
            "cs": "🇨🇿",
            "sk": "🇸🇰",
            "hu": "🇭🇺",
            "ro": "🇷🇴",
            "bg": "🇧🇬",
            "hr": "🇭🇷",
            "ca": "🇪🇸",
            "Base": "📦"
        ]

        return flagMap[code] ?? "🌐"
    }
}

struct LanguageSummaryCard: View {
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

enum LanguageFilter {
    case all
    case removable
    case system
}

enum LanguageSortOrder {
    case size
    case name
    case appCount
}

@MainActor
class LanguageFilesViewModel: ObservableObject {
    enum State {
        case idle
        case scanning
        case completed
        case cancelled
        case error(String)
    }

    @Published var state: State = .idle
    @Published var scanProgress: String = ""
    @Published var languages: [LanguageInfo] = []
    @Published var systemLanguages: Set<String> = []
    @Published var selectedLanguages: Set<UUID> = []
    @Published var expandedLanguages: Set<UUID> = []
    @Published var filter: LanguageFilter = .all
    @Published var sortOrder: LanguageSortOrder = .size
    @Published var showDeleteConfirmation = false
    @Published var showDeletionResult = false
    @Published var lastFreedSpace: Int64 = 0
    @Published var lastDeletedCount: Int = 0

    private let scanner = LanguageFilesScanner()

    var totalSize: Int64 {
        languages.reduce(0) { $0 + $1.totalSize }
    }

    var removableSize: Int64 {
        languages.filter { !$0.isSystemLanguage && $0.code != "Base" }
            .reduce(0) { $0 + $1.totalSize }
    }

    var selectedSize: Int64 {
        languages.filter { selectedLanguages.contains($0.id) }
            .reduce(0) { $0 + $1.totalSize }
    }

    var filteredLanguages: [LanguageInfo] {
        var result = languages

        // Apply filter
        switch filter {
        case .all:
            break
        case .removable:
            result = result.filter { !$0.isSystemLanguage && $0.code != "Base" }
        case .system:
            result = result.filter { $0.isSystemLanguage }
        }

        // Apply sort
        switch sortOrder {
        case .size:
            result.sort { $0.totalSize > $1.totalSize }
        case .name:
            result.sort { $0.displayName.lowercased() < $1.displayName.lowercased() }
        case .appCount:
            result.sort { $0.appCount > $1.appCount }
        }

        return result
    }

    func scan() {
        state = .scanning
        selectedLanguages.removeAll()
        expandedLanguages.removeAll()

        Task {
            let result = await scanner.scan { progress in
                Task { @MainActor in
                    self.scanProgress = progress
                }
            }

            self.languages = result.languages
            self.systemLanguages = result.systemLanguages
            self.state = .completed
        }
    }

    func toggleSelection(_ language: LanguageInfo) {
        // Don't allow selecting system languages or Base
        if language.isSystemLanguage || language.code == "Base" {
            return
        }

        if selectedLanguages.contains(language.id) {
            selectedLanguages.remove(language.id)
        } else {
            selectedLanguages.insert(language.id)
        }
    }

    func toggleExpanded(_ language: LanguageInfo) {
        if expandedLanguages.contains(language.id) {
            expandedLanguages.remove(language.id)
        } else {
            expandedLanguages.insert(language.id)
        }
    }

    func selectAllRemovable() {
        let removable = languages.filter { !$0.isSystemLanguage && $0.code != "Base" }
        selectedLanguages = Set(removable.map { $0.id })
    }

    func deselectAll() {
        selectedLanguages.removeAll()
    }

    func selectLarge() {
        let largeThreshold: Int64 = 50_000_000 // 50 MB
        let large = languages.filter { !$0.isSystemLanguage && $0.code != "Base" && $0.totalSize >= largeThreshold }
        selectedLanguages = Set(large.map { $0.id })
    }

    func removeSelected() {
        let toRemove = languages.filter { selectedLanguages.contains($0.id) }

        Task {
            let result = await scanner.removeLanguages(toRemove)

            // Show success feedback
            if result.success > 0 {
                lastFreedSpace = result.freedSpace
                lastDeletedCount = result.success
                showDeletionResult = true
            }

            // Refresh the list
            self.scan()

            if result.failed > 0 {
                AppLogger.deletion.error("Failed to remove \(result.failed) language file items")
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
    LanguageFilesView()
        .frame(width: 900, height: 600)
        .environmentObject(ViewModelStore())
        .environmentObject(DiskSpaceManager())
}
