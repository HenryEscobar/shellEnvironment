#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash) -- block obviously destructive commands.
#
# Extracted verbatim from settings.json on 2026-07-27. Behavior is unchanged:
# same patterns, same matching, same messages, same exit codes.
#
# Contract: exit 2 blocks the tool call and shows stderr to Claude. Exit 0 allows.
#
# KNOWN LIMITATIONS (documented, deliberately NOT fixed here -- fixing them is a
# behavior change, not an extraction):
#   * Patterns are matched with `grep -iE` against the raw command STRING, so
#     "rm -rf /" matches ANY absolute path. `rm -rf /Users/me/scratch` is blocked
#     as if it were root deletion. This fired twice on legitimate cleanup on
#     2026-07-27.
#   * Equivalent spellings pass straight through: `rm -fr /`,
#     `rm --recursive --force /`, `rm -rf //`, `cd / && rm -rf *`.
#   * It matches flag spelling rather than the resolved target path. A real fix
#     resolves the target and compares against a protected-prefix list.
# Erring toward over-blocking is the safe failure direction, which is why this
# is a warning in a comment and not an urgent fix.

set -u

CMD=$(jq -r ".tool_input.command" <<< "$(cat)")

PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "DROP TABLE"
  "DROP DATABASE"
  "TRUNCATE"
  "push.*--force"
  "push.*-f "
  "reset --hard"
)

for p in "${PATTERNS[@]}"; do
  if echo "$CMD" | grep -qiE "$p"; then
    echo "Blocked: destructive pattern \"$p\" detected" >&2
    exit 2
  fi
done

# Secret-file reads via the shell.
#
# settings.json denies Read(**/.env.*), Read(~/.ssh/**) etc., but those rules bind
# the Read TOOL only -- `cat backend/.env` through Bash walks straight past them and
# prints secrets into the transcript. Added 2026-07-28 after a compound call bundled
# `cat frontend/app/.env.local` with an allowed `pnpm` command; only the interactive
# prompt caught it.
#
# Templates (.env.example / .env.template / .env.sample) are checked in and safe, so
# they are excluded before matching.
READERS="cat|bat|less|more|head|tail|nl|xxd|od|strings|grep|rg|ag|awk|sed|jq|cut|sort|uniq"
SCRUBBED=$(echo "$CMD" | sed -E 's/\.env\.(example|template|sample)//g')

# Where a command word can begin. A reader only counts at one of these, so that
# "concatenate" does not read as "cat".
#
# The openers of a command substitution belong here too: $(cat .env) and the
# backtick spelling each start a fresh command, but until 2026-08-01 the class
# held only the plain separators, so both walked past this check. `export $(cat
# .env | xargs)` was the live example -- one paren away from the block.
#
# Defined once and used by every pattern below. Two copies of a character class
# is how one of them ends up missing a character.
CMD_START='(^|[|;&(`[:space:]])'

SECRET_PATHS=(
  "$CMD_START($READERS)[^|;&]*\.env([^a-zA-Z0-9_.-]|\.[a-zA-Z0-9_-]+|$)"
  "$CMD_START($READERS)[^|;&]*(\.ssh/|\.gnupg/|\.aws/credentials|\.npmrc|id_rsa|id_ed25519)"
)

for p in "${SECRET_PATHS[@]}"; do
  if echo "$SCRUBBED" | grep -qE "$p"; then
    echo "Blocked: reading a secrets file through the shell bypasses the Read(**/.env.*) deny rules." >&2
    echo "If you need a specific value, ask the user for it. To list files, use ls or Glob." >&2
    exit 2
  fi
done

exit 0
