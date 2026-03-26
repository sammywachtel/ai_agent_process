# Step 0.7b: Working Tree Check

**Model tier:** cheap
**Tools needed:** Bash
**Input:** scope
**Output:** `.run/execution/007b-working-tree.md`

---

## Your Task

Verify the working tree is in a good state before making changes.

## Checks

```bash
# Quick check — any uncommitted changes at all?
git status --porcelain 2>/dev/null | head -10
```

If there are uncommitted changes, check if they overlap with files in scope:
```bash
# Get files in scope from iteration plan
grep -A 50 "## Files in Scope" .agent_process/work/{scope}/iteration_plan.md 2>/dev/null | grep "^- \`" | sed 's/^- `//;s/`.*$//'
```

## Output Format

Write to `.run/execution/007b-working-tree.md`:

```markdown
# Working Tree Check

CONFLICT: true/false
UNCOMMITTED_CHANGES: {count}

## Details
- {If no changes: "Clean working tree"}
- {If changes in unrelated files: "Uncommitted changes in {N} files, none overlap with scope"}
- {If changes in scope files: "WARNING: Uncommitted changes in scope files: {list}"}
```
