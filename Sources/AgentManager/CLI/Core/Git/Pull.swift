import ArgumentParser
import Foundation

struct Pull: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Pull latest changes from remote."
    )

    func run() throws {
        let gitDir = repoRoot.appendingPathComponent(".git")
        guard fm.fileExists(atPath: gitDir.path) else {
            fail("No git repository found. Run `skills repo --init` first.")
            return
        }

        let remote = GitRunner.run("remote").output
        guard !remote.isEmpty else {
            warn("No remote configured.")
            info("Add one with: git remote add origin <url>")
            return
        }

        print("\n\(bold)Pulling latest changes…\(reset)\n")
        let result = GitRunner.run("pull")
        if result.exitCode == 0 {
            let msg = result.output.isEmpty ? "Already up to date." : result.output
            ok(msg)
        } else {
            fail("git pull failed.")
        }
        print()
    }
}
