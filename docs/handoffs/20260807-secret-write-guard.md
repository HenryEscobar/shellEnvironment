# Handoff: close the Bash write path around the secret denies

**Date:** 2026-08-07
**Status:** Done. Written and tested 2026-08-07; synced and merged to `main` in PR #12 on 2026-08-09.
**Repos touched:** `~/irad/shellEnvironment` (this repo, tracks `claude/`), `~/.claude` (live config)

This document is self-contained. You do not need the session that produced it.

---

## 1. Outstanding work

None. Kept below as the record of what was carried out.

1. Branched off `main` as `fix/secret-write-guard`.
2. `claude/hooks/block-destructive-bash.sh` synced from `~/.claude/hooks/`; `diff` clean.
3. The section 5 harness was committed as `claude/hooks/tests/block-destructive-bash.test.sh`,
   with one change from the version printed there: `HOOK` now resolves as a sibling of the
   script's parent directory instead of hardcoding `$HOME/.claude/hooks/`, so the repo copy
   tests the repo hook and the copy `INSTALL.sh` installs tests the live hook. Argument 1
   overrides.
4. Re-run on 2026-08-07 against the repo copy: 30/30 pass. Output pasted in the PR body.
5. PR #12 opened and merged on 2026-08-09.

`claude/settings.json` needed no action: it was verified byte-identical to `~/.claude/settings.json`
before the PR was opened. The four inert deny rules (section 3) were removed in PR #8.

---

## 2. Background: what prompted this

On startup, Claude Code printed four warnings against `~/.claude/settings.json`:

```
Permission deny rule: Write(**/.env) is not matched by file permission checks
  - only Edit(path) rules are. Use Edit(**/.env) instead
  (Edit rules cover all file-editing tools).
```

Same for `Write(**/.env.*)`, `Write(./secrets/**)`, `Write(./**/credentials*)`.

Fixing them exposed a genuine hole, described in section 4.

---

## 3. Change 1: `claude/settings.json` (done, verify only)

Four deny rules were removed:

```
- "Write(**/.env)"        - "Write(./secrets/**)"
- "Write(**/.env.*)"      - "Write(./**/credentials*)"
```

Every one had an `Edit(...)` twin two lines below it that was already present and already
enforcing. `Edit(path)` is the file-write rule namespace and covers Write, Edit, and
NotebookEdit. Net protection is unchanged. The JSON validates, and no other settings file
(project or local) contained `Write(...)` rules.

These four rules were introduced in `737341c`, the initial tracking commit, and were never
evaluated by the harness at any point in their life.

---

## 4. Change 2: `claude/hooks/block-destructive-bash.sh` (the actual fix, needs syncing)

### Problem

Permission rules and the `block-protected-paths.sh` hook both bind **tools**. Bash is a
different tool, so every one of these reached the filesystem untouched:

```bash
echo "STRIPE_KEY=sk_live_..." > backend/.env     # passed all deny rules and both hooks
tee backend/.env <<< "KEY=v"
cp /tmp/x backend/.env
mv /tmp/x .env.production
dd if=/dev/zero of=~/.ssh/id_rsa
printf x > secrets/service-account.json
ln -sf /tmp/fake backend/.env
cp backend/.env /tmp/leak                        # exfiltration direction
```

`sed -i ... .env` happened to be caught already, but only by accident: `sed` appears in the
`READERS` list of the pre-existing read block.

Commit `558ac02` (#6) closed the equivalent hole on the **read** side on 2026-07-28
(`cat backend/.env` and friends). The write side was left open. This change is its mirror.

### Fix

Appended to `block-destructive-bash.sh`, after the existing `SECRET_PATHS` loop and before
the final `exit 0`. It reuses `CMD_START` and `SCRUBBED`, both already defined in that file.

```bash
# Secret-file WRITES via the shell.
#
# The mirror image of the block above, added 2026-08-07. permissions.deny holds
# Edit(**/.env), Edit(./secrets/**), Edit(./**/credentials*), and
# block-protected-paths.sh guards the same paths -- but every one of those binds a
# file-editing TOOL. `echo "KEY=..." > backend/.env` is a Bash call and walked past
# all of them. So did tee, cp, mv, and dd. (sed -i was already caught, but only by
# accident: sed is in READERS above.)
#
# Append is deliberately NOT blocked. `>>` and `tee -a` are the spellings the
# standing rule "never use > on a file you cannot read, use >> or ASK" points at,
# so blocking them would contradict the rule this hook exists to enforce. Both
# spellings are neutralized before matching rather than special-cased in each
# pattern.
WRITERS="tee|cp|mv|install|dd|truncate|ln"

# Same .env clause as the read patterns, plus the two path families that only
# permissions.deny covered until now. `secrets/` and `credentials` are matched as
# bare substrings, so `mysecrets/` and `credentials.md` are caught too; that is the
# safe direction, consistent with block-protected-paths.sh.
SECRET_TARGET='(\.env([^a-zA-Z0-9_.-]|\.[a-zA-Z0-9_-]+|$)|\.ssh/|\.gnupg/|\.aws/credentials|\.npmrc|id_rsa|id_ed25519|secrets/|credentials)'

WRITE_SCRUBBED=$(echo "$SCRUBBED" | sed -E 's/>>/@APPEND@/g; s/(^|[|;&(`[:space:]])tee[[:space:]]+(-a|--append)([[:space:]]|$)/\1@APPEND@\3/g')

SECRET_WRITES=(
  # Truncating redirect: `> .env`, `>.env`, `>| .env`, `2> .env`. `>>` is gone by now.
  ">[|]?[^>|;&]*$SECRET_TARGET"
  # Writer commands. Also fires when a secret is the SOURCE (`cp backend/.env /tmp`),
  # which is copying a secret somewhere readable -- worth blocking either way.
  "$CMD_START($WRITERS)[^|;&]*$SECRET_TARGET"
)

for p in "${SECRET_WRITES[@]}"; do
  if echo "$WRITE_SCRUBBED" | grep -qE "$p"; then
    echo "Blocked: writing a secrets file through the shell bypasses the Edit(**/.env) deny rules." >&2
    echo "Ask the user to run it themselves with a leading ! in the prompt. Appending with >> or tee -a is allowed." >&2
    exit 2
  fi
done
```

### Design decisions worth preserving

- **Append is allowed on purpose.** `>>` and `tee -a` pass. The user's standing rule is
  "never use `>` (overwrite) on files you cannot read; use `>>` or ASK first", so blocking
  `>>` would contradict the rule the hook exists to enforce. Both spellings are neutralized
  in `WRITE_SCRUBBED` before matching rather than special-cased in each regex.
- **`secrets/` and `credentials` match as bare substrings.** `mysecrets/` and
  `credentials.md` are caught too. Over-blocking is the safe direction and is consistent
  with the sibling hook `block-protected-paths.sh`, which documents the same choice.
- **Secret-as-source is blocked too.** `cp backend/.env /tmp/leak` fires. That is copying a
  secret somewhere readable, worth blocking in either direction.
- **`rm` was deliberately left out** of `WRITERS`. Deleting a `.env` is destructive, but
  adding `rm` risks blocking legitimate cleanup, and the scope approved was writes. Add it
  if you want, but say so explicitly in the PR.

### Known behavior change to flag in the PR

`cp backend/ENV_TEMPLATE.txt backend/.env` is now blocked. That is the documented first-run
setup step in the `relationship-crm` CLAUDE.md. The user runs it themselves by typing
`! cp backend/ENV_TEMPLATE.txt backend/.env` in the prompt. Carve it out only if asked.

---

## 5. Test harness and results

Written to a session scratchpad, so copy it into the repo if you want it kept. Note that the
test payloads cannot be typed directly into a Bash tool call, because the hook under test
blocks its own test strings. They must live in a file.

```bash
#!/usr/bin/env bash
# Pipe-test block-destructive-bash.sh with the real PreToolUse stdin shape.
HOOK="$HOME/.claude/hooks/block-destructive-bash.sh"
fail=0

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
```

Result on 2026-08-07: **30/30 pass.** 14 write vectors blocked, 10 ordinary commands allowed,
6 regression cases confirming the read blocks from #6 and the destructive patterns still fire.

---

## 6. A review claim about this work, and why it is wrong

A code review of PR #8 in this repo raised the following about the `settings.json` change.
All three parts are wrong. Recorded here so it is not re-litigated.

> The second one loosens the security posture [...] The matching `Edit(...)` denies survived,
> but they don't cover the same ground: Edit needs an existing file that was read first,
> while Write creates or clobbers wholesale. Combined with `"defaultMode": "acceptEdits"`, an
> agent can now overwrite a `.env` or drop a file into `./secrets/` with no prompt. That's
> also a partial undo of what `558ac02` (#6) set out to close.

**Claim A: `Edit(...)` does not cover Write, because the Edit tool needs a prior Read.**
False. This conflates the Edit _tool_ with the `Edit(...)` _permission-rule namespace_. The
read-before-edit precondition belongs to the tool. The rule namespace is the file-write
namespace and covers all file-editing tools. Three independent confirmations:

1. The harness states it directly in its own startup warning, quoted in section 2:
   "Edit rules cover all file-editing tools."
2. `~/docs/vendor/claude-code/15-permissions.md` titles its path-pattern table
   "Read/Edit patterns (gitignore spec)". There is no `Write()` path namespace to match on.
3. Empirical, run on 2026-08-07. The **Write** tool was aimed at
   `~/irad/relationship-crm/secrets/probe.txt`, a path matching `Edit(./secrets/**)` but
   matching none of `block-protected-paths.sh`'s patterns (`.env`, `.git/`, `id_rsa`,
   `id_ed25519`, `.pem`), so the deny rule is the only thing that could answer. Result:
   `File is in a directory that is denied by your permission settings.` Nothing was created.

**Claim B: it loosens the posture under `acceptEdits`.** False. The removed rules were never
evaluated, which is exactly why the harness printed a warning about each one on every
startup. Removing four unevaluated strings cannot loosen anything. A Write to `.env` still
hits the `Edit(**/.env)` deny and then `block-protected-paths.sh`, which exits 2 and cannot
be overridden per-project.

**Claim C: partial undo of `558ac02` (#6).** False, and backwards. The entire
`claude/settings.json` diff in `558ac02` is one line adding `skill-creator` to
`enabledPlugins`. It never touched the deny array. Its security work was the +26 line shell
read-block in `block-destructive-bash.sh`, which PR #8 does not touch. Verify with:

```bash
git show 558ac02 -- claude/settings.json
git log --oneline -S'"Write(**/.env)"' -- claude/settings.json
```

**What the review was circling but did not name.** There was a real hole, in Bash rather than
in the Write tool. That is the subject of section 4, and it is now closed.

---

## 7. Lessons

- A permission rule namespace is not the tool of the same name. `Edit(path)` governs every
  file-editing tool; the Edit tool's read-first precondition is unrelated to rule matching.
- Deny rules bind tools, not effects. Any protection expressed only as `Read(...)` or
  `Edit(...)` has a Bash-shaped hole next to it. #6 found this on the read side on
  2026-07-28; the write side survived another ten days.
- When a hook blocks a pattern, its own test cases cannot be typed into a shell tool call.
  Put them in a file.
- The harness's startup warnings are evidence about harness behavior. The four warnings here
  said in plain text that the rules were inert, and a review still read their removal as a
  security regression.
