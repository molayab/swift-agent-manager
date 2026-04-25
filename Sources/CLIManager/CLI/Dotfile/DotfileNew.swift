import ArgumentParser
import Foundation

struct DotfileNew: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: "Scaffold a new dotfile entry."
    )

    @Argument(help: "Name for the new dotfile (will prompt if omitted).")
    var name: String?

    func run() throws {
        // Step 1 — Resolve name
        let resolvedName: String
        if let name {
            resolvedName = name
        } else {
            print("\(bold)Dotfile name:\(reset) ", terminator: "")
            fflush(stdout)
            resolvedName = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
        }
        guard !resolvedName.isEmpty else { throw ValidationError("Name cannot be empty.") }
        let slug = makeSlug(from: resolvedName)
        guard !slug.isEmpty else { throw ValidationError("Provide a valid dotfile name.") }

        // Step 2 — Check for existing entry
        let dest = dotfilesDir.appendingPathComponent(slug)
        guard !fm.fileExists(atPath: dest.path) else {
            fail("Already exists: dotfiles/\(slug)"); return
        }

        // Step 3 — Prompt for link path
        print("\(bold)Link target path\(reset) \(gray)(e.g. ~/.gitconfig):\(reset) ", terminator: "")
        fflush(stdout)
        let linkPath = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !linkPath.isEmpty else { throw ValidationError("Link path cannot be empty.") }

        // Step 4 — Derive fileName from link path
        let fileName = URL(fileURLWithPath: linkPath).lastPathComponent
        guard !fileName.isEmpty, fileName != "/" else {
            throw ValidationError("Could not derive a file name from '\(linkPath)'.")
        }

        // Step 5 — Scaffold
        let template = """
        ---
        name: \(resolvedName)
        description:
        link: \(linkPath)
        file: \(fileName)
        ---

        # \(resolvedName)

        Managed by cli-manager. Edit \(fileName) directly.
        """

        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        try template.write(to: dest.appendingPathComponent("DOTFILE.md"), atomically: true, encoding: .utf8)
        try "".write(to: dest.appendingPathComponent(fileName), atomically: true, encoding: .utf8)

        // Step 6 — Next steps
        print()
        ok("Created  \(gray)dotfiles/\(slug)/DOTFILE.md\(reset)")
        ok("Created  \(gray)dotfiles/\(slug)/\(fileName)\(reset)  \(gray)(empty placeholder)\(reset)")
        info("Edit dotfiles/\(slug)/\(fileName), then run:")
        info("  cli-manager dotfile link --dotfile \(slug)")
    }
}
