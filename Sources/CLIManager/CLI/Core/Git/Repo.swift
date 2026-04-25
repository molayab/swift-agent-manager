import ArgumentParser
import Foundation

struct Repo: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show git repository status, or initialise one."
    )

    @Option(name: .customLong("init"), help: "Create a new repo at <path> and set it as active.")
    var initPath: String?

    @Option(name: .customLong("use"), help: "Switch the active repo to an existing path.")
    var usePath: String?

    func run() throws {
        if let initPath {
            try initRepo(at: initPath)
            return
        }

        if let usePath {
            try switchRepo(to: usePath)
            return
        }

        let gitDir = repoRoot.appendingPathComponent(".git")
        let hasGit = fm.fileExists(atPath: gitDir.path)

        print("\n\(bold)Repository\(reset)  \(gray)\(repoRoot.path)\(reset)\n")

        if !hasGit {
            warn("No git repository found.")
            info("Run  cli-manager repo --init <path>  to create one.")
            print()
            return
        }

        let branch = GitRunner.run("rev-parse", "--abbrev-ref", "HEAD").output
        print("  \(bold)Branch:\(reset)   \(branch.isEmpty ? "\(gray)unknown\(reset)" : branch)")

        let remote = GitRunner.run("remote", "get-url", "origin").output
        print("  \(bold)Remote:\(reset)   \(remote.isEmpty ? "\(gray)none\(reset)" : remote)")

        let countResult = GitRunner.run("rev-list", "--count", "HEAD")
        if countResult.exitCode == 0, let commitCount = Int(countResult.output) {
            print("  \(bold)Commits:\(reset)  \(commitCount)")
        } else {
            print("  \(bold)Commits:\(reset)  \(gray)none yet\(reset)")
        }

        let dirty = GitRunner.run("status", "--porcelain").output
        let statusText = dirty.isEmpty ? "\(green)clean\(reset)" : "\(yellow)uncommitted changes\(reset)"
        print("  \(bold)Status:\(reset)   \(statusText)")

        print()
    }

    private func initRepo(at path: String) throws {
        let expanded = URL(fileURLWithPath: expandingTilde(in: path)).standardized

        if !fm.fileExists(atPath: expanded.path) {
            try fm.createDirectory(at: expanded, withIntermediateDirectories: true)
            ok("Created  \(gray)\(expanded.path)\(reset)")
        }

        guard isDirectory(expanded) else {
            fail("Path is not a directory: \(expanded.path)")
            return
        }

        let gitDir = expanded.appendingPathComponent(".git")
        if fm.fileExists(atPath: gitDir.path) {
            warn("Git repository already exists at \(expanded.path)")
        } else {
            let result = GitRunner.runIn(expanded, "init")
            if result.exitCode == 0 {
                ok("Initialised git repository")
            } else {
                fail("git init failed.")
                return
            }
        }

        try writeRepoConfig(expanded)
        ok("Active repo → \(bold)\(expanded.path)\(reset)")
    }

    private func switchRepo(to path: String) throws {
        let expanded = URL(fileURLWithPath: expandingTilde(in: path)).standardized
        guard fm.fileExists(atPath: expanded.path) else {
            fail("Path does not exist: \(expanded.path)")
            return
        }
        guard isDirectory(expanded) else {
            fail("Path is not a directory: \(expanded.path)")
            return
        }
        try writeRepoConfig(expanded)
        ok("Active repo → \(bold)\(expanded.path)\(reset)")
    }

    private func writeRepoConfig(_ repoURL: URL) throws {
        let configDir = home
            .appendingPathComponent(".config")
            .appendingPathComponent("cli-manager")
        try fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        try repoURL.path.write(
            to: configDir.appendingPathComponent("repo"),
            atomically: true,
            encoding: .utf8
        )
        ok("Config saved  \(gray)~/.config/cli-manager/repo\(reset)")
    }
}
