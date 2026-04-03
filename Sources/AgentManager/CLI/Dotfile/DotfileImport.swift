import ArgumentParser
import Foundation

struct DotfileImport: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Scan home directory for common dotfiles and import them."
    )

    @Flag(name: .long, help: "Also create symlinks after importing.")
    var link = false

    // ── Well-known dotfiles ───────────────────────────────────────────────────

    private struct KnownDotfile {
        let link: String
        let slug: String
        let name: String
    }

    private static let knownDotfiles: [KnownDotfile] = [
        // Shell
        .init(link: "~/.zshrc", slug: "zshrc", name: "Zsh RC"),
        .init(link: "~/.zprofile", slug: "zprofile", name: "Zsh Profile"),
        .init(link: "~/.zsh_profile", slug: "zsh-profile", name: "Zsh Profile (alt)"),
        .init(link: "~/.bashrc", slug: "bashrc", name: "Bash RC"),
        .init(link: "~/.bash_profile", slug: "bash-profile", name: "Bash Profile"),
        .init(link: "~/.profile", slug: "profile", name: "Shell Profile"),
        // Git
        .init(link: "~/.gitconfig", slug: "gitconfig", name: "Git Config"),
        .init(link: "~/.gitignore_global", slug: "gitignore-global", name: "Git Global Ignore"),
        // Editors
        .init(link: "~/.vimrc", slug: "vimrc", name: "Vim RC"),
        .init(link: "~/.nanorc", slug: "nanorc", name: "Nano RC"),
        .init(link: "~/.editorconfig", slug: "editorconfig", name: "EditorConfig"),
        // Terminal multiplexers
        .init(link: "~/.tmux.conf", slug: "tmux-conf", name: "tmux Config"),
        .init(link: "~/.screenrc", slug: "screenrc", name: "GNU Screen RC"),
        // Terminal emulators
        .init(link: "~/.wezterm.lua", slug: "wezterm", name: "WezTerm Config"),
        .init(link: "~/.alacritty.toml", slug: "alacritty", name: "Alacritty Config"),
        .init(link: "~/.config/alacritty/alacritty.toml", slug: "alacritty", name: "Alacritty Config"),
        .init(link: "~/.config/kitty/kitty.conf", slug: "kitty", name: "Kitty Config"),
        // Prompt / shell tools
        .init(link: "~/.config/starship/starship.toml", slug: "starship", name: "Starship Prompt"),
        .init(link: "~/.config/fish/config.fish", slug: "fish", name: "Fish Shell Config"),
        // Misc
        .init(link: "~/.ssh/config", slug: "ssh-config", name: "SSH Config"),
        .init(link: "~/.curlrc", slug: "curlrc", name: "curl RC"),
        .init(link: "~/.npmrc", slug: "npmrc", name: "npm RC"),
        .init(link: "~/.config/gh/config.yml", slug: "gh-config", name: "GitHub CLI Config")
    ]

    // ── Candidate ─────────────────────────────────────────────────────────────

    private struct Candidate {
        let link: String
        let slug: String
        let name: String
        let sourcePath: URL
        let fileName: String
    }

    // ── Run ───────────────────────────────────────────────────────────────────

    func run() throws {
        let existing = Set(DotfileModel.loadDotfiles().map { $0.id })
        let alreadySlugs = Set(DotfileModel.loadDotfiles().map { $0.link })

        // Find known dotfiles present on disk that are not yet tracked
        var seen = Set<String>()   // deduplicate by slug when multiple paths map to same slug
        let candidates: [Candidate] = Self.knownDotfiles.compactMap { entry in
            let expanded = URL(fileURLWithPath: expandingTilde(in: entry.link))
            // Skip if not a regular file, already tracked by slug or link, or duplicate slug
            guard fm.fileExists(atPath: expanded.path),
                  !isSymlink(expanded),
                  !existing.contains(entry.slug),
                  !alreadySlugs.contains(entry.link),
                  seen.insert(entry.slug).inserted
            else { return nil }
            return Candidate(
                link: entry.link,
                slug: entry.slug,
                name: entry.name,
                sourcePath: expanded,
                fileName: expanded.lastPathComponent
            )
        }

        guard !candidates.isEmpty else {
            if existing.isEmpty {
                warn("No common dotfiles found in home directory.")
            } else {
                ok("All found common dotfiles are already tracked.")
            }
            return
        }

        print("\n\(bold)Found \(candidates.count) untracked dotfile(s)\(reset)\n")

        let selected = selectInteractive(
            prompt: "Select dotfiles to import",
            items: candidates,
            display: { "\($0.name)  \(gray)\($0.link)\(reset)" }
        )
        guard !selected.isEmpty else {
            warn("Nothing selected.")
            return
        }

        print()
        for candidate in selected {
            try importCandidate(candidate)
        }

        if link {
            try linkImported(selected)
        } else {
            print()
            info("Run  \(bold)agent-manager dotfile link\(reset)  to activate symlinks.")
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func linkImported(_ selected: [Candidate]) throws {
        print()
        info("Creating symlinks…")
        let dotfiles = DotfileModel.loadDotfiles()
        for candidate in selected {
            guard let dotfile = dotfiles.first(where: { $0.id == candidate.slug }) else { continue }
            try linkDotfile(dotfile)
        }
    }

    private func importCandidate(_ candidate: Candidate) throws {
        let destDir = dotfilesDir.appendingPathComponent(candidate.slug)

        if fm.fileExists(atPath: destDir.path) {
            skip("  \(candidate.slug)  \(gray)directory already exists\(reset)")
            return
        }

        let template = """
        ---
        name: \(candidate.name)
        description:
        link: \(candidate.link)
        file: \(candidate.fileName)
        ---

        # \(candidate.name)

        Managed by agent-manager. Edit \(candidate.fileName) directly.
        """

        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        try template.write(to: destDir.appendingPathComponent("DOTFILE.md"), atomically: true, encoding: .utf8)
        try fm.copyItem(at: candidate.sourcePath, to: destDir.appendingPathComponent(candidate.fileName))
        ok("  \(candidate.slug)  \(gray)← \(candidate.link)\(reset)")
    }

    private func linkDotfile(_ dotfile: DotfileModel) throws {
        let target = dotfile.linkTarget
        let source = dotfile.sourceFile

        guard fm.fileExists(atPath: source.path) else {
            fail("  \(dotfile.id): source missing")
            return
        }

        if isSymlink(target) {
            let dest = try? fm.destinationOfSymbolicLink(atPath: target.path)
            if dest == source.path {
                skip("  \(dotfile.id)  \(gray)already linked\(reset)")
                return
            }
            try fm.removeItem(at: target)
        } else if fm.fileExists(atPath: target.path) {
            // The original file still exists (we copied, not moved) — replace with symlink
            try fm.removeItem(at: target)
        }

        try fm.createSymbolicLink(at: target, withDestinationURL: source)
        ok("  \(dotfile.id)  → \(gray)\(target.path)\(reset)")
    }
}
