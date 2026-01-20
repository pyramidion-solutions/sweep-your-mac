//
//  SecurityValidator.swift
//  SweepYourMac
//
//  Security validation utilities to prevent command injection,
//  symlink traversal, and unauthorized path access.
//

import Foundation

// MARK: - Security Errors

enum SecurityError: Error, LocalizedError {
    case invalidDockerIdentifier(String, reason: String)
    case symlinkEscape(path: String, target: String)
    case blockedPath(String)
    case pathTraversal(String)
    case fileInUse(String)

    var errorDescription: String? {
        switch self {
        case .invalidDockerIdentifier(let id, let reason):
            return "Invalid Docker identifier '\(id)': \(reason)"
        case .symlinkEscape(let path, let target):
            return "Symlink at '\(path)' points outside allowed directories to '\(target)'"
        case .blockedPath(let path):
            return "Path '\(path)' is a protected system path and cannot be modified"
        case .pathTraversal(let path):
            return "Path '\(path)' contains path traversal sequences"
        case .fileInUse(let path):
            return "File at '\(path)' is currently in use"
        }
    }
}

// MARK: - Docker ID Validator

/// Validates Docker identifiers to prevent command injection attacks.
/// Docker IDs follow strict format rules that we enforce before passing to shell commands.
struct DockerIDValidator {

    /// Characters that could enable shell injection
    private static let dangerousCharacters = CharacterSet(charactersIn: ";|&$`\\\"'<>(){}[]!\n\r\t ")

    /// Valid characters for Docker image/container IDs (hexadecimal)
    private static let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")

    /// Valid characters for Docker volume names
    private static let volumeNameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-")

    /// Valid characters for Docker image names (repository:tag format)
    private static let imageNameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-:/")

    /// Validates a Docker image ID or name.
    /// Accepts: 12-char short ID, 64-char full ID, sha256:... format, or repository:tag names
    static func validateImageID(_ id: String) throws {
        guard !id.isEmpty else {
            throw SecurityError.invalidDockerIdentifier(id, reason: "ID cannot be empty")
        }

        // Check for dangerous characters first
        if id.unicodeScalars.contains(where: { dangerousCharacters.contains($0) }) {
            throw SecurityError.invalidDockerIdentifier(id, reason: "contains prohibited characters")
        }

        // Accept sha256: prefixed full IDs
        if id.hasPrefix("sha256:") {
            let hash = String(id.dropFirst(7))
            guard hash.count == 64,
                  hash.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) else {
                throw SecurityError.invalidDockerIdentifier(id, reason: "invalid sha256 hash format")
            }
            return
        }

        // Accept short (12) or full (64) hex IDs
        if id.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) {
            guard id.count == 12 || id.count == 64 else {
                throw SecurityError.invalidDockerIdentifier(id, reason: "hex ID must be 12 or 64 characters")
            }
            return
        }

        // Accept repository:tag format (e.g., "nginx:latest", "myapp")
        guard id.unicodeScalars.allSatisfy({ imageNameCharacters.contains($0) }) else {
            throw SecurityError.invalidDockerIdentifier(id, reason: "contains invalid characters for image name")
        }

        // Validate structure: no leading/trailing special chars, no double colons
        guard !id.hasPrefix(".") && !id.hasPrefix("-") && !id.hasPrefix(":"),
              !id.hasSuffix(".") && !id.hasSuffix("-") && !id.hasSuffix(":"),
              !id.contains("::") && !id.contains("..") else {
            throw SecurityError.invalidDockerIdentifier(id, reason: "malformed image name structure")
        }
    }

    /// Validates a Docker container ID or name.
    static func validateContainerID(_ id: String) throws {
        guard !id.isEmpty else {
            throw SecurityError.invalidDockerIdentifier(id, reason: "ID cannot be empty")
        }

        // Check for dangerous characters
        if id.unicodeScalars.contains(where: { dangerousCharacters.contains($0) }) {
            throw SecurityError.invalidDockerIdentifier(id, reason: "contains prohibited characters")
        }

        // Accept hex IDs (12 or 64 chars)
        if id.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) {
            guard id.count == 12 || id.count == 64 else {
                throw SecurityError.invalidDockerIdentifier(id, reason: "hex ID must be 12 or 64 characters")
            }
            return
        }

        // Accept container names: alphanumeric, underscores, hyphens, periods
        guard id.unicodeScalars.allSatisfy({ volumeNameCharacters.contains($0) }) else {
            throw SecurityError.invalidDockerIdentifier(id, reason: "contains invalid characters for container name")
        }

        guard !id.hasPrefix(".") && !id.hasPrefix("-"),
              !id.hasSuffix(".") && !id.hasSuffix("-") else {
            throw SecurityError.invalidDockerIdentifier(id, reason: "name cannot start or end with . or -")
        }
    }

    /// Validates a Docker volume name.
    /// Volume names must start with alphanumeric and contain only [a-zA-Z0-9_.-]
    static func validateVolumeName(_ name: String) throws {
        guard !name.isEmpty else {
            throw SecurityError.invalidDockerIdentifier(name, reason: "volume name cannot be empty")
        }

        // Check for dangerous characters
        if name.unicodeScalars.contains(where: { dangerousCharacters.contains($0) }) {
            throw SecurityError.invalidDockerIdentifier(name, reason: "contains prohibited characters")
        }

        // Must only contain valid volume name characters
        guard name.unicodeScalars.allSatisfy({ volumeNameCharacters.contains($0) }) else {
            throw SecurityError.invalidDockerIdentifier(name, reason: "contains invalid characters")
        }

        // Must start with alphanumeric
        guard let first = name.first,
              first.isLetter || first.isNumber else {
            throw SecurityError.invalidDockerIdentifier(name, reason: "must start with alphanumeric character")
        }
    }
}

// MARK: - Blocked Path Validator

/// Validates paths against a blocklist of system-critical directories.
/// This provides defense-in-depth beyond UI-level isReadOnly flags.
struct BlockedPathValidator {

    /// Path prefixes that should never be deleted
    static let blockedPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/Library/Apple",
        "/Library/SystemExtensions",
        "/Library/Filesystems",
        "/Library/DirectoryServices",
        "/Library/Frameworks",  // System frameworks
    ]

    /// Paths that are blocked UNLESS they are under an allowed exception
    static let conditionallyBlockedPrefixes: [String] = [
        "/var",
        "/private/var",
        "/private/etc",
    ]

    /// Exceptions to conditionally blocked prefixes (temp directories are safe)
    static let allowedExceptions: [String] = [
        "/var/folders",
        "/private/var/folders",
    ]

    /// Exact paths that should never be deleted (even their contents)
    static let blockedExactPaths: Set<String> = [
        "/",
        "/Applications",
        "/Library",
        "/Users",
        "/Volumes",
        "/cores",
        "/opt",
        "/private",
        "/tmp",
        "/dev",
        "/etc",
        "/home",
    ]

    /// Validates that a path is not in a protected system location.
    /// - Parameter path: The path to validate
    /// - Throws: SecurityError.blockedPath if the path is protected
    static func validate(_ path: String) throws {
        // Normalize and resolve the path
        let url = URL(fileURLWithPath: path)
        let normalizedPath = url.standardized.path

        // Check for path traversal attempts
        if path.contains("../") || path.contains("/..") || path.hasSuffix("/..") {
            throw SecurityError.pathTraversal(path)
        }

        // Check exact path matches
        if blockedExactPaths.contains(normalizedPath) {
            throw SecurityError.blockedPath(path)
        }

        // Check prefix matches (always blocked)
        for prefix in blockedPrefixes {
            if normalizedPath == prefix || normalizedPath.hasPrefix(prefix + "/") {
                throw SecurityError.blockedPath(path)
            }
        }

        // Check conditionally blocked prefixes (blocked unless under an allowed exception)
        for prefix in conditionallyBlockedPrefixes {
            if normalizedPath == prefix || normalizedPath.hasPrefix(prefix + "/") {
                // Check if under an allowed exception
                let isAllowed = allowedExceptions.contains { exception in
                    normalizedPath == exception || normalizedPath.hasPrefix(exception + "/")
                }
                if !isAllowed {
                    throw SecurityError.blockedPath(path)
                }
            }
        }
    }

    /// Returns true if the path is blocked, false otherwise.
    static func isBlocked(_ path: String) -> Bool {
        do {
            try validate(path)
            return false
        } catch {
            return true
        }
    }
}

// MARK: - Symlink Validator

/// Validates that paths and their contents don't contain symlinks
/// that would escape to directories outside the allowed roots.
struct SymlinkValidator {

    /// Validates that a path (and its contents if a directory) doesn't contain
    /// symlinks pointing outside the allowed root directories.
    /// - Parameters:
    ///   - path: The path to validate
    ///   - allowedRoots: List of root directories that symlinks may point to
    /// - Throws: SecurityError.symlinkEscape if an escaping symlink is found
    static func validateNoEscape(at path: String, allowedRoots: [String]) throws {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        // Check if the path itself is a symlink
        if let isSymlink = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink,
           isSymlink {
            let realPath = url.resolvingSymlinksInPath().path
            if !isPathWithinAllowedRoots(realPath, allowedRoots: allowedRoots) {
                throw SecurityError.symlinkEscape(path: path, target: realPath)
            }
        }

        // For directories, check all contents
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return
        }

        for case let itemURL as URL in enumerator {
            guard let resourceValues = try? itemURL.resourceValues(forKeys: [.isSymbolicLinkKey]),
                  resourceValues.isSymbolicLink == true else {
                continue
            }

            let realPath = itemURL.resolvingSymlinksInPath().path
            if !isPathWithinAllowedRoots(realPath, allowedRoots: allowedRoots) {
                throw SecurityError.symlinkEscape(path: itemURL.path, target: realPath)
            }
        }
    }

    /// Resolves a path to its real location and validates it's within allowed roots.
    /// - Parameters:
    ///   - path: The path to resolve and validate
    ///   - allowedRoots: List of allowed root directories
    /// - Returns: The resolved real path
    /// - Throws: SecurityError.symlinkEscape if resolved path is outside allowed roots
    static func resolveAndValidate(path: String, allowedRoots: [String]) throws -> String {
        let url = URL(fileURLWithPath: path)
        let realPath = url.resolvingSymlinksInPath().path

        guard isPathWithinAllowedRoots(realPath, allowedRoots: allowedRoots) else {
            throw SecurityError.symlinkEscape(path: path, target: realPath)
        }

        return realPath
    }

    /// Checks if a symlink at the given path points outside allowed roots.
    /// Returns nil if not a symlink, true if escapes, false if safe.
    static func checkSymlink(at path: String, allowedRoots: [String]) -> Bool? {
        let url = URL(fileURLWithPath: path)

        guard let isSymlink = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink,
              isSymlink else {
            return nil  // Not a symlink
        }

        let realPath = url.resolvingSymlinksInPath().path
        return !isPathWithinAllowedRoots(realPath, allowedRoots: allowedRoots)
    }

    // MARK: - Private Helpers

    private static func isPathWithinAllowedRoots(_ path: String, allowedRoots: [String]) -> Bool {
        let normalizedPath = URL(fileURLWithPath: path).standardized.path

        for root in allowedRoots {
            let normalizedRoot = URL(fileURLWithPath: root).standardized.path
            if normalizedPath == normalizedRoot ||
               normalizedPath.hasPrefix(normalizedRoot.hasSuffix("/") ? normalizedRoot : normalizedRoot + "/") {
                return true
            }
        }

        return false
    }
}
