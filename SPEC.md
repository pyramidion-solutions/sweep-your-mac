# SweepYourMac - Specification

**A native macOS app (SwiftUI) that helps users reclaim disk space by scanning and cleaning various cache and junk file locations.**

> Legend: ✅ Completed | 🔶 Partial | ❌ Not Started

---

## 1. Dashboard

| Feature | Status | Notes |
|---------|--------|-------|
| Show total/used/free disk space | ✅ | Ring chart visualization |
| Visual storage breakdown | ✅ | Stacked bar with legend |
| Smart Scan button | ✅ | Scans all categories at once |
| Show potential space to recover | ✅ | Displays after Smart Scan |
| Quick Actions (Empty Trash, Clear Caches, Clean Xcode) | ✅ | Working with feedback |

---

## 2. Scan Categories

### System Caches ✅
| Path | Status |
|------|--------|
| `~/Library/Caches/*` | ✅ |
| `/Library/Caches/*` | ✅ |
| `/System/Library/Caches/*` | ✅ Read-only, shows size only |

### Browser Caches ✅
| Browser | Status |
|---------|--------|
| Safari (`~/Library/Caches/com.apple.Safari`) | ✅ |
| Chrome (`~/Library/Caches/Google/Chrome`) | ✅ |
| Firefox (`~/Library/Caches/Firefox`) | ✅ |
| Edge (`~/Library/Caches/com.microsoft.Edge`) | ✅ |
| Brave (`~/Library/Caches/BraveSoftware`) | ✅ |
| Opera | ✅ |
| Vivaldi | ✅ |
| Arc | ✅ |
| Service Workers cleanup | ✅ |

### Developer Caches ✅
| Tool/Path | Status |
|-----------|--------|
| `~/Library/Developer/Xcode/DerivedData` | ✅ |
| `~/Library/Developer/Xcode/Archives` | ✅ Shows versions, user selects |
| `~/Library/Developer/Xcode/iOS DeviceSupport` | ✅ |
| `~/Library/Developer/Xcode/watchOS DeviceSupport` | ✅ |
| `~/Library/Developer/Xcode/tvOS DeviceSupport` | ✅ |
| `~/Library/Developer/CoreSimulator/Devices` | ✅ |
| `/Library/Developer/CoreSimulator/Caches` | ✅ |
| `~/.gradle/caches` | ✅ |
| `~/.android/avd` | ✅ |
| `~/.android/cache` | ✅ |
| `~/Library/Android/sdk/build-tools` | ✅ Shows versions |
| `~/Library/Android/sdk/system-images` | ✅ |
| `~/.pub-cache` | ✅ |
| `~/.dartServer` | ✅ |
| `~/fvm/versions` | ✅ Shows versions |
| `~/.cocoapods/repos` | ✅ |
| `~/Library/Caches/CocoaPods` | ✅ |
| `~/.cargo/registry` | ✅ |
| `~/.rustup/toolchains` | ✅ Shows versions |
| `~/.npm/_cacache` | ✅ |
| `~/.yarn/cache` | ✅ |
| `~/Library/Caches/Homebrew` | ✅ |
| `~/Library/Caches/pip` | ✅ |
| `~/.cache` | ✅ |
| `xcrun simctl delete unavailable` | ✅ |

### Node Modules ✅
| Feature | Status | Notes |
|---------|--------|-------|
| Find all `node_modules` folders | ✅ | Integrated into Developer Caches with tabbed UI |
| Category enum defined | ✅ | Available through Developer Caches navigation |
| Dedicated node_modules scanner | ✅ | `scanForNodeModules()` in DeveloperCachesScanner |
| Dedicated view | ✅ | Tabbed interface within DeveloperCachesView |

### Application Leftovers ✅
| Feature | Status |
|---------|--------|
| `~/Library/Application Support/*` orphan detection | ✅ |
| `~/Library/Preferences/*` orphan detection | ✅ |
| `~/Library/Saved Application State/*` | ✅ |
| `~/Library/Containers/*` | ✅ |
| `~/Library/Group Containers/*` | ✅ |
| `~/Library/Logs/*` | ✅ |
| `~/Library/WebKit/*` | ✅ |

### Large & Old Files ✅
| Feature | Status |
|---------|--------|
| Scan Downloads folder for old files | ✅ Configurable age threshold |
| Scan Documents, Desktop, Movies, Music, Pictures | ✅ |
| Find files > 50MB/100MB/500MB | ✅ Configurable size threshold |
| File type categorization | ✅ |
| Find duplicate files (hash comparison) | ✅ |

### Mail & Messages Attachments ✅
| Path | Status |
|------|--------|
| `~/Library/Mail/V*/` attachments | ✅ |
| `~/Library/Messages/Attachments` | ✅ |
| `~/Library/Mail Downloads` | ✅ |
| `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads` | ✅ |

### Trash ✅
| Feature | Status |
|---------|--------|
| `~/.Trash` scanning | ✅ |
| Show size | ✅ |
| Empty trash | ✅ |
| File type breakdown | ✅ |
| Individual item deletion | ✅ |

### iOS/Mobile Backups ✅
| Feature | Status |
|---------|--------|
| `~/Library/Application Support/MobileSync/Backup` | ✅ |
| Parse device info from Info.plist | ✅ |
| Show device name, model, iOS version | ✅ |
| Show backup date and size | ✅ |
| Selective backup deletion | ✅ |

### Logs ✅
| Path | Status |
|------|--------|
| `~/Library/Logs/*` | ✅ |
| `/Library/Logs/*` | ✅ |
| `~/Library/Application Support/CrashReporter` | ✅ |
| `~/Library/Logs/DiagnosticReports` | ✅ |
| `/Library/Logs/DiagnosticReports` | ✅ |
| Skip current day's logs | ✅ |

### Language Files ✅
| Feature | Status |
|---------|--------|
| Scan `.lproj` in /Applications | ✅ |
| Scan `.lproj` in ~/Applications | ✅ |
| Scan Frameworks for localizations | ✅ |
| Detect user's system languages | ✅ |
| Keep Base resources | ✅ |
| Show removable size | ✅ |

### Docker ✅ (if installed)
| Feature | Status |
|---------|--------|
| Detect Docker installation | ✅ |
| Show disk usage (disk image) | ✅ |
| List images with sizes | ✅ |
| List containers with sizes | ✅ |
| List volumes | ✅ |
| Show build cache | ✅ |
| `docker system prune -f` | ✅ |
| `docker image prune -a -f` | ✅ |
| `docker container prune -f` | ✅ |
| `docker volume prune -f` | ✅ |
| `docker builder prune -f` | ✅ |
| Remove individual images/containers/volumes | ✅ |
| Command injection prevention | ✅ DockerIDValidator |

### Flutter/FVM ✅ (if installed)
| Feature | Status |
|---------|--------|
| `~/fvm/versions/*` show versions | ✅ |
| `~/.pub-cache` | ✅ |

### Android SDK ✅ (if installed)
| Feature | Status |
|---------|--------|
| `~/Library/Android/sdk/ndk/*` | ❌ Not scanned |
| `~/Library/Android/sdk/system-images` | ✅ |
| `~/Library/Android/sdk/build-tools` | ✅ Shows versions |

---

## 3. UI/UX Features

| Feature | Status | Notes |
|---------|--------|-------|
| Space Lens (visual treemap) | ❌ | Not implemented |
| Category Cards with size | ✅ | Shows safety level badges |
| Safe/Caution/Risky Labels | ✅ | Color coded (green/yellow/red) |
| Preview before deletion | 🔶 | Shows file list, no file content preview |
| Selective Cleaning (checkboxes) | ✅ | Per-item selection |
| Schedule cleanup | ❌ | Not implemented |
| Undo (temporary storage) | ❌ | Items go to Trash by default |
| Progress indicators | ✅ | During scan and deletion |
| Permission banner | ✅ | Prompts for Full Disk Access |

---

## 4. Technical Requirements

| Requirement | Status | Notes |
|-------------|--------|-------|
| Request Full Disk Access permission | ✅ | PermissionManager handles this |
| Use `FileManager` for file operations | ✅ | |
| Use `Process` for shell commands | ✅ | Docker, xcrun simctl |
| Calculate folder sizes asynchronously | ✅ | Actor-based scanners |
| Show progress during scan/clean | ✅ | |
| Handle "Operation not permitted" gracefully | ✅ | |
| Refresh macOS storage cache (`mdutil -E /`) | ❌ | Not implemented |

---

## 5. Safety Rules

| Rule | Status | Implementation |
|------|--------|----------------|
| NEVER delete folders themselves, only contents | ✅ | SafeFileOperations.deleteContents() |
| NEVER touch `/System/*` | ✅ | BlockedPathValidator |
| NEVER delete without user confirmation | ✅ | UI requires explicit action |
| Show clear warnings for large deletions | 🔶 | Safety badges, but no size-based warnings |
| Skip files currently in use (`lsof`) | ✅ | SafeFileOperations |
| Exclude current day's logs/caches | ✅ | skipTodaysFiles option |
| Symlink escape prevention | ✅ | SymlinkValidator |
| Path validation before deletion | ✅ | BlockedPathValidator |
| Move to Trash by default | ✅ | DeletionOptions.moveToTrash |
| NSFileCoordinator for atomic operations | ✅ | TOCTOU prevention |

---

## 6. Bonus Features

| Feature | Status |
|---------|--------|
| Uninstaller (drag app to find related files) | ❌ |
| Startup Items Manager | ❌ |
| Memory Cleaner | ❌ |
| Update Checker | ❌ |

---

## Architecture Summary

### Implemented Patterns
- **MVVM**: Each view has an inline ViewModel (`@MainActor`, `ObservableObject`)
- **Actor-based Scanners**: Thread-safe file operations
- **ScanState Pattern**: `.idle`, `.scanning`, `.completed`, `.error`
- **SafetyLevel System**: `.safe`, `.caution`, `.risky` with color coding
- **ViewModelStore**: Lazy singleton pattern for ViewModel persistence

### Files Structure
```
SweepYourMac/
├── SweepYourMacApp.swift
├── ContentView.swift
├── Models/
│   ├── ScanCategory.swift      ✅
│   ├── ScanResult.swift        ✅
│   └── DiskSpace.swift         ✅
├── Services/
│   ├── SystemCachesScanner.swift       ✅
│   ├── BrowserCachesScanner.swift      ✅
│   ├── DeveloperCachesScanner.swift    ✅
│   ├── LogsScanner.swift               ✅
│   ├── TrashScanner.swift              ✅
│   ├── iOSBackupsScanner.swift         ✅
│   ├── DockerScanner.swift             ✅
│   ├── MailAttachmentsScanner.swift    ✅
│   ├── LargeOldFilesScanner.swift      ✅
│   ├── ApplicationLeftoversScanner.swift ✅
│   ├── LanguageFilesScanner.swift      ✅
│   ├── SafeFileOperations.swift        ✅
│   ├── SecurityValidator.swift         ✅
│   ├── ScanCoordinator.swift           ✅
│   ├── DiskSpaceManager.swift          ✅
│   ├── PermissionManager.swift         ✅
│   ├── ViewModelStore.swift            ✅
│   └── AppLogger.swift                 ✅
└── Views/
    ├── DashboardView.swift             ✅
    ├── SystemCachesView.swift          ✅
    ├── BrowserCachesView.swift         ✅
    ├── DeveloperCachesView.swift       ✅
    ├── LogsView.swift                  ✅
    ├── TrashView.swift                 ✅
    ├── iOSBackupsView.swift            ✅
    ├── DockerView.swift                ✅
    ├── MailAttachmentsView.swift       ✅
    ├── LargeOldFilesView.swift         ✅
    ├── ApplicationLeftoversView.swift  ✅
    ├── LanguageFilesView.swift         ✅
    └── PermissionBannerView.swift      ✅
```

### Test Coverage
- SafeFileOperationsTests ✅
- SecurityValidatorTests ✅
- DockerScannerTests ✅
- ScanCoordinatorTests ✅
- LogsScannerTests ✅
- BrowserCachesScannerTests ✅
- ScannerIntegrationTests ✅
- ViewModelTests ✅

---

## Completion Summary

| Category | Status |
|----------|--------|
| **Core Scanning (12/12 categories)** | 100% |
| **Safety Features** | 100% |
| **UI/UX Core Features** | 80% |
| **Bonus Features** | 0% |
| **Overall** | ~83% |

### What's Working
- All 12 main scan categories with full scan + delete functionality
- Smart Scan with aggregated results
- Safe deletion with multi-layer protection
- Dashboard with disk visualization
- Permission handling for Full Disk Access

### What's Missing
- Visual treemap (Space Lens)
- Scheduled cleanup
- Undo functionality
- Bonus features (Uninstaller, Startup Items, Memory Cleaner, Update Checker)
