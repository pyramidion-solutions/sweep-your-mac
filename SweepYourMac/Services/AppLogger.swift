import Foundation
import os.log

/// Centralized logging for SweepYourMac using Apple's unified logging system
struct AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sweepyourmac"

    /// Logger for scanner operations (scanning directories, finding files)
    static let scanner = Logger(subsystem: subsystem, category: "Scanner")

    /// Logger for deletion operations (removing files, emptying trash)
    static let deletion = Logger(subsystem: subsystem, category: "Deletion")

    /// Logger for permission-related events
    static let permissions = Logger(subsystem: subsystem, category: "Permissions")

    /// Logger for general application events
    static let general = Logger(subsystem: subsystem, category: "General")
}
