import Foundation

struct LanguageInfo: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let displayName: String
    let isSystemLanguage: Bool
    var totalSize: Int64
    var appCount: Int
    var locations: [LanguageLocation]
    var isSelected: Bool = false

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LanguageInfo, rhs: LanguageInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct LanguageLocation: Identifiable, Hashable {
    let id = UUID()
    let appName: String
    let path: String
    let size: Int64

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LanguageLocation, rhs: LanguageLocation) -> Bool {
        lhs.id == rhs.id
    }
}

struct LanguageFilesScanResult {
    let languages: [LanguageInfo]
    let totalSize: Int64
    let removableSize: Int64
    let systemLanguages: Set<String>
    let scanDate: Date
}

actor LanguageFilesScanner {
    private let fileManager = FileManager.default

    // Map of language codes to display names
    private let languageNames: [String: String] = [
        "en": "English",
        "en-GB": "English (UK)",
        "en-AU": "English (Australia)",
        "es": "Spanish",
        "es-419": "Spanish (Latin America)",
        "fr": "French",
        "fr-CA": "French (Canada)",
        "de": "German",
        "it": "Italian",
        "pt": "Portuguese",
        "pt-BR": "Portuguese (Brazil)",
        "pt-PT": "Portuguese (Portugal)",
        "nl": "Dutch",
        "sv": "Swedish",
        "da": "Danish",
        "fi": "Finnish",
        "nb": "Norwegian Bokmål",
        "no": "Norwegian",
        "pl": "Polish",
        "tr": "Turkish",
        "ru": "Russian",
        "uk": "Ukrainian",
        "ar": "Arabic",
        "he": "Hebrew",
        "hi": "Hindi",
        "th": "Thai",
        "vi": "Vietnamese",
        "id": "Indonesian",
        "ms": "Malay",
        "zh-Hans": "Chinese (Simplified)",
        "zh-Hant": "Chinese (Traditional)",
        "zh-HK": "Chinese (Hong Kong)",
        "zh-TW": "Chinese (Taiwan)",
        "ja": "Japanese",
        "ko": "Korean",
        "el": "Greek",
        "cs": "Czech",
        "sk": "Slovak",
        "hu": "Hungarian",
        "ro": "Romanian",
        "bg": "Bulgarian",
        "hr": "Croatian",
        "ca": "Catalan",
        "eu": "Basque",
        "Base": "Base Resources"
    ]

    func scan(progressHandler: @escaping (String) -> Void) async -> LanguageFilesScanResult {
        // Get system preferred languages
        let systemLanguages = getSystemLanguages()
        progressHandler("System languages: \(systemLanguages.joined(separator: ", "))")

        // Directories to scan for applications
        let appDirectories = [
            "/Applications",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]

        var languageData: [String: (size: Int64, locations: [LanguageLocation])] = [:]

        for directory in appDirectories {
            progressHandler("Scanning \(directory)...")

            guard let apps = try? fileManager.contentsOfDirectory(atPath: directory) else {
                continue
            }

            for app in apps where app.hasSuffix(".app") {
                let appPath = "\(directory)/\(app)"
                let appName = app.replacingOccurrences(of: ".app", with: "")

                // Scan Resources folder
                let resourcesPath = "\(appPath)/Contents/Resources"
                await scanForLanguages(
                    at: resourcesPath,
                    appName: appName,
                    languageData: &languageData,
                    progressHandler: progressHandler
                )

                // Also scan Frameworks for localizations
                let frameworksPath = "\(appPath)/Contents/Frameworks"
                if fileManager.fileExists(atPath: frameworksPath) {
                    await scanFrameworks(
                        at: frameworksPath,
                        appName: appName,
                        languageData: &languageData
                    )
                }
            }
        }

        progressHandler("Processing results...")

        // Convert to LanguageInfo array
        var languages: [LanguageInfo] = languageData.map { (code, data) in
            let displayName = getLanguageDisplayName(for: code)
            let isSystem = systemLanguages.contains(code) ||
                           systemLanguages.contains(where: { code.hasPrefix($0) || $0.hasPrefix(code) })

            return LanguageInfo(
                code: code,
                displayName: displayName,
                isSystemLanguage: isSystem,
                totalSize: data.size,
                appCount: Set(data.locations.map { $0.appName }).count,
                locations: data.locations.sorted { $0.size > $1.size }
            )
        }

        // Sort by size descending
        languages.sort { $0.totalSize > $1.totalSize }

        let totalSize = languages.reduce(0) { $0 + $1.totalSize }
        let removableSize = languages.filter { !$0.isSystemLanguage && $0.code != "Base" }
            .reduce(0) { $0 + $1.totalSize }

        progressHandler("Found \(languages.count) languages")

        return LanguageFilesScanResult(
            languages: languages,
            totalSize: totalSize,
            removableSize: removableSize,
            systemLanguages: systemLanguages,
            scanDate: Date()
        )
    }

    private func getSystemLanguages() -> Set<String> {
        var languages = Set<String>()

        // Get preferred languages from system
        let preferredLanguages = Locale.preferredLanguages
        for lang in preferredLanguages {
            // Add the full code
            languages.insert(lang)

            // Also add base language code (e.g., "en" from "en-US")
            if let baseCode = lang.split(separator: "-").first {
                languages.insert(String(baseCode))
            }
        }

        // Always keep Base and English
        languages.insert("Base")
        languages.insert("en")

        return languages
    }

    private func scanForLanguages(
        at resourcesPath: String,
        appName: String,
        languageData: inout [String: (size: Int64, locations: [LanguageLocation])],
        progressHandler: @escaping (String) -> Void
    ) async {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: resourcesPath) else {
            return
        }

        for item in contents where item.hasSuffix(".lproj") {
            let lprojPath = "\(resourcesPath)/\(item)"
            let languageCode = item.replacingOccurrences(of: ".lproj", with: "")
            let size = calculateDirectorySize(path: lprojPath)

            if size > 0 {
                let location = LanguageLocation(
                    appName: appName,
                    path: lprojPath,
                    size: size
                )

                if languageData[languageCode] == nil {
                    languageData[languageCode] = (size: 0, locations: [])
                }
                languageData[languageCode]?.size += size
                languageData[languageCode]?.locations.append(location)
            }
        }
    }

    private func scanFrameworks(
        at frameworksPath: String,
        appName: String,
        languageData: inout [String: (size: Int64, locations: [LanguageLocation])]
    ) async {
        guard let frameworks = try? fileManager.contentsOfDirectory(atPath: frameworksPath) else {
            return
        }

        for framework in frameworks where framework.hasSuffix(".framework") {
            let resourcesPath = "\(frameworksPath)/\(framework)/Resources"
            if fileManager.fileExists(atPath: resourcesPath) {
                await scanForLanguages(
                    at: resourcesPath,
                    appName: "\(appName) (\(framework))",
                    languageData: &languageData,
                    progressHandler: { _ in }
                )
            }

            // Also check Versions folder structure
            let versionsPath = "\(frameworksPath)/\(framework)/Versions"
            if let versions = try? fileManager.contentsOfDirectory(atPath: versionsPath) {
                for version in versions {
                    let versionResourcesPath = "\(versionsPath)/\(version)/Resources"
                    if fileManager.fileExists(atPath: versionResourcesPath) {
                        await scanForLanguages(
                            at: versionResourcesPath,
                            appName: "\(appName) (\(framework))",
                            languageData: &languageData,
                            progressHandler: { _ in }
                        )
                    }
                }
            }
        }
    }

    private func getLanguageDisplayName(for code: String) -> String {
        // Check our predefined map first
        if let name = languageNames[code] {
            return name
        }

        // Try to get display name from system
        let locale = Locale(identifier: code)
        if let displayName = Locale.current.localizedString(forIdentifier: code) {
            return displayName
        }

        // Try language code only
        if let languageName = Locale.current.localizedString(forLanguageCode: code) {
            return languageName
        }

        // Return code as fallback
        return code
    }

    private func calculateDirectorySize(path: String) -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return 0
        }

        while let file = enumerator.nextObject() as? String {
            let fullPath = "\(path)/\(file)"
            if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }

        return totalSize
    }

    func removeLanguages(_ languages: [LanguageInfo]) async -> (success: Int, failed: Int, freedSpace: Int64) {
        let safeOps = SafeFileOperations()

        // Language files are within application bundles
        let allowedRoots = [
            "/Applications",
            "/Library",
            fileManager.homeDirectoryForCurrentUser.path + "/Applications"
        ]

        var successCount = 0
        var failedCount = 0
        var freedSpace: Int64 = 0

        for language in languages {
            // Skip system languages and Base
            if language.isSystemLanguage || language.code == "Base" {
                continue
            }

            for location in language.locations {
                // Validate path is not blocked (but allow /Applications which is normally blocked)
                // Language files in apps are safe to remove
                if BlockedPathValidator.isBlocked(location.path) &&
                   !location.path.hasPrefix("/Applications/") &&
                   !location.path.contains(".app/Contents/Resources/") {
                    failedCount += 1
                    continue
                }

                let options = DeletionOptions(
                    checkInUse: false,
                    validateSymlinks: true,
                    allowedRoots: allowedRoots,
                    moveToTrash: false,
                    skipTodaysFiles: false
                )

                let size = location.size
                let result = await safeOps.deleteItem(at: location.path, options: options)
                if result.success {
                    successCount += 1
                    freedSpace += size
                } else {
                    failedCount += 1
                }
            }
        }

        return (successCount, failedCount, freedSpace)
    }
}
