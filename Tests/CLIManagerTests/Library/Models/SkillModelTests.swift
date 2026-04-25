import Testing
import Foundation

@testable import cli_manager

struct SkillModelTests {

    // MARK: - Helpers

    private func makeSkill(id: String, name: String, isPrivate: Bool = false) -> SkillModel {
        SkillModel(
            id: id,
            dir: URL(fileURLWithPath: "/tmp/\(id)"),
            name: name,
            description: "Test skill",
            isPrivate: isPrivate
        )
    }

    // MARK: - resolveSkills

    @Test("Returns the full list when no filter is specified")
    func resolveSkillsReturnsAllWhenFilterIsEmpty() {
        let skills = [
            makeSkill(id: "swift-testing", name: "Swift Testing"),
            makeSkill(id: "swiftui", name: "SwiftUI")
        ]
        #expect(SkillModel.resolveSkills([], from: skills).count == skills.count)
    }

    @Test("Filters skills matching by id, by name, multiple terms, or nothing for unknown terms", arguments: [
        (["swift-testing"], 1),   // match by id
        (["Swift Testing"], 1),   // match by name (case-sensitive)
        (["nonexistent"], 0),   // no match
        (["swift-testing", "swiftui"], 2)   // match multiple by id
    ])
    func resolveSkillsByIdOrName(filter: [String], expectedCount: Int) {
        let skills = [
            makeSkill(id: "swift-testing", name: "Swift Testing"),
            makeSkill(id: "swiftui", name: "SwiftUI")
        ]
        #expect(SkillModel.resolveSkills(filter, from: skills).count == expectedCount)
    }

    @Test("A private skill is found by its base id (without the .private suffix)")
    func privateSkillIsFoundByBaseID() throws {
        // SkillModel strips .private when computing the id, so callers always use the clean id.
        let privateSkill = makeSkill(id: "my-skill", name: "My Skill", isPrivate: true)
        let skills = [privateSkill]
        let resolved = SkillModel.resolveSkills(["my-skill"], from: skills)
        let first = try #require(resolved.first)
        #expect(first.isPrivate == true)
    }
}
