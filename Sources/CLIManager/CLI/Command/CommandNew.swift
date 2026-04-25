import ArgumentParser
import Foundation

struct CommandNew: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: "Scaffold a new slash command."
    )

    @Argument(help: "Name for the new command (becomes /name).")
    var name: String

    func run() throws {
        let slug = makeSlug(from: name)
        guard !slug.isEmpty else { throw ValidationError("Provide a valid command name.") }

        try fm.createDirectory(at: commandsDir, withIntermediateDirectories: true)
        let dest = commandsDir.appendingPathComponent("\(slug).md")
        guard !fm.fileExists(atPath: dest.path) else {
            fail("Already exists: commands/\(slug).md"); return
        }

        let template = """
        ---
        description: Describe what /\(slug) does.
        ---

        Describe the steps or prompt for this command.
        Use $ARGUMENTS to reference any arguments the user passes.
        """

        try template.write(to: dest, atomically: true, encoding: .utf8)
        ok("Created  \(gray)commands/\(slug).md\(reset)")
        info("Edit the file, then run:  skills command activate --command \(slug)")
    }
}
