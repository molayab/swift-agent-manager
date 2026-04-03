import ArgumentParser
import Foundation

struct SkillDeactivate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "deactivate",
        abstract: "Remove skills from agent directories."
    )

    @OptionGroup var filter: SkillFilterOptions

    @Flag(name: .long, help: "Preview changes without applying them.")
    var dryRun = false

    func run() throws {
        let allSkills = SkillModel.loadSkills()
        guard !allSkills.isEmpty else { fail("No skills found in skills/"); return }

        let skills: [SkillModel] = filter.skill.isEmpty
            ? selectInteractive(prompt: "Select skills to deactivate", items: allSkills, display: \.name)
        : SkillModel.resolveSkills(filter.skill, from: allSkills)
        guard !skills.isEmpty else { fail("No matching skills."); return }

        let targets: [Agent]
        if filter.agent.isEmpty {
            let detected = detectedAgents()
            guard !detected.isEmpty else {
                warn("No agents detected on this machine.")
                info("Use --agent <id>. Available: \(allAgents.map(\.id).joined(separator: ", "))")
                return
            }
            targets = selectInteractive(prompt: "Select agents", items: detected, display: \.name)
        } else {
            guard let resolvedTargets = resolveTargets(filter.agent) else { return }
            targets = resolvedTargets
        }
        guard !targets.isEmpty else { fail("No agents selected."); return }

        print("\n\(bold)Deactivating \(skills.count) skill(s) from \(targets.count) agent(s)\(reset)"
            + (dryRun ? "  \(yellow)(dry run)\(reset)" : "") + "\n")

        for agent in targets {
            print("\(bold)\(agent.name)\(reset)  \(gray)\(agent.path.path)\(reset)")
            for skill in skills {
                deactivateSkill(skill, from: agent)
            }
            print()
        }
    }

    private func deactivateSkill(_ skill: SkillModel, from agent: Agent) {
        let dest = agent.path.appendingPathComponent(skill.id)
        guard fm.fileExists(atPath: dest.path) else {
            skip("  \(skill.id)  \(gray)not active\(reset)"); return
        }
        if dryRun {
            ok("  \(skill.id)  \(gray)→ would remove\(reset)")
        } else {
            do {
                try fm.removeItem(at: dest)
                ok("  \(skill.id)  \(gray)removed\(reset)")
            } catch {
                fail("  \(skill.id): \(error.localizedDescription)")
            }
        }
    }
}
