---
name: silent-change-audit
description: Audit recently merged PRs for behaviour changes that were NOT the headline of the PR that made them — flipped defaults, deleted fallbacks, newly-required env vars, routes gated off, destructive paths reachable from the UI, dropped CI guards, renamed analytics. Use after a batch of parallel-agent PRs, before a release cut, or when asked to "find the secret changes" / "what snuck in".
argument-hint: "[window start date, e.g. 2026-07-22] [optional: repo path]"
---

# Silent-change audit

Find what changed that nobody meant to announce.

## Why this exists

A PR gets reviewed for the thing it says it does. The risk is what it does _incidentally_: a constant flipped, a `.catch()` fallback deleted, a config value that was optional becoming required, a route gated behind an env var, a colour rebranded inside a "refactor", a CI job quietly dropped. Nobody reviewed those, because they weren't the headline.

This is acute after batches of parallel-agent PRs, where no single human read the whole diff. On one 92-PR run of this audit, **three of the six production-breaking findings were incidental**, including the top one: the value the deploy checklist told you to set for `CORS_ORIGIN` had silently started rejecting every browser request.

**The question is not "is each PR correct?" It is "what is now true that wasn't, that no PR title mentions?"**

## This skill stands alone

It requires no other skill and no state outside the repo it is run against. Everything it
reads and everything it writes lives in that repo, under `docs/audits/`. If the repo has
never been audited, there is simply no prior baseline and Step 3.5 is skipped; the run is
otherwise identical.

Keeping the baselines in the audited repo is deliberate. They carry `file:line` anchors
into that codebase, so they belong under its access control, not in a dotfiles repo. It
also means a cloud agent working from a plain checkout can read them, which one working
from `~/.claude/` cannot.

## Step 0 — Setup and baseline

```bash
git log --oneline -1                    # record this sha; the report is pinned to it
git worktree list                       # who else is mid-flight — do not write their files
gh pr list --state merged --limit 200 --json number,mergedAt,title \
  --jq '.[] | select(.mergedAt >= "<WINDOW_START>") | "\(.number)\t\(.mergedAt[0:10])\t\(.title)"'
gh pr list --state open --limit 50 --json number,title,createdAt
git diff --shortstat <base>..HEAD       # base = last commit before the window
```

`WINDOW_START` comes from `$ARGUMENTS`, or defaults to 7 days back. You may take it from the **filename** of the newest file in this repo's `docs/audits/` (`ls`, not `cat`) — a date is not a finding. Do not open the file.

**Work in a worktree** (EnterWorktree) if other agents are active in the repo. Note that open PRs are in scope: on the last run, the worst pagination regression was in an _unmerged_ branch.

### Do NOT read the previous baseline yet

**This is the most important rule in this skill, and it is easy to violate by accident.**

This repo's `docs/audits/` holds a dated file per prior run. **Do not open it, and do not put it in any subagent's context, until your own findings are written.** Reconciliation is Step 3.5, after discovery.

The reason is anchoring. Hand an agent a list of sixteen prior findings and it goes looking for those sixteen and stops. Agents are agreeable: given a claim, they find a way to confirm it. A finding that was fixed three weeks ago gets re-confirmed as "still open" because nobody re-derived it, and a stale claim becomes a zombie truth that survives every subsequent run. Worse, the whole point of this audit is to find what is _new and unannounced_, and a prior list steers directly away from novelty.

A blind sweep that independently rediscovers a prior finding is real corroboration. A sweep that was handed the finding first proves nothing.

### What you SHOULD read first

Settled facts, not prior findings. The two carry opposite risk:

- **Prior findings** are positive claims about defects. They anchor. Read them _after_ (Step 3.5).
- **Settled facts** are negative results — "we proved X is not broken, stop looking." These cannot create a false positive; they can only prevent a false lead. Read them _before_.

So do read: a "do not re-litigate" or "things that are settled" section in a plan doc, an ADR index, `CLAUDE.md`, investigation write-ups that closed with "not a bug". Typically that is the settled section of the active `docs/plans/` file, which records things like _`updated_at` was never broken, a trigger maintains it_ and _expo-sqlite cannot run in Node_. Each of those cost real time to establish once.

If you cannot tell which kind a document is, treat it as a prior finding and read it later.

## Step 1 — Dispatch the sweeps

If the window is under ~20 PRs, do this inline. Above that, dispatch **four Explore agents in one message**. They must not overlap or they burn tokens twice and still miss ground. Budget note: a four-agent fan-out ran ~460k subagent tokens on a 92-PR window.

Agents A-C are domain sweeps — adapt them to what the project actually is. Agent D is the one that finds the surprises and runs on every project.

**Agent A — the riskiest subsystem.** Whatever the project's most bug-prone area is (offline sync, a job queue, a payment path, a migration runner). Read the real source, not just names. Constants and their values; what happens at each limit; whether retry/backoff exists _and whether the caller actually opts into it_; error classification per status code; growth caps; timeouts.

**Agent B — pagination and payload bounds.** Every list endpoint: does it page, does it cap. Then the client: does it consume the pager. Then pickaxe the window for removals:

```bash
git log --since=<W> -S"offset" -S"pageSize" -S"pagination" --oneline
```

Check bulk/export/sync endpoints for a missing `LIMIT`.

**Agent C — degraded-mode survival.** What happens with the backend down, the network gone, the token expired, the cursor stale? Does anything fail _closed_ that should fail open? Does local state grow unbounded?

**Agent D — the silent-change ledger.** The core of this skill. Sweep for:

| Hunt for                  | How                                                                                                                                                      |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Changed constants         | `git log -p --since=<W> -- <constants dirs>`; grep window diffs for `const [A-Z_]+ =`                                                                    |
| Deleted fallbacks         | grep diffs for removed `.catch(`, `?? default`, `\|\| default`, `try/except` — a deleted fallback turns a tolerated input into a hard error              |
| Newly gated routes        | env-var checks, `isLocalMode`-style predicates, allow-lists — anything that now 404s/403s where it worked                                                |
| Tightened validation      | new regex validators, ownership checks, soft-delete guards, rate limiters applied to new paths                                                           |
| Env-var contracts         | any config now **required** that was optional. **Cross-check the deploy docs and TODOs — the PR that changed the behaviour almost never updates them**   |
| Data that changes meaning | migrations rewriting existing rows in place, timezone/boundary changes, new NOT NULL, soft-delete conversions, DB pragma/mode changes                    |
| Destructive paths         | `DELETE FROM`, `clear*`, `wipe`, `reset`, `sweep`, `truncate` — and specifically whether any is reachable from **user-facing UI** rather than a dev menu |
| Copy and colour           | hex values, brand tokens, spacing/size constants, notification and empty-state strings                                                                   |
| CI guard rails            | workflow and CI-script diffs: what stopped running, and was it re-wired into a local hook instead                                                        |
| Analytics                 | renamed or dropped event names and properties, new size caps, new silent-drop paths                                                                      |
| Deleted tests             | for each removed test, find its replacement. No replacement = that behaviour is now uncovered                                                            |

Every finding must carry: **PR number, `file:line`, what changed, and who notices** — end user, operator, or developer. Rank by "most likely to be an unwelcome surprise".

Tell agent D explicitly: **do not report the advertised headline of each PR. Report the incidental changes.** Without that line it summarises PR bodies, which is not this job.

## Step 2 — Verify before you believe

**Do not relay a subagent finding you have not opened yourself.** On the last run the agents were right on substance but wrong on details, and one finding was materially _worse_ than reported once read first-hand. Open every top-ranked claim, read the surrounding code, quote it.

Two traps that have already cost time here:

- **Shell `cd` does not persist between tool calls, and the main checkout may be on a different branch than `main`.** A finding briefly appeared to have vanished because the file being read was a refactored copy on another branch. Confirm `git log --oneline -1` in the directory you are actually reading.
- **A test can pass against the very bug it exists to catch.** If you propose a guard, re-run it against the _unfixed_ code and state how many failed. Copy the file aside with `cp`, never `git checkout --`, which has destroyed uncommitted work here.

## Step 3 — Ask, then write

Use `AskUserQuestion` for the decisions that change what gets built, not for approval. On the last run those were: what replaces a queue's age cap, how much scope to take, and what to do with an offending open PR.

Report structure:

1. **Context** — window, PR count, diffstat, what is in flight (open PRs, live worktrees, running reviews).
2. **Findings ranked by severity** — each with `file:line` and a concrete failure scenario, not an abstraction.
3. **What is actually solid** — say this explicitly. It is as useful as the defects and stops the next run re-investigating it.
4. **Scope boundaries** — what you deliberately did not cover.
5. **Plan** — P0/P1/P2, each item naming the file and the test that proves it.

Write sections 1-5 **before** opening any prior baseline. Freeze them. Reconciliation is the next step and it must not be able to edit them.

## Step 3.5 — Now reconcile against the prior baseline

Only now open the newest file in this repo's `docs/audits/`. If there is none, this is the first audit of this repo: say so in one line and skip to Step 4. Otherwise your own findings already exist and are frozen; this step adds a section, it does not revise the ones above.

Classify every prior finding into exactly one of four buckets:

| Bucket           | Meaning                                                                                         | What to do                                                                                                                                                                       |
| ---------------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Corroborated** | Your blind sweep found it independently                                                         | Strongest possible signal. Say so — this is real, and it is still there.                                                                                                         |
| **Fixed**        | Not in your sweep; you verify at `file:line` that it is genuinely resolved                      | Cite the PR that fixed it.                                                                                                                                                       |
| **Missed**       | Not in your sweep, but still true when you go look                                              | Your sweep has a blind spot. **Say which sweep should have caught it and why it did not.** This is the most valuable output of the whole step, because it improves the next run. |
| **Stale**        | The claim no longer parses — the code was restructured, the file is gone, the premise was wrong | Retire it explicitly. Do not carry it forward as "open" by default.                                                                                                              |

The default must not be "still open". A finding survives to the new baseline only if you re-verified it in this run. **An unverified carry-forward is how a fixed defect stays on the books for a month.**

If a prior finding turns out to have been wrong when written, say that plainly and record it as a settled negative result, so a future run reads it in Step 0 and does not chase it again.

## Step 4 — Save the new baseline

Write the findings to **`docs/audits/<YYYY-MM-DD>.md` in the repo you audited**, pinned to the sha you recorded in step 0, opening with a checklist table (`#`, finding, `file:line` anchor, blank status column) so the next run can tick through it fast. Branch and open a PR; never commit to the default branch.

If a same-dated file already exists, suffix it (`<YYYY-MM-DD>-b.md`). Never overwrite an older baseline.

If `docs/audits/README.md` does not exist, create it in the same PR with this much and no more:

> One file per audit run, `<YYYY-MM-DD>.md`, written by the `silent-change-audit` skill.
> **Do not read these at the start of an audit.** Discovery happens blind: sweep, write
> your findings, freeze them, and only then open the newest file to reconcile. Handing an
> auditor a list of prior findings makes it confirm those and stop looking for what is new.

**Keep findings out of this SKILL.md.** It loads into context on every invocation; baselines are data and they go stale.

## Ground rules

- Absolute dates only, never "last week" or a weekday name.
- Never commit to the default branch; branch + PR even for docs.
- **A fresh git worktree has no Husky hooks** (`.husky/_/` is gitignored) — run the package manager's install inside it or the pre-push suite silently does not run. This shipped 15 failing tests to a repo here once.
- Report what you could not verify as explicitly as what you could.
