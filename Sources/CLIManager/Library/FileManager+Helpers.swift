import Foundation

nonisolated(unsafe) let fm = FileManager.default
let home = URL(fileURLWithPath: NSHomeDirectory())

/// Expands a leading `~` to the current user's home directory.
/// Replaces `(str as NSString).expandingTildeInPath`, which requires the ObjC runtime.
func expandingTilde(in path: String) -> String {
    guard path.hasPrefix("~") else {
        return path
    }
    return NSHomeDirectory() + path.dropFirst()
}

func findRepoRoot() -> URL {
    // 1. Explicit environment override — useful in CI or multi-repo setups.
    if let envPath = ProcessInfo.processInfo.environment["CLI_MANAGER_REPO"] {
        let url = URL(fileURLWithPath: expandingTilde(in: envPath))
        if fm.fileExists(atPath: url.path) {
            return url
        }
    }

    // 2. Config file written by install.sh — the primary path for installed binaries.
    let configFile = home
        .appendingPathComponent(".config")
        .appendingPathComponent("cli-manager")
        .appendingPathComponent("repo")
    if let saved = try? String(contentsOf: configFile, encoding: .utf8) {
        let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let url = URL(fileURLWithPath: expandingTilde(in: trimmed))
            if fm.fileExists(atPath: url.path) {
                return url
            }
        }
    }

    // 3. Walk up from CWD looking for Package.swift — fallback for `swift run` / dev.
    var url = URL(fileURLWithPath: fm.currentDirectoryPath)
    for _ in 0..<8 {
        if fm.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            return url
        }
        url = url.deletingLastPathComponent()
    }
    return URL(fileURLWithPath: fm.currentDirectoryPath)
}

let repoRoot    = findRepoRoot()
let skillsDir   = repoRoot.appendingPathComponent("skills")
let commandsDir = repoRoot.appendingPathComponent("commands")
let dotfilesDir = repoRoot.appendingPathComponent("dotfiles")

func isSymlink(_ url: URL) -> Bool {
    (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil
}

/// Returns the absolute, standardized path that `symlink` resolves to.
/// `destinationOfSymbolicLink` can return a relative path; this resolves
/// it against the symlink's parent directory before standardizing.
func symlinkDestination(at symlink: URL) -> String? {
    guard let dest = try? fm.destinationOfSymbolicLink(atPath: symlink.path) else { return nil }
    if dest.hasPrefix("/") {
        return URL(fileURLWithPath: dest).standardized.path
    }
    return symlink.deletingLastPathComponent()
        .appendingPathComponent(dest)
        .standardized.path
}

/// Returns true when `url` is located inside `ancestor`, verified by comparing
/// path components rather than a raw string prefix. This prevents false matches
/// on paths that share a common string prefix (e.g. `/repo` vs `/repo-fork`).
func isDescendant(_ url: URL, of ancestor: URL) -> Bool {
    let child  = url.standardized.pathComponents
    let parent = ancestor.standardized.pathComponents
    guard child.count > parent.count else { return false }
    return child.prefix(parent.count).elementsEqual(parent)
}

func isDirectory(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
}

/// Converts a human-readable name to a lowercase, hyphen-separated slug.
func makeSlug(from name: String) -> String {
    name
        .lowercased()
        .replacingOccurrences(of: " ", with: "-")
        .filter { $0.isLetter || $0.isNumber || $0 == "-" }
}

/// Repoints existing symlinks under each agent directory to a new target URL.
/// Skips entries that are not currently symlinks.
func relinkSymlinks(agents: [(path: URL, name: String)], childName: String, to newURL: URL) {
    for agent in agents {
        let dest = agent.path.appendingPathComponent(childName)
        guard isSymlink(dest) else { continue }
        do {
            try fm.removeItem(at: dest)
            try fm.createSymbolicLink(at: dest, withDestinationURL: newURL)
            info("  Updated symlink → \(agent.name)")
        } catch {
            warn("  Could not update symlink in \(agent.name): \(error.localizedDescription)")
        }
    }
}
