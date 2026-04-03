import ArgumentParser
import Foundation

struct CommandActivate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "activate",
        abstract: "Install commands into agent directories."
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
            ? selectInteractive(prompt: "Select commands to activate", items: allCmds, display: { "/\($0.id)" })
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

        print("\n\(bold)Activating \(cmds.count) command(s) → \(targets.count) agent(s)\(reset)"
            + (dryRun ? "  \(yellow)(dry run)\(reset)" : "") + "\n")

        for agent in targets {
            print("\(bold)\(agent.name)\(reset)  \(gray)\(agent.path.path)\(reset)")
            if !dryRun && !fm.fileExists(atPath: agent.path.path) {
                try fm.createDirectory(at: agent.path, withIntermediateDirectories: true)
            }
            for cmd in cmds {
                try activateCommand(cmd, into: agent)
            }
            print()
        }
    }

    private func activateCommand(_ cmd: UserCommandModel, into agent: CommandModel) throws {
        let dest = agent.path.appendingPathComponent("\(cmd.id).\(agent.fileExtension)")
        if fm.fileExists(atPath: dest.path) {
            let kind = agent.format == .markdown ? (isSymlink(dest) ? "symlink" : "copy") : "toml"
            skip("  /\(cmd.id)  \(gray)already active (\(kind))\(reset)")
            return
        }
        if dryRun {
            let action = agent.format == .geminiTOML ? "would write TOML" : "would symlink"
            ok("  /\(cmd.id)  \(gray)→ \(action)\(reset)")
            return
        }
        do {
            switch agent.format {
            case .markdown:
                try fm.createSymbolicLink(at: dest, withDestinationURL: cmd.file)
                ok("  /\(cmd.id)")
            case .geminiTOML:
                try UserCommandModel.geminiTOML(from: cmd).write(to: dest, atomically: true, encoding: .utf8)
                ok("  /\(cmd.id)  \(gray)→ TOML\(reset)")
            }
        } catch {
            fail("  /\(cmd.id): \(error.localizedDescription)")
        }
    }
}
