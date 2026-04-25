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
        relinkSymlinks(
            agents: allAgents.map { (path: $0.path, name: $0.name) },
            childName: skill.id,
            to: newDir
        )
    }
}
