import Foundation
import AppKit

actor BrowserCachesScanner {
    private let fileManager = FileManager.default

    enum Browser: String, CaseIterable, Identifiable {
        case safari = "Safari"
        case chrome = "Chrome"
        case firefox = "Firefox"
        case edge = "Edge"
        case brave = "Brave"
        case opera = "Opera"
        case vivaldi = "Vivaldi"
        case arc = "Arc"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .safari: return "safari"
            case .chrome: return "globe"
            case .firefox: return "flame"
            case .edge: return "globe.americas"
            case .brave: return "shield"
            case .opera: return "o.circle"
            case .vivaldi: return "v.circle"
            case .arc: return "circle.grid.cross"
            }
        }

        var bundleIdentifier: String {
            switch self {
            case .safari: return "com.apple.Safari"
            case .chrome: return "com.google.Chrome"
            case .firefox: return "org.mozilla.firefox"
            case .edge: return "com.microsoft.edgemac"
            case .brave: return "com.brave.Browser"
            case .opera: return "com.operasoftware.Opera"
            case .vivaldi: return "com.vivaldi.Vivaldi"
            case .arc: return "company.thebrowser.Browser"
            }
        }

        var appName: String {
            switch self {
            case .safari: return "Safari"
            case .chrome: return "Google Chrome"
            case .firefox: return "Firefox"
            case .edge: return "Microsoft Edge"
            case .brave: return "Brave Browser"
            case .opera: return "Opera"
            case .vivaldi: return "Vivaldi"
            case .arc: return "Arc"
            }
        }
    }

    struct BrowserCacheLocation {
        let browser: Browser
        let path: String
        let type: CacheType
        let description: String

        enum CacheType: String {
            case cache = "Cache"
            case cookies = "Cookies"
            case history = "History"
            case localStorage = "Local Storage"
            case sessionStorage = "Session Storage"
            case serviceWorkers = "Service Workers"
            case webData = "Web Data"
        }
    }

    private var cacheLocations: [BrowserCacheLocation] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let libraryPath = "\(home)/Library"

        return [
            // Safari
            BrowserCacheLocation(
                browser: .safari,
                path: "\(libraryPath)/Caches/com.apple.Safari",
                type: .cache,
                description: "Safari browser cache"
            ),
            BrowserCacheLocation(
                browser: .safari,
                path: "\(libraryPath)/Safari/LocalStorage",
                type: .localStorage,
                description: "Safari local storage data"
            ),

            // Chrome
            BrowserCacheLocation(
                browser: .chrome,
                path: "\(libraryPath)/Caches/Google/Chrome",
                type: .cache,
                description: "Chrome browser cache"
            ),
            BrowserCacheLocation(
                browser: .chrome,
                path: "\(libraryPath)/Caches/Google/Chrome/Default/Cache",
                type: .cache,
                description: "Chrome default profile cache"
            ),
            BrowserCacheLocation(
                browser: .chrome,
                path: "\(libraryPath)/Application Support/Google/Chrome/Default/Service Worker",
                type: .serviceWorkers,
                description: "Chrome service workers"
            ),

            // Firefox
            BrowserCacheLocation(
                browser: .firefox,
                path: "\(libraryPath)/Caches/Firefox",
                type: .cache,
                description: "Firefox browser cache"
            ),
            BrowserCacheLocation(
                browser: .firefox,
                path: "\(libraryPath)/Caches/org.mozilla.firefox",
                type: .cache,
                description: "Firefox app cache"
            ),

            // Edge
            BrowserCacheLocation(
                browser: .edge,
                path: "\(libraryPath)/Caches/com.microsoft.Edge",
                type: .cache,
                description: "Edge browser cache"
            ),
            BrowserCacheLocation(
                browser: .edge,
                path: "\(libraryPath)/Caches/Microsoft Edge",
                type: .cache,
                description: "Edge additional cache"
            ),
            BrowserCacheLocation(
                browser: .edge,
                path: "\(libraryPath)/Application Support/Microsoft Edge/Default/Service Worker",
                type: .serviceWorkers,
                description: "Edge service workers"
            ),

            // Brave
            BrowserCacheLocation(
                browser: .brave,
                path: "\(libraryPath)/Caches/BraveSoftware",
                type: .cache,
                description: "Brave browser cache"
            ),
            BrowserCacheLocation(
                browser: .brave,
                path: "\(libraryPath)/Caches/com.brave.Browser",
                type: .cache,
                description: "Brave app cache"
            ),
            BrowserCacheLocation(
                browser: .brave,
                path: "\(libraryPath)/Application Support/BraveSoftware/Brave-Browser/Default/Service Worker",
                type: .serviceWorkers,
                description: "Brave service workers"
            ),

            // Opera
            BrowserCacheLocation(
                browser: .opera,
                path: "\(libraryPath)/Caches/com.operasoftware.Opera",
                type: .cache,
                description: "Opera browser cache"
            ),
            BrowserCacheLocation(
                browser: .opera,
                path: "\(libraryPath)/Application Support/com.operasoftware.Opera/Service Worker",
                type: .serviceWorkers,
                description: "Opera service workers"
            ),

            // Vivaldi
            BrowserCacheLocation(
                browser: .vivaldi,
                path: "\(libraryPath)/Caches/Vivaldi",
                type: .cache,
                description: "Vivaldi browser cache"
            ),
            BrowserCacheLocation(
                browser: .vivaldi,
                path: "\(libraryPath)/Caches/com.vivaldi.Vivaldi",
                type: .cache,
                description: "Vivaldi app cache"
            ),

            // Arc
            BrowserCacheLocation(
                browser: .arc,
                path: "\(libraryPath)/Caches/company.thebrowser.Browser",
                type: .cache,
                description: "Arc browser cache"
            ),
            BrowserCacheLocation(
                browser: .arc,
                path: "\(libraryPath)/Application Support/Arc/User Data/Default/Service Worker",
                type: .serviceWorkers,
                description: "Arc service workers"
            )
        ]
    }

    func scan(progressHandler: @escaping (String) -> Void) async -> CategoryScanResult {
        let startTime = Date()
        var allItems: [ScanResult] = []

        // Get installed browsers
        let installedBrowsers = await getInstalledBrowsers()

        for location in cacheLocations {
            // Skip browsers that aren't installed
            guard installedBrowsers.contains(location.browser) else { continue }

            await MainActor.run {
                progressHandler("Scanning \(location.browser.rawValue) \(location.type.rawValue.lowercased())...")
            }

            guard fileManager.fileExists(atPath: location.path) else { continue }

            let size = await calculateSize(at: location.path)
            guard size > 0 else { continue }

            let itemCount = await countItems(at: location.path)
            let lastModified = getModificationDate(at: URL(fileURLWithPath: location.path))

            let result = ScanResult(
                path: location.path,
                name: "\(location.browser.rawValue) - \(location.type.rawValue)",
                size: size,
                itemCount: itemCount,
                lastModified: lastModified,
                safetyLevel: .safe,
                isReadOnly: false,
                isSelected: true
            )

            allItems.append(result)
        }

        // Sort by size descending
        allItems.sort { $0.size > $1.size }

        let totalSize = allItems.reduce(0) { $0 + $1.size }
        let duration = Date().timeIntervalSince(startTime)

        return CategoryScanResult(
            category: .browserCaches,
            items: allItems,
            totalSize: totalSize,
            scanDuration: duration
        )
    }

    func getInstalledBrowsers() async -> Set<Browser> {
        var installed: Set<Browser> = []

        for browser in Browser.allCases {
            if isBrowserInstalled(browser) {
                installed.insert(browser)
            }
        }

        return installed
    }

    private func isBrowserInstalled(_ browser: Browser) -> Bool {
        // Check if browser app exists
        let workspace = NSWorkspace.shared
        if let _ = workspace.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) {
            return true
        }

        // Fallback: check common paths
        let commonPaths = [
            "/Applications/\(browser.appName).app",
            "\(fileManager.homeDirectoryForCurrentUser.path)/Applications/\(browser.appName).app"
        ]

        for path in commonPaths {
            if fileManager.fileExists(atPath: path) {
                return true
            }
        }

        return false
    }

    func isBrowserRunning(_ browser: Browser) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == browser.bundleIdentifier }
    }

    func getRunningBrowsers() -> [Browser] {
        Browser.allCases.filter { isBrowserRunning($0) }
    }

    private func calculateSize(at path: String) async -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                return size
            }
            return 0
        }

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               values.isDirectory == false {
                totalSize += Int64(values.fileSize ?? 0)
            }
        }

        return totalSize
    }

    private func countItems(at path: String) async -> Int {
        var count = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 1
        }

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
               values.isDirectory == false {
                count += 1
            }
        }

        return count
    }

    private func getModificationDate(at url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    func deleteItems(_ items: [ScanResult], checkRunning: Bool = true) async -> (deleted: Int, failed: Int, freedSpace: Int64, runningBrowsers: [Browser]) {
        let safeOps = SafeFileOperations()
        let home = fileManager.homeDirectoryForCurrentUser.path

        // Browser caches are in user Library
        let allowedRoots = [
            "\(home)/Library/Caches",
            "\(home)/Library/Application Support"
        ]

        var deleted = 0
        var failed = 0
        var freedSpace: Int64 = 0
        var runningBrowsers: [Browser] = []

        if checkRunning {
            runningBrowsers = getRunningBrowsers()
        }

        for item in items {
            // Check if associated browser is running
            let browser = getBrowserForPath(item.path)
            if let browser = browser, checkRunning && isBrowserRunning(browser) {
                failed += 1
                if !runningBrowsers.contains(browser) {
                    runningBrowsers.append(browser)
                }
                continue
            }

            // Validate path is not blocked
            guard !BlockedPathValidator.isBlocked(item.path) else {
                failed += 1
                continue
            }

            let options = DeletionOptions.withRoots(allowedRoots, checkInUse: false)
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Delete contents, not the folder itself
                    let result = await safeOps.deleteContents(of: item.path, options: options)
                    if result.deleted > 0 {
                        deleted += 1
                        freedSpace += result.freedSpace
                    } else if result.failed > 0 {
                        failed += 1
                    }
                } else {
                    let result = await safeOps.deleteItem(at: item.path, options: options)
                    if result.success {
                        deleted += 1
                        freedSpace += result.freedBytes
                    } else {
                        failed += 1
                    }
                }
            } else {
                failed += 1
            }
        }

        return (deleted, failed, freedSpace, runningBrowsers)
    }

    private func getBrowserForPath(_ path: String) -> Browser? {
        let pathLower = path.lowercased()

        if pathLower.contains("safari") { return .safari }
        if pathLower.contains("google") || pathLower.contains("chrome") { return .chrome }
        if pathLower.contains("firefox") || pathLower.contains("mozilla") { return .firefox }
        if pathLower.contains("microsoft") || pathLower.contains("edge") { return .edge }
        if pathLower.contains("brave") { return .brave }
        if pathLower.contains("opera") { return .opera }
        if pathLower.contains("vivaldi") { return .vivaldi }
        if pathLower.contains("arc") || pathLower.contains("thebrowser") { return .arc }

        return nil
    }

    func getBrowserInfo(_ browser: Browser) async -> (installed: Bool, running: Bool, cacheSize: Int64) {
        let installed = isBrowserInstalled(browser)
        let running = isBrowserRunning(browser)

        var cacheSize: Int64 = 0
        for location in cacheLocations where location.browser == browser {
            if fileManager.fileExists(atPath: location.path) {
                cacheSize += await calculateSize(at: location.path)
            }
        }

        return (installed, running, cacheSize)
    }
}
