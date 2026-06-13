#!/bin/bash
# host-os/npm-globals.sh — globally-installed npm CLIs that you actually invoke
# from the shell. Re-run safely: `npm install -g` is idempotent.
#
# Scope:
#   - This file is for CLIs you type at a prompt (eas, gworkspace, ...).
#   - For MCP server runtimes, prefer `npx -y <pkg>` in claude/mcp-servers.sh.
#     That way new machines get them automatically with zero global install.
#
# Drift policy:
#   - When you `npm install -g <something>` ad hoc, add it here.
#   - When you stop using something, delete it AND `npm uninstall -g <pkg>`
#     by hand (this script doesn't prune; that'd be too destructive).
#
# Permissions note:
#   If `npm install -g` fails with EACCES, your Node is in a root-owned prefix
#   (e.g. /usr/local/ from a nodejs.org installer). Two real fixes:
#     a. `brew install node` — Homebrew puts npm under /opt/homebrew, no sudo.
#     b. Point npm at a user-writable prefix:
#          npm config set prefix "$HOME/.npm-global"
#          and add "$HOME/.npm-global/bin" to PATH.
#   This script will NOT sudo automatically.

# Note: no `set -e` — we want to try every package even if one fails.
set -uo pipefail

log()  { printf '\033[1;34m[npm-globals]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[npm-globals]\033[0m %s\n' "$*" >&2; }

if ! command -v npm >/dev/null 2>&1; then
    warn "npm not on PATH — skipping. (Uncomment 'node' in Brewfile, or install"
    warn "Node via nvm/fnm, then re-run this script.)"
    exit 0
fi

PACKAGES=(
    eas-cli                       # Expo / EAS Build deploys
    "@googleworkspace/cli"        # Google Workspace CLI
    "@anthropic-ai/claude-code"   # Claude Code CLI (needed for `claude mcp add`)
)

failed=()
for pkg in "${PACKAGES[@]}"; do
    log "ensuring $pkg"
    # Capture stderr to detect EACCES specifically; let stdout flow.
    if ! err=$(npm install -g "$pkg" 2>&1 >/dev/null); then
        if printf '%s' "$err" | grep -q 'EACCES'; then
            warn "permission denied installing $pkg — your npm prefix is root-owned."
            warn "See the 'Permissions note' at the top of this file."
        else
            warn "failed to install $pkg:"
            printf '%s\n' "$err" | sed 's/^/    /' >&2
        fi
        failed+=("$pkg")
    fi
done

if [ "${#failed[@]}" -eq 0 ]; then
    log "done — all packages installed"
    exit 0
else
    warn "done with ${#failed[@]} failure(s): ${failed[*]}"
    exit 1
fi
