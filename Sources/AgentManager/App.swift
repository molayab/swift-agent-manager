import ArgumentParser

@main
struct CLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent-manager",
        abstract: "Personal AI agent configuration manager — skills, commands, and git.",
        version: "1.0.0",
        subcommands: [
            Skills.self,
            Sync.self,
            Repo.self,
            Push.self,
            Pull.self,
            Commands.self,
            Clean.self
        ]
    )
}
