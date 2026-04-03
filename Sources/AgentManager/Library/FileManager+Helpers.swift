import Foundation

nonisolated(unsafe) let fm = FileManager.default
let home = URL(fileURLWithPath: NSHomeDirectory())

func findRepoRoot() -> URL {
    // 1. Explicit environment override — useful in CI or multi-repo setups.
    if let envPath = ProcessInfo.processInfo.environment["AGENT_MANAGER_REPO"] {
        let url = URL(fileURLWithPath: (envPath as NSString).expandingTildeInPath)
        if fm.fileExists(atPath: url.path) { return url }
    }

    // 2. Config file written by install.sh — the primary path for installed binaries.
    let configFile = home
        .appendingPathComponent(".config")
        .appendingPathComponent("agent-manager")
        .appendingPathComponent("repo")
    if let saved = try? String(contentsOf: configFile, encoding: .utf8) {
        let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let url = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
            if fm.fileExists(atPath: url.path) { return url }
        }
    }

    // 3. Walk up from CWD looking for Package.swift — fallback for `swift run` / dev.
    var url = URL(fileURLWithPath: fm.currentDirectoryPath)
    for _ in 0..<8 {
        if fm.fileExists(atPath: url.appendingPathComponent("Package.swift").path) { return url }
        url = url.deletingLastPathComponent()
    }
    return URL(fileURLWithPath: fm.currentDirectoryPath)
}

let repoRoot    = findRepoRoot()
let skillsDir   = repoRoot.appendingPathComponent("skills")
let commandsDir = repoRoot.appendingPathComponent("commands")

func isSymlink(_ url: URL) -> Bool {
    (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil
}

func isDirectory(_ url: URL) -> Bool {
    var isDir: ObjCBool = false
    return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
}
