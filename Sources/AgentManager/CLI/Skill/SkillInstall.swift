import ArgumentParser
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct SkillInstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install skills from a GitHub repository into this repo."
    )

    @Argument(help: "Source repository in owner/repo format.")
    var repo: String

    @Argument(help: "Skill names to install (omit to pick interactively).")
    var names: [String] = []

    @Flag(name: .long, help: "Overwrite an existing local skill.")
    var force = false

    func run() async throws {
        guard repo.contains("/") else {
            fail("Repo must be in owner/repo format (e.g. rudrankriyam/app-store-connect-cli-skills)")
            return
        }

        info("Fetching available skills from \(repo)…")

        let remote: [RemoteEntry]
        do {
            remote = try await remoteSkills()
        } catch {
            fail("Could not reach \(repo): \(error.localizedDescription)")
            return
        }
        guard !remote.isEmpty else {
            fail("No skills found in \(repo).")
            return
        }

        let selected: [RemoteEntry]
        if names.isEmpty {
            selected = selectInteractive(
                prompt: "Select skills to install",
                items: remote,
                display: \.name
            )
        } else {
            selected = names.compactMap { name in
                guard let match = remote.first(where: { $0.name == name }) else {
                    warn("'\(name)' not found in \(repo) — skipping.")
                    return nil
                }
                return match
            }
        }
        guard !selected.isEmpty else {
            fail("No skills selected.")
            return
        }

        print("\n\(bold)Installing \(selected.count) skill(s) → \(skillsDir.path)\(reset)\n")

        for entry in selected {
            do {
                try await installSkill(entry)
            } catch {
                fail("  \(entry.name): \(error.localizedDescription)")
            }
        }
        print()
    }

    // MARK: - Per-skill

    private func installSkill(_ entry: RemoteEntry) async throws {
        let dest = skillsDir.appendingPathComponent(entry.name)

        if fm.fileExists(atPath: dest.path) {
            guard force else {
                skip("  \(entry.name)  \(gray)already installed (use --force to overwrite)\(reset)")
                return
            }
            try fm.removeItem(at: dest)
        }

        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        do {
            try await downloadDirectory(from: entry.url, to: dest)
            ok("  \(entry.name)")
        } catch {
            try? fm.removeItem(at: dest)
            throw error
        }
    }

    // MARK: - Recursive download (concurrent per directory level)

    private func downloadDirectory(from url: URL, to dest: URL) async throws {
        let entries = try await listContents(url: url)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for entry in entries {
                group.addTask {
                    try await self.handleEntry(entry, in: dest)
                }
            }
            for try await _ in group { }
        }
    }

    private func handleEntry(_ entry: RemoteEntry, in dest: URL) async throws {
        switch entry.type {
        case "file":
            guard let downloadURL = entry.downloadURL else {
                return
            }
            let data = try await fetch(downloadURL)
            try data.write(to: dest.appendingPathComponent(entry.name))
        case "dir":
            let sub = dest.appendingPathComponent(entry.name)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try await downloadDirectory(from: entry.url, to: sub)
        default:
            break
        }
    }

    // MARK: - GitHub Contents API

    private func remoteSkills() async throws -> [RemoteEntry] {
        let url = URL(string: "https://api.github.com/repos/\(repo)/contents/skills")!
        return try await listContents(url: url).filter { $0.type == "dir" }
    }

    private func listContents(url: URL) async throws -> [RemoteEntry] {
        try JSONDecoder().decode([RemoteEntry].self, from: await fetch(url))
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("agent-manager/1.0.0", forHTTPHeaderField: "User-Agent")
        if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let host = url.host ?? url.absoluteString
            throw URLError(
                .badServerResponse,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode) from \(host)"]
            )
        }
        return data
    }
}

// MARK: - GitHub Contents API entry

private struct RemoteEntry: Decodable, Sendable {
    let name: String
    let type: String
    let url: URL
    let downloadURL: URL?

    enum CodingKeys: String, CodingKey {
        case name, type, url
        case downloadURL = "download_url"
    }
}
