# Day 1: Architecture

## Focus
Structural health — SRP violations, God Objects, dependency injection consistency, dead code, and duplication.

## What to Look For

### God Objects (>500 LOC)
- Files with too many responsibilities
- Classes/modules that "know about everything"
- Split into focused, single-responsibility modules

### SRP Violations
- Functions doing more than one thing (fetch + transform + render)
- Modules mixing concerns (data access in UI components, business logic in handlers)
- Extract into layers: handler → service → data access

### Dependency Injection Consistency
- Check if the project uses DI (factories, constructor injection, etc.)
- Find places where dependencies are created inline instead of injected
- Align with the project's existing DI pattern

### Dead Code
- Unused exports (exported but never imported anywhere)
- Commented-out code blocks
- Unreachable code paths
- Remove with confidence (git preserves history)

### Duplication
- Near-identical functions in different files
- Copy-pasted logic that should be a shared utility
- Extract to a common location following the project's conventions

## How to Make Changes

1. **Start with the highest-impact God Object** — split it first
2. **Extract, don't rewrite** — move code into new files, update imports, verify tests pass
3. **One refactor per commit** if changes are large, or batch small ones
4. **Run tests after each significant change**
5. **Do not change behavior** — this is pure refactoring. Inputs and outputs must stay the same.

## Commit Message Format
```
cabin(day-1): [specific refactor description]
```

Examples:
- `cabin(day-1): extract contact service from monolithic handler`
- `cabin(day-1): remove dead exports and unused utilities`
