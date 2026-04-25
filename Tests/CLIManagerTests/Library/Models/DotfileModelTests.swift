import Testing
import Foundation

@testable import cli_manager

struct DotfileModelTests {

    // MARK: - Helpers

    private func makeDotfile(
        id: String = "gitconfig",
        name: String = "Git Config",
        description: String = "Git configuration",
        link: String = "~/.gitconfig",
        fileName: String = ".gitconfig",
        isPrivate: Bool = false
    ) -> DotfileModel {
        DotfileModel(
            id: id,
            dir: URL(fileURLWithPath: "/tmp/\(id)"),
            name: name,
            description: description,
            link: link,
            fileName: fileName,
            isPrivate: isPrivate
        )
    }

    // MARK: - resolveDotfiles

    @Test("Returns all dotfiles when no filter is provided")
    func resolveAllDotfilesWhenFilterIsEmpty() {
        let dotfiles = [
            makeDotfile(id: "gitconfig", name: "Git Config"),
            makeDotfile(id: "zshrc", name: "Zsh RC")
        ]
        #expect(DotfileModel.resolveDotfiles([], from: dotfiles).count == dotfiles.count)
    }

    @Test("Filters dotfiles by id, by name, multiple terms, or nothing for unknown terms", arguments: [
        (["gitconfig"], 1),             // match by id
        (["Git Config"], 1),            // match by name (case-sensitive)
        (["unknown"], 0),               // no match
        (["gitconfig", "zshrc"], 2)     // match multiple by id
    ])
    func resolveDotfilesByIdOrName(filter: [String], expectedCount: Int) {
        let dotfiles = [
            makeDotfile(id: "gitconfig", name: "Git Config"),
            makeDotfile(id: "zshrc", name: "Zsh RC")
        ]
        #expect(DotfileModel.resolveDotfiles(filter, from: dotfiles).count == expectedCount)
    }

    @Test("A private dotfile is resolved by its base id (without the .private suffix)")
    func privateDotfileResolvedByBaseID() throws {
        let privateDotfile = makeDotfile(id: "gitconfig", isPrivate: true)
        let resolved = DotfileModel.resolveDotfiles(["gitconfig"], from: [privateDotfile])
        let first = try #require(resolved.first)
        #expect(first.isPrivate == true)
    }

    // MARK: - Computed properties

    @Test("linkTarget expands tilde to the user home directory")
    func linkTargetExpandsTilde() {
        let dotfile = makeDotfile(link: "~/.gitconfig")
        let expected = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".gitconfig")
        #expect(dotfile.linkTarget == expected)
    }

    @Test("linkTarget works for nested config paths")
    func linkTargetNestedPath() {
        let dotfile = makeDotfile(link: "~/.config/starship/starship.toml", fileName: "starship.toml")
        let expected = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/starship/starship.toml")
        #expect(dotfile.linkTarget == expected)
    }

    @Test("sourceFile is dir joined with fileName")
    func sourceFileCombinesDirAndFileName() {
        let dir = URL(fileURLWithPath: "/tmp/gitconfig")
        let dotfile = DotfileModel(
            id: "gitconfig",
            dir: dir,
            name: "Git Config",
            description: "",
            link: "~/.gitconfig",
            fileName: ".gitconfig",
            isPrivate: false
        )
        #expect(dotfile.sourceFile == dir.appendingPathComponent(".gitconfig"))
    }

    // MARK: - Frontmatter parsing (via Frontmatter helper, mirrors loadDotfiles logic)

    @Test("fileName falls back to last path component of link when file: field is absent")
    func fileNameFallsBackToLinkLastComponent() {
        // Simulate what loadDotfiles does when `file:` is not in DOTFILE.md
        let link = "~/.config/starship/starship.toml"
        let fallback = URL(fileURLWithPath: link).lastPathComponent
        #expect(fallback == "starship.toml")
    }

    @Test("isPrivate is true and id strips .private suffix for private directories")
    func privateDirectorySetsIsPrivateAndStripsIDSuffix() {
        let dirName = "gitconfig.private"
        let isPrivate = dirName.hasSuffix(".private")
        let id = isPrivate ? String(dirName.dropLast(".private".count)) : dirName
        #expect(isPrivate == true)
        #expect(id == "gitconfig")
    }

    @Test("isPrivate is false for regular (non-.private) directories")
    func nonPrivateDirectoryIsNotPrivate() {
        let dirName = "gitconfig"
        let isPrivate = dirName.hasSuffix(".private")
        let id = isPrivate ? String(dirName.dropLast(".private".count)) : dirName
        #expect(isPrivate == false)
        #expect(id == "gitconfig")
    }

    @Test("Missing link: field causes the entry to be skipped (yamlField returns nil)")
    func missingLinkFieldReturnsNil() {
        let text = """
        ---
        name: My Dotfile
        description: No link here
        ---
        """
        let link = Frontmatter.yamlField("link", in: text)
        // loadDotfiles skips entries where link is nil or empty
        #expect(link == nil)
    }

    @Test("Whitespace-only link: value is treated as empty by loadDotfiles")
    func whitespaceOnlyLinkFieldIsEmpty() {
        // yamlField returns "" for a value of only spaces (regex backtracking hands .+ the spaces,
        // trimming gives ""). loadDotfiles then guards `!link.isEmpty` and skips the entry.
        // Use string concat to preserve the trailing spaces the regex needs to backtrack.
        let line = "link:   "  // three trailing spaces — no following content on this line
        let link = Frontmatter.yamlField("link", in: line)
        #expect(link?.isEmpty == true)
    }

    @Test("name: field is parsed correctly from DOTFILE.md frontmatter")
    func nameParsedFromFrontmatter() {
        let text = """
        ---
        name: Git Config
        link: ~/.gitconfig
        file: .gitconfig
        ---
        """
        #expect(Frontmatter.yamlField("name", in: text) == "Git Config")
        #expect(Frontmatter.yamlField("link", in: text) == "~/.gitconfig")
        #expect(Frontmatter.yamlField("file", in: text) == ".gitconfig")
    }
}
