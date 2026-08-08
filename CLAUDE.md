# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles + macOS machine setup (Apple Silicon first; most dotfiles also work on Linux).
There is no build/test/lint toolchain — it's Bash scripts plus config files. "Running" it means
invoking the install/sync scripts.

## Do not edit tracked files in this repo directly

**The scripts are the interface to this repo. `INSTALL.sh` copies out, `sync.sh` copies back.**
Every file under `claude/`, `bin/`, and the tracked dotfiles is a copy of something live in
`$HOME`. Edit the **real** location (`~/.claude/...`, `~/bin/...`, `~/.zshrc`, ...), then run
`./sync.sh` and choose `o` to bring the change in.

Editing the repo copy directly is wrong in both directions: the live config does not change, so
you have not fixed anything yet, and the next `./sync.sh` sees the repo diverging **from** home
and offers to overwrite your edit with the stale home version. Someone answering `o` out of habit
silently reverts you.

**Ask for explicit permission before editing any tracked file here.** Two exceptions, both
repo-only files with no `$HOME` twin, safe to edit in place: `.gitignore`, `README.md`,
`CLAUDE.md`, `LICENSE`, and the scripts themselves (`INSTALL.sh`, `sync.sh`, `host-os/`).

## Core model: two-way copy between repo and `$HOME`

The repo and `$HOME` hold parallel copies of each tracked file. Two scripts move changes between
them, in opposite directions. **Files are real copies, not symlinks** (deleting the repo must not
break the live shell or `~/.claude/`); `copy_one()` in `INSTALL.sh` does `cp -p`.

**Both directions default to the same set: dotfiles + `bin/` + `claude/`.** `INSTALL.sh` used to
hide `claude/` behind `--claude` while `sync.sh` walked it by default, so a plain `./INSTALL.sh`
applied strictly less than a plain `./sync.sh` captured. `--claude` is now a no-op; `--no-claude`
opts out. MCP registration is the one thing `INSTALL.sh` does NOT do by default (`--mcp`/`--all`),
because it shells out to the `claude` CLI and needs keys from `~/.zshrc-local`.

| Script         | Direction      | Use when                                                               |
| -------------- | -------------- | ---------------------------------------------------------------------- |
| `./INSTALL.sh` | repo → `$HOME` | Fresh machine, or a `git pull` brought new versions to apply locally   |
| `./sync.sh`    | `$HOME` → repo | You edited a dotfile / claude config in `$HOME` and want to capture it |

Both are idempotent (identical files skipped), support `--dry-run`, and never destroy data. They
prompt per differing file (mirrored, opposite directions): `INSTALL.sh` shows a diff and asks
`[o]verwrite home / [k]eep home / [m]erge in $EDITOR / [s]how / [q]uit` (non-interactive runs with
no tty fall back to timestamped backup + overwrite); `sync.sh` does the same toward the repo
(`[o]verwrite repo / [k]eep / [m]erge / [s]how / [q]uit`). Nothing is overwritten without an
explicit `o` or a save during `m`.

## Common commands

```sh
./host-os/bootstrap.sh        # fresh macOS: Xcode CLT, Homebrew, brew bundle, npm globals
./INSTALL.sh                  # dotfiles + bin/ + claude/* into ~  (claude is DEFAULT)
./INSTALL.sh --no-claude      # dotfiles + bin/ only, leave ~/.claude/ alone
./INSTALL.sh --mcp            # the default, plus MCP server registration
./INSTALL.sh --all            # host-os bootstrap first, then dotfiles + claude + MCP
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
  statusline.sh, rules/, agents/, commands/, skills/, hooks/, mcp-servers.sh). Runtime state
  (sessions/, projects/, caches, `*.jsonl`) is gitignored — see `claude/README.md`.
  `hooks/` holds hook scripts referenced from `settings.json` plus the `package.json` /
  `package-lock.json` for their dependencies; `claude/hooks/.gitignore` keeps `node_modules/`
  and the bootstrap log out of the repo.
- **`bin/`**: executable convenience scripts copied to `~/bin` by `INSTALL.sh` (which
  `.shell_common` puts on PATH). Each file is mirrored by name; `cp -p` keeps the executable
  bit, so commit scripts with `chmod +x`. e.g. `gh-newrepo` creates a GitHub repo pre-configured
  to the standard (squash-only, PR-required, linear history).

## Editing rules specific to this repo

- **The tracked-dotfile list is duplicated.** A `DOTFILES=(...)` array appears in both
  `INSTALL.sh` (~line 169) and `sync.sh` (~line 223). Adding/removing a tracked dotfile means
  editing **both**, or the two directions fall out of sync.
- **Adding a claude config file**: drop it under `claude/<path>`, then `./INSTALL.sh`
  (claude/ is copied by default; `--no-claude` opts out, `--claude` is a kept no-op).
  `INSTALL.sh` walks `claude/` recursively but skips `README.md` and `.gitkeep`; `sync.sh`
  additionally skips `mcp-servers.sh` (it's a generator, not a mirrored file).
- **`sync.sh` mostly cannot discover new files.** Its main walk is repo-driven
  (`find "$REPO_DIR/claude"`, `find "$REPO_DIR/bin"`), comparing each repo file to its `$HOME`
  twin, so a file created in `~/.claude/` or `~/bin` with no repo counterpart is invisible to it.
  This dropped an entire `~/.claude/hooks/` directory and three skills once (`a46cc88`), then
  `silent-change-audit` and `weekly-digest` a day later.
  **One exception, added 2026-08-01:** a second pass walks `$HOME/.claude/skills/*/` and offers
  any directory with no repo counterpart for adoption (`[a]dopt / [k]eep out / [v]iew / [q]uit`),
  skipping symlinked skills and anything `.gitignore` excludes, per file as well as per directory.
  Disable with `--no-adopt`.
  **Everything else is still blind**: new files under `~/bin`, `~/.claude/hooks/`,
  `~/.claude/agents/`, `~/.claude/commands/`, `~/.claude/rules/`, and any new dotfile must be
  copied into the repo by hand once. Only then does `sync.sh` track them thereafter.
- **Adding an MCP server**: `claude mcp add <name> --scope user -- <cmd> <args>` to test, then
  append the matching `add_user_mcp` line to `claude/mcp-servers.sh`; `./sync.sh --mcp` should
  then report "in sync". Drift detection is **name-only** — same name with a different command
  is not flagged.
- **`claude/settings.json` churns.** Claude Code rewrites it when you toggle plugins or change
  permissions; review diffs before committing and never let secrets land in it.
- **Adding a convenience script**: drop an executable file under `bin/` (`chmod +x`), then
  `./INSTALL.sh` copies it to `~/bin`. Both `INSTALL.sh` and `sync.sh` walk `bin/` recursively
  by basename — no array to update (unlike the `DOTFILES` list).

## Secrets / machine-local values

Anything secret or per-machine goes in a `*-local` file that lives in `$HOME` but is gitignored
(`*-local`, `*.local`). Each shared shell file sources its `-local` twin **last**, so local values
win. MCP servers needing keys reference an env var (e.g. `$STRIPE_API_KEY`) set in `~/.zshrc-local`;
OAuth-based MCPs re-auth per machine by design and are never synced.
