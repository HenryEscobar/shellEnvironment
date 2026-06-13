#!/bin/bash
# INSTALL.sh — copy this repo's files into $HOME (repo -> home).
#
# Usage:
#   ./INSTALL.sh                # dotfiles only
#   ./INSTALL.sh --claude       # also copy claude/* into ~/.claude/
#   ./INSTALL.sh --host-os      # also run host-os/bootstrap.sh first
#   ./INSTALL.sh --all          # everything
#   ./INSTALL.sh --dry-run      # print actions, change nothing
#
# Safety:
#   - Real file copies (not symlinks), so deleting the repo doesn't break ~.
#   - Idempotent: identical files are skipped silently.
#   - If a home file DIFFERS from the repo copy, it's backed up to
#     <name>-YYYYMMDD-HHMMSS before being overwritten. Nothing is nuked.
#   - Use sync.sh to push changes the other way (home -> repo).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_TAG="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
DO_CLAUDE=0
DO_HOST_OS=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --claude)  DO_CLAUDE=1 ;;
        --host-os) DO_HOST_OS=1 ;;
        --all)     DO_CLAUDE=1; DO_HOST_OS=1 ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        *)         echo "unknown flag: $arg" >&2; exit 2 ;;
    esac
done

log()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[install]\033[0m %s\n' "$*" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then echo "  + $*"; else eval "$@"; fi; }

# copy_one <src> <dest>
#   - src missing in repo  -> skip with warning
#   - dest is a symlink    -> remove it (legacy from old INSTALL.sh)
#   - dest identical       -> skip silently
#   - dest differs         -> backup with timestamp, then copy
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
        log "backup $dest -> $dest-$BACKUP_TAG  (home differs from repo)"
        run "cp -p '$dest' '$dest-$BACKUP_TAG'"
        log "update $dest"
    else
        log "create $dest"
    fi

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

# --- 3. Claude config (optional) --------------------------------------------
if [ "$DO_CLAUDE" -eq 1 ]; then
    log "Copying claude/* into ~/.claude/..."
    run "mkdir -p '$HOME/.claude'"

    while IFS= read -r -d '' src; do
        rel="${src#"$REPO_DIR/claude/"}"
        case "$rel" in
            README.md|*/.gitkeep|.gitkeep) continue ;;
        esac
        copy_one "$src" "$HOME/.claude/$rel"
    done < <(find "$REPO_DIR/claude" -type f -print0)

    # Register user-scope MCP servers. Needs the `claude` CLI (installed by
    # host-os bootstrap via npm-globals). Servers that take an API key read it
    # from ~/.zshrc-local — set those there first, or they register keyless.
    if command -v claude >/dev/null 2>&1; then
        log "Registering MCP servers (claude/mcp-servers.sh)..."
        if [ -z "${STRIPE_SECRET_KEY:-}" ]; then
            warn "STRIPE_SECRET_KEY not set — stripe will register without a key."
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
