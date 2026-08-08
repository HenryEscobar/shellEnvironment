#!/bin/bash
# claude/mcp-servers.sh — re-create user-scope MCP servers.
#
# When to run:
#   - On a fresh machine, after INSTALL.sh.
#   - After git pull, if new servers were added to this file.
#   - You can also re-run safely; existing servers are removed-then-added so
#     this script is idempotent.
#
# What it does NOT do:
#   - Doesn't store secrets. Any server that needs an API key references it as
#     an env var ($SOMETHING_TOKEN). Set those in ~/.zshrc-local (gitignored).
#   - Doesn't handle OAuth. Servers like Sentry / Stripe / Google open an auth
#     flow the first time you use them — that's per-machine, not config.
#   - Doesn't touch claude.ai-managed servers (Gmail, Google Drive, Google
#     Calendar). Those follow your claude.ai account, not this file.
#   - Doesn't touch project-scope servers (e.g. postgres + sentry inside
#     relationship-crm). Those live in that project's .mcp.json.

set -euo pipefail

log()  { printf '\033[1;34m[mcp]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[mcp]\033[0m %s\n' "$*" >&2; }

if ! command -v claude >/dev/null 2>&1; then
    warn "claude CLI not on PATH; install Claude Code first."
    exit 1
fi

# add_user_mcp <name> [flags-to-claude-mcp-add...] -- <command> [args...]
#
# Caller MUST include `--` to separate flags (passed to `claude mcp add`) from
# the actual command to run. This is what makes --env work correctly.
#
# Removes any existing entry with that name first, then adds fresh.
add_user_mcp() {
    local name="$1"; shift
    log "installing user-scope MCP: $name"
    claude mcp remove "$name" -s user >/dev/null 2>&1 || true
    claude mcp add "$name" --scope user "$@"
}

# --- User-scope servers ------------------------------------------------------
# Format: add_user_mcp <name> [flags] -- <command> [args...]
# Environment vars (if any) should come from ~/.zshrc-local.

add_user_mcp playwright   -- npx -y @playwright/mcp@latest
add_user_mcp sentry-mcp   -- npx mcp-remote https://mcp.sentry.io/mcp
add_user_mcp stripe       --env STRIPE_SECRET_KEY="$STRIPE_SECRET_KEY" -- npx -y @stripe/mcp

# --- Add new servers below ---------------------------------------------------
# Examples:
#   add_user_mcp google-docs  -- npx -y @some-pkg/google-docs-mcp
#   add_user_mcp github       -- npx -y @modelcontextprotocol/server-github
#
# For servers that take an API key via env var:
#   1. ~/.zshrc-local:   export FOO_TOKEN="..."
#   2. Here:             add_user_mcp foo --env FOO_TOKEN="$FOO_TOKEN" -- npx -y @foo/mcp
#                                         ^^^^^ flag BEFORE the --   ^^ command AFTER
#
# Run: ./sync.sh --mcp  to check for drift between this file and what's
# actually installed on your machine.
#
# Drift detection is NAME-ONLY. sync.sh compares the `add_user_mcp <name>` names
# here against the names from `claude mcp list`; it never looks at the command
# or args. A server declared here with one command and installed locally with a
# different one reports "in sync". Changing a command means re-running this
# script by hand — nothing will tell you the two sides diverged.

log "done"
log "verify: claude mcp list"
