# `skl add` Command Implementation Plan

> **For agentic workers:** Use executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `skl add <repo-url>` — clone a git repo, let the user pick skills from its skills directory interactively (or via `--skill`), and copy them into a target directory with per-skill conflict handling.

**Tech Stack:** let-go, lgx, tiny-cli (arg parsing), tiny-tui (interactive UI), shelling out to `git`, `cp`, `rm` via `os/sh`.

---

## Design

### Command

```
skl add <URL> [options]
```

- `URL` — required positional, git repo url. Validated non-blank.
- `-s, --skill NAME` — install exactly this one skill; skips the multi-select.
  tiny-cli options are single-value, so this takes one name; for several
  skills use the interactive picker.
- `-d, --dir DIR` — target install dir; skips the target-dir prompt.
- `-p, --path DIR` — skills dir inside the source repo. Default: `skills`.
  `--path .` means the repo root itself contains the skill dirs.

Fully non-interactive form: `skl add <url> --skill foo --dir .agents/skills`
(a conflict still asks its confirm question interactively; `--force` is a
deliberate non-goal for V1).

### Flow

1. Shallow-clone the repo (`git clone --depth 1 <url> <tmp>`) into a unique
   temp dir under `os/temp-dir`. On non-zero exit, print git's stderr and exit 1.
2. Resolve the skills dir inside the clone from `--path` (default `skills`).
   If it doesn't exist or isn't a directory, error out. List its
   subdirectories (via `os/ls` + `os/stat`, dirs only, sorted) — these are the
   available skills. Empty list is an error ("no skills found").
3. Determine which skills to install:
   - `--skill NAME` given: if NAME is in the list, install just it; otherwise
     print an error plus the available skill names, exit 1.
   - Otherwise: `tui/multi-select` with `:filterable? true :inline? true`
     over the skill names. Cancel (`nil`) or empty submit (`[]`) aborts with
     "Nothing selected." and exit 0.
4. Determine target dir:
   - `--dir` given: use it.
   - Otherwise: `tui/input`, title "Install skills to", `:value ".agents/skills"`
     (editable), `:validate` non-blank. Cancel aborts, exit 0.
   - Expand a leading `~/` to `$HOME` (error if `$HOME` unset, as in wtr).
     Create the dir with `mkdir` (recursive) if missing.
5. For each selected skill, in order:
   - If `<target>/<skill>` exists: `tui/confirm` — title
     "Skill '<name>' already exists", message "Overwrite <target>/<name>?".
     Decline → skip. Accept → `rm -rf` the existing dir, then copy.
   - Copy with `cp -R <clone>/<skills-path>/<skill> <target>/<skill>`.
6. Print a summary: one line per skill — installed / overwritten / skipped.
7. Always remove the temp clone (`rm -rf`), including on error paths
   (wrap the work after a successful clone in `try`/`finally`).

### Key decisions (approved)

- **No install manifest in V1.** `add` just copies dirs. The filesystem is the
  source of truth for the exists-check. A lockfile can come with future
  `list`/`update`/`remove` commands.
- **No path autocomplete in the target-dir input.** tiny-tui's `input` has no
  tab completion; a prefilled editable value covers V1. Path completion is a
  candidate future tiny-tui widget, not skl code.
- **Conflict prompt is `tui/confirm`** (y = overwrite, n = skip).
- **Overwrite = replace, not merge:** `rm -rf` the old skill dir first so
  stale files don't survive.
- **Shell out** for clone/copy/remove (`os/sh` with git/cp/rm) — the wtr
  precedent; no pure-let-go recursive copy.
- `greet` command, `skl.core`, and its test are deleted — they were scaffold.

### Error handling

Follow the wtr pattern: helpers that shell out throw `ex-info` with git/cp
stderr in the data; the command handler catches at the edge, prints the
message (and stderr when present) to stderr, and exits 1. User cancellation
of any widget is not an error — print a short notice and exit 0.

### Testing strategy

- Pure/fs helpers (`expand-home`, `list-skills`, `skill-exists?`,
  `copy-skill!`) are tested against real temp dirs built with `mkdir`/`spit`
  under `os/temp-dir`.
- The interactive flow is tested with tiny-tui's testing hooks
  (`:screen false :read-key-fn (scripted keys) :render-fn (fn [_] nil)`).
  The `add!` orchestration accepts an options map of tui hooks so tests can
  drive it without a terminal; production passes `{}`.
- Clone is not tested against the network. `clone-shallow!` is tested by
  cloning a local file-path repo created in the test (git accepts a local dir
  as a url).

## File Structure

- `src/skl/git.lg` — `clone-shallow!` (url → temp clone path, throws on
  failure), `temp-clone-dir` (unique path under `os/temp-dir`), `cleanup!`
  (rm -rf a dir).
- `src/skl/skills.lg` — filesystem/path helpers: `expand-home`,
  `skills-dir` (join clone path + `--path` value), `list-skills`,
  `skill-exists?`, `copy-skill!`, `remove-skill!`, `ensure-dir!`.
- `src/skl/commands.lg` — `add!` handler: orchestrates flow, owns all tui
  calls and the summary printing; takes the tiny-cli ctx map, reads tui hook
  overrides from a dynamic/extra arg for tests.
- `main.lg` — app spec: `add` command with args/opts; `greet` removed.
- `test/skl/skills_test.lg` — helper tests against temp dirs.
- `test/skl/git_test.lg` — local-repo clone test.
- `test/skl/commands_test.lg` — scripted-key flow tests.
- Delete: `src/skl/core.lg`, `test/skl/core_test.lg`.

## Tasks

### Task 1: Filesystem helpers (`skl.skills`)

**Files:**
- Create: `src/skl/skills.lg`
- Test: `test/skl/skills_test.lg`

- [ ] **Step 1: Write failing tests**
  In `test/skl/skills_test.lg`, using a fresh dir under `os/temp-dir` per test:
  - `expand-home`: `"~/x"` → `<$HOME>/x`; `".agents/skills"` unchanged;
    absolute path unchanged. Unset-HOME case: skip if impractical to unset,
    otherwise assert throw.
  - `list-skills`: build `<tmp>/skills/{a,b}/SKILL.md` plus a stray file
    `<tmp>/skills/readme.txt`; expect `["a" "b"]` (dirs only, sorted).
    Missing dir → throws `ex-info`. Empty dir → `[]`.
  - `skill-exists?`: true only when `<target>/<name>` exists as a dir.
  - `copy-skill!`: copies a skill dir with a nested file into target;
    file content survives.
  - `remove-skill!`: removes an existing skill dir.
  - `ensure-dir!`: creates nested dirs; idempotent when dir exists.

- [ ] **Step 2: Run tests to verify they fail**
  Run: `lgx test`
  Expected: FAIL (namespace `skl.skills` not found).

- [ ] **Step 3: Implement `src/skl/skills.lg`**
  Follow wtr idioms (`os/ls`, `os/stat`, `os/sh`, `file-exists?`, `mkdir`).
  `list-skills` filters `os/ls` entries by `(:is-dir (os/stat ...))` and sorts.
  `copy-skill!` shells `cp -R src dst`, throws `ex-info` with stderr on
  non-zero exit. `remove-skill!` shells `rm -rf`. `ensure-dir!` wraps `mkdir`.

- [ ] **Step 4: Run tests to verify they pass**
  Run: `lgx test`
  Expected: PASS.

- [ ] **Step 5: Commit**
  `git commit -m "Add skl.skills filesystem helpers"`

### Task 2: Git clone helper (`skl.git`)

**Files:**
- Create: `src/skl/git.lg`
- Test: `test/skl/git_test.lg`

- [ ] **Step 1: Write failing tests**
  In the test, create a local source repo under `os/temp-dir`: `git init`,
  add `skills/demo/SKILL.md`, commit (set `user.email`/`user.name` via
  `git -c` or local config so commit works in CI). Then:
  - `clone-shallow!` on the local path returns a path where
    `skills/demo/SKILL.md` exists.
  - `clone-shallow!` on a bogus url (e.g. a nonexistent local path) throws
    `ex-info` whose data carries git's stderr.
  - `cleanup!` removes the clone dir.

- [ ] **Step 2: Run tests to verify they fail**
  Run: `lgx test`
  Expected: FAIL (namespace `skl.git` not found).

- [ ] **Step 3: Implement `src/skl/git.lg`**
  `temp-clone-dir` builds a unique path under `(os/temp-dir)` (suffix from
  a counter/random-ish source available in let-go — e.g. current pid or a
  timestamp via `os/sh date +%s%N` if nothing simpler exists; keep it one
  line). `clone-shallow!` runs
  `git clone --depth 1 <url> <dir>` via `os/sh`, throws `ex-info` with
  stderr on non-zero exit, returns the dir. `cleanup!` = `rm -rf`.

- [ ] **Step 4: Run tests to verify they pass**
  Run: `lgx test`
  Expected: PASS.

- [ ] **Step 5: Commit**
  `git commit -m "Add skl.git shallow clone helper"`

### Task 3: `add!` command flow (`skl.commands`)

**Files:**
- Create: `src/skl/commands.lg`
- Test: `test/skl/commands_test.lg`

- [ ] **Step 1: Write failing tests**
  Structure `add!` as `(add! ctx)` calling `(add* ctx tui-opts)`, where
  `tui-opts` is merged into every tiny-tui call — tests pass
  `{:screen false :read-key-fn <scripted> :render-fn (fn [_] nil)}`.
  Use a local git repo fixture (as in Task 2) with skills `alpha`, `beta`.
  Test cases:
  - `--skill alpha --dir <tmp-target>`: installs `alpha` without any tui
    interaction; target contains `alpha/SKILL.md`; returns/prints
    "installed" summary.
  - `--skill missing`: throws or exits with error listing `alpha`, `beta`
    (assert on the error message; use the non-exiting internal fn).
  - Interactive path: scripted keys select `beta` in multi-select
    (`:down`, space, enter), then target input accepts prefilled default —
    but override the default by scripting text input is brittle, so pass
    `--dir` and script only the multi-select.
  - Conflict: pre-create `<target>/alpha`; scripted `y` on confirm →
    overwritten (old marker file gone); scripted `n`/esc → skipped
    (marker file survives).
  Scripted `read-key-fn` pattern: an atom holding a queue of keys, fn pops
  one per call (see tiny-tui `test/tiny_tui/core_test.lg`).

- [ ] **Step 2: Run tests to verify they fail**
  Run: `lgx test`
  Expected: FAIL (namespace `skl.commands` not found).

- [ ] **Step 3: Implement `src/skl/commands.lg`**
  `add*` implements the Design flow §Flow steps 1–7: clone → list →
  select (or `--skill`) → target dir (or `--dir`) → per-skill
  conflict/copy loop → summary → cleanup in `finally`. Collect per-skill
  outcomes as data (`[{:skill "a" :status :installed} ...]`), print the
  summary from it, and return it (test-friendly). `add!` is the thin
  tiny-cli handler: calls `add*` with `{}`, catches `ex-info`, prints
  message + stderr from ex-data to `*err*`, exits 1.

- [ ] **Step 4: Run tests to verify they pass**
  Run: `lgx test`
  Expected: PASS.

- [ ] **Step 5: Commit**
  `git commit -m "Add skl add command flow"`

### Task 4: Wire the CLI, drop scaffold

**Files:**
- Modify: `main.lg`, `README.md`
- Delete: `src/skl/core.lg`, `test/skl/core_test.lg`

- [ ] **Step 1: Update `main.lg`**
  Replace the `greet` command with `add`:
  - `:args` — `{:key :url :doc "Git repository url." :validate non-blank}`.
  - `:opts` — `skill` (`-s/--skill`, `:value? true`), `dir`
    (`-d/--dir`, `:value? true`), `path` (`-p/--path`, `:value? true`,
    `:default "skills"`), each with `:doc`.
  - `:run c/add!`, require `skl.commands`.
  Delete `src/skl/core.lg` and `test/skl/core_test.lg`.

- [ ] **Step 2: Update README usage section**
  Replace `greet` examples with `skl add` usage: interactive form,
  `--skill`/`--dir`/`--path` form.

- [ ] **Step 3: Verify checks pass**
  Run: `lgx check`
  Expected: fmt, lint, and tests all pass.

- [ ] **Step 4: Smoke-test manually**
  Run: `lgx run -- add --help` (shows command help) and
  `lgx run -- add <local-fixture-repo> --skill alpha --dir /tmp/skl-smoke`
  Expected: installs the skill, prints summary.

- [ ] **Step 5: Commit**
  `git commit -m "Wire skl add command, drop greet scaffold"`

### Task 5: Build and end-to-end check

- [ ] **Step 1: Build the binary**
  Run: `lgx build`
  Expected: `bin/skl` produced.

- [ ] **Step 2: End-to-end against a real repo**
  Run `bin/skl add <any small public skills repo or local fixture>`
  interactively once: filter, multi-select two skills, accept default
  `.agents/skills`, re-run to hit the overwrite/skip confirm.
  Expected: skills land in `.agents/skills/`, summary correct, temp clone
  removed.

- [ ] **Step 3: Commit any fixes**
  `git commit -m "Fix issues found in end-to-end check"` (only if needed).
