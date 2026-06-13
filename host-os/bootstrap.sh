#!/bin/bash
# host-os/bootstrap.sh — one-shot setup for a fresh macOS box.
# Idempotent: re-running it is safe and just installs anything missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE="$SCRIPT_DIR/Brewfile"

log()  { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bootstrap]\033[0m %s\n' "$*" >&2; }

if [ "$(uname)" != "Darwin" ]; then
    warn "bootstrap.sh targets macOS; detected $(uname). Aborting."
    exit 1
fi

# --- Xcode Command Line Tools -----------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
    log "Installing Xcode Command Line Tools (a GUI dialog will appear)..."
    xcode-select --install
    log "Re-run this script once the CLT install finishes."
    exit 0
else
    log "Xcode CLT already present."
fi

# --- Homebrew ---------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Make brew callable in this shell on Apple Silicon.
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    log "Homebrew already installed: $(brew --version | head -1)"
fi

# --- Brewfile ---------------------------------------------------------------
if [ -f "$BREWFILE" ]; then
    log "Running brew bundle against $BREWFILE..."
    brew bundle --file="$BREWFILE"
else
    warn "No Brewfile at $BREWFILE; skipping bundle step."
fi

# --- Global npm packages ----------------------------------------------------
# Allowed to fail independently: bootstrap proceeds even if some npm installs
# can't run (e.g. EACCES on a non-Homebrew Node prefix).
if [ -x "$SCRIPT_DIR/npm-globals.sh" ]; then
    log "Installing global npm CLIs..."
    "$SCRIPT_DIR/npm-globals.sh" || warn "npm-globals.sh reported failures (continuing)"
fi

log "Bootstrap complete."
log "Next: run ../INSTALL.sh from the repo root to copy dotfiles into ~"
