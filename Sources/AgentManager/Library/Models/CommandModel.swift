import Foundation

enum CommandFormat { case markdown, geminiTOML }

struct CommandModel {
    let id: String
    let name: String
    let path: URL
    let format: CommandFormat

    var fileExtension: String { format == .geminiTOML ? "toml" : "md" }

    static var allCommandAgents: [CommandModel] {
        [
            .init(
                id: "claude-code",
                name: "Claude Code",
                path: home.appendingPathComponent(".claude/commands"),
                format: .markdown
            ),
            .init(
                id: "opencode",
                name: "OpenCode",
                path: home.appendingPathComponent(".config/opencode/commands"),
                format: .markdown
            ),
            .init(
                id: "windsurf",
                name: "Windsurf",
                path: home.appendingPathComponent(".codeium/windsurf/global_workflows"),
                format: .markdown
            ),
            .init(
                id: "gemini-cli",
                name: "Gemini CLI",
                path: home.appendingPathComponent(".gemini/commands"),
                format: .geminiTOML
            )
        ]
    }

    static func detectedCommandAgents() -> [CommandModel] {
        allCommandAgents.filter { fm.fileExists(atPath: $0.path.path) }
    }

    static func resolveCommandAgents(_ ids: [String]) -> [CommandModel]? {
        guard !ids.isEmpty else {
            let detected = detectedCommandAgents()
            if detected.isEmpty {
                warn("No command agents detected.")
                info("Use --agent <id>. Available: \(allCommandAgents.map(\.id).joined(separator: ", "))")
                return nil
            }
            return detected
        }
        return ids.compactMap { id in
            guard let agent = allCommandAgents.first(where: { $0.id == id }) else {
                warn("Unknown agent: \(id)"); return nil
            }
            return agent
        }
    }
}
