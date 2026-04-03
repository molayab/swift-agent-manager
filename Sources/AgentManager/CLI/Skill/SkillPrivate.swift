import ArgumentParser
import Foundation

struct SkillPrivate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "private",
        abstract: "Toggle a skill between private (untracked) and public (committed)."
    )

    @Argument(help: "Skill id to toggle (e.g. swiftui-pro).")
    var name: String

    func run() throws {
        let skills = SkillModel.loadSkills()
        guard let skill = skills.first(where: { $0.id == name }) else {
            fail("Skill '\(name)' not found."); return
        }

        let newDirName = skill.isPrivate ? skill.id : "\(skill.id).private"
        let newDir = skillsDir.appendingPathComponent(newDirName)

        guard !fm.fileExists(atPath: newDir.path) else {
            fail("'\(newDirName)' already exists in skills/ — resolve the conflict first."); return
        }

        try fm.moveItem(at: skill.dir, to: newDir)
        updateSymlinks(for: skill, newDir: newDir)

        let state = skill.isPrivate ? "public (will be committed)" : "private (git-ignored)"
        ok("'\(skill.id)' is now \(state)")
    }

    private func updateSymlinks(for skill: SkillModel, newDir: URL) {
        for agent in allAgents {
            let dest = agent.path.appendingPathComponent(skill.id)
            guard isSymlink(dest) else { continue }
            do {
                try fm.removeItem(at: dest)
                try fm.createSymbolicLink(at: dest, withDestinationURL: newDir)
                info("  Updated symlink → \(agent.name)")
            } catch {
                warn("  Could not update symlink in \(agent.name): \(error.localizedDescription)")
            }
        }
    }
}
