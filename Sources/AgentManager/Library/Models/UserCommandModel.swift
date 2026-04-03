import Foundation

struct UserCommandModel {
    let id: String           // filename stem without .private, used as /id
    let file: URL            // source .md (or .private.md) file in repo
    let name: String
    let description: String
    let body: String         // content with frontmatter stripped (used for TOML export)
    let isPrivate: Bool

    static func loadCommands() -> [UserCommandModel] {
        guard let entries = try? fm.contentsOfDirectory(
            at: commandsDir, includingPropertiesForKeys: nil
        ) else { return [] }

        return entries
            .filter { $0.pathExtension == "md" }
            .map { file in
                let stem = file.deletingPathExtension().lastPathComponent  // "review" or "review.private"
                let privateFile = stem.hasSuffix(".private")
                let cmdID = privateFile ? String(stem.dropLast(".private".count)) : stem
                let text = (try? String(contentsOf: file)) ?? ""
                return UserCommandModel(
                    id: cmdID,
                    file: file,
                    name: Frontmatter.yamlField("name", in: text) ?? cmdID,
                    description: Frontmatter.yamlField("description", in: text) ?? "",
                    body: Frontmatter.stripFrontmatter(text),
                    isPrivate: privateFile
                )
            }
            .sorted { $0.id < $1.id }
    }

    /// Generates Gemini CLI–compatible TOML content from a UserCommand.
    static func geminiTOML(from cmd: UserCommandModel) -> String {
        var lines: [String] = []
        if !cmd.description.isEmpty {
            let escaped = cmd.description
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("description = \"\(escaped)\"")
        }
        let safeBody = cmd.body.replacingOccurrences(of: "\"\"\"", with: "\"\"\\\"")
        lines.append("prompt = \"\"\"\n\(safeBody)\n\"\"\"")
        return lines.joined(separator: "\n")
    }

    static func resolveUserCommands(_ filter: [String], from all: [UserCommandModel]) -> [UserCommandModel] {
        filter.isEmpty ? all : all.filter { filter.contains($0.id) || filter.contains($0.name) }
    }
}
