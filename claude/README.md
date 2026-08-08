# claude/

Tracked subset of `~/.claude/`. `INSTALL.sh` copies each file under `claude/`
to the matching path under `~/.claude/` — real copies, not symlinks. This runs
on **every** `./INSTALL.sh`, not behind a flag; `--no-claude` opts out.

## What to track here

| Path                       | What                                                     | Why                            |
| -------------------------- | -------------------------------------------------------- | ------------------------------ |
| `claude/CLAUDE.md`         | Global instructions Claude reads on every session        | Stable, useful across machines |
| `claude/investigations.md` | Investigations rule (referenced by `@investigations.md`) | Same                           |
| `claude/settings.json`     | Permissions, hooks, statusline, plugin toggles           | Audited — no secrets           |
| `claude/statusline.sh`     | Status line renderer                                     | Stable script                  |
| `claude/rules/`            | Rules included via `@rules/*`                            | Persistent prefs               |
| `claude/agents/`           | Custom subagent definitions                              | Hand-curated                   |
| `claude/commands/`         | Custom slash commands                                    | Hand-curated                   |
| `claude/skills/`           | Custom skills                                            | Hand-curated                   |

## What NOT to track (already in `.gitignore`)

Runtime / per-machine state: `sessions/`, `projects/`, `history.jsonl`,
`cache/`, `telemetry/`, `backups/`, `file-history/`, `shell-snapshots/`,
`paste-cache/`, `debug/`, `plans/`, `*-cache.json`, `mcp-needs-auth-cache.json`,
`.last-*`.

> **Heads-up on `settings.json`** — Claude Code may rewrite this file when you
> toggle plugins or change permissions via `/config`. The next `../sync.sh`
> surfaces those writes as a diff toward the repo. Review before committing; if
> anything sensitive ever appears, move secrets into a separate file and use
> the `*-local` pattern.

## Adding more files later

1. Drop the file into `claude/<path>` in this repo.
2. Re-run `../INSTALL.sh` from the repo root (no flag needed; `claude/` is part
   of the default run).
3. If `~/.claude/<path>` already exists and differs, you're shown the diff and
   prompted per file. Non-interactive runs back the home version up with a
   timestamp suffix and overwrite.

## MCP servers — `mcp-servers.sh`

MCP server config lives in `~/.claude.json`, not in `~/.claude/`, so it's
intentionally not synced as a file. Instead, `claude/mcp-servers.sh` re-creates
each user-scope MCP via `claude mcp add`. Run it on a fresh machine after
`INSTALL.sh`.

Drift check from the repo root: `./sync.sh --mcp`.

See the parent [README.md § MCP servers](../README.md#mcp-servers) for the
secrets pattern and a worked example.
