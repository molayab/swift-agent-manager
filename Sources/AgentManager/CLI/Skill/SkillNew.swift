import ArgumentParser
import Foundation

struct SkillNew: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: "Scaffold a new skill."
    )

    @Argument(help: "Name for the new skill.")
    var name: String

    func run() throws {
        let slug = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        guard !slug.isEmpty else { throw ValidationError("Provide a valid skill name.") }

        let dest = skillsDir.appendingPathComponent(slug)
        guard !fm.fileExists(atPath: dest.path) else {
            fail("Already exists: skills/\(slug)"); return
        }

        let template = """
        ---
        name: \(slug)
        description: Describe what this skill does and when the agent should use it.
        ---

        # \(slug)

        ## Overview

        Describe the purpose of this skill.

        ## When to Use

        Describe the scenarios where this skill should be activated.

        ## Steps

        1. First, do this.
        2. Then, do that.
        """

        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        try template.write(to: dest.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        ok("Created  \(gray)skills/\(slug)/SKILL.md\(reset)")
        info("Edit the file, then run:  skills activate --skill \(slug)")
    }
}
