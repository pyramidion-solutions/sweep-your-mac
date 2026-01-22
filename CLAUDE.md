# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

This is a native macOS SwiftUI project. Use Xcode or the command line:

```bash
# Build the project
xcodebuild -project SweepYourMac.xcodeproj -scheme SweepYourMac -configuration Debug build

# Build for release
xcodebuild -project SweepYourMac.xcodeproj -scheme SweepYourMac -configuration Release build

# Run tests (if added)
xcodebuild -project SweepYourMac.xcodeproj -scheme SweepYourMac test
```

Open with Xcode: `open SweepYourMac.xcodeproj`

## Architecture

SweepYourMac is a macOS disk cleanup utility built with SwiftUI. The app scans various system locations for cache files, logs, and other cleanable items.

### Project Structure

```
SweepYourMac/
├── SweepYourMacApp.swift    # App entry point
├── ContentView.swift        # Main navigation (sidebar + detail)
├── Models/
│   ├── ScanCategory.swift   # Enum defining all scan categories with metadata
│   ├── ScanResult.swift     # Individual scan item + CategoryScanResult wrapper
│   └── DiskSpace.swift      # Disk space model + Int64 byte formatting
├── Services/                # Scanners (actors) for each category
└── Views/                   # SwiftUI views for each category
```

### Key Patterns

**MVVM with Inline ViewModels**: Each category view (e.g., `SystemCachesView`) contains its own `@MainActor` ViewModel class at the bottom of the file. ViewModels are `ObservableObject` with `@Published` properties.

**Actor-Based Scanners**: Each scanner (e.g., `SystemCachesScanner`) is an `actor` to ensure thread-safe file operations. Scanners provide:
- `scan(progressHandler:)` - Returns `CategoryScanResult` with items found
- `deleteItems(_:)` - Removes selected items, returns deleted/failed counts

**ScanState Pattern**: Views use a `ScanState` enum to manage UI state:
- `.idle` - Initial state
- `.scanning(progress:)` - Shows progress message
- `.completed(result:)` - Shows results list
- `.error(message:)` - Shows error with retry

**Safety Levels**: Items are tagged with `SafetyLevel` (.safe/.caution/.risky) which determines:
- Color coding (green/orange/red)
- Default selection state
- Warning messages

### Category-Scanner-View Mapping

Each scan category follows the pattern:
- `ScanCategory.systemCaches` → `SystemCachesScanner` → `SystemCachesView`
- `ScanCategory.docker` → `DockerScanner` → `DockerView`
- etc.

New categories require: enum case in `ScanCategory`, scanner in Services/, view in Views/, routing in `CategoryDetailView`.

### External Tool Integration

Some scanners invoke external tools via `Process`:
- `lsof` - Check if files are in use before deletion
- `docker` - Query/prune Docker resources (DockerScanner)

## Safety Rules

Per SPEC.md, the app must:
- Never delete folders themselves, only contents
- Never touch `/System/*`
- Never delete without user confirmation
- Check if files are in use with `lsof` before deletion
- Exclude current day's logs/caches
- Show clear warnings for large deletions

## Entitlements

The app runs **without sandboxing** (`com.apple.security.app-sandbox = false`) to access system directories. Requires Full Disk Access permission from users for full functionality.
