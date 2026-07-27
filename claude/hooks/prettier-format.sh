#!/usr/bin/env bash
# PostToolUse hook: format the file Claude just wrote or edited with prettier.
#
# Resolution order:
#   1. A prettier in the file's own project (walk up from the file for
#      node_modules/.bin/prettier). The repo installed prettier, so it opted in:
#      format any supported extension.
#   2. The prettier installed next to this hook. The repo did NOT opt in, so
#      only format markdown. Reformatting someone's TypeScript to prettier
#      defaults in a repo that never chose prettier produces enormous diffs.
#   3. Neither present, and the file is markdown: bootstrap the hook-local
#      prettier once (see below), then format.
#   4. Nothing available: exit silently, ~20ms.
#
# SELF-BOOTSTRAP (so a new machine needs no manual setup):
#   The first time markdown is edited with no prettier anywhere, this runs
#   `npm ci` in ~/.claude/hooks. It is guarded so it can only ever cost you once:
#     - runs only for markdown, only when no prettier was found
#     - atomic mkdir lock, so concurrent edits can't run two installs
#     - 120s timeout (macOS has no timeout(1), so it is done with a watchdog)
#     - on failure, writes .bootstrap-failed and never retries; delete that file
#       to try again
#     - all output goes to bootstrap.log, never to stdout
#   Requires package.json and package-lock.json to be present next to this
#   script. To set up manually instead: cd ~/.claude/hooks && npm ci
#
# Never blocks a turn: always exits 0.

set -u

HOOK_DIR="$HOME/.claude/hooks"
FALLBACK="$HOOK_DIR/node_modules/.bin/prettier"
LOCK="$HOOK_DIR/.bootstrap.lock"
FAILED="$HOOK_DIR/.bootstrap-failed"
LOG="$HOOK_DIR/bootstrap.log"

FILE=$(jq -r '.tool_input.file_path // empty' 2>/dev/null <<< "$(cat)")
[ -n "$FILE" ] || exit 0
[ -f "$FILE" ] || exit 0

case "$FILE" in
  *.md|*.mdx)             MARKDOWN=1 ;;
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.jsonc|*.css|*.scss|*.less|*.html|*.yaml|*.yml|*.graphql)
                          MARKDOWN=0 ;;
  *)                      exit 0 ;;
esac

# Run a command with a timeout. macOS ships no timeout(1), so use a watchdog.
run_with_timeout() {
  local secs="$1"; shift
  "$@" & local pid=$!
  ( sleep "$secs"; kill -9 "$pid" 2>/dev/null ) & local watchdog=$!
  wait "$pid" 2>/dev/null; local rc=$?
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  return "$rc"
}

bootstrap() {
  [ -e "$FAILED" ] && return 1
  [ -f "$HOOK_DIR/package.json" ] || return 1
  command -v npm >/dev/null 2>&1 || { : > "$FAILED"; return 1; }

  # Atomic lock: mkdir fails if another process already holds it.
  mkdir "$LOCK" 2>/dev/null || return 1
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT

  {
    echo "=== bootstrap $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    if [ -f "$HOOK_DIR/package-lock.json" ]; then
      run_with_timeout 120 npm --prefix "$HOOK_DIR" ci --no-audit --no-fund
    else
      run_with_timeout 120 npm --prefix "$HOOK_DIR" install --no-audit --no-fund
    fi
  } >> "$LOG" 2>&1

  rmdir "$LOCK" 2>/dev/null
  trap - EXIT

  if [ -x "$FALLBACK" ]; then
    return 0
  fi
  : > "$FAILED"
  echo "bootstrap failed, will not retry (delete $FAILED to try again)" >> "$LOG"
  return 1
}

# 1. Project-local prettier, walking up from the file itself (not $PWD --
#    Claude routinely edits files outside the session's working directory).
BIN=""
DIR=$(cd "$(dirname "$FILE")" 2>/dev/null && pwd) || exit 0
while [ -n "$DIR" ] && [ "$DIR" != "/" ]; do
  if [ -x "$DIR/node_modules/.bin/prettier" ]; then
    BIN="$DIR/node_modules/.bin/prettier"
    break
  fi
  DIR=$(dirname "$DIR")
done

# 2. Hook-local fallback, markdown only, bootstrapping it if this is a fresh machine.
if [ -z "$BIN" ] && [ "$MARKDOWN" = "1" ]; then
  [ -x "$FALLBACK" ] || bootstrap
  [ -x "$FALLBACK" ] && BIN="$FALLBACK"
fi

[ -n "$BIN" ] || exit 0

"$BIN" --write --cache --log-level=silent "$FILE" >/dev/null 2>&1
exit 0
