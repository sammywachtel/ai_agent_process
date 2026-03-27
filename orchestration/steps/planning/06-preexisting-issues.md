# Step 06: Document Pre-existing Issues

**Model tier:** cheap
**Tools needed:** Read, Bash
**Input:** Files-in-scope output (`.run/planning/04-files-in-scope.md`)
**Output:** `.run/planning/06-preexisting-issues.md`

---

## Your Task

Identify validation commands that will fail for reasons **unrelated** to this scope. Documenting these once prevents endless "request skip approval" cycles during iteration.

## How to Find Pre-existing Issues

For each validation command the project uses, run it and note failures:

```bash
# Common validation commands to check
npm run typecheck 2>&1 | tail -5      # TypeScript errors
npm run lint 2>&1 | tail -5           # Linting errors
npm test 2>&1 | tail -5               # Test failures
ruff check . 2>&1 | tail -5           # Python linting
mypy . 2>&1 | tail -5                 # Python type checking
```

For each failure, determine: is it in a file THIS scope touches? If not, it's pre-existing.

## Output Format

Write to `.run/planning/06-preexisting-issues.md`:

```markdown
# Pre-existing Issues (Out of Scope)

**Scope:** {scope_name}
**Date documented:** {today}

## Issues Found

- **{N} {type} errors in non-scope files**
  - Owner: {which scope or team owns these}
  - Impact on this scope: None
  - Example: {one example error}

## Validation Commands

**SKIP (pre-existing debt):**
- `{command}` → SKIP ({reason})

**RUN (scope-relevant):**
- `{command}` → MUST PASS

## Summary
{count} pre-existing issues documented. These will NOT block iterations.
```

If no pre-existing issues found:
```markdown
# Pre-existing Issues (Out of Scope)

*No pre-existing validation failures detected. All commands clean.*
```
