# shellEnvironment

My shell + machine setup, scoped for macOS (Apple Silicon) but most of the
dotfiles work on Linux too.

## Layout

```
.
├── INSTALL.sh           # repo -> home: copy dotfiles + (optional) claude/ into ~
├── sync.sh              # home -> repo: interactively capture edits made in ~
├── .shell_common        # aliases + functions sourced by both bash and zsh
├── .bashrc / .zshrc     # shell-specific bits; each sources .shell_common
├── .zprofile            # zsh login env (Homebrew shellenv etc.)
├── .tmux.conf / .tmux.reset / .screenrc
├── .gitconfig
├── .ssh/config
├── host-os/             # macOS bootstrap — Xcode CLT, Homebrew, Brewfile
└── claude/              # tracked subset of ~/.claude/ (config, rules, skills)
    └── mcp-servers.sh   # re-create user-scope MCP servers via `claude mcp add`
```

## Fresh-Mac install

```sh
# 1. clone
git clone git@github.com:HenryEscobar/shellEnvironment.git ~/irad/shellEnvironment
cd ~/irad/shellEnvironment

# 2. one shot: bootstrap (Xcode CLT, Homebrew, brew bundle, npm globals)
#    + dotfiles into ~ + claude configs into ~/.claude + MCP registration
./INSTALL.sh --all
```

`--all` runs `host-os/bootstrap.sh` first, then copies dotfiles and `claude/`,
then registers MCP servers via `claude/mcp-servers.sh`. Preview it all with
`./INSTALL.sh --dry-run --all`. Narrower runs: `./INSTALL.sh` (dotfiles only),
`./INSTALL.sh --claude` (dotfiles + claude + MCP), `./INSTALL.sh --host-os`.

**One manual prerequisite — secrets can't be cloned.** Before MCP servers that
need a key will work, create `~/.zshrc-local` (gitignored) with e.g.
`export STRIPE_SECRET_KEY="sk_test_..."`, then re-run `./claude/mcp-servers.sh`.
If the key isn't set when `--all` runs, that server registers keyless and the
install warns you.

## How the two scripts relate

This repo uses **real file copies**, not symlinks — so deleting the repo
doesn't break your shell or `~/.claude/`.

```
   repo -------- INSTALL.sh ------->  $HOME
   repo <-------- sync.sh ----------  $HOME
```

| Script | Direction | When to use |
| --- | --- | --- |
| `./INSTALL.sh` | repo → home | Fresh machine, or `git pull` brought new versions you want applied locally |
| `./sync.sh`    | home → repo | You edited a dotfile or claude config at home and want to capture it |

Both scripts:
- **Never overwrite without a safety net.** Both show the diff and prompt per
  file when a file differs (INSTALL.sh toward home, sync.sh toward the repo).
  INSTALL.sh falls back to a timestamped backup + overwrite only when run with no
  tty (unattended).
- **Are idempotent.** Identical files are skipped silently.
- Support `--dry-run` to preview without changing anything.

### `sync.sh` per-file options

When a home file differs from the repo version, sync.sh shows the diff and
prompts:

- **o** — overwrite repo with the home version
- **k** — keep repo as-is (your local edit stays at home only)
- **m** — open a 2-pane merge in `$EDITOR` (defaults to `vimdiff`); save the
  merged result into the repo side
- **s** — show the full diff again, paged
- **q** — quit, leave remaining files untouched

Nothing in the repo is overwritten unless you press **o** or save during **m**.

## MCP servers

Claude Code stores MCP server config in `~/.claude.json`, **not** in
`~/.claude/settings.json`. That file mixes config with churning state and
sometimes holds tokens, so we don't track it directly. Instead:

| File | What |
| --- | --- |
| `claude/mcp-servers.sh` | Declarative `claude mcp add` lines for every user-scope MCP. Run it to install. |
| `./sync.sh --mcp` | Diff what's installed locally vs declared in the script. Tells you what to add to the script (or what to install). |

### Adding a new MCP

1. `claude mcp add <name> --scope user -- <command> <args...>`  — try it locally.
2. Once it works, append the same line to `claude/mcp-servers.sh`.
3. `./sync.sh --mcp` should report "in sync".

### Secrets

Tokens stay out of the repo. The pattern:

```sh
# in ~/.zshrc-local (gitignored):
export STRIPE_SECRET_KEY="sk_test_..."

# in claude/mcp-servers.sh:
add_user_mcp stripe --env STRIPE_SECRET_KEY="$STRIPE_SECRET_KEY" -- npx -y @stripe/mcp
```

OAuth-based MCPs (Sentry, Stripe, Google Docs, etc.) re-do their auth flow
the first time you use them on a new machine. That's intentional — tokens
are device-bound and shouldn't sync.

### What's NOT covered

- **claude.ai-managed servers** (Gmail, Google Drive, Google Calendar) — these
  follow your claude.ai account, not this file.
- **Project-scope servers** — live in each project's `.mcp.json`. Track them
  in the project repo, not here.

## Machine-local overrides

Anything secret or machine-specific goes in a `*-local` file that lives in
`~` but **not** in this repo:

| Shared (tracked) | Local (gitignored) |
| --- | --- |
| `~/.zshrc` | `~/.zshrc-local` |
| `~/.zprofile` | `~/.zprofile-local` |
| `~/.bashrc` | `~/.bashrc-local` |

Each shared file sources its `-local` twin last, so local values win.

## Sections

### Dotfiles
`.shell_common` holds anything portable (aliases, `title()`, Homebrew shellenv,
PATH additions). `.bashrc` / `.zshrc` add shell-specific options (history,
prompt, completion). `.tmux.conf` auto-picks `pbcopy`/`pbpaste` on macOS and
`xclip` on Linux for clipboard binds.

### `host-os/`
One-shot macOS bootstrap. See [host-os/README.md](host-os/README.md).

### `claude/`
Hand-picked subset of `~/.claude/` (CLAUDE.md, rules, agents, commands, skills).
Runtime state (sessions, history, caches) is gitignored. See
[claude/README.md](claude/README.md) for the migration workflow and a
deliberate note on **not** tracking `settings.json` by default.

## What changed from the Linux-era setup

- Shell config now targets zsh first; `.bashrc` is kept for non-macOS hosts.
- Tmux clipboard uses `pbcopy`/`pbpaste` on Darwin.
- `INSTALL.sh` uses **symlinks** (not hardlinks), backs up non-symlink
  collisions with a timestamp, and is idempotent.
- New `host-os/` and `claude/` sections.
- `.gitignore` blocks `*-local`, SSH keys, `.env*`, macOS junk, and Claude
  runtime state.
