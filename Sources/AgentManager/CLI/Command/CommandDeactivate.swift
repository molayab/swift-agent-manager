import ArgumentParser
import Foundation

struct CommandDeactivate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "deactivate",
        abstract: "Remove commands from agent directories."
    )

    @Option(name: .shortAndLong, help: "Target a specific command by name (repeatable).")
    var command: [String] = []

    @Option(name: .shortAndLong, help: "Target a specific agent by ID (repeatable).")
    var agent: [String] = []

    @Flag(name: .long, help: "Preview changes without applying them.")
    var dryRun = false

    func run() throws {
        let allCmds = UserCommandModel.loadCommands()
        guard !allCmds.isEmpty else { fail("No commands found in commands/"); return }

        let cmds: [UserCommandModel] = command.isEmpty
            ? selectInteractive(prompt: "Select commands to deactivate", items: allCmds, display: { "/\($0.id)" })
        : UserCommandModel.resolveUserCommands(command, from: allCmds)
        guard !cmds.isEmpty else { fail("No matching commands."); return }

        let targets: [CommandModel]
        if agent.isEmpty {
            let detected = CommandModel.detectedCommandAgents()
            guard !detected.isEmpty else {
                warn("No command agents detected.")
                info("Use --agent <id>. Available: \(CommandModel.allCommandAgents.map(\.id).joined(separator: ", "))")
                return
            }
            targets = selectInteractive(prompt: "Select agents", items: detected, display: \.name)
        } else {
            guard let resolvedTargets = CommandModel.resolveCommandAgents(agent) else { return }
            targets = resolvedTargets
        }
        guard !targets.isEmpty else { fail("No agents selected."); return }

        print("\n\(bold)Deactivating \(cmds.count) command(s) from \(targets.count) agent(s)\(reset)"
            + (dryRun ? "  \(yellow)(dry run)\(reset)" : "") + "\n")

        for agent in targets {
            print("\(bold)\(agent.name)\(reset)  \(gray)\(agent.path.path)\(reset)")
            for cmd in cmds {
                deactivateCommand(cmd, from: agent)
            }
            print()
        }
    }

    private func deactivateCommand(_ cmd: UserCommandModel, from agent: CommandModel) {
        let dest = agent.path.appendingPathComponent("\(cmd.id).\(agent.fileExtension)")
        guard fm.fileExists(atPath: dest.path) else {
            skip("  /\(cmd.id)  \(gray)not active\(reset)"); return
        }
        if dryRun {
            ok("  /\(cmd.id)  \(gray)→ would remove\(reset)")
        } else {
            do {
                try fm.removeItem(at: dest)
                ok("  /\(cmd.id)  \(gray)removed\(reset)")
            } catch {
                fail("  /\(cmd.id): \(error.localizedDescription)")
            }
        }
    }
}
