import Foundation

nonisolated(unsafe) let fm = FileManager.default
let home = URL(fileURLWithPath: NSHomeDirectory())

func findRepoRoot() -> URL {
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
