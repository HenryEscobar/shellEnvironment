#!/usr/bin/env bash
# PreToolUse hook (matcher: Write|Edit) -- block writes to sensitive files.
#
# Extracted verbatim from settings.json on 2026-07-27. Behavior is unchanged:
# same patterns, same substring matching, same messages, same exit codes.
#
# Contract: exit 2 blocks the tool call and shows stderr to Claude. Exit 0 allows.
#
# Matching is a case-SENSITIVE substring test against the file path, so
# ".env" also matches ".environment" or "my.env.example", and ".git/" matches
# any path segment containing it. Over-blocking is the safe direction here.
#
# Note this duplicates part of permissions.deny in settings.json (which already
# denies Write/Edit on **/.env and friends). The hook is the enforcing layer:
# deny rules can be overridden per-project, a PreToolUse hook exiting 2 cannot.

set -u

FILE=$(jq -r ".tool_input.file_path" <<< "$(cat)")

PATTERNS=(
  ".env"
  ".git/"
  "id_rsa"
  "id_ed25519"
  ".pem"
)

for p in "${PATTERNS[@]}"; do
  if [[ "$FILE" == *"$p"* ]]; then
    echo "Blocked: $FILE matches protected pattern $p" >&2
    exit 2
  fi
done

exit 0
