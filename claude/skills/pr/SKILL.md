---
name: pr
description: Create a pull request for the current branch using the standard format
disable-model-invocation: true
argument-hint: "[optional: PR title or focus area]"
context: fork
agent: pr
---

## Current State

- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Commits vs main: !`git log main..HEAD --oneline`

Create a pull request for the current branch.

Steps:

1. Run `git diff main...HEAD` for all changes and `git log main..HEAD --oneline` for history.
2. Draft a PR title (under 70 chars) and a body in the format below, derived from the actual changes.
3. Push the branch if it isn't on the remote yet.
4. Create the PR with `gh pr create`.

If `$ARGUMENTS` is provided, use it as the PR title or focus area.

Use this PR body format:

```markdown
## Problem

Clear explanation of the issue being solved.

## Solution

Overview of the approach taken.

## Implementation Details

- Bullet points of the specific changes made

## Testing Done

How the changes were tested.

## Related Information

Links to relevant tickets, discussions, etc.

## Reviewer Notes

Anything specific reviewers should know.
```

Do not include AI attribution or "Generated with" lines in the PR description.
