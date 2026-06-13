# Day 8: Documentation

## Focus
README, inline docs, API docs, JSDoc/docstrings on public interfaces — make the codebase approachable.

## What to Check and Fix

### README
- Does it exist and is it complete?
- Quick start instructions (clone, install, run)
- Architecture overview
- Contributing guidelines
- Required environment setup

### Public Interface Documentation
- Exported functions/classes/types that other modules import → need JSDoc/docstrings
- Focus on non-obvious parameters, return values, side effects, and thrown errors
- Do NOT add docs to private/internal functions unless they're complex

### API Documentation
- Are API endpoints documented? (OpenAPI/Swagger, markdown, or inline)
- Request/response schemas, auth requirements, error codes
- If no formal API docs exist, add a concise markdown reference

### Complex Logic
- Algorithms, business rules, or workarounds that aren't self-evident
- Add inline comments explaining WHY, not WHAT
- Link to issues/tickets/investigations if they exist

### What NOT to Document
- Self-explanatory code (don't add `// increment counter` above `counter++`)
- Framework boilerplate
- Private helper functions with clear names
- Anything that would go stale quickly without a maintenance plan

## How to Make Changes

1. **README first** — it's the front door of the project
2. **Public interfaces second** — what other developers will import
3. **API docs third** — what consumers need to know
4. **Inline comments last** — only where logic is genuinely complex
5. **Match the project's existing documentation style**
6. **Do not create separate documentation files** unless the project already has a `docs/` convention

## Commit Message Format
```
cabin(day-8): [documentation improvement summary]
```

Examples:
- `cabin(day-8): add JSDoc to exported service interfaces`
- `cabin(day-8): document API endpoints and error codes`
