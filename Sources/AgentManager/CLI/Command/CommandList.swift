import ArgumentParser
import Foundation

struct CommandList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all commands in this repo."
    )

    func run() throws {
        let cmds = UserCommandModel.loadCommands()
        guard !cmds.isEmpty else { warn("No commands found in commands/"); return }

        let agents = CommandModel.detectedCommandAgents()
        print("\n\(bold)Commands\(reset) \(gray)(\(cmds.count))\(reset)\n")
        for cmd in cmds {
            let privTag = cmd.isPrivate ? " \(yellow)(private)\(reset)" : ""
            print("  \(cyan)\(bold)/\(cmd.id)\(reset)\(privTag)")
            if !cmd.description.isEmpty { print("  \(dim)\(cmd.description)\(reset)") }

            if !agents.isEmpty {
                let activeIn = agents.filter {
                    fm.fileExists(atPath: $0.path.appendingPathComponent("\(cmd.id).\($0.fileExtension)").path)
                }
                if activeIn.isEmpty {
                    print("  \(gray)not activated\(reset)")
                } else {
                    let names = activeIn.map { agent -> String in
                        let dest = agent.path.appendingPathComponent("\(cmd.id).\(agent.fileExtension)")
                        let tag  = (agent.format == .markdown && isSymlink(dest)) ? "" : " \(yellow)(copy)\(reset)"
                        return "\(green)●\(reset) \(agent.name)\(tag)"
                    }.joined(separator: "  ")
                    print("  \(names)")
                }
            }
            print()
        }
    }
}
