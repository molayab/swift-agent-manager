# agent-manager

Manage AI agent skills and slash commands across every tool and machine from a single git repository.

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B%20%7C%20Linux-lightgrey)](https://www.swift.org/)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![CI](https://github.com/molayab/swift-agent-manager/actions/workflows/ci.yml/badge.svg)](https://github.com/molayab/swift-agent-manager/actions/workflows/ci.yml)
[![Release](https://github.com/molayab/swift-agent-manager/actions/workflows/release.yml/badge.svg)](https://github.com/molayab/swift-agent-manager/actions/workflows/release.yml)

---

Modern development involves several AI coding agents — OpenCode, Claude Code, GitHub Copilot, Cursor, Windsurf, and more. Each stores its skills and slash commands in its own local directory. The result:

- The same prompt exists in five different places, each slightly out of sync
- A fix to a system prompt must be applied manually to every agent
- Nothing is versioned, so configuration is lost when you reformat or switch machines
- There is no way to share useful prompts with teammates or the community

`agent-manager` fixes this with a single git repo as the source of truth. Skills and commands live here. The tool creates symlinks into each agent's configuration directory so every agent picks them up. Update a file once — every agent sees the change.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Option A — one-liner](#option-a--one-liner-no-clone-required)
  - [Option B — clone and install](#option-b--clone-and-install)
  - [How the binary locates the repo](#how-the-binary-locates-the-repo)
- [Quick Start](#quick-start)
- [Repository Layout](#repository-layout)
- [Adding Skills and Commands](#adding-skills-and-commands)
- [Installing Skills from GitHub](#installing-skills-from-github)
- [Importing Commands from Agents](#importing-commands-from-agents)
- [Public, Private, or Mixed](#public-private-or-mixed)
- [Syncing Across Machines](#syncing-across-machines)
- [Command Reference](#command-reference)
- [Supported Agents](#supported-agents)
- [Skill Format](#skill-format)
- [Command Format](#command-format)
- [Contributing](#contributing)
- [License](#license)

---

## Prerequisites

- macOS 13 or later, or Linux (Ubuntu 22.04+)
- Swift 6.2 — only required when **building from source**; pre-compiled binaries need no toolchain
  - macOS: bundled with [Xcode 26+](https://developer.apple.com/xcode/) or the [Swift toolchain](https://www.swift.org/install/)
  - Linux: install via the [Swift toolchain](https://www.swift.org/install/)

---

## Installation

### Option A — one-liner (no clone required)

```sh
curl -fsSL https://raw.githubusercontent.com/molayab/swift-agent-manager/main/quickinstall.py | python3
```

The script sets up everything from scratch — no existing repo or Swift toolchain needed:

1. Downloads the pre-compiled binary for your platform
2. Creates an **empty repo** at `~/.config/agent-manager/src/` with `skills/`, `commands/`, and a `.gitignore`
3. Runs `git init` and makes an initial commit (skipped if the directory is already a git repo)
4. Installs the binary to `~/.config/agent-manager/src/bin/`
5. Writes `~/.config/agent-manager/repo` so the binary knows where your repo lives

After install, add your skills and commands, then push to your own remote whenever you're ready:

```sh
cd ~/.config/agent-manager/src
git remote add origin https://github.com/<you>/my-agents.git
git push -u origin main
```

**Options:**

```sh
# Install binary to /usr/local/bin as well
curl -fsSL https://raw.githubusercontent.com/molayab/swift-agent-manager/main/quickinstall.py | python3 - --global

# Pin to a specific release
curl -fsSL https://raw.githubusercontent.com/molayab/swift-agent-manager/main/quickinstall.py | python3 - --version 1.0.5 --global

# Custom repo directory
curl -fsSL https://raw.githubusercontent.com/molayab/swift-agent-manager/main/quickinstall.py | python3 - --dir ~/my-agents
```

### Option B — clone and install

Clone your fork (or this repo), then choose how to build or download:

```sh
git clone https://github.com/<you>/agent-manager ~/agent-manager
cd ~/agent-manager
```

**Download a pre-compiled binary** (no Swift toolchain required):

```sh
python3 install.py --binary            # install to ./bin/
python3 install.py --binary --global   # install to /usr/local/bin
python3 install.py --binary --version 1.0.4 --global
```

**Build from source** (requires Swift 6.2):

```sh
python3 install.py            # install to ./bin/
python3 install.py --global   # install to /usr/local/bin
```

Examples throughout this README assume a global install. If you installed locally, replace `agent-manager` with `./bin/agent-manager`.

### How the binary locates the repo

After a successful install, `install.py` writes the repo path to `~/.config/agent-manager/repo`. The binary reads this file at runtime so it always knows where `skills/` and `commands/` live, regardless of your working directory.

Resolution order:

1. `AGENT_MANAGER_REPO` environment variable — useful in CI or when managing multiple repos
2. `~/.config/agent-manager/repo` — written automatically by `install.py`
3. Walk up from the current directory looking for `Package.swift` — fallback for `swift run` / development

If you ever move the repo, re-run `install.py` to update the config file, or set `AGENT_MANAGER_REPO` to the new path:

```sh
export AGENT_MANAGER_REPO=~/new-location/agent-manager
```

---

## Quick Start

```sh
# Symlink all skills into every detected agent
agent-manager skill activate

# Symlink all slash commands into every detected agent
agent-manager command activate
```

Both commands detect which agents are installed on your machine and only target those. Use flags to narrow scope:

```sh
agent-manager skill activate -a opencode        # one agent
agent-manager skill activate -s swiftui-pro     # one skill
agent-manager skill activate --dry-run          # preview without making changes
```

---

## Repository Layout

```
skills/      ← skill context files, one directory per skill
commands/    ← slash command markdown files
Sources/     ← Swift CLI source (the agent-manager binary)
```

---

## Adding Skills and Commands

Scaffold a new file, edit it, then activate:

```sh
agent-manager skill new "my-skill"     # creates skills/my-skill/SKILL.md
agent-manager command new "deploy"     # creates commands/deploy.md
```

After editing the generated file:

```sh
agent-manager skill activate -s my-skill
agent-manager command activate -c deploy
```

---

## Installing Skills from GitHub

Any public GitHub repository that follows the `skills/<name>/SKILL.md` layout works as a source:

```sh
# Interactive picker — browse the full remote catalogue
agent-manager skill install rudrankriyam/app-store-connect-cli-skills

# Install a specific skill by name
agent-manager skill install rudrankriyam/app-store-connect-cli-skills asc-build-lifecycle

# Overwrite a skill that already exists locally
agent-manager skill install rudrankriyam/app-store-connect-cli-skills asc-build-lifecycle --force

# Activate after installing
agent-manager skill activate
```

> **Rate limits** — unauthenticated GitHub API requests are limited to 60/hour. Set `GITHUB_TOKEN` in your environment to raise this limit:
>
> ```sh
> export GITHUB_TOKEN=ghp_…
> agent-manager skill install rudrankriyam/app-store-connect-cli-skills
> ```

---

## Importing Commands from Agents

Copy `.md` command files from agent directories on your machine into the repo's `commands/` folder, so they can be versioned and activated across all agents:

```sh
agent-manager command import              # interactive picker
agent-manager command import -a opencode  # specific agent only
agent-manager command import --force      # overwrite existing files
```

Only markdown-format agents are supported (OpenCode, Claude Code, Windsurf). TOML-based agents such as Gemini CLI are skipped.

---

## Public, Private, or Mixed

### Fully public repo

Commit everything. Your skills and commands are openly shareable. Others can install them with `skill install`.

### Fully private repo

Keep the repository private on GitHub. Nothing is shared. All tooling works identically.

### Mixed — public repo with private files

The most common setup. The repo is public, but individual skills or commands that are personal or work-specific are marked private. They are git-ignored and never leave your machine; everything else is shared.

Use the `.private` naming convention:

| Item | On disk | Symlinked as |
|---|---|---|
| Private skill | `skills/my-skill.private/` | `<agent>/skills/my-skill` |
| Private command | `commands/my-cmd.private.md` | `<agent>/commands/my-cmd.md` |

The `skill private` and `command private` subcommands toggle a file between private and public — renaming it and repairing any active symlinks automatically:

```sh
# Make a skill private (git-ignored)
agent-manager skill private swiftui-pro
# skills/swiftui-pro/ → skills/swiftui-pro.private/

# Make a command private (git-ignored)
agent-manager command private commit
# commands/commit.md → commands/commit.private.md

# Toggle back to public
agent-manager skill private swiftui-pro
```

You can also create private files directly using the `.private` naming convention — no toggle step required.

---

## Syncing Across Machines

```sh
agent-manager push -m "add deploy command"   # stage all changes, commit, and push
agent-manager pull                           # pull latest on another machine
agent-manager clean                          # remove dead symlinks
```

`clean` is useful after deleting, renaming, or moving skills and commands. It scans every known agent directory and removes any symlink whose target no longer exists:

```sh
agent-manager clean           # remove dead symlinks
agent-manager clean --dry-run # preview without removing
```

---

## Command Reference

### `skill` — Manage agent skills

| Subcommand | Description |
|---|---|
| `skill install <owner/repo> [name…]` | Install skills from any GitHub repository into this repo |
| `skill activate` | Symlink skills into agent directories |
| `skill deactivate` | Remove skill symlinks from agent directories |
| `skill private <name>` | Toggle a skill between private (git-ignored) and public |
| `skill new <name>` | Scaffold a new skill |
| `skill list` | List all skills in this repo |
| `skill status` | Show activation status per agent |

**Options for `activate`, `deactivate`, `sync`:**

| Flag | Description |
|---|---|
| `-s, --skill <name>` | Target a specific skill (repeatable) |
| `-a, --agent <id>` | Target a specific agent (repeatable) |
| `--dry-run` | Preview changes without applying them |

**Options for `install`:**

| Flag | Description |
|---|---|
| `--force` | Overwrite an existing local skill |

---

### `command` — Manage slash commands

| Subcommand | Description |
|---|---|
| `command import` | Copy commands from agent directories into this repo |
| `command activate` | Install slash commands into agent directories |
| `command deactivate` | Remove command symlinks from agent directories |
| `command private <name>` | Toggle a command between private (git-ignored) and public |
| `command new <name>` | Scaffold a new slash command |
| `command list` | List all commands in this repo |
| `command status` | Show activation status per agent |

**Options for `import`:**

| Flag | Description |
|---|---|
| `-a, --agent <id>` | Target a specific agent (repeatable) |
| `--force` | Overwrite an existing local command |

**Options for `activate`, `deactivate`:**

| Flag | Description |
|---|---|
| `-c, --command <name>` | Target a specific command (repeatable) |
| `-a, --agent <id>` | Target a specific agent (repeatable) |
| `--dry-run` | Preview changes without applying them |

---

### Global commands

| Command | Description |
|---|---|
| `clean` | Remove dead symlinks from all agent directories |
| `sync` | Convert plain-copy skills into symlinks |
| `repo` | Show git status, or initialise a repository |
| `push [-m <message>]` | Stage all changes, commit, and push |
| `pull` | Pull latest changes from remote |

---

## Supported Agents

| Agent | Skills | Commands |
|---|---|---|
| OpenCode | `~/.config/opencode/skills` | `~/.config/opencode/commands` |
| Claude Code | `~/.claude/skills` | `~/.claude/commands` |
| GitHub Copilot | `~/.copilot/skills` | — |
| Cursor | `~/.cursor/skills` | — |
| Windsurf | `~/.codeium/windsurf/skills` | `~/.codeium/windsurf/global_workflows` |
| Gemini CLI | `~/.gemini/skills` | `~/.gemini/commands` (TOML) |
| Codex | `~/.codex/skills` | — |

Only agents whose directory already exists on disk are offered in the interactive picker.

---

## Skill Format

`SKILL.md` requires YAML frontmatter with `name` and `description`:

```markdown
---
name: my-skill
description: What this skill does and when the agent should use it.
---

# My Skill

Instructions for the agent…
```

---

## Command Format

`commands/name.md` uses a `description` frontmatter field and `$ARGUMENTS` as a placeholder for whatever the user types after the slash command:

```markdown
---
description: Review the given file or diff for issues.
---

Review the following for correctness, style, and potential bugs:

$ARGUMENTS
```

---

## Contributing

Contributions are welcome. Please open an issue first to discuss any significant change before submitting a pull request.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes — a clean build (`swift build`) and zero SwiftLint violations (`swiftlint lint --quiet Sources/`) are required
4. Open a pull request against `main`

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
