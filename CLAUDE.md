# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles + macOS machine setup (Apple Silicon first; most dotfiles also work on Linux).
There is no build/test/lint toolchain — it's Bash scripts plus config files. "Running" it means
invoking the install/sync scripts.

## Core model: two-way copy between repo and `$HOME`

The repo and `$HOME` hold parallel copies of each tracked file. Two scripts move changes between
them, in opposite directions. **Files are real copies, not symlinks** (deleting the repo must not
break the live shell or `~/.claude/`). Note: README's "What changed from the Linux-era setup"
section still says "symlinks" in two places — that's stale; `copy_one()` in `INSTALL.sh` does `cp`.

| Script | Direction | Use when |
| --- | --- | --- |
| `./INSTALL.sh` | repo → `$HOME` | Fresh machine, or a `git pull` brought new versions to apply locally |
| `./sync.sh` | `$HOME` → repo | You edited a dotfile / claude config in `$HOME` and want to capture it |

Both are idempotent (identical files skipped), support `--dry-run`, and never destroy data:
`INSTALL.sh` timestamp-backs-up any differing home file before overwriting; `sync.sh` shows a diff
and prompts per file (`[o]verwrite repo / [k]eep / [m]erge in $EDITOR / [s]how / [q]uit`) — nothing
in the repo changes without an explicit `o` or a save during `m`.

## Common commands

```sh
./host-os/bootstrap.sh        # fresh macOS: Xcode CLT, Homebrew, brew bundle, npm globals
./INSTALL.sh                  # copy dotfiles into ~
./INSTALL.sh --claude         # also copy claude/* into ~/.claude/
./INSTALL.sh --all            # dotfiles + claude + run host-os bootstrap first
./INSTALL.sh --dry-run --all  # preview everything, change nothing

./sync.sh                     # interactive capture of home edits back into repo
./sync.sh --dry-run           # list only the files that diverge
./sync.sh --mcp               # check MCP-server drift only (no file diffs)

./claude/mcp-servers.sh       # (re)create user-scope MCP servers via `claude mcp add`
```

## Three domains

- **Dotfiles** (repo root): `.shell_common` holds everything portable (aliases, `title()`,
  Homebrew `shellenv`, PATH). `.bashrc` / `.zshrc` add shell-specific bits and each sources
  `.shell_common`. `.tmux.conf` picks `pbcopy`/`pbpaste` on Darwin, `xclip` on Linux.
- **`host-os/`**: one-shot macOS bootstrap — Xcode CLT → Homebrew → `Brewfile` → `npm-globals.sh`.
  Darwin-only (aborts otherwise). Idempotent; npm step is allowed to fail without aborting.
- **`claude/`**: the tracked subset of `~/.claude/` (CLAUDE.md, investigations.md, settings.json,
  statusline.sh, rules/, agents/, commands/, skills/, mcp-servers.sh). Runtime state
  (sessions/, projects/, caches, `*.jsonl`) is gitignored — see `claude/README.md`.

## Editing rules specific to this repo

- **The tracked-dotfile list is duplicated.** A `DOTFILES=(...)` array appears in both
  `INSTALL.sh` (~line 87) and `sync.sh` (~line 135). Adding/removing a tracked dotfile means
  editing **both**, or the two directions fall out of sync.
- **Adding a claude config file**: drop it under `claude/<path>`, then `./INSTALL.sh --claude`.
  `INSTALL.sh` walks `claude/` recursively but skips `README.md` and `.gitkeep`; `sync.sh`
  additionally skips `mcp-servers.sh` (it's a generator, not a mirrored file).
- **Adding an MCP server**: `claude mcp add <name> --scope user -- <cmd> <args>` to test, then
  append the matching `add_user_mcp` line to `claude/mcp-servers.sh`; `./sync.sh --mcp` should
  then report "in sync". Drift detection is **name-only** — same name with a different command
  is not flagged.
- **`claude/settings.json` churns.** Claude Code rewrites it when you toggle plugins or change
  permissions; review diffs before committing and never let secrets land in it.

## Secrets / machine-local values

Anything secret or per-machine goes in a `*-local` file that lives in `$HOME` but is gitignored
(`*-local`, `*.local`). Each shared shell file sources its `-local` twin **last**, so local values
win. MCP servers needing keys reference an env var (e.g. `$STRIPE_API_KEY`) set in `~/.zshrc-local`;
OAuth-based MCPs re-auth per machine by design and are never synced.
