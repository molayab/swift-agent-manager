import ArgumentParser

struct Commands: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "command",
        abstract: "Manage slash commands (/name) for AI agents.",
        subcommands: [
            CommandList.self, CommandActivate.self, CommandDeactivate.self,
            CommandNew.self, CommandStatus.self, CommandImport.self, CommandPrivate.self
        ],
        defaultSubcommand: CommandList.self
    )
}
