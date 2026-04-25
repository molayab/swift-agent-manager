import Testing
import Foundation

@testable import cli_manager

struct UserCommandModelTests {

    // MARK: - Helpers

    private func makeCommand(
        id: String = "test",
        name: String = "Test",
        description: String = "A test command",
        body: String = "Do something useful.",
        isPrivate: Bool = false
    ) -> UserCommandModel {
        UserCommandModel(
            id: id,
            file: URL(fileURLWithPath: "/tmp/test.md"),
            name: name,
            description: description,
            body: body,
            isPrivate: isPrivate
        )
    }

    // MARK: - geminiTOML

    @Test("Produces correct TOML with both a description line and a triple-quoted prompt block")
    func geminiTOMLWithDescriptionAndBody() {
        let cmd = makeCommand(description: "Reviews code", body: "Review the following code.")
        let expected = "description = \"Reviews code\"\nprompt = \"\"\"\nReview the following code.\n\"\"\""
        #expect(UserCommandModel.geminiTOML(from: cmd) == expected)
    }

    @Test("Omits the description line entirely when description is empty")
    func geminiTOMLOmitsDescriptionLineWhenEmpty() {
        let cmd = makeCommand(description: "", body: "Do something.")
        let toml = UserCommandModel.geminiTOML(from: cmd)
        #expect(toml.contains("description") == false)
        #expect(toml.hasPrefix("prompt = \"\"\""))
    }

    @Test("Doubles each backslash in the description so TOML interprets them as literal backslashes")
    func geminiTOMLDoublesBackslashesInDescription() {
        // description [actual]: path\to\file  →  TOML value: path\\to\\file
        let cmd = makeCommand(description: "path\\to\\file", body: "body")
        let toml = UserCommandModel.geminiTOML(from: cmd)
        #expect(toml.contains("path\\\\to\\\\file"))
    }

    @Test("Escapes double quotes in the description with a preceding backslash")
    func geminiTOMLEscapesDoubleQuotesInDescription() {
        // description [actual]: say "hello"  →  TOML value: say \"hello\"
        let cmd = makeCommand(description: "say \"hello\"", body: "body")
        let toml = UserCommandModel.geminiTOML(from: cmd)
        #expect(toml.contains("\\\"hello\\\""))
    }

    @Test("Escapes backslash before escaping quotes so the backslash from quote-escaping is not doubled")
    func geminiTOMLEscapesBackslashBeforeQuote() {
        // description [actual]: path\"note
        // Correct order — \ → \\ first, then " → \"  →  TOML value: path\\\"note
        // Wrong order  — " → \" first, then \ → \\  →  TOML value: path\\\\\"note  (extra doubling)
        let cmd = makeCommand(description: "path\\\"note", body: "body")
        let toml = UserCommandModel.geminiTOML(from: cmd)
        // Expect exactly two backslashes before the escaped quote (not four)
        #expect(toml.contains("path\\\\\\\"note"))
        #expect(toml.contains("path\\\\\\\\") == false)
    }

    @Test("Replaces triple-quote sequences in the body to prevent accidentally closing the TOML multi-line string")
    func geminiTOMLEscapesTripleQuoteInBody() {
        // body [actual]: Use """ for docstrings.
        // """ must become ""\" so TOML does not interpret it as the closing delimiter
        let cmd = makeCommand(description: "", body: "Use \"\"\" for docstrings.")
        let toml = UserCommandModel.geminiTOML(from: cmd)
        #expect(toml.contains("\"\"\\\""))
    }

    // MARK: - resolveUserCommands

    @Test("Returns all commands when no filter is provided")
    func resolveAllCommandsWhenFilterIsEmpty() {
        let commands = [
            makeCommand(id: "review", name: "Review"),
            makeCommand(id: "explain", name: "Explain")
        ]
        let resolved = UserCommandModel.resolveUserCommands([], from: commands)
        #expect(resolved.count == commands.count)
    }

    @Test("Filters commands by id, by name, by both, or returns nothing for unknown terms", arguments: [
        (["review"], 1),   // match by id
        (["Review"], 1),   // match by name (case-sensitive exact match)
        (["unknown"], 0),   // no match
        (["review", "explain"], 2)  // match multiple
    ])
    func resolveCommandsByIdOrName(filter: [String], expectedCount: Int) {
        let commands = [
            makeCommand(id: "review", name: "Review"),
            makeCommand(id: "explain", name: "Explain")
        ]
        #expect(UserCommandModel.resolveUserCommands(filter, from: commands).count == expectedCount)
    }
}
