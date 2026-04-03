import Foundation

struct SkillModel {
    let id: String
    let dir: URL
    let name: String
    let description: String
    let isPrivate: Bool

    static func loadSkills() -> [SkillModel] {
        guard let entries = try? fm.contentsOfDirectory(
            at: skillsDir, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        return entries
            .filter { url in
                var isDir: ObjCBool = false
                return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
                    && fm.fileExists(atPath: url.appendingPathComponent("SKILL.md").path)
            }
            .map { dir in
                let dirName = dir.lastPathComponent
                let privateDir = dirName.hasSuffix(".private")
                let skillID = privateDir ? String(dirName.dropLast(".private".count)) : dirName
                let text = (try? String(contentsOf: dir.appendingPathComponent("SKILL.md"))) ?? ""
                return SkillModel(
                    id: skillID,
                    dir: dir,
                    name: Frontmatter.yamlField("name", in: text) ?? skillID,
                    description: Frontmatter.yamlField("description", in: text) ?? "",
                    isPrivate: privateDir
                )
            }
            .sorted { $0.id < $1.id }
    }

    static func resolveSkills(_ filter: [String], from all: [SkillModel]) -> [SkillModel] {
        filter.isEmpty ? all : all.filter { filter.contains($0.id) || filter.contains($0.name) }
    }
}
