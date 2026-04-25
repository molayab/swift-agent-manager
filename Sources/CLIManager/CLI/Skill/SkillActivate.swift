import ArgumentParser
import Foundation

struct SkillActivate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "activate",
        abstract: "Symlink skills into agent directories."
    )

    @OptionGroup var filter: SkillFilterOptions

    @Flag(name: .long, help: "Preview changes without applying them.")
    var dryRun = false

    func run() throws {
        let allSkills = SkillModel.loadSkills()
        guard !allSkills.isEmpty else {
            fail("No skills found in skills/")
            return
        }

        let skills: [SkillModel] = filter.skill.isEmpty
            ? selectInteractive(prompt: "Select skills to activate", items: allSkills, display: \.name)
        : SkillModel.resolveSkills(filter.skill, from: allSkills)
        guard !skills.isEmpty else {
            fail("No matching skills.")
            return
        }

        guard let targets = selectAgentTargets(filter: filter.agent) else {
            return
        }

        print("\n\(bold)Activating \(skills.count) skill(s) → \(targets.count) agent(s)\(reset)"
            + (dryRun ? "  \(yellow)(dry run)\(reset)" : "") + "\n")

        for agent in targets {
            print("\(bold)\(agent.name)\(reset)  \(gray)\(agent.path.path)\(reset)")
            if !dryRun && !fm.fileExists(atPath: agent.path.path) {
                try fm.createDirectory(at: agent.path, withIntermediateDirectories: true)
            }
            for skill in skills {
                try activateSkill(skill, into: agent)
            }
            print()
        }
    }

    private func activateSkill(_ skill: SkillModel, into agent: Agent) throws {
        let dest = agent.path.appendingPathComponent(skill.id)
        if fm.fileExists(atPath: dest.path) {
            skip("  \(skill.id)  \(gray)already active (\(isSymlink(dest) ? "symlink" : "copy"))\(reset)")
        } else if dryRun {
            ok("  \(skill.id)  \(gray)→ would symlink\(reset)")
        } else {
            do {
                try fm.createSymbolicLink(at: dest, withDestinationURL: skill.dir)
                ok("  \(skill.id)")
            } catch {
                fail("  \(skill.id): \(error.localizedDescription)")
            }
        }
    }
}
