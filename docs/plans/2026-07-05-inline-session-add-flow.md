# Inline Session for `skl add`

> **For agentic workers:** Use executing-plans to implement this plan
> task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the whole interactive `skl add` flow (multi-select → target
prompt → overwrite confirms → summary) in a single tiny-tui **inline session**
instead of the full-screen alternate screen, adopting `tui/with-inline-session`
from tiny-tui v0.1.3. Result: no inter-widget flicker, terminal scrollback
preserved, and the install summary printed in place where the widgets were.

**Tech Stack:** let-go, lgx, tiny-cli, tiny-tui v0.1.3 (already pinned in
`lgx.edn`), shelling out to `git`/`cp`/`rm` via `os/sh`.

---

## Design

### Background — what changed upstream

tiny-tui **v0.1.3** (commit `3d2aeaa`, already pinned in `lgx.edn`) shipped:

1. **Word navigation/editing** in the input widget and list filter
   (Option/Alt+←/→, Ctrl-W, Alt-b/f/d). This is **automatic** via the key
   parser — skl's target-dir prompt and skill filter already get it for free.
   **No code change needed or wanted.**
2. **`tui/with-inline-session`** — a macro that runs a whole flow of widgets in
   **one raw-mode span**. Widgets render in place and erase themselves as the
   next appears, instead of each entering/leaving raw mode on its own (which
   flickered when chained). This is the improvement this plan adopts.

### Why this change

`skl add` chains **multi-select → input → confirm(s)**. Commit `9437c62`
("Start fullscreen TUI on add command") dropped `:inline? true` and switched to
the alternate screen specifically to dodge the per-widget inline flicker.
`with-inline-session` removes that reason: the whole chain shares one span, so
inline works flicker-free. Inline is a better fit for an installer — it keeps
terminal scrollback and prints the summary in place rather than taking over the
screen and vanishing.

### Approach

Wrap the interactive portion of `add` in `tui/with-inline-session`, and move
**all `println` output to after the session closes**. Inside a session the
terminal is in raw mode, so a bare `\n` won't return the carriage — results
must print once the session has restored cooked mode (documented tiny-tui
gotcha; the widgets erase themselves, so the cursor rests where they were).

### Key decisions

- **Inline session, not fullscreen.** Revert the fullscreen decision. The
  multi-select does **not** get `:inline? true` back — inside a session,
  per-widget `:inline?` is neither needed nor wanted; tiny-tui's `run` detects
  the active session itself and renders inline.
- **Gate the session on `interactive? AND (not (false? (:screen tui-opts)))`.**
  Open the span only when a picker or prompt will actually render — i.e.
  `--skill` and `--dir` are **not both** supplied — and we are not in a headless
  test. This preserves current no-TTY behavior: a fully-specified
  `skl add --skill X --dir Y <url>` with no conflict touches zero widgets and
  must not demand a terminal, but `screen/init-inline!` throws without a TTY, so
  blindly opening a session there would be a regression. In the both-flags path,
  at most a single overwrite confirm renders standalone (as today).
- **`run-flow!` becomes non-printing; a new `report!` prints after the
  session** and returns the outcomes vector — preserving `add*`'s existing
  return contract (tests assert on the returned vector, not stdout).

### Behavior preserved

- `add*` still returns the vector of `{:skill … :status …}` outcome maps
  (`[]` on cancel / nothing-selected). All existing tests assert on this and
  must stay green unchanged.
- Cancellation messages ("Nothing selected." / "Cancelled.") and the summary
  ("Target: …" + per-skill lines) are unchanged in content — only *where* they
  are emitted moves (after the session).
- The clone (`git/clone-shallow!`, via `os/sh`, output captured) and cleanup run
  outside the session, unchanged. The try/catch cleanup-and-rethrow on error is
  unchanged.

---

## File Structure

Single file touched:

- `src/skl/commands.lg` — restructure `run-flow!`, add `report!` and
  `with-inline-flow` helpers, rewire `add*`.

No changes to `main.lg`, `skl/git.lg`, `skl/skills.lg`, `lgx.edn`, or tests.

---

## Task 1: Make `run-flow!` non-printing (return a status map)

- [ ] In `src/skl/commands.lg`, change `run-flow!` so it **returns a status
      map** instead of printing:
  - Nothing selected (`selected` empty/nil): return `{:status :empty}` (remove
    the `(println "Nothing selected.")`).
  - Target cancelled (`target` nil): return `{:status :cancelled}` (remove the
    `(println "Cancelled.")`).
  - Success: return `{:status :done :outcomes outcomes :target target}` (remove
    the `(print-summary! outcomes target)` call from here).
- [ ] Update the `run-flow!` docstring to say it returns a status map and prints
      nothing (the caller reports after the session).
- [ ] Verify compile: `lgx lint` (no undefined-var / arity errors in the file).

## Task 2: Add `report!` and `with-inline-flow` helpers

- [ ] Add `report!` above `add*`:
  - Signature `[result]` where `result` is the status map from `run-flow!`.
  - `case` on `(:status result)`:
    - `:empty` → `(println "Nothing selected.")`, return `[]`.
    - `:cancelled` → `(println "Cancelled.")`, return `[]`.
    - `:done` → `(print-summary! (:outcomes result) (:target result))`, return
      `(:outcomes result)`.
  - Docstring: prints the outcome (after the session has closed) and returns the
    outcomes vector, preserving `add*`'s return contract.
- [ ] Add `with-inline-flow` helper:
  - Signature `[interactive? tui-opts thunk]`.
  - Body: `(if (and interactive? (not (false? (:screen tui-opts)))) (tui/with-inline-session (thunk)) (thunk))`.
  - Docstring: run the interactive flow in one inline raw-mode span in
    production; skip the span when headless (`:screen false`) or fully
    non-interactive (both `--skill` and `--dir` given), so no TTY is demanded up
    front and headless tests keep working.
  - Note: `tui/with-inline-session` is a macro taking a body; `(tui/with-inline-session (thunk))` is correct (it wraps the `(thunk)` call in the session).
- [ ] `lgx lint`.

## Task 3: Rewire `add*` to open the session and report after it

- [ ] In `add*`, compute interactivity from opts up front, e.g.
      `interactive? (or (not (seq (:skill opts))) (not (seq (:dir opts))))`.
- [ ] Replace the direct `run-flow!` call inside the `try` with:
  - `(let [result (with-inline-flow interactive? tui-opts (fn [] (run-flow! clone opts tui-opts)))] (git/cleanup! clone) (report! result))`
  - i.e. run the (possibly session-wrapped) flow, clean up the clone, then
    `report!` — whose return value becomes `add*`'s return value.
- [ ] Keep the `catch` branch unchanged: `(git/cleanup! clone)` then
      `(throw e)`.
- [ ] Update `add*`'s docstring only if wording about printing needs a tweak;
      the return contract (outcomes vector, `[]` on cancel) is unchanged.
- [ ] `lgx lint`.

## Task 4: Verify — automated

- [ ] `lgx fmt fix`
- [ ] `lgx lint`
- [ ] `lgx test` — expect the existing **18 tests, 37 assertions, 0 failures**
      still green (all drive `:screen false`, so they exercise the no-session
      path and assert on returned vectors + filesystem).

## Task 5: Verify — real terminal (inline session path)

The session path can't be unit-tested headlessly (same reason tiny-tui uses PTY
verification). Confirm it by hand in a real terminal:

- [ ] `lgx build` (or `lgx run --`) and run the fully interactive flow against a
      real skills repo, e.g.
      `bin/skl add https://github.com/anthropics/skills`.
- [ ] Confirm, in one terminal session:
  - The skill picker, target prompt, and any overwrite confirm render **in
    place** (inline), each replacing the previous — **no full-screen takeover**
    and **no flicker** between steps.
  - After the flow, the "Target: …" summary prints **where the widgets were**,
    and prior terminal scrollback is intact.
  - In the target prompt, Option/Alt+←/→ jump by path segment and Ctrl-W deletes
    the trailing word (word-nav sanity check — should already work via v0.1.3).
- [ ] Spot-check the non-interactive no-TTY path is not regressed: piping with
      both flags and no conflict still works without a terminal, e.g.
      `bin/skl add --skill <name> --dir /tmp/skl-check <url> </dev/null` (should
      install without demanding a TTY).

## Task 6: Commit

- [ ] `git add -A && git commit` with a concise message, e.g.
      `Run add flow in one inline tiny-tui session`. No attribution footer.
- [ ] Mark this plan complete (add a short ✅ completion note at the top).
