#!/usr/bin/env bash
# Pipe-test block-destructive-bash.sh with the real PreToolUse stdin shape.
#
# Why this file exists at all: the hook under test blocks its own test payloads.
# `echo "KEY=v" > backend/.env` cannot be typed into a Bash tool call by an agent,
# because the hook intercepts the call before it runs. The cases have to live in a
# file that is read from disk. Do not inline them back into a command.
#
# The hook is resolved as a sibling of this script's parent directory, so this works
# unchanged from both locations the file is mirrored to: the repo copy tests
# claude/hooks/block-destructive-bash.sh, and the copy INSTALL.sh places at
# ~/.claude/hooks/tests/ tests the live hook. Override with argument 1.
#
# Usage: bash block-destructive-bash.test.sh [path-to-hook]
# Exit:  0 = all pass, 1 = at least one failure. Requires jq.

HOOK="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/block-destructive-bash.sh}"
fail=0

if [ ! -f "$HOOK" ]; then
  echo "hook not found: $HOOK" >&2
  exit 1
fi
echo "testing: $HOOK"
echo

run() { # run <BLOCK|ALLOW> <command>
  local expect="$1" cmd="$2" rc got
  jq -n --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}' | bash "$HOOK" >/dev/null 2>&1
  rc=$?
  got=ALLOW; [ "$rc" -eq 2 ] && got=BLOCK
  if [ "$got" = "$expect" ]; then
    printf 'ok    %-5s  %s\n' "$got" "$cmd"
  else
    printf 'FAIL  want=%s got=%s  %s\n' "$expect" "$got" "$cmd"; fail=1
  fi
}

echo "--- new: shell writes to secrets (want BLOCK) ---"
run BLOCK 'echo "KEY=v" > backend/.env'
run BLOCK 'printf x >backend/.env'
run BLOCK 'cat /tmp/x >| frontend/app/.env.local'
run BLOCK 'echo x 2> .env'
run BLOCK 'tee backend/.env <<< "KEY=v"'
run BLOCK 'cp /tmp/x backend/.env'
run BLOCK 'mv /tmp/x .env.production'
run BLOCK 'cp backend/ENV_TEMPLATE.txt backend/.env'
run BLOCK 'dd if=/dev/zero of=/Users/h/.ssh/id_rsa'
run BLOCK 'printf x > secrets/service-account.json'
run BLOCK 'cp foo credentials.json'
run BLOCK 'echo registry=x > ~/.npmrc'
run BLOCK 'ln -sf /tmp/fake backend/.env'
run BLOCK 'cp backend/.env /tmp/leak'

echo
echo "--- new: append carve-out + ordinary work (want ALLOW) ---"
run ALLOW 'echo "KEY=v" >> backend/.env'
run ALLOW 'tee -a backend/.env <<< "KEY=v"'
run ALLOW 'tee --append backend/.env'
run ALLOW 'pnpm test'
run ALLOW 'pnpm dev > /tmp/dev.log 2>&1'
run ALLOW 'echo hi > /tmp/out.txt'
run ALLOW 'git commit -m "update env docs"'
run ALLOW 'cp README.md /tmp/README.md'
run ALLOW 'cp .env.example .env.example.bak'
run ALLOW 'ls -la backend'

echo
echo "--- regression: pre-existing rules still fire ---"
run BLOCK 'cat backend/.env'
run BLOCK 'export $(cat .env | xargs)'
run BLOCK 'rm -rf /'
run BLOCK 'git push --force'
run ALLOW 'cat backend/.env.example'
run ALLOW 'cat README.md'

echo
[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit "$fail"
