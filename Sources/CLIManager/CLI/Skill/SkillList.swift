import ArgumentParser
import Foundation

struct SkillList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all skills in this repo."
    )

    func run() throws {
        let skills = SkillModel.loadSkills()
        guard !skills.isEmpty else {
            warn("No skills found in skills/")
            return
        }

        let agents = detectedAgents()
        print("\n\(bold)Skills\(reset) \(gray)(\(skills.count))\(reset)\n")
        for skill in skills {
            let privTag = skill.isPrivate ? " \(yellow)(private)\(reset)" : ""
            print("  \(cyan)\(bold)\(skill.name)\(reset)\(privTag)")
            if !skill.description.isEmpty { print("  \(dim)\(skill.description)\(reset)") }

            if !agents.isEmpty {
                let activeIn = agents.filter {
                    fm.fileExists(atPath: $0.path.appendingPathComponent(skill.id).path)
                }
                if activeIn.isEmpty {
                    print("  \(gray)not activated\(reset)")
                } else {
                    let names = activeIn.map { agent in
                        let dest = agent.path.appendingPathComponent(skill.id)
                        let tag = isSymlink(dest) ? "" : " \(yellow)(copy)\(reset)"
                        return "\(green)●\(reset) \(agent.name)\(tag)"
                    }.joined(separator: "  ")
                    print("  \(names)")
                }
            }
            print()
        }
    }
}
