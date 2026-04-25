import ArgumentParser
import Foundation

struct DotfileLink: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "link",
        abstract: "Create symlinks for dotfiles at their target paths."
    )

    @Option(name: .shortAndLong, help: "Dotfile id to link (repeatable).")
    var dotfile: [String] = []

    @Flag(name: .long, help: "Preview changes without applying them.")
    var dryRun = false

    func run() throws {
        let all = DotfileModel.loadDotfiles()
        guard !all.isEmpty else {
            fail("No dotfiles found in dotfiles/")
            return
        }

        let selected: [DotfileModel] = dotfile.isEmpty
            ? selectInteractive(prompt: "Select dotfiles to link", items: all, display: \.name)
            : DotfileModel.resolveDotfiles(dotfile, from: all)
        guard !selected.isEmpty else {
            fail("No matching dotfiles.")
            return
        }

        print("\n\(bold)Linking \(selected.count) dotfile(s)\(reset)"
            + (dryRun ? "  \(yellow)(dry run)\(reset)" : "") + "\n")

        for dotfileItem in selected {
            try linkDotfile(dotfileItem)
        }
    }

    private func linkDotfile(_ dotfile: DotfileModel) throws {
        let target = dotfile.linkTarget
        let source = dotfile.sourceFile

        guard fm.fileExists(atPath: source.path) else {
            fail("  \(dotfile.id): source file missing at \(source.path)")
            return
        }

        let targetIsSymlink = isSymlink(target)
        let targetExists = fm.fileExists(atPath: target.path)

        if targetIsSymlink {
            let dest = symlinkDestination(at: target)
            if dest == source.standardized.path {
                skip("  \(dotfile.id)  \(gray)already linked\(reset)")
                return
            }
            warn("  \(dotfile.id)  replacing symlink → \(dest ?? "?")")
            if !dryRun {
                try fm.removeItem(at: target)
            }
        } else if targetExists {
            warn("  \(dotfile.id)  \(target.path) already exists (not a symlink) — skipping")
            info("    Move or back up the file first, then run link again.")
            return
        }

        let parentDir = target.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDir.path) {
            if dryRun {
                ok("  \(dotfile.id)  \(gray)→ would create \(parentDir.path) and link\(reset)")
                return
            }
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        if dryRun {
            ok("  \(dotfile.id)  \(gray)→ would symlink \(target.path)\(reset)")
        } else {
            try fm.createSymbolicLink(at: target, withDestinationURL: source)
            ok("  \(dotfile.id)  → \(gray)\(target.path)\(reset)")
        }
    }
}
