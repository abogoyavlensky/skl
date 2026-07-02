# skl

A minimal single binary CLI app to fetch and install agent skills.

## Development

Install dependencies with [mise](https://mise.jdx.dev/getting-started.html) (or manaully consulting the `.mise.toml` file):

```bash
mise trust && mise install
```

Run main application commands during development:
```bash
lgx --help
lgx run
lgx run -- help
lgx run -- greet
lgx test
lgx fmt
lgx lint
lgx nrepl
```

Buld a binary and use it:

```bash
lgx build
bin/skl --help
bin/skl --version
bin/skl help greet
bin/skl greet
```
