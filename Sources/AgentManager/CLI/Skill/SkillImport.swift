import ArgumentParser
import Foundation

struct SkillImport: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Copy skills from agent directories into this repo."
    )

    @Option(name: .shortAndLong, help: "Target a specific agent by ID (repeatable).")
    var agent: [String] = []

    @Flag(name: .long, help: "Overwrite an existing local skill.")
    var force = false

    func run() throws {
        let targets: [Agent]
        if agent.isEmpty {
            let detected = allAgents.filter { isDirectory($0.path) }
            guard !detected.isEmpty else {
                warn("No skill agents detected on this machine.")
                info("Use --agent <id>. Available: \(allAgents.map(\.id).joined(separator: ", "))")
                return
            }
            targets = selectInteractive(prompt: "Select agents to import from", items: detected, display: \.name)
        } else {
            targets = agent.compactMap { agentID in
                guard let match = allAgents.first(where: { $0.id == agentID }) else {
                    warn("Unknown agent: \(agentID)")
                    return nil
                }
                return match
            }
        }
        guard !targets.isEmpty else {
            fail("No agents selected.")
            return
        }

        try fm.createDirectory(at: skillsDir, withIntermediateDirectories: true)

        print("\n\(bold)Importing skills → \(skillsDir.path)\(reset)\n")

        for target in targets {
            print("\(bold)\(target.name)\(reset)  \(gray)\(target.path.path)\(reset)")
            try importSkills(from: target)
            print()
        }
    }

    private func importSkills(from agent: Agent) throws {
        guard isDirectory(agent.path) else {
            warn("  \(agent.name) skills directory not found — skipping.")
            return
        }

        let resolvedPath = agent.path.resolvingSymlinksInPath()
        let entries = (try? fm.contentsOfDirectory(
            at: resolvedPath,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        // Include symlinked directories too; resolve each to its real path so we
        // can detect whether it already lives inside skillsDir (and skip it).
        let skillDirs = entries.filter { isDirectory($0) }

        guard !skillDirs.isEmpty else {
            info("  no skill directories found")
            return
        }

        for entry in skillDirs {
            let source = entry.resolvingSymlinksInPath()
            // Skip entries that are already tracked inside this repo
            if source.path.hasPrefix(skillsDir.resolvingSymlinksInPath().path) {
                skip("  \(entry.lastPathComponent)  \(gray)already in repo\(reset)")
                continue
            }
            let slug = entry.lastPathComponent
            let dest = skillsDir.appendingPathComponent(slug)
            if fm.fileExists(atPath: dest.path) {
                if force {
                    try fm.removeItem(at: dest)
                } else {
                    skip("  \(slug)  \(gray)already in repo\(reset)")
                    continue
                }
            }
            try fm.copyItem(at: source, to: dest)
            ok("  \(slug)")
        }
    }
}
