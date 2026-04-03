import ArgumentParser
import Foundation

struct SkillStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show activation status per agent."
    )

    func run() throws {
        let skills = SkillModel.loadSkills()
        print("\n\(bold)Status\(reset)\n")
        print("  \(bold)Repo:\(reset)   \(gray)\(repoRoot.path)\(reset)")
        print("  \(bold)Skills:\(reset) \(skills.count)\n")

        for agent in allAgents {
            let exists = fm.fileExists(atPath: agent.path.path)
            let indicator = exists ? "\(green)●\(reset)" : "\(gray)○\(reset)"
            print("  \(indicator) \(bold)\(agent.name)\(reset)  \(gray)\(agent.path.path)\(reset)")
            if exists {
                for skill in skills {
                    let dest = agent.path.appendingPathComponent(skill.id)
                    guard fm.fileExists(atPath: dest.path) else { continue }
                    print("      → \(skill.id)  \(gray)\(isSymlink(dest) ? "symlink" : "copy")\(reset)")
                }
            }
        }
        print()
    }
}
