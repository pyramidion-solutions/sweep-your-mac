import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var diskSpaceManager: DiskSpaceManager
    @State private var selectedCategory: ScanCategory? = nil

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCategory: $selectedCategory)
        } detail: {
            if let category = selectedCategory {
                CategoryDetailView(category: category)
            } else {
                DashboardView(diskSpaceManager: diskSpaceManager, selectedCategory: $selectedCategory)
            }
        }
        .frame(minWidth: 800, minHeight: 550)
    }
}

struct SidebarView: View {
    @Binding var selectedCategory: ScanCategory?

    var body: some View {
        List(selection: $selectedCategory) {
            Section {
                Button(action: { selectedCategory = nil }) {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
                .buttonStyle(.plain)
                .listRowBackground(selectedCategory == nil ? Color.accentColor.opacity(0.2) : Color.clear)
            }

            Section("Categories") {
                ForEach(ScanCategory.allCases, id: \.self) { category in
                    Label(category.displayName, systemImage: category.iconName)
                        .tag(category as ScanCategory?)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("SweepYourMac")
    }
}

struct CategoryDetailView: View {
    let category: ScanCategory

    var body: some View {
        switch category {
        case .systemCaches:
            SystemCachesView()
        case .browserCaches:
            BrowserCachesView()
        case .developerCaches, .nodeModules:
            DeveloperCachesView()
        case .trash:
            TrashView()
        case .logs:
            LogsView()
        case .iosBackups:
            iOSBackupsView()
        case .mailAttachments:
            MailAttachmentsView()
        case .largeOldFiles:
            LargeOldFilesView()
        case .docker:
            DockerView()
        case .applicationLeftovers:
            ApplicationLeftoversView()
        case .languageFiles:
            LanguageFilesView()
        default:
            PlaceholderCategoryView(category: category)
        }
    }
}

struct PlaceholderCategoryView: View {
    let category: ScanCategory

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: category.iconName)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(category.displayName)
                .font(.largeTitle)
            Text("Coming soon...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(DiskSpaceManager())
        .environmentObject(ViewModelStore())
}
