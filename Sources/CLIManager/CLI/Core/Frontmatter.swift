import Foundation

enum Frontmatter {
    static func yamlField(_ key: String, in text: String) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: "^\(key):\\s*(.+)$", options: .anchorsMatchLines),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range]).trimmingCharacters(in: .whitespaces)
    }

    static func stripFrontmatter(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard !lines.isEmpty, lines[0].trimmingCharacters(in: .whitespaces) == "---" else {
            return text
        }
        for index in 1..<lines.count where lines[index].trimmingCharacters(in: .whitespaces) == "---" {
            return lines[(index + 1)...].joined(separator: "\n").trimmingCharacters(in: .newlines)
        }
        return text
    }
}
