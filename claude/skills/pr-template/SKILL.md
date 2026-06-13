---
name: pr-template
description: Create a pull request with the team's standard format
disable-model-invocation: true
argument-hint: "[optional: PR title or focus area]"
---

Create a pull request for the current branch. Use this format:

```markdown
# PR Description: [Title]

## Problem
Clear explanation of the issue being solved

## Solution
Overview of the approach taken

## Implementation Details
- Bullet points of specific changes made

## Testing Done
Details on how the changes were tested

## Related Information
Links to relevant tickets, discussions, etc.

## Reviewer Notes
Any specific information for reviewers
```

Steps:
1. Run `git diff main...HEAD` to see all changes on this branch
2. Run `git log main..HEAD --oneline` for commit history
3. Draft the PR title and body from the actual changes
4. Push the branch and create the PR with `gh pr create`

If `$ARGUMENTS` is provided, use it as the PR title or focus area.
