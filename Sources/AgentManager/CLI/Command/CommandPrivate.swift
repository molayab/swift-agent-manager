import ArgumentParser
import Foundation

struct CommandPrivate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "private",
        abstract: "Toggle a command between private (untracked) and public (committed)."
    )

    @Argument(help: "Command id to toggle (e.g. review).")
    var name: String

    func run() throws {
        let cmds = UserCommandModel.loadCommands()
        guard let cmd = cmds.first(where: { $0.id == name }) else {
            fail("Command '\(name)' not found."); return
        }

        let newFilename = cmd.isPrivate ? "\(cmd.id).md" : "\(cmd.id).private.md"
        let newFile = commandsDir.appendingPathComponent(newFilename)

        guard !fm.fileExists(atPath: newFile.path) else {
            fail("'\(newFilename)' already exists in commands/ — resolve the conflict first."); return
        }

        try fm.moveItem(at: cmd.file, to: newFile)
        updateSymlinks(for: cmd, newFile: newFile)

        let state = cmd.isPrivate ? "public (will be committed)" : "private (git-ignored)"
        ok("'/\(cmd.id)' is now \(state)")
    }

    private func updateSymlinks(for cmd: UserCommandModel, newFile: URL) {
        relinkSymlinks(
            agents: CommandModel.allCommandAgents
                .filter { $0.format == .markdown }
                .map { (path: $0.path, name: $0.name) },
            childName: "\(cmd.id).md",
            to: newFile
        )
    }
}
