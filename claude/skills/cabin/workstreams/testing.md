# Day 3: Testing

## Focus
Close coverage gaps by writing new tests for under-tested code. Target the project's stated coverage threshold (check CLAUDE.md) or 80% if none specified.

## What to Do

### Identify Gaps
- Use the coverage data from the itinerary
- Prioritize: business logic > API handlers > utilities > UI components
- Focus on files with 0% coverage first, then low coverage

### Write Meaningful Tests
- **Test behavior, not implementation** — assert on outcomes, not method calls
- **Behavior-driven names** — `should return 404 when contact not found`, not `test getContact`
- **Cover happy path + error paths** — success, validation errors, not-found, unauthorized
- **Use the project's existing test patterns** — match style, helpers, and conventions already in the codebase

### Test Quality Rules
- No snapshot tests unless the project already uses them
- Mocks only for external dependencies (HTTP, database, third-party APIs), not internal modules
- Tests should survive implementation changes (don't assert on internal state)
- Each test should be independent — no shared mutable state between tests

### What NOT to Test
- Framework code (Express routing, React rendering)
- Trivial getters/setters
- Third-party library behavior
- Type definitions

## How to Make Changes

1. **Read existing test files first** — understand the project's test conventions
2. **Create test files alongside source files** following the project's naming convention (`.test.ts`, `.spec.ts`, `_test.go`, etc.)
3. **Run the full test suite** after writing all tests — everything must pass
4. **Run coverage** to verify improvement
5. **Include before/after coverage numbers** in the PR description

## Commit Message Format
```
cabin(day-3): [what was tested]
```

Examples:
- `cabin(day-3): add tests for contact and category services`
- `cabin(day-3): cover error paths in auth middleware`
