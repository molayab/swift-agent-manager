import ArgumentParser
import Foundation

struct CommandStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show command activation status per agent."
    )

    func run() throws {
        let cmds = UserCommandModel.loadCommands()
        print("\n\(bold)Command Status\(reset)\n")
        print("  \(bold)Repo:\(reset)     \(gray)\(repoRoot.path)\(reset)")
        print("  \(bold)Commands:\(reset) \(cmds.count)\n")

        for agent in CommandModel.allCommandAgents {
            let exists = fm.fileExists(atPath: agent.path.path)
            let indicator = exists ? "\(green)●\(reset)" : "\(gray)○\(reset)"
            print("  \(indicator) \(bold)\(agent.name)\(reset)  \(gray)\(agent.path.path)\(reset)")
            if exists {
                for cmd in cmds {
                    let dest = agent.path.appendingPathComponent("\(cmd.id).\(agent.fileExtension)")
                    guard fm.fileExists(atPath: dest.path) else { continue }
                    let kind = agent.format == .markdown ? (isSymlink(dest) ? "symlink" : "copy") : "toml"
                    print("      → /\(cmd.id)  \(gray)\(kind)\(reset)")
                }
            }
        }
        print()
    }
}
