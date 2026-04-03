import ArgumentParser
import Foundation

struct Repo: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show git repository status, or initialise one."
    )

    @Flag(name: .customLong("init"), help: "Initialise a git repository if one does not exist.")
    var shouldInit = false

    func run() throws {
        let gitDir = repoRoot.appendingPathComponent(".git")
        let hasGit = fm.fileExists(atPath: gitDir.path)

        print("\n\(bold)Repository\(reset)  \(gray)\(repoRoot.path)\(reset)\n")

        if !hasGit {
            if shouldInit {
                let result = GitRunner.run("init")
                if result.exitCode == 0 {
                    ok("Initialised git repository.")
                } else {
                    fail("git init failed.")
                }
            } else {
                warn("No git repository found.")
                info("Run with --init to create one.")
            }
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
}
