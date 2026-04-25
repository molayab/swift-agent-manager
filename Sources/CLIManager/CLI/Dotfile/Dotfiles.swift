import ArgumentParser

struct Dotfiles: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dotfile",
        abstract: "Manage dotfiles tracked in this repo.",
        subcommands: [
            DotfileList.self,
            DotfileLink.self,
            DotfileUnlink.self,
            DotfileNew.self,
            DotfileImport.self,
            DotfileStatus.self,
            DotfilePrivate.self
        ],
        defaultSubcommand: DotfileList.self
    )
}
