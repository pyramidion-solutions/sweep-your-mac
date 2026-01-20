import Foundation
import SwiftUI

/// Central store for all category ViewModels to preserve state across tab switches.
/// ViewModels are created lazily on first access using Swift's thread-safe lazy semantics.
@MainActor
class ViewModelStore: ObservableObject {

    // MARK: - Lazy ViewModels (thread-safe under @MainActor)

    lazy var systemCachesViewModel = SystemCachesViewModel()
    lazy var browserCachesViewModel = BrowserCachesViewModel()
    lazy var developerCachesViewModel = DeveloperCachesViewModel()
    lazy var trashViewModel = TrashViewModel()
    lazy var logsViewModel = LogsViewModel()
    lazy var dockerViewModel = DockerViewModel()
    lazy var iOSBackupsVM = iOSBackupsViewModel()
    lazy var largeOldFilesViewModel = LargeOldFilesViewModel()
    lazy var mailAttachmentsViewModel = MailAttachmentsViewModel()
    lazy var applicationLeftoversViewModel = ApplicationLeftoversViewModel()
    lazy var languageFilesViewModel = LanguageFilesViewModel()
}
