import ArgumentParser
import Foundation

struct DotfileStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show link status for all dotfiles."
    )

    func run() throws {
        let dotfiles = DotfileModel.loadDotfiles()
        print("\n\(bold)Status\(reset)\n")
        print("  \(bold)Repo:\(reset)      \(gray)\(repoRoot.path)\(reset)")
        print("  \(bold)Dotfiles:\(reset) \(dotfiles.count)\n")

        for dotfile in dotfiles {
            let indicator = dotfile.isLinked ? "\(green)●\(reset)" : "\(gray)○\(reset)"
            let privTag = dotfile.isPrivate ? "  \(yellow)(private)\(reset)" : ""
            let status = dotfile.isLinked ? "\(green)linked\(reset)" : "\(gray)not linked\(reset)"
            print("  \(indicator) \(bold)\(dotfile.name)\(reset)\(privTag)  \(gray)\(dotfile.link)\(reset)  \(status)")
        }
        print()
    }
}
