#!/bin/bash
# INSTALL.sh — copy this repo's files into $HOME (repo -> home).
#
# Usage:
#   ./INSTALL.sh                # dotfiles + bin/ + claude/   <- the default
#   ./INSTALL.sh --no-claude    # dotfiles + bin/ only, leave ~/.claude/ alone
#   ./INSTALL.sh --mcp          # also (re)register user-scope MCP servers
#   ./INSTALL.sh --host-os      # also run host-os/bootstrap.sh first
#   ./INSTALL.sh --all          # host-os + dotfiles + bin + claude + MCP
#   ./INSTALL.sh --dry-run      # print actions, change nothing
#
# Why claude/ is on by default:
#   ~/.claude/ is the bulk of what this repo keeps in sync, and sync.sh has
#   always walked claude/ by default. Having the two directions disagree meant
#   a plain ./INSTALL.sh silently applied half of what a plain ./sync.sh
#   captured. `--claude` is still accepted as a no-op so old habits keep working.
#
# Why MCP registration is NOT on by default:
#   It isn't a file copy — it shells out to the `claude` CLI to remove-then-add
#   user-scope servers, needs the network (npx), and needs the API keys from
#   ~/.zshrc-local. That's fresh-machine setup (--all) or an explicit --mcp,
#   not something every dotfile refresh should redo.
#
# Safety:
#   - Real file copies (not symlinks), so deleting the repo doesn't break ~.
#   - Idempotent: identical files are skipped silently.
#   - If a home file DIFFERS from the repo copy, you're prompted per file
#     (show diff / [o]verwrite home / [k]eep home / [m]erge / [q]uit). Nothing is
#     overwritten without your say-so. Non-interactive runs (no tty) fall back to
#     backup (<name>-YYYYMMDD-HHMMSS) + overwrite so they never hang.
#   - Use sync.sh to push changes the other way (home -> repo).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_TAG="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
DO_CLAUDE=1
DO_HOST_OS=0
DO_MCP=0
# Nothing to copy if this checkout has no claude/ dir (mirrors sync.sh).
[ -d "$REPO_DIR/claude" ] || DO_CLAUDE=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=1 ;;
        --claude)    DO_CLAUDE=1 ;;   # no-op: on by default. Kept for muscle memory.
        --no-claude) DO_CLAUDE=0 ;;
        --mcp)       DO_MCP=1 ;;
        --host-os)   DO_HOST_OS=1 ;;
        --all)       DO_CLAUDE=1; DO_HOST_OS=1; DO_MCP=1 ;;
        -h|--help)   sed -n '2,31p' "$0"; exit 0 ;;
        *)           echo "unknown flag: $arg" >&2; exit 2 ;;
    esac
done

# --mcp without claude/ files is legal (re-register servers only), but --mcp
# after --no-claude is worth a word so it doesn't look like a silent skip.
if [ "$DO_MCP" -eq 1 ] && [ "$DO_CLAUDE" -eq 0 ]; then
    echo "[install] --mcp: registering MCP servers only; ~/.claude/ files untouched." >&2
fi

log()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[install]\033[0m %s\n' "$*" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then echo "  + $*"; else eval "$@"; fi; }

# Editor used for the [m]erge option. Must be a 2-pane diff tool.
MERGE_TOOL="${EDITOR:-vimdiff}"
case "$MERGE_TOOL" in
    *vimdiff*|*nvim*-d*|*opendiff*|*meld*) ;;   # already diff-capable
    *) MERGE_TOOL="vimdiff" ;;
esac

# show_diff <current> <incoming>  (current=home, incoming=repo)
# Colorized git diff if available, else plain unified diff.
show_diff() {
    local cur="$1" inc="$2"
    if command -v git >/dev/null 2>&1; then
        git --no-pager diff --no-index --color=always -- "$cur" "$inc" || true
    else
        diff -u "$cur" "$inc" || true
    fi
}

# prompt_diff <src=repo> <dest=home> — only called when the two differ.
prompt_diff() {
    local src="$1" dest="$2"

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  diverges: $dest"
        return 0
    fi

    # Non-interactive (no tty): fall back to the old safe behavior so unattended
    # runs never hang on a prompt — back up, then overwrite.
    if [ ! -e /dev/tty ]; then
        log "backup $dest -> $dest-$BACKUP_TAG (non-interactive)"
        cp -p "$dest" "$dest-$BACKUP_TAG"
        cp -p "$src" "$dest"
        log "update $dest"
        return 0
    fi

    while true; do
        echo
        log "$dest differs from repo."
        show_diff "$dest" "$src" | sed -n '1,80p'
        local n; n=$(show_diff "$dest" "$src" | wc -l | tr -d ' ')
        [ "$n" -gt 80 ] && echo "(diff truncated — $n lines; [s]how full or [m]erge)"
        printf '\n  [o]verwrite home  [k]eep home  [m]erge in %s  [s]how full diff  [q]uit  > ' "$MERGE_TOOL"
        read -r choice </dev/tty
        case "$choice" in
            o|O) cp -p "$src" "$dest"; log "updated $dest from repo"; return 0 ;;
            k|K) log "kept home $dest unchanged"; return 0 ;;
            m|M) "$MERGE_TOOL" "$dest" "$src" </dev/tty >/dev/tty 2>&1 || true
                 if cmp -s "$src" "$dest"; then log "merged $dest (now identical)"; return 0
                 else log "still differs after merge — re-prompting"; fi ;;
            s|S) show_diff "$dest" "$src" | ${PAGER:-less -R} ;;
            q|Q) warn "quit — remaining files left as-is"; exit 0 ;;
            *)   echo "  pick o / k / m / s / q" ;;
        esac
    done
}

# copy_one <src> <dest>
#   - src missing in repo  -> skip with warning
#   - dest is a symlink    -> remove it (legacy from old INSTALL.sh)
#   - dest identical       -> skip silently
#   - dest differs         -> prompt per file (prompt_diff)
#   - dest missing         -> just copy
copy_one() {
    local src="$1" dest="$2"

    if [ ! -e "$src" ]; then
        warn "skip (missing in repo): $src"
        return 0
    fi

    if [ -L "$dest" ]; then
        log "removing legacy symlink at $dest"
        run "rm '$dest'"
    fi

    if [ -e "$dest" ]; then
        if cmp -s "$src" "$dest"; then
            return 0  # identical, nothing to do
        fi
        prompt_diff "$src" "$dest"  # differs — ask the user
        return 0
    fi

    log "create $dest"
    run "mkdir -p '$(dirname "$dest")'"
    run "cp -p '$src' '$dest'"
}

# --- 1. host-os bootstrap (optional, runs first) -----------------------------
if [ "$DO_HOST_OS" -eq 1 ]; then
    log "Running host-os bootstrap..."
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  + $REPO_DIR/host-os/bootstrap.sh"
    else
        "$REPO_DIR/host-os/bootstrap.sh"
    fi
fi

# --- 2. Dotfiles (always) ----------------------------------------------------
DOTFILES=(
    .shell_common
    .bashrc
    .zshrc
    .zprofile
    .tmux.conf
    .tmux.reset
    .screenrc
    .gitconfig
)

log "Copying dotfiles..."
for f in "${DOTFILES[@]}"; do
    copy_one "$REPO_DIR/$f" "$HOME/$f"
done

# SSH config (separate because it lives in ~/.ssh/).
if [ ! -d "$HOME/.ssh" ]; then
    log "Creating ~/.ssh (0700)"
    run "mkdir -p '$HOME/.ssh'"
    run "chmod 0700 '$HOME/.ssh'"
fi
copy_one "$REPO_DIR/.ssh/config" "$HOME/.ssh/config"

# --- 2b. Convenience scripts (bin/ -> ~/bin) --------------------------------
# Executable helpers. ~/bin is put on PATH by .shell_common. cp -p in copy_one
# preserves the executable bit committed in the repo.
if [ -d "$REPO_DIR/bin" ]; then
    log "Copying bin/* into ~/bin..."
    run "mkdir -p '$HOME/bin'"
    while IFS= read -r -d '' src; do
        copy_one "$src" "$HOME/bin/$(basename "$src")"
    done < <(find "$REPO_DIR/bin" -type f -print0)
fi

# --- 3. Claude config (on by default; --no-claude to skip) -------------------
if [ "$DO_CLAUDE" -eq 1 ] && [ -d "$REPO_DIR/claude" ]; then
    log "Copying claude/* into ~/.claude/..."
    run "mkdir -p '$HOME/.claude'"

    while IFS= read -r -d '' src; do
        rel="${src#"$REPO_DIR/claude/"}"
        case "$rel" in
            README.md|*/.gitkeep|.gitkeep) continue ;;
        esac
        copy_one "$src" "$HOME/.claude/$rel"
    done < <(find "$REPO_DIR/claude" -type f -print0)
fi

# --- 4. MCP servers (opt-in: --mcp or --all) ---------------------------------
# Not a file copy: this removes-then-adds user-scope servers through the
# `claude` CLI (installed by host-os bootstrap via npm-globals). Servers that
# take an API key read it from ~/.zshrc-local — set those there first, or the
# generator aborts on the unset variable.
if [ "$DO_MCP" -eq 1 ]; then
    if command -v claude >/dev/null 2>&1; then
        log "Registering MCP servers (claude/mcp-servers.sh)..."
        if [ -z "${STRIPE_SECRET_KEY:-}" ]; then
            warn "STRIPE_SECRET_KEY not set — mcp-servers.sh will abort on it."
            warn "Set it in ~/.zshrc-local, then re-run: ./claude/mcp-servers.sh"
        fi
        run "'$REPO_DIR/claude/mcp-servers.sh'"
    else
        warn "claude CLI not on PATH — skipping MCP registration."
        warn "Install it (host-os bootstrap), then run: ./claude/mcp-servers.sh"
    fi
fi

log "Done."
if [ "$DRY_RUN" -eq 1 ]; then
    warn "Dry run — no changes made. Re-run without --dry-run to apply."
fi
