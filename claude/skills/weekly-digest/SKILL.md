---
name: weekly-digest
description: Summarize what changed in a repo over a date range, organized by consequence rather than by PR — what users see differently, what operators must do, what is now unverified, which work was off-plan, and which decisions are waiting. Use for a weekly catch-up, a "what have you been doing" review, a stakeholder or CTO update, or before a planning session.
argument-hint: '[range: 7d | 30d | 2026-06-01 | 2026-06-01..2026-07-01 | "since last digest"] [optional: repo path]'
---

# Weekly digest

Answer one question: **where are we, and what do I need to decide?**

## Why this exists

The reader cannot keep up with the merge rate. They do not need to know what shipped; they need to know what is now _true_ that wasn't, and what that costs them.

PR titles describe intent. `refactor(ui): design tokens and one button` is intent. _The app is purple now_ is the consequence. A digest organized by PR is unreadable at 90 PRs a week. **Organize by consequence.**

This is not a defect hunt. A digest reports consequences; it does not go looking for defects.

## This skill stands alone

It requires no other skill and no state outside the repo it is run against. Everything it
reads and everything it writes lives in that repo.

One optional shortcut, not a dependency: if the repo happens to have `docs/audits/`, the
newest file there is a prior defect sweep. **Cite it rather than re-deriving those
findings** — the expensive work is already done. If the directory is absent, derive
section 3 from the diff as normal and say nothing about it. Never block, warn, or ask the
user to run an audit first.

## Resolving the range

From `$ARGUMENTS`:

| Argument                  | Means                                       |
| ------------------------- | ------------------------------------------- |
| _(empty)_                 | last 7 days                                 |
| `7d`, `14d`, `30d`, `90d` | that many days back from today              |
| `2026-06-01`              | that date to today                          |
| `2026-06-01..2026-07-01`  | explicit window                             |
| `since last digest`       | newest file in `docs/digests/`, else 7 days |

State the resolved window and both shas at the top of the digest. Use absolute dates everywhere, never "last week" or a weekday name.

**Scale the depth to the range.** A week is one pass. A month or more: sweep in parallel by area (backend / frontend / infra / docs) and merge, and expect to summarize themes rather than individual PRs — at that size the value is the arc, not the enumeration.

## Gather

```bash
git log --oneline -1
git log --since=<START> --until=<END> --oneline | wc -l
git diff --shortstat <base>..<head>
gh pr list --state merged --limit 300 --json number,mergedAt,title,author \
  --jq '.[] | select(.mergedAt >= "<START>" and .mergedAt <= "<END>") | "\(.number)\t\(.mergedAt[0:10])\t\(.title)"'
gh pr list --state open --limit 50 --json number,title,createdAt,isDraft
git log --since=<START> --name-only --format="" | sort | uniq -c | sort -rn | head -30
git worktree list
```

The file-churn ranking is the fastest read on where effort actually went — it routinely disagrees with what the PR titles emphasize, and that disagreement is itself worth reporting.

Then read the repo's own records: `TODO.md`, `PLAN.md`, `SUMMARY.md`, `docs/plans/`, recent `docs/investigations/`. These are what make section 4 possible.

## The five sections

Write these, in this order. Lead the whole document with anything that will break production.

**1. What a user sees or does differently.** Concrete and visual: copy, colour, layout, flows added or removed, notifications that changed in tone or frequency. If a change is visible and you could not see it rendered, say so.

**2. What an operator has to do differently.** New or newly-_required_ env vars, deploy steps, migrations, changed rate limits, routes now gated off, anything that will break on the next deploy but is fine today. Cross-check the deploy docs: the PR that changes a config contract almost never updates them.

**3. What is now unsafe or unverified.** Guards or CI jobs removed, tests deleted without replacement, code that shipped without device or production verification, known-broken things still open. Also: what was verified, and how — a real test count beats "green".

**4. What we worked on that wasn't planned.** Diff the actual work against `TODO.md` / `PLAN.md` / the active plan doc. Name each tangent, say what triggered it, and judge it: worth it, or drift? **This is the section the reader cannot get anywhere else** — every other section is derivable from the diff, this one needs the plan as context. Do not soften it. A tangent that produced a real fix is a good tangent; say that too.

**5. Decisions waiting on the reader.** Each with: what is blocked, what the options are, your recommendation, and what happens if they do nothing. Anything needing a human — a device pass, an account setting, a billing action, a product call — belongs here, not buried in prose.

## Rules

- **Cite `file:line` or a PR number for anything load-bearing.** A claim without an anchor is a rumour.
- **Say what you could not verify.** Explicitly, not by omission.
- **Do not editorialize about effort.** No "we made great progress". Report what is true and let it stand.
- **Lead with the worst thing.** If something will break production, it goes first, above the summary.
- Follow the repo's writing conventions from `CLAUDE.md` — for this user that means absolute dates and no em dashes.
- Length target: **a week fits on one screen** plus detail sections below it. If the top summary does not fit, you are enumerating instead of synthesizing.

## Output

Write to `docs/digests/<YYYY-MM-DD>.md` in the repo, on a branch, and open a PR. Never commit to the default branch.

If running headless (a scheduled agent, no interactive terminal), you cannot ask a clarifying question — make the call, and flag the assumption in the digest rather than blocking on it.

## Maintenance: there is a second copy of this

A cloud scheduled agent gets a checkout of the target repo and **cannot see `~/.claude/skills/`**, so a routine cannot invoke this skill by name. The instructions in this file are therefore duplicated, inlined, into the scheduled routine's prompt.

Note that the audit shortcut above works in the scheduled run too, because `docs/audits/` is in the checkout. Nothing this skill reads lives outside the repo.

**If you edit the five sections or the rules here, update the routine too**, or the Monday run silently keeps using the old version:

**Which routine, and its id, are recorded in `routines.local.md` next to this file.** That
file is gitignored: it names a private repo and carries a trigger id, neither of which
belongs in a public dotfiles repo. If it is missing on this machine, list the routines
with `CronList` and re-create it.

|          |                                                                                                    |
| -------- | -------------------------------------------------------------------------------------------------- |
| Schedule | `13 12 * * 1` UTC = Mondays 8:13am America/New_York                                                |
| Manage   | `https://claude.ai/code/routines/<trigger-id from routines.local.md>`                              |
| Update   | `RemoteTrigger` with `action: "update"`, replacing `job_config.ccr.events[0].data.message.content` |

The routine is pinned to a 7-day range. For a deeper range, run this skill locally with an argument instead — the scheduled copy is not the place to do a quarterly review.

If this duplication ever becomes a problem, the fix is to move the skill into the target repo at `.claude/skills/weekly-digest/`, where the cloud checkout can read it, and have the routine prompt say only "run the weekly-digest skill".
