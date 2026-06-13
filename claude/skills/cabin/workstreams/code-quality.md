# Day 4: Code Quality

## Focus
Clean code (Robert C. Martin) — eliminate code smells, improve readability, reduce complexity.

## What to Fix

### Long Methods (>20 lines)
- Extract logical chunks into well-named helper functions
- Each function should do one thing at one level of abstraction
- Name the function after what it does, not how

### Data Clumps
- Same 3+ parameters passed together to multiple functions
- Extract into a value object / interface / struct
- Example: `(firstName, lastName, email)` → `ContactInfo`

### Feature Envy
- Method uses another module's data more than its own
- Move the method to the class/module whose data it uses

### Primitive Obsession
- Strings/numbers representing domain concepts (user IDs as plain strings, money as numbers)
- Introduce value objects or branded types where it matters

### Boolean Parameters
- Functions with boolean params that change behavior → split into two functions or use Strategy pattern
- `processOrder(order, true)` → `processExpressOrder(order)`

### Deep Nesting
- More than 3 levels of nesting → extract early returns (guard clauses) or helper functions
- Flatten `if/else` chains with early returns

### Magic Numbers/Strings
- Unexplained literal values → extract to named constants
- `if (status === 3)` → `if (status === STATUS_ACTIVE)`

## How to Make Changes

1. **Focus on the highest-impact smells** identified in the itinerary
2. **Preserve behavior** — this is refactoring, not feature work
3. **Run tests after each refactor** to catch regressions
4. **Small, incremental changes** — don't rewrite entire files at once
5. **Follow the project's existing style** — match naming conventions, file organization

## Commit Message Format
```
cabin(day-4): [specific quality improvement]
```

Examples:
- `cabin(day-4): extract guard clauses and reduce nesting in sync logic`
- `cabin(day-4): introduce ContactInfo value object for repeated param groups`
