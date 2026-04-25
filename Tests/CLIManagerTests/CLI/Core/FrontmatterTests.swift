import Testing

@testable import cli_manager

struct FrontmatterTests {

    // MARK: - yamlField

    @Test("Extracts each field correctly from a multi-field YAML frontmatter block", arguments: [
        ("name", "My Skill"),
        ("description", "A great skill for testing"),
        ("version", "1.2.3")
    ])
    func extractsFieldFromFrontmatter(key: String, expected: String) {
        let text = """
        ---
        name: My Skill
        description: A great skill for testing
        version: 1.2.3
        ---
        Some content here.
        """
        #expect(Frontmatter.yamlField(key, in: text) == expected)
    }

    @Test("Returns nil for a key that does not exist in the frontmatter")
    func missingKeyReturnsNil() {
        let text = """
        ---
        name: My Skill
        ---
        """
        #expect(Frontmatter.yamlField("author", in: text) == nil)
    }

    @Test("Returns an empty string (not nil) for a whitespace-only value due to regex backtracking")
    func whitespaceOnlyValueReturnsEmptyString() {
        // The greedy \s* backtracks so (.+) can capture a trailing space, which then
        // trims to "". Callers that use ?? to substitute a fallback must also guard
        // against the empty-string case, since "" is not nil.
        let text = "name:   "
        #expect(Frontmatter.yamlField("name", in: text) == "")
    }

    @Test("Returns nil when the text has no frontmatter at all")
    func noFrontmatterReturnsNil() {
        #expect(Frontmatter.yamlField("name", in: "Just plain text with no delimiters.") == nil)
    }

    @Test("Does not match a key that contains the search key as an embedded substring")
    func doesNotMatchKeyEmbeddedInAnotherKey() {
        // "name" must not match "full-name" — the ^ anchor enforces line-start matching,
        // and the colon delimiter prevents prefix ambiguity (e.g. "named:").
        let text = "---\nfull-name: Somebody\nnamed: Something\n---"
        #expect(Frontmatter.yamlField("name", in: text) == nil)
    }

    @Test("Trims leading and trailing whitespace from an extracted value")
    func trimsWhitespaceFromExtractedValue() {
        // The regex captures everything after the colon; trimmingCharacters cleans the edges.
        let text = "name:   padded value   "
        #expect(Frontmatter.yamlField("name", in: text) == "padded value")
    }

    // MARK: - stripFrontmatter

    @Test("Strips a valid YAML frontmatter block and returns only the body content")
    func stripsValidFrontmatter() {
        let text = """
        ---
        name: My Skill
        ---
        This is the body content.
        """
        #expect(Frontmatter.stripFrontmatter(text) == "This is the body content.")
    }

    @Test("Returns the original text unchanged when there is no opening frontmatter delimiter")
    func noFrontmatterDelimiterReturnsTextUnchanged() {
        let text = "Just plain text."
        #expect(Frontmatter.stripFrontmatter(text) == text)
    }

    @Test("Returns the original text unchanged when the frontmatter opening delimiter is never closed")
    func unclosedFrontmatterReturnsTextUnchanged() {
        let text = "---\nname: My Skill\ndescription: Never closed"
        #expect(Frontmatter.stripFrontmatter(text) == text)
    }

    @Test("Trims surrounding newlines from the body content after stripping frontmatter")
    func trimsSurroundingNewlinesFromBody() {
        let text = "---\nname: Test\n---\n\nContent with surrounding newlines.\n\n"
        #expect(Frontmatter.stripFrontmatter(text) == "Content with surrounding newlines.")
    }

    @Test("Returns an empty string when the frontmatter block is empty (--- immediately followed by ---)")
    func emptyFrontmatterBlockYieldsEmptyBody() {
        let text = "---\n---\n"
        #expect(Frontmatter.stripFrontmatter(text) == "")
    }
}
