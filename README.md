# skl

A minimal single binary CLI app to fetch and install agent skills.

## Usage

Install skills from any git repository that has a `skills/` directory — no
central registry, any repo is a valid source.

Interactive — clone the repo, filter and multi-select skills, then choose a
target directory:

```bash
skl add https://github.com/owner/skills-repo
```

Non-interactive — name the skill and target with flags. Options come **before**
the url (tiny-cli parses options ahead of positional arguments):

```bash
# install one skill into a specific directory
skl add --skill code-review --dir .agents/skills https://github.com/owner/skills-repo

# a repo whose skills live somewhere other than skills/
skl add --path packages https://github.com/owner/skills-repo
```

Options:

- `-s, --skill NAME` — install exactly this skill; skips the interactive picker.
- `-d, --dir DIR` — target install directory; skips the prompt (the prompt
  otherwise defaults to `.agents/skills`).
- `-p, --path DIR` — skills directory inside the source repo (default `skills`;
  use `.` when the repo root itself holds the skill directories).

When a skill already exists in the target, `skl` asks before overwriting it;
an overwrite replaces the whole skill directory.

## Development

Install dependencies with [mise](https://mise.jdx.dev/getting-started.html) (or manaully consulting the `.mise.toml` file):

```bash
mise trust && mise install
```

Run main application commands during development:
```bash
lgx --help
lgx run -- add --help
lgx run -- add --skill demo --dir .agents/skills <repo-url>
lgx test
lgx fmt
lgx lint
lgx nrepl
```

Build a binary and use it:

```bash
lgx build
bin/skl --help
bin/skl --version
bin/skl help add
bin/skl add <repo-url>
```
