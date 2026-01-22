# Implementation Plan: Enhanced Safety Features

## Overview
Implement 10 safety improvements to make SweepYourMac's deletion safety "excellent":
1. Dry-run/preview mode
2. Deletion audit log
3. Size threshold confirmation
4. Extended attributes check (immutable flags)
5. Finder tags respect
6. Recovery manifest
7. Move-to-trash as default option
8. SIP-aware path detection
9. Improved lsof check for individual files
10. Cancellation support for batch deletion

---

## Files to Create

### 1. `Services/DeletionSettings.swift`
User preferences for safe deletion behavior.

```swift
// Stores user preferences using @AppStorage
class DeletionSettings: ObservableObject {
    @AppStorage("moveToTrashByDefault") var moveToTrashByDefault: Bool = true
    @AppStorage("showPreviewBeforeDelete") var showPreviewBeforeDelete: Bool = true
    @AppStorage("largeDeleteThresholdGB") var largeDeleteThresholdGB: Double = 1.0
    @AppStorage("respectFinderTags") var respectFinderTags: Bool = true
    @AppStorage("skipImmutableFiles") var skipImmutableFiles: Bool = true
    @AppStorage("enableAuditLog") var enableAuditLog: Bool = true
}
```

### 2. `Services/DeletionAuditLog.swift`
Persistent audit logging for accountability.

```swift
// Features:
// - Logs all deletions to ~/Library/Application Support/SweepYourMac/audit-logs/
// - Records: timestamp, path, size, category, wasMovedToTrash
// - Export to CSV functionality
// - Auto-cleanup of logs older than 90 days
struct DeletionAuditLog {
    struct Entry: Codable { ... }
    static func record(entries: [Entry]) async
    static func export() async -> URL
    static func pruneOldEntries() async
}
```

### 3. `Services/DeletionPreview.swift`
Preview/dry-run models for showing what will be deleted.

```swift
// Models for preview step
struct PreviewItem {
    let path: String
    let size: Int64
    let willDelete: Bool
    let skipReason: SkipReason?
}

enum SkipReason {
    case fileInUse
    case immutableFlag
    case importantTag
    case sipProtected
    case symlinkEscape
    case blockedPath
}

// Preview generator
actor DeletionPreviewGenerator {
    func generatePreview(
        for paths: [String],
        options: DeletionOptions,
        cancellationToken: CancellationToken
    ) async -> [PreviewItem]
}
```

### 4. `Views/DeletionPreviewSheet.swift`
SwiftUI sheet showing preview before actual deletion.

```swift
// Shows:
// - List of items to delete with sizes
// - Items that will be skipped and why
// - Total size to be freed
// - "Move to Trash" vs "Permanent Delete" toggle
// - Cancel / Confirm buttons
// - Extra confirmation for large deletions (>threshold)
```

### 5. `Views/SettingsView.swift`
Settings panel for deletion preferences.

```swift
// Settings categories:
// - Safety: move to trash, preview before delete, respect tags
// - Thresholds: large deletion warning size
// - Audit: enable logging, export logs, clear logs
```

---

## Files to Modify

### 6. `Services/SecurityValidator.swift`
Add SIP-protected paths.

```swift
// Add to BlockedPathValidator:
static let sipProtectedPaths: [String] = [
    "/System/Library",
    "/usr/bin",
    "/usr/lib",
    "/usr/sbin",
    "/usr/share",
    "/bin",
    "/sbin",
]

// Add method:
static func isSIPProtected(_ path: String) -> Bool
```

### 7. `Services/SafeFileOperations.swift`
Major enhancements:

```swift
// 1. Add to DeletionOptions:
struct DeletionOptions {
    // ... existing ...
    let skipImmutableFiles: Bool
    let respectFinderTags: Bool
    let cancellationToken: CancellationToken?
}

// 2. Add new checks before deletion:
private func hasProtectionFlags(at url: URL) -> Bool {
    // Check isUserImmutable, isSystemImmutable
}

private func hasImportantTag(at url: URL) -> Bool {
    // Check Finder tags for "Important" or color labels
}

// 3. Improve isItemInUse to check individual files:
private func isFileInUse(at path: String) async -> Bool {
    // Use lsof without +D flag for single file check
}

// 4. Add cancellation support:
func deleteItems(
    _ paths: [String],
    options: DeletionOptions,
    progressHandler: ((Int, Int) -> Void)? = nil
) async -> BatchDeletionResult {
    for path in paths {
        // Check cancellation before each item
        if options.cancellationToken?.isCancelled == true {
            break
        }
        // ... existing deletion logic
    }
}

// 5. Add preview method:
func previewDeletion(
    _ paths: [String],
    options: DeletionOptions
) async -> [PreviewItem]

// 6. Add manifest generation:
func generateManifest(
    for paths: [String]
) async -> DeletionManifest
```

### 8. `Services/AppLogger.swift`
Add audit log category.

```swift
// Add:
static let audit = Logger(subsystem: subsystem, category: "Audit")
```

### 9. `SweepYourMacApp.swift`
Add settings as environment object.

```swift
@main
struct SweepYourMacApp: App {
    @StateObject private var deletionSettings = DeletionSettings()
    // ...

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deletionSettings)
                // ...
        }

        Settings {
            SettingsView()
                .environmentObject(deletionSettings)
        }
    }
}
```

### 10. `Views/SystemCachesView.swift` (and all other category views)
Update deletion flow to use preview.

```swift
// In ViewModel:
@Published var showPreviewSheet = false
@Published var previewItems: [PreviewItem] = []
@Published var deletionCancellationToken = CancellationToken()

func initiateDelete() async {
    if settings.showPreviewBeforeDelete {
        // Generate preview first
        previewItems = await generatePreview()
        showPreviewSheet = true
    } else {
        await performDelete()
    }
}

func confirmDelete(moveToTrash: Bool) async {
    // Check for large deletion warning
    if totalSize > settings.largeDeleteThresholdBytes {
        showLargeDeletionWarning = true
        return
    }
    await performDelete(moveToTrash: moveToTrash)
}
```

### 11. Fix `Views/ApplicationLeftoversView.swift` and `Views/LanguageFilesView.swift`
Replace print() with AppLogger.

```swift
// Line 632 and 718 respectively:
// Change: print("Failed to remove \(result.failed) items")
// To: AppLogger.deletion.error("Failed to remove \(result.failed) items")
```

---

## Implementation Order

| Step | Task | Files |
|------|------|-------|
| 1 | Create settings infrastructure | DeletionSettings.swift, SettingsView.swift, SweepYourMacApp.swift |
| 2 | Add SIP detection | SecurityValidator.swift |
| 3 | Add protection checks | SafeFileOperations.swift (immutable, tags, lsof) |
| 4 | Add cancellation support | SafeFileOperations.swift, new CancellationToken |
| 5 | Create preview system | DeletionPreview.swift, DeletionPreviewSheet.swift |
| 6 | Create audit log | DeletionAuditLog.swift, AppLogger.swift |
| 7 | Update all views | SystemCachesView.swift + 11 other views |
| 8 | Fix print statements | ApplicationLeftoversView.swift, LanguageFilesView.swift |
| 9 | Add tests | SafeFileOperationsTests.swift additions |

---

## Safety Considerations

- All new features default to **safer** options (move to trash ON, preview ON)
- Audit log stored locally, never transmitted
- Settings persisted via @AppStorage (UserDefaults)
- Cancellation is cooperative - checks between each file, not mid-deletion
- Preview is read-only - no modifications during preview generation
- Manifest written atomically before deletion begins

---

## Testing Strategy

Add tests for:
1. Immutable file detection
2. Finder tag detection
3. SIP path detection
4. Cancellation mid-batch
5. Preview generation accuracy
6. Audit log write/read/export
7. Large deletion threshold logic
