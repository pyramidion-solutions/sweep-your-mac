import Foundation
import SwiftUI
import os.log

/// Manages Full Disk Access permission checking and user guidance
@MainActor
class PermissionManager: ObservableObject {
    @Published var hasFullDiskAccess: Bool = false
    @Published var lastCheckTime: Date?

    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sweepyourmac", category: "Permissions")

    init() {
        checkPermissions()
    }

    /// Checks if the app has Full Disk Access by testing protected paths
    func checkPermissions() {
        // Test multiple protected paths for reliability
        // ~/Library/Mail requires Full Disk Access
        let testPaths = [
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mail").path,
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Safari").path
        ]

        hasFullDiskAccess = testPaths.contains { fileManager.isReadableFile(atPath: $0) }
        lastCheckTime = Date()

        if hasFullDiskAccess {
            logger.info("Full Disk Access is granted")
        } else {
            logger.warning("Full Disk Access is NOT granted - some features will be limited")
        }
    }

    /// Opens System Preferences to the Full Disk Access settings
    func openSystemPreferences() {
        // Deep link to Privacy & Security > Full Disk Access
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
            logger.info("Opened System Preferences for Full Disk Access")
        }
    }
}
