import Foundation

enum ScanCategory: String, CaseIterable, Identifiable, Hashable {
    case systemCaches = "system_caches"
    case browserCaches = "browser_caches"
    case developerCaches = "developer_caches"
    case applicationLeftovers = "application_leftovers"
    case largeOldFiles = "large_old_files"
    case mailAttachments = "mail_attachments"
    case trash = "trash"
    case iosBackups = "ios_backups"
    case logs = "logs"
    case languageFiles = "language_files"
    case docker = "docker"
    case nodeModules = "node_modules"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemCaches: return "System Caches"
        case .browserCaches: return "Browser Caches"
        case .developerCaches: return "Developer Caches"
        case .applicationLeftovers: return "App Leftovers"
        case .largeOldFiles: return "Large & Old Files"
        case .mailAttachments: return "Mail Attachments"
        case .trash: return "Trash"
        case .iosBackups: return "iOS Backups"
        case .logs: return "Logs"
        case .languageFiles: return "Language Files"
        case .docker: return "Docker"
        case .nodeModules: return "Node Modules"
        }
    }

    var iconName: String {
        switch self {
        case .systemCaches: return "internaldrive"
        case .browserCaches: return "globe"
        case .developerCaches: return "hammer"
        case .applicationLeftovers: return "app.badge.checkmark"
        case .largeOldFiles: return "doc.badge.clock"
        case .mailAttachments: return "paperclip"
        case .trash: return "trash"
        case .iosBackups: return "iphone"
        case .logs: return "doc.text"
        case .languageFiles: return "globe.americas"
        case .docker: return "shippingbox"
        case .nodeModules: return "shippingbox.fill"
        }
    }

    var safetyLevel: SafetyLevel {
        switch self {
        case .systemCaches, .browserCaches, .logs, .trash:
            return .safe
        case .developerCaches, .languageFiles, .nodeModules, .docker:
            return .caution
        case .applicationLeftovers, .largeOldFiles, .mailAttachments, .iosBackups:
            return .risky
        }
    }

    var description: String {
        switch self {
        case .systemCaches:
            return "Temporary files created by macOS and applications"
        case .browserCaches:
            return "Cached data from web browsers"
        case .developerCaches:
            return "Build artifacts, simulators, and development tools"
        case .applicationLeftovers:
            return "Files left behind by uninstalled applications"
        case .largeOldFiles:
            return "Large files and files not accessed recently"
        case .mailAttachments:
            return "Attachments from Mail and Messages apps"
        case .trash:
            return "Files in your Trash waiting to be deleted"
        case .iosBackups:
            return "Device backups from iTunes/Finder"
        case .logs:
            return "System and application log files"
        case .languageFiles:
            return "Unused language localizations in apps"
        case .docker:
            return "Docker images, containers, and volumes"
        case .nodeModules:
            return "Node.js dependencies in project folders"
        }
    }
}

enum SafetyLevel: String {
    case safe = "Safe"
    case caution = "Caution"
    case risky = "Risky"

    var color: String {
        switch self {
        case .safe: return "green"
        case .caution: return "yellow"
        case .risky: return "red"
        }
    }
}
