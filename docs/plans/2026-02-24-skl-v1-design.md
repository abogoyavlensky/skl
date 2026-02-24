# `skl` — AI Agent Skills Installer CLI (V1 Design)

## Overview

`skl` is a single-binary CLI tool that installs, manages, and updates AI coding agent skill directories from GitHub repositories into local agent configurations. It supports multiple agents (Claude Code, Codex, GitHub Copilot) and custom paths.

**Tech stack:** Go, Cobra, Charm stack (lipgloss, huh, log)

## Commands

### `skl install <skill-name>` (alias: `i`)

Install a skill from a GitHub repository.

**Flags:**
- `--source`, `-s` — Source path: `user/repo[/skills-dir]`. Skills dir defaults to `skills` if omitted
- `--agent`, `-a` — Target agent: `agents` (default), `claude-code`, `codex`, `copilot`
- `--level`, `-l` — Install level: `local` (default), `global`
- `--path`, `-p` — Custom target path (mutually exclusive with `--agent`)

**Flow:**
1. Resolve target path. Print "Installing `<skill-name>` → `<path>/<skill-name>/`"
2. If skill already installed and not modified: silently update to latest
3. If skill already installed and modified: interactive dialog ("Local modifications detected. Overwrite?")
4. Fetch all files into memory from GitHub (API first, git sparse checkout fallback for private repos)
5. Write files to disk
6. Compute SHA256 hash, update `skills.json`
7. Display styled success output

### `skl list`

List all installed skills with status.

**Flags:** `--agent`, `-a` / `--path`, `-p` / `--level`, `-l` / `--all`

**Flow:**
1. Resolve target path (or scan all known agent paths if `--all`)
2. Read `skills.json`, recompute hashes
3. Display styled table: name, source, status (✓ clean / ⚠ modified)

### `skl show <skill-name>`

Show detailed info for an installed skill.

**Flags:** `--agent`, `-a` / `--path`, `-p` / `--level`, `-l`

**Output:** Name, source, installed date, last updated, modification status, file listing.

### `skl remove <skill-name>`

Remove an installed skill with confirmation.

**Flags:** `--agent`, `-a` / `--path`, `-p` / `--level`, `-l`

**Flow:**
1. Print "Removing `<skill-name>` from `<path>/<skill-name>/`"
2. Show full skill info including modification status
3. Interactive confirmation dialog (extra warning if modified)
4. Delete skill directory, remove from `skills.json`

### `skl update <skill-name>`

Update an installed skill to latest version from source.

**Flags:** `--agent`, `-a` / `--path`, `-p` / `--level`, `-l`

**Flow:**
1. Print "Updating `<skill-name>` at `<path>/<skill-name>/`"
2. If locally modified: interactive dialog warning, ask to proceed
3. If clean: proceed silently
4. Fetch latest from GitHub into memory, write to disk
5. Recompute hash, update `skills.json`

## Agent Path Resolution

| Agent | Local Path | Global Path |
|---|---|---|
| `agents` (default) | `./.agents/skills/` | `~/.agents/skills/` |
| `claude-code` | `./.claude/skills/` | `~/.claude/skills/` |
| `codex` | `./.agents/skills/` | `~/.agents/skills/` |
| `copilot` | `./.github/skills/` | `~/.copilot/skills/` |

`--agent` and `--path` are mutually exclusive. If `--path` is provided, `--agent` is ignored.

## Data Models

### Global Config: `~/.config/skl/config.json`

```json
{
  "agent": "claude-code",
  "level": "local"
}
```

Both fields optional. Defaults without config: `agent = "agents"`, `level = "local"`.

### Skills Registry: `skills.json`

Lives at the root of the resolved skills directory (e.g. `.claude/skills/skills.json`).

```json
{
  "skills": [
    {
      "name": "my-skill",
      "source": "username/repo/skills",
      "installed_at": "2026-02-24T01:00:00Z",
      "updated_at": "2026-02-24T01:00:00Z",
      "hash": "sha256:a1b2c3d4..."
    }
  ]
}
```

- **`name`** — Directory name of the skill
- **`source`** — Container path on GitHub (without skill name). Always fully expanded even if user omitted the default `skills` dir
- **`installed_at`** / **`updated_at`** — ISO 8601 timestamps
- **`hash`** — SHA256 of skill directory contents at install/update time

### Hash Computation

Deterministic: sort all files alphabetically by relative path, concatenate `path + content` for each, SHA256 the result. Detects any file addition, deletion, or content change.

## Fetching Strategy

1. **GitHub REST API** (default) — Use Contents/Trees API to download skill subdirectory. Works with public repos (or with a configured token).
2. **Git sparse checkout** (fallback) — For private repos or when API fails. Requires git on the system.

All fetched files are held **in memory** until the network call completes successfully. Nothing touches disk until all files are ready. This provides atomicity without temp directories.

## Error Handling

| Scenario | Behavior |
|---|---|
| `--source` not provided and skill not in registry | Error: "Source required. Use `--source user/repo`" |
| Skill not found on GitHub | Error: "Skill `<name>` not found at `<source>/<name>`" |
| GitHub API rate limited | Fall back to git sparse checkout |
| Private repo, no git available | Error: "Private repo detected. Install git for private repo support" |
| No `skills.json` at target | Auto-create on `install`; error for other commands |
| Target directory doesn't exist | Auto-create on `install` |
| `--agent` and `--path` both provided | Error: "Cannot use both --agent and --path" |
| Skill not found in registry | Error: "Skill `<name>` is not installed" |
| Network failure during fetch | Error with clear message, no disk writes |

## Project Structure

```
skl/
├── cmd/
│   ├── root.go          # Root command, global flags
│   ├── install.go       # install/i command
│   ├── list.go          # list command
│   ├── show.go          # show command
│   ├── remove.go        # remove command
│   └── update.go        # update command
├── internal/
│   ├── config/
│   │   └── config.go    # Global config load/save
│   ├── registry/
│   │   └── registry.go  # skills.json CRUD, hash computation
│   ├── resolver/
│   │   └── resolver.go  # Agent + level → path resolution
│   ├── fetcher/
│   │   ├── github.go    # GitHub API fetcher
│   │   └── git.go       # Git sparse checkout fallback
│   └── ui/
│       └── ui.go        # Styled output, confirmation dialogs
├── main.go
├── go.mod
├── go.sum
├── Makefile
├── .goreleaser.yml
└── README.md
```

## Build & Release

- **GoReleaser** for multi-platform builds: linux/{amd64,arm64}, darwin/{amd64,arm64}, windows/amd64
- **GitHub Releases** via git tags (`v0.1.0`)
- **Homebrew tap** auto-generated by GoReleaser
- Future: `go install github.com/user/skl@latest`

## Out of Scope (V1)

- `--ref` / `--branch` flag for specific git refs
- Authentication / GitHub token configuration
- Skill versioning (semver)
- Skill dependencies
- Skill templates / scaffolding
