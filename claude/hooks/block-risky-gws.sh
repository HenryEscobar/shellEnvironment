#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash) -- block high-risk Google Workspace CLI commands.
#
# Extracted verbatim from settings.json on 2026-07-27. Behavior is unchanged:
# same regex, same message, same exit codes.
#
# Contract: exit 2 blocks the tool call and shows stderr to Claude. Exit 0 allows.
#
# Blocks, per the gws guardrails in ~/.claude/CLAUDE.md:
#   gws gmail ...                          (no mail access for the agent)
#   gws script ...                         (arbitrary Apps Script execution)
#   gws drive files delete|emptyTrash      (irreversible deletion)
#   gws auth export|logout                 (credential exfiltration / lockout)
#
# The regex requires whitespace between tokens, so `gws  gmail` and
# `gws\tgmail` are caught, and `gwsgmail` is not a match. As with the other
# Bash hook, this matches the command STRING: an alias, a wrapper script, or a
# command built through variable expansion would not be seen.

set -u

CMD=$(jq -r ".tool_input.command" <<< "$(cat)")

BLOCKED_RE="gws[[:space:]]+(gmail|script)([[:space:]]|$)|gws[[:space:]]+drive[[:space:]]+files[[:space:]]+(delete|emptyTrash)|gws[[:space:]]+auth[[:space:]]+(export|logout)"

if echo "$CMD" | grep -qiE "$BLOCKED_RE"; then
  echo "Blocked: high-risk gws command (gmail/script, drive delete or emptyTrash, auth export/logout) is not permitted for the agent" >&2
  exit 2
fi

exit 0
