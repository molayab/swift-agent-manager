import Foundation

struct Agent {
    let id: String
    let name: String
    let path: URL
}

let allAgents: [Agent] = [
    .init(id: "opencode", name: "OpenCode", path: home.appendingPathComponent(".config/opencode/skills")),
    .init(id: "claude-code", name: "Claude Code", path: home.appendingPathComponent(".claude/skills")),
    .init(id: "github-copilot", name: "GitHub Copilot", path: home.appendingPathComponent(".copilot/skills")),
    .init(id: "cursor", name: "Cursor", path: home.appendingPathComponent(".cursor/skills")),
    .init(id: "opencode", name: "OpenCode", path: home.appendingPathComponent(".agents/skills")),
    .init(id: "codex", name: "Codex", path: home.appendingPathComponent(".codex/skills")),
    .init(id: "gemini-cli", name: "Gemini CLI", path: home.appendingPathComponent(".gemini/skills")),
    .init(id: "windsurf", name: "Windsurf", path: home.appendingPathComponent(".codeium/windsurf/skills"))
]

func detectedAgents() -> [Agent] {
    allAgents.filter { fm.fileExists(atPath: $0.path.path) }
}

func resolveTargets(_ filterAgents: [String]) -> [Agent]? {
    guard !filterAgents.isEmpty else {
        let detected = detectedAgents()
        if detected.isEmpty {
            warn("No agents detected on this machine.")
            info("Use --agent <id>. Available: \(allAgents.map(\.id).joined(separator: ", "))")
            return nil
        }
        return detected
    }
    return filterAgents.compactMap { id in
        guard let agent = allAgents.first(where: { $0.id == id }) else {
            warn("Unknown agent: \(id)"); return nil
        }
        return agent
    }
}

/// Resolves agents to operate on, prompting interactively when no filter is given.
/// Returns `nil` — and prints an appropriate message — when there is nothing to do.
func selectAgentTargets(filter: [String]) -> [Agent]? {
    if filter.isEmpty {
        let detected = detectedAgents()
        guard !detected.isEmpty else {
            warn("No agents detected on this machine.")
            info("Use --agent <id>. Available: \(allAgents.map(\.id).joined(separator: ", "))")
            return nil
        }
        return selectInteractive(prompt: "Select agents", items: detected, display: \.name)
    }
    let resolved = resolveTargets(filter) ?? []
    guard !resolved.isEmpty else {
        fail("No agents selected.")
        return nil
    }
    return resolved
}
