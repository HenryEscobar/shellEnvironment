# claude/

Tracked subset of `~/.claude/`. INSTALL.sh symlinks each file/dir under
`claude/` into the matching path under `~/.claude/`.

## What to track here

| Path | What | Why |
| --- | --- | --- |
| `claude/CLAUDE.md` | Global instructions Claude reads on every session | Stable, useful across machines |
| `claude/investigations.md` | Investigations rule (referenced by `@investigations.md`) | Same |
| `claude/settings.json` | Permissions, hooks, statusline, plugin toggles | Audited — no secrets |
| `claude/statusline.sh` | Status line renderer | Stable script |
| `claude/rules/` | Rules included via `@rules/*` | Persistent prefs |
| `claude/agents/` | Custom subagent definitions | Hand-curated |
| `claude/commands/` | Custom slash commands | Hand-curated |
| `claude/skills/` | Custom skills | Hand-curated |

## What NOT to track (already in `.gitignore`)

Runtime / per-machine state: `sessions/`, `projects/`, `history.jsonl`,
`cache/`, `telemetry/`, `backups/`, `file-history/`, `shell-snapshots/`,
`paste-cache/`, `debug/`, `plans/`, `*-cache.json`, `mcp-needs-auth-cache.json`,
`.last-*`.

> **Heads-up on `settings.json`** — Claude Code may rewrite this file when you
> toggle plugins or change permissions via `/config`. Because it's symlinked,
> those writes flow back into the repo as diffs. Review before committing; if
> anything sensitive ever appears, move secrets into a separate file and use
> the `*-local` pattern.

## Adding more files later

1. Drop the file into `claude/<path>` in this repo.
2. Re-run `../INSTALL.sh --claude` from the repo root.
3. Any existing `~/.claude/<path>` gets backed up with a timestamp suffix and
   replaced with a copy of the repo version.

## MCP servers — `mcp-servers.sh`

MCP server config lives in `~/.claude.json`, not in `~/.claude/`, so it's
intentionally not synced as a file. Instead, `claude/mcp-servers.sh` re-creates
each user-scope MCP via `claude mcp add`. Run it on a fresh machine after
`INSTALL.sh`.

Drift check from the repo root: `./sync.sh --mcp`.

See the parent [README.md § MCP servers](../README.md#mcp-servers) for the
secrets pattern and a worked example.
