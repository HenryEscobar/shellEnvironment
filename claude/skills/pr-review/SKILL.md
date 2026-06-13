---
name: pr-review
description: Multi-lens pull request review covering code quality, security, testing, and performance.
disable-model-invocation: true
argument-hint: "[PR number or branch name]"
context: fork
---

# PR Review: $ARGUMENTS

Review this pull request through four lenses. For each lens, be specific — cite file paths and line numbers.

## 1. Code Quality
- SOLID violations, code smells, duplication
- Naming clarity, method length, class cohesion
- Are existing utilities/patterns being reused?
- DRY — is shared logic extracted?

## 2. Security
- Input validation on external boundaries
- Secrets or credentials exposed
- Injection risks (SQL, command, XSS)
- Auth/authz checks present where needed

## 3. Testing
- Are new code paths tested?
- Do tests verify behavior, not implementation?
- Edge cases and error paths covered?
- Test names describe the behavior being verified?

## 4. Performance
- N+1 queries or unnecessary DB calls
- Unbounded collections or missing pagination
- Blocking calls in async paths
- Cache implications

## Output Format
For each finding:
- **File:line** — what the issue is
- **Severity:** Critical / Warning / Suggestion
- **Fix:** specific recommendation

End with a summary verdict: Approve, Approve with nits, or Request Changes.
