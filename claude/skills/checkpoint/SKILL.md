---
name: checkpoint
description: Write a self-contained, execute-able checkpoint plan capturing the current state of work, so a fresh session can pick it up with `read and execute <file>` after a /clear.
disable-model-invocation: true
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

## Step 5: Repoint the entry point

Update the project's task file (`TODO.md` or equivalent) so its "start here"
pointer names the new checkpoint and the exact phrase to say. Put the single most
important warning from the checkpoint inline there too, since that file is read
more often than the plan is.

Update `SUMMARY.md` (or equivalent session-context file) if the project has one.

## Step 6: Branch, PR, and tell the user how to resume

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
