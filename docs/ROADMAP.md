# skl Roadmap

skl is a minimal single-binary CLI to fetch and install agent skills from git
repositories. The long-term shape: a package-manager-like experience for
skills — add, list, update, remove — while staying a small tool where the
filesystem stays the source of truth and any repo with a skills directory is
a valid source. No central registry required.

This roadmap is directional, not a promise; versions group work by theme and
may shift.

## v0.1.0 — `skl add` (planned: docs/plans/2026-07-02-skl-add-command.md)

The core install flow.

- `skl add <repo-url>` — shallow clone, pick skills interactively
  (filterable multi-select, inline), copy into a target dir.
- `--skill NAME` to skip the picker, `--dir DIR` to skip the target prompt,
  `--path DIR` for non-standard skills dirs inside the source repo.
- Per-skill conflict handling: confirm overwrite or skip.
- Default target: local `.agents/skills`.

## v0.2.0 — Non-interactive and source ergonomics

Make `add` comfortable in scripts and across real-world repos.

- `--force` / `--skip-existing` flags to resolve conflicts without prompts
  (unattended installs, CI).
- Git ref selection: `--branch` / `--tag` / `--sha`.
- URL shorthands: `user/repo` (GitHub), maybe `gh:` / `gl:` prefixes.
- Multiple skills per run non-interactively (repeatable `--skill` or
  comma-separated), pending tiny-cli support for repeatable options.
- Skill sanity check on install: warn when a skill dir has no `SKILL.md`.

## v0.3.0 — Managing installed skills

Everything after "installed" needs to know where skills came from — this
milestone introduces a manifest (likely `.agents/skills.edn` next to the
skills, or per-skill metadata) recording source url, ref, resolved sha, and
source path.

- `skl list` — installed skills with their source and version.
- `skl remove` — interactive multi-select removal (or `--skill` for one).
- `skl update` — re-fetch recorded sources, show which skills changed,
  update selectively. Skills without a manifest entry (installed by hand or
  by v0.1) are listed as "unmanaged" and left alone.

## v0.4.0 — Distribution and polish

- Prebuilt binaries for macOS/Linux via CI releases; install script;
  possibly a Homebrew formula.
- Document shell completions (tiny-cli provides bash/zsh/fish for free).
- Path autocomplete in the target-dir prompt — this is a tiny-tui widget
  (tab-completion against the filesystem in `input`), built there and
  adopted here.

## Ideas / undecided

Worth exploring, not committed to:

- `skl search` across a configurable set of known skill repos, or a curated
  index repo the community can PR into.
- Config file (`~/.config/skl/config.toml`) for defaults: target dir,
  favorite sources.
- Installing a single skill by direct path/url without the skills-dir
  convention.
- Skill "collections": install a named group of skills in one command.

## Non-goals

- A central registry service or accounts — git repos are the distribution
  mechanism.
- Skill authoring/scaffolding tooling — other tools do this; skl fetches and
  manages.
- Dependency resolution between skills — skills are flat, independent dirs.
