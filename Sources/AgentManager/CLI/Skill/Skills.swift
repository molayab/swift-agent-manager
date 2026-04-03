import ArgumentParser

struct Skills: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skill",
        abstract: "Manage AI agent skills.",
        subcommands: [
            SkillList.self,
            SkillActivate.self,
            SkillDeactivate.self,
            SkillNew.self,
            SkillStatus.self,
            SkillInstall.self,
            SkillPrivate.self
        ],
        defaultSubcommand: SkillList.self
    )
}
