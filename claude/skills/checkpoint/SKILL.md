---
name: checkpoint
description: Write a self-contained, execute-able checkpoint plan capturing the current state of work, so a fresh session can pick it up with `read and execute <file>` after a /clear.
argument-hint: "<optional short name for the checkpoint, e.g. 'after the sync refactor'>"
---

Write a checkpoint for: **$ARGUMENTS**

A checkpoint is the handoff document between a context window that is full and one
that is empty. It gets read cold, by someone with no memory of this session. Its
whole job is to make the next session as effective as this one was, without the
transcript.

## The one rule everything else serves

**The reader must never need to open another document.** If a finding, plan or
investigation matters, restate the relevant part here in a sentence or two. Link
to the source as a citation for someone who wants more, never as a substitute for
the explanation. "See the audit" is a failure.

## Step 1: Measure the state, do not recall it

Run these. Do not write numbers from memory; a wrong test count in a checkpoint
gets trusted and wastes an hour later.

```bash
git rev-parse --short HEAD && git log --oneline -5
git status --short
gh pr list --state open --json number,title,baseRefName,headRefName \
  --jq '.[] | "#\(.number) \(.headRefName) -> \(.baseRefName) :: \(.title)"'
```

Then run the actual test suites and record what they print. If a suite cannot be
run, say so in the checkpoint rather than omitting it.

## Step 2: Pick the path

```bash
DATE=$(date +%Y%m%d)
# Slug from $ARGUMENTS, or a short description of where the work stands.
FILE="docs/plans/${DATE}-<slug>.md"
```

If a prior checkpoint exists in `docs/plans/`, the new one **supersedes** it: say
so at the top of the new file, and leave the old file in place so existing links
still resolve.

## Step 3: Write it

Use this structure. Skip a section only if it is genuinely empty.

```markdown
# Remaining Work (Execute) — <what this checkpoint follows>

**Written:** YYYY-MM-DD
**Baseline:** `main` at `<sha>`
**Supersedes:** <prior checkpoint, if any>
**How to run this:** say `read and execute <path>`, optionally naming a batch.

This file is self-contained.

## Where things stand

<Measured test counts. What merged, as a table of PR number to one-line summary.
Anything open and untriaged.>

## Things that are settled. Do not re-litigate or re-verify

<Every fact that cost real time to establish, with the evidence compressed to a
sentence. Include things that turned out to be FALSE, stated as flatly as the
true ones. This section is the highest-value part of the document: it is what
stops the next session re-deriving what this one already paid for.>

## Lessons that changed how work gets verified here

<Only if something about the process was wrong, not just the code. A guard that
passed against its own target, a harness that diverged from production, a
verification step that gave false confidence. State the rule that follows.>

## Ground rules

<Branch and PR conventions, what CI can and cannot run right now, merge
constraints, project behavioural rules, writing conventions. Restate them; do not
link to them.>

## Blocking items that need a human

<Anything that cannot be done by an agent: device passes, production checks,
credentials, approvals. Say why each one blocks.>

## <Batch ID>. <Name>

<One section per batch. Each states: why it exists, the concrete evidence
(file:line, measured number, reproduction), what to do, and the PR name to use.
If a batch changed since the last checkpoint, say what changed and why, not just
its status.>

## Known bugs still open

## Ops follow-ups (not code)

## Suggested order

<A fenced block ordering the batches, with inline warnings on the dangerous ones.>
```

## Step 4: Quality bar before you commit

Check each of these against what you wrote:

- **Would a stranger know what to do next?** Not "R5 foreign keys" but why, what
  breaks, and in which order the steps must happen.
- **Did you record what turned out to be wrong?** A checkpoint that only lists
  successes will send the next session down a path this one already closed.
- **Are the dangerous batches marked as dangerous, inline?** If a step destroys
  data unless it is done in a particular order, that warning belongs in the
  suggested-order block too, not only in the batch section.
- **Did you measure, or assume?** Every number should trace to a command you ran.
- **Is anything load-bearing only in your head?** That is the thing most worth
  writing down.
- **Does any source-of-truth document now contradict the checkpoint?** Every
  tracker a project keeps is a file that can disagree with the new plan. The next
  session will trust whichever it opens first, so leaving one behind silently
  sends it down a closed path. **The cheapest fix is to have fewer of them: see
  Step 5.**

## Step 5: Repoint the entry point, and keep it to two files

**Aim for exactly two live trackers.** Everything else is either a pointer or an
archive. More than two and they drift, because nothing keeps them in step except
remembering to; the tell is that they all change in the same commit.

The two that earn their place:

1. **A durable backlog** (`TODO.md` or equivalent) — open tasks, known bugs, and
   the traps worth carrying between sessions. Long-lived, edited in place.
2. **The dated checkpoint you just wrote** (`docs/plans/<DATESTAMP>-<slug>.md`) —
   the executable "what to do next". Never overwritten; a new session writes a
   new one and the old ones stay as a record.

Update the backlog so its "start here" pointer names the new checkpoint and the
exact phrase to say. Put the single most important warning from the checkpoint
inline there too, since that file is read more often than the plan is.

**Any other tracker the project keeps should be shrunk, not maintained.**

- **A session-context file** (`SUMMARY.md` or equivalent) should be a pointer of
  a few lines: the current checkpoint's path, the resume phrase, and nothing
  that also exists elsewhere. The moment it carries content of its own it is a
  third thing to keep in step. If it has grown, cut it back rather than updating
  it.
- **A feature-plan file** (`PLAN.md` or equivalent) should keep only what is
  genuinely durable and lives nowhere else: the product direction, the bets, the
  reasoning behind them. Implementation detail belongs in the checkpoint. This
  file is the easiest to leave stale, because unlike the others it is not
  obviously about "right now", and a stale plan is worse than no plan: it is read
  as current and acted on.

When you shrink one, **say in it what it is now for and where the rest went**, so
the next reader does not go looking for the missing sections or paste them back.
Move nothing to the archive that only exists in one place; a trimmed file should
lose duplication, never the only copy of a decision.

If a trimmed file and the checkpoint disagree about what remains, that
disagreement is the finding. Resolve it against the code, not by picking
whichever document reads more confidently.

**If the project's `CLAUDE.md` names the trackers, update it in the same PR.**
An instruction file that still declares three sources of truth will have the next
session recreate the third.

## Step 6: Refresh the durable memory, which is read BEFORE the checkpoint

The checkpoint is opened when someone asks for it. **The memory directory is
loaded automatically, every session, before anything else.** So a stale fact
there outranks a correct one in the checkpoint: the next session acts on the
memory first and only discovers the contradiction later, if at all. A checkpoint
that leaves the memory stale has not finished the job.

Update `<memory dir>/MEMORY.md` so that at minimum these agree with what you
measured in Step 1:

- **The current `main` sha**, and the newest checkpoint's path with the resume
  phrase.
- **What production actually runs**, and how far behind it is. If a migration is
  merged but unapplied, say so in the memory too, not only in the checkpoint:
  that is the fact most likely to cause damage when acted on blind.
- **Anything measured this session that contradicts a line already there.** Fix
  the line; do not append a second, newer claim beside it. Two contradicting
  bullets is worse than one stale one, because now the reader has to adjudicate.

Then consider whether the session produced anything that belongs in memory as
its own file, rather than in the checkpoint:

- **A checkpoint is superseded; a memory file is not.** Anything true beyond this
  batch of work belongs in memory. A trap that will still be a trap in three
  months, a decision about how work gets verified, a fact about the environment.
- **`type: feedback`** for anything about how to WORK (a verification step that
  gives false confidence, a tool that lies about its own status). These are the
  ones most often left in the transcript and lost.
- **`type: project`** for a constraint or goal not derivable from the code.
- Update an existing file rather than adding a near-duplicate, and delete one
  that has turned out to be wrong.

🔴 **Another agent may be editing the same memory concurrently.** Check whether
lines you did not write have appeared since you last looked, and make targeted
replacements rather than rewriting the file wholesale.

Finally, rescue anything load-bearing that currently exists only in a scratchpad
or a temp directory. Those are session-scoped and will be gone. If a draft,
a measurement or a working document will be needed by the next session, move it
into the repo (or into memory) and cite it from the checkpoint. **A checkpoint
that says "the draft must be rewritten" when the draft still exists on disk has
thrown away real work.**

## Step 7: Branch, PR, and tell the user how to resume

Docs-only change, so branch (`docs/` prefix), commit, and open a PR. Never commit
to the default branch.

Then tell the user, in one short block:

```
Checkpoint: <path>
Resume with: read and execute <path>
PR: <url>
```

## Notes

- Absolute dates only. No "tomorrow", no weekday names. A relative date in a
  document read three weeks later is worse than no date.
- If the session produced findings that belong in a durable reference (an
  architecture note, an investigation), write those to their own files and cite
  them from the checkpoint **with the relevant part restated inline**.
- A checkpoint is not a changelog. Git already has one. This is about what to do
  next and what not to redo.

## Maintenance

This skill's instructions are not duplicated anywhere. If a copy is ever made
(a cloud routine, a project-local override), record it here, or the copies drift
silently and only one of them gets fixed.
