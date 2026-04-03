import ArgumentParser
import Foundation

struct Push: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stage all changes, commit, and push to remote."
    )

    @Option(name: .shortAndLong, help: "Commit message.")
    var message: String = "Update skills"

    func run() throws {
        let gitDir = repoRoot.appendingPathComponent(".git")
        guard fm.fileExists(atPath: gitDir.path) else {
            fail("No git repository found. Run `skills repo --init` first.")
            return
        }

        let add = GitRunner.run("add", ".")
        guard add.exitCode == 0 else { fail("git add failed."); return }

        let staged = GitRunner.run("diff", "--cached", "--quiet")
        if staged.exitCode == 0 {
            info("Nothing to commit — working tree clean.")
            return
        }

        let commit = GitRunner.run("commit", "-m", message)
        guard commit.exitCode == 0 else {
            fail("git commit failed:\n\(commit.output)")
            return
        }
        ok("Committed: \(message)")

        let remote = GitRunner.run("remote").output
        guard !remote.isEmpty else {
            warn("No remote configured — skipping push.")
            info("Add one with: git remote add origin <url>")
            return
        }

        let branch = GitRunner.run("rev-parse", "--abbrev-ref", "HEAD").output
        let push = GitRunner.run("push", "-u", remote, branch)
        if push.exitCode == 0 {
            ok("Pushed to \(remote)/\(branch)")
        } else {
            fail("git push failed.")
        }
    }
}
