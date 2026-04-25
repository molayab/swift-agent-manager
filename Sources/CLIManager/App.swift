import ArgumentParser

@main
struct CLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cli-manager",
        abstract: "Personal AI agent configuration manager — skills, commands, and git.",
        version: buildVersion,
        subcommands: [
            Skills.self,
            Commands.self,
            Dotfiles.self,
            Sync.self,
            Repo.self,
            Push.self,
            Pull.self,
            Clean.self
        ]
    )

    mutating func run() throws {
        print("\(bold)Repo:\(reset) \(gray)\(repoRoot.path)\(reset)\n")
        throw CleanExit.helpRequest()
    }
}
