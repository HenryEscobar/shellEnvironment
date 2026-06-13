# Day 6: Performance

## Focus
Identify and fix performance bottlenecks — database queries, memory leaks, blocking operations, bundle size.

## What to Fix

### N+1 Queries
- Loop that makes a DB call per iteration → batch query outside the loop
- `for (const id of ids) { await db.get(id) }` → `await db.getMany(ids)`
- Check ORM usage for lazy-loading traps

### Missing Database Indexes
- Columns used in WHERE, JOIN, ORDER BY clauses without indexes
- Check migration files for CREATE INDEX statements
- Add indexes for frequently-queried columns (but don't over-index)

### Unbounded Queries
- SELECT without LIMIT → add pagination
- API endpoints returning full tables → add limit/offset or cursor pagination
- Large result sets loaded into memory at once

### Blocking Async
- Synchronous operations in async contexts (sync file reads, CPU-heavy loops)
- `JSON.parse` on large payloads in request handlers
- Missing `await` on async operations (fire-and-forget bugs)

### Memory Leaks (Frontend)
- Event listeners not cleaned up in useEffect
- Intervals/timeouts not cleared on unmount
- Growing arrays/maps that never get pruned
- Subscriptions without unsubscribe

### Bundle Size (Frontend)
- Large imports that could be lazy-loaded: `import _ from 'lodash'` → `import groupBy from 'lodash/groupBy'`
- Conditional imports loaded eagerly
- Dev dependencies accidentally bundled

### Expensive Re-renders (React/React Native)
- Components re-rendering on every parent render — missing `memo`, `useMemo`, `useCallback`
- Only fix if the component is expensive (long lists, complex trees) — don't over-optimize

## How to Make Changes

1. **Fix N+1 queries first** — highest impact, usually straightforward
2. **Add missing indexes** — create migration files following project conventions
3. **Add pagination** to unbounded endpoints
4. **Fix memory leaks** — add cleanup in useEffect returns
5. **Run tests after each change**
6. **Document performance improvements** in the PR with before/after if measurable

## Commit Message Format
```
cabin(day-6): [specific performance fix]
```

Examples:
- `cabin(day-6): batch contact queries and add missing indexes`
- `cabin(day-6): fix memory leaks in notification listeners`
