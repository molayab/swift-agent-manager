import Foundation

struct DotfileModel {
    let id: String
    let dir: URL
    let name: String
    let description: String
    let link: String
    let fileName: String
    let isPrivate: Bool

    /// Expanded path in the user's home directory where the symlink should live.
    var linkTarget: URL {
        URL(fileURLWithPath: expandingTilde(in: link))
    }

    /// The actual dotfile inside the repo directory.
    var sourceFile: URL {
        dir.appendingPathComponent(fileName)
    }

    /// True if a symlink at `linkTarget` exists and points into this repo.
    var isLinked: Bool {
        guard let dest = symlinkDestination(at: linkTarget) else { return false }
        return isDescendant(URL(fileURLWithPath: dest), of: repoRoot)
    }

    static func loadDotfiles() -> [DotfileModel] {
        guard let entries = try? fm.contentsOfDirectory(
            at: dotfilesDir, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        return entries
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                    && fm.fileExists(atPath: url.appendingPathComponent("DOTFILE.md").path)
            }
            .compactMap { dir in
                let dirName = dir.lastPathComponent
                let isPrivate = dirName.hasSuffix(".private")
                let id = isPrivate ? String(dirName.dropLast(".private".count)) : dirName
                let text = (try? String(contentsOf: dir.appendingPathComponent("DOTFILE.md"), encoding: .utf8)) ?? ""

                guard let link = Frontmatter.yamlField("link", in: text), !link.isEmpty else {
                    warn("dotfiles/\(dirName)/DOTFILE.md missing 'link:' field — skipping")
                    return nil
                }

                let fileName: String
                if let file = Frontmatter.yamlField("file", in: text), !file.isEmpty {
                    fileName = file
                } else {
                    fileName = URL(fileURLWithPath: link).lastPathComponent
                }

                return DotfileModel(
                    id: id,
                    dir: dir,
                    name: Frontmatter.yamlField("name", in: text) ?? id,
                    description: Frontmatter.yamlField("description", in: text) ?? "",
                    link: link,
                    fileName: fileName,
                    isPrivate: isPrivate
                )
            }
            .sorted { $0.id < $1.id }
    }

    static func resolveDotfiles(_ filter: [String], from all: [DotfileModel]) -> [DotfileModel] {
        filter.isEmpty ? all : all.filter { filter.contains($0.id) || filter.contains($0.name) }
    }
}
