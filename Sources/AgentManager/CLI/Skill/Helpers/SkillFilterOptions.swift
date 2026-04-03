import ArgumentParser

struct SkillFilterOptions: ParsableArguments {
    @Option(name: .shortAndLong, help: "Target a specific skill by name (repeatable).")
    var skill: [String] = []

    @Option(name: .shortAndLong, help: "Target a specific agent by ID (repeatable).")
    var agent: [String] = []
}
