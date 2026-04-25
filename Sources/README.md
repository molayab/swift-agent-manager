# CLIManager — Architecture & Technical Reference

## Overview

`cli-manager` is a Swift CLI for managing AI agent skills and slash commands across multiple code editors. It stores everything in a local git repository and synchronizes via symlinks into each agent's configuration directory.

**Supported agents:** Claude Code, OpenCode, GitHub Copilot, Cursor, Codex, Gemini CLI, Windsurf

---

## Command Hierarchy

```
cli-manager
├── skill               Skill management
│   ├── list            List all skills with activation status (default)
│   ├── new <name>      Scaffold a new skill directory with SKILL.md
│   ├── install <repo>  Download skills from a GitHub repository
│   ├── activate        Symlink skills into agent directories
│   ├── deactivate      Remove skills from agent directories
│   ├── status          Show activation status per agent
│   └── private <id>    Toggle skill between public and private
├── command             Slash command management
│   ├── list            List all commands with activation status (default)
│   ├── new <name>      Scaffold a new command file
│   ├── activate        Install commands into agent directories
│   ├── deactivate      Remove commands from agent directories
│   ├── status          Show activation status per agent
│   ├── import          Pull commands from agent directories into the repo
│   └── private <id>    Toggle command between public and private
├── sync                Convert file copies into symlinks
├── clean               Remove dead symlinks from all agent directories
├── repo                Show git status or initialize the repo (--init)
├── push                Stage, commit, and push all changes
└── pull                Pull latest changes from remote
```

---

## Architecture

### Entry Point

**`App.swift`** — Defines the root `CLIManager` struct using `ArgumentParser`. Version is stamped from the git tag at build time via a `Run Script` phase that rewrites `App.swift` before compilation.

```swift
@main struct CLIManager: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "cli-manager",
        version: buildVersion,
        subcommands: [Skills.self, Commands.self, Sync.self, Repo.self, Push.self, Pull.self, Clean.self]
    )
}
```

All commands inherit from `ParsableCommand` (sync) or `AsyncParsableCommand` (async, e.g. `SkillInstall`).

### Directory Layout

```
Sources/CLIManager/
├── App.swift                        Entry point and root command
├── CLI/
│   ├── Core/                        System-level commands
│   │   ├── Agent.swift              Agent definitions and detection
│   │   ├── Frontmatter.swift        YAML frontmatter parsing
│   │   ├── Sync.swift               Symlink synchronization
│   │   ├── Clean.swift              Dead symlink removal
│   │   └── Git/
│   │       ├── Repo.swift           Git status / repo init
│   │       ├── Push.swift           Commit and push
│   │       └── Pull.swift           Pull from remote
│   ├── Skill/                       Skill subcommands
│   │   ├── Skills.swift             Subcommand group
│   │   ├── SkillList.swift
│   │   ├── SkillNew.swift
│   │   ├── SkillInstall.swift       Async GitHub API download
│   │   ├── SkillActivate.swift
│   │   ├── SkillDeactivate.swift
│   │   ├── SkillStatus.swift
│   │   ├── SkillPrivate.swift
│   │   └── Helpers/
│   │       └── SkillFilterOptions.swift   Reusable --skill / --agent flags
│   └── Command/                     Slash command subcommands
│       ├── Commands.swift           Subcommand group
│       ├── CommandList.swift
│       ├── CommandNew.swift
│       ├── CommandActivate.swift
│       ├── CommandDeactivate.swift
│       ├── CommandStatus.swift
│       ├── CommandImport.swift
│       └── CommandPrivate.swift
└── Library/
    ├── Terminal.swift               TTY detection, ANSI colors, status output
    ├── FileManager+Helpers.swift    Path resolution and tilde expansion
    ├── GitRunner.swift              Process-based git wrapper
    └── Models/
        ├── CommandModel.swift       Slash command agent definitions
        ├── UserCommandModel.swift   User-authored command parsing
        └── SkillModel.swift         Skill directory parsing
```

---

## Key Models

### `Agent` (`CLI/Core/Agent.swift`)

Represents a supported AI coding agent. Hardcodes the 8 known agents and their skill directory paths.

| Property | Description |
|---|---|
| `id` | Short identifier (e.g. `"claude"`) |
| `name` | Display name |
| `path` | Absolute URL to agent's skills directory |

Key methods:
- `detectedAgents()` — returns agents whose skill directories exist on disk
- `resolveTargets(_:)` — resolves a list of IDs to `Agent` instances
- `selectAgentTargets(filter:)` — interactive multi-select (falls back to all if not a TTY)

### `SkillModel` (`Library/Models/SkillModel.swift`)

Represents a skill in the repository. A skill is a directory under `skills/` containing a `SKILL.md` file with YAML frontmatter.

| Property | Description |
|---|---|
| `id` | Directory name |
| `dir` | URL of the skill directory |
| `name` | Parsed from frontmatter `name:` field |
| `description` | Parsed from frontmatter `description:` field |
| `isPrivate` | True when a `.private` file exists in the skill directory |

Key methods:
- `loadSkills()` — scans `skillsDir` and returns all valid skills
- `resolveSkills(_:from:)` — resolves skill identifiers to models

### `UserCommandModel` (`Library/Models/UserCommandModel.swift`)

Represents a slash command (a `.md` file under `commands/`).

| Property | Description |
|---|---|
| `id` | Filename without extension |
| `file` | URL of the source file |
| `name` | Parsed from frontmatter `name:` field |
| `description` | Parsed from frontmatter `description:` field |
| `body` | Full file content (frontmatter stripped for activation) |
| `isPrivate` | True for `.private.md` files |

Key methods:
- `loadCommands()` — scans `commandsDir`
- `geminiTOML(from:)` — generates Gemini CLI TOML format from a command

### `CommandModel` (`Library/Models/CommandModel.swift`)

Represents a target agent for slash commands. Supports two formats:

- `.markdown` — file symlinked directly (Claude Code, OpenCode, Windsurf)
- `.geminiTOML` — content converted and written as TOML (Gemini CLI)

Key methods:
- `detectedCommandAgents()` — agents whose command directories exist
- `selectTargets(_:)` — interactive multi-select

### `Frontmatter` (`CLI/Core/Frontmatter.swift`)

Enum providing static YAML frontmatter utilities:
- `yamlField(_:in:)` — extracts a scalar value from `key: value` lines using regex
- `stripFrontmatter(_:)` — removes the `---` delimited block from a markdown string

---

## Library Utilities

### `Terminal` (`Library/Terminal.swift`)

- Detects TTY with `isatty(STDOUT_FILENO)`
- Provides colored status printers: `ok()`, `warn()`, `fail()`, `info()`, `skip()`
- Falls back to plain symbols (`✓ ! ✗ i −`) when piped

### `FileManager+Helpers` (`Library/FileManager+Helpers.swift`)

- `repoRoot` — resolved via: `$CLI_MANAGER_REPO` env var → `~/.config/cli-manager/repo` config file → walk up directories for `Package.swift` → current directory
- `skillsDir` — `repoRoot/skills`
- `commandsDir` — `repoRoot/commands`
- Custom tilde expansion avoids ObjC runtime dependency

### `GitRunner` (`Library/GitRunner.swift`)

Thin wrapper around `/usr/bin/env git` using `Foundation.Process`:
```swift
GitRunner.run(["commit", "-m", "Update skills"], in: repoRoot)
// Returns (output: String, exitCode: Int32)
```

---

## File Formats

### Skill (`skills/<name>/SKILL.md`)

```markdown
---
name: My Skill
description: What this skill does
---

Skill content here...
```

Privacy is controlled by the presence of a `.private` file in the skill directory (causing `SKILL.md` to be git-ignored).

### Command (`commands/<name>.md`)

```markdown
---
name: My Command
description: What this command does
---

Prompt template content here...
```

Private commands use `.private.md` extension.

### Gemini CLI TOML (generated)

```toml
[[commands]]
name = "my-command"
description = """
What this command does
"""
prompt = """
Prompt template content here...
"""
```

---

## Agent Directory Paths

| Agent | Skills path | Commands path |
|---|---|---|
| Claude Code | `~/.claude/skills` | `~/.claude/commands` |
| OpenCode | `~/.config/opencode/skills` | `~/.config/opencode/commands` |
| GitHub Copilot | `~/.copilot/skills` | — |
| Cursor | `~/.cursor/skills` | — |
| Codex | `~/.codex/skills` | — |
| Gemini CLI | `~/.gemini/skills` | `~/.gemini/commands` |
| Windsurf | `~/.codeium/windsurf/skills` | `~/.codeium/windsurf/global_workflows` |

---

## GitHub Install Flow (`skill install`)

1. Calls GitHub Contents API (`https://api.github.com/repos/<owner>/<repo>/contents/skills`)
2. Recursively traverses directories using `withThrowingTaskGroup` for concurrent downloads
3. Writes files to the local `skills/` directory
4. After install, run `sync` to convert any plain copies into symlinks

Environment variables:
- `GITHUB_TOKEN` — optional, raises API rate limit from 60 to 5000 req/hr

Request settings: 15-second timeout, `Accept: application/vnd.github+json`

---

## Build & Dependencies

**`Package.swift`**
- Swift tools: 6.1
- Platform: macOS 13+
- Dependencies: [`swift-argument-parser`](https://github.com/apple/swift-argument-parser) 1.7.1 (exact)
- Single executable target: `cli-manager`

**Version stamping** — A Xcode `Run Script` build phase replaces the `version:` string in `App.swift` with the current `git describe --tags` output before compilation.

---

## Configuration

| Source | Description |
|---|---|
| `$CLI_MANAGER_REPO` | Override the repository root path |
| `~/.config/cli-manager/repo` | Persisted repo path written by `install.py` or `cli-manager repo --init`/`--use` |
| `$GITHUB_TOKEN` | GitHub API token for `skill install` |

Binary installed to: `~/.config/cli-manager/bin/cli-manager`
