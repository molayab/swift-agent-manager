# AGENTS.md

This file provides guidance to AI agents working in this repository.

## What This Project Does

`cli-manager` is a CLI tool that manages AI agent skills and slash commands across multiple agents (Claude Code, Cursor, Windsurf, Gemini CLI, etc.) using a single git repository as the source of truth. It creates symlinks from each agent's config directory into this repo so one update propagates everywhere.

## Build & Test Commands

```sh
swift build                                              # Build executable
swift test                                               # Run all tests
swift test --filter SkillModelTests                      # Run specific test class
swift test --filter SkillModelTests/testMethodName       # Run specific test
swiftlint lint --quiet Sources/                          # Lint
```

## Architecture

### Repository Discovery
The binary locates this repo via a 3-step fallback (in `FileManager+Helpers.swift`):
1. `CLI_MANAGER_REPO` environment variable
2. `~/.config/cli-manager/repo` config file (written by install.py)
3. Walk-up search from CWD looking for `Package.swift`

### Key Globals (`FileManager+Helpers.swift`)
`fm`, `home`, `repoRoot`, `skillsDir`, `commandsDir`, `dotfilesDir` — used throughout all CLI commands.

### CLI Structure (`Sources/CLIManager/CLI/`)
- **`skill/`** — 9 subcommands: list, new, activate, deactivate, install, import, status, private
- **`command/`** — 7 subcommands: list, new, activate, deactivate, import, status, private
- **`dotfile/`** — 7 subcommands: list, link, unlink, new, import, status, private
- **`Core/`** — clean (dead symlinks), sync (copies→symlinks), git push/pull/repo init

### Models (`Sources/CLIManager/Library/Models/`)
- `SkillModel` — loads from `skills/<slug>/SKILL.md`, reads YAML frontmatter
- `CommandModel` — loads from `commands/<slug>.md`, supports Markdown and TOML agent formats
- `DotfileModel` — loads from `dotfiles/<slug>/DOTFILE.md`, reads YAML frontmatter

### Skill Format
```
skills/<name>/
  SKILL.md          # Required: YAML frontmatter (name:, description:) + markdown body
  references/       # Optional: supporting docs referenced in SKILL.md
```

### Command Format
```
commands/<name>.md  # YAML frontmatter (description:) + prompt body with $ARGUMENTS placeholder
```

### Dotfile Format
```
dotfiles/<name>/
  DOTFILE.md        # Required: YAML frontmatter (name:, description:, link:, file:) + markdown body
                    #   link: target symlink path, e.g. ~/.gitconfig or ~/.config/starship/starship.toml
                    #   file: source filename in this dir (optional, defaults to last component of link)
  <filename>        # The actual dotfile content (e.g. .gitconfig, starship.toml)
```

When `dotfile link` is run, a symlink is created at `link` → `dotfiles/<name>/<file>`.

### Private Files
Append `.private` to a skill/command/dotfile slug to git-ignore it (personal or work-specific content not shared in the repo).

## Code Style & Conventions

- **Naming**: PascalCase for files/types, camelCase for variables/functions
- **Types**: Favor `struct` over `class` for data models
- **Optionals**: Use `if let`/`guard let`; avoid force unwrap
- **Errors**: Throwing functions over `fatalError()`; `enum` for specific error types
- **Docs**: `///` triple-slash comments for public APIs
- **Indentation**: 4 spaces
- **Imports**: Standard library → third-party (ArgumentParser) → local modules
