# Step 0.7b: Working Tree Check

**Model tier:** cheap
**Tools needed:** Bash
**Input:** scope, iteration (e.g., "iteration_01_a")
**Output:** `.run/execution/007b-working-tree.md`

---

## Your Task

Verify the working tree is in a good state before making changes.

## Understanding Sub-Iterations

**IMPORTANT:** Sub-iterations (`iteration_01_a`, `iteration_01_b`, etc.) are revisions of the parent iteration. They are **expected** to have uncommitted changes in scope files from the prior iteration. This is normal workflow, not a problem.

- `iteration_01` — first attempt, expect clean tree or prior scope work
- `iteration_01_a` — revision of 01, expect uncommitted changes from 01
- `iteration_01_b` — revision of 01_a, expect uncommitted changes from 01 + 01_a

**Only flag as CONFLICT if:**
1. Uncommitted changes exist in files **outside** the scope (unrelated work mixed in)
2. We're on `iteration_01` (not a sub-iteration) AND there are uncommitted changes that look like prior incomplete work

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

Determine if this is a sub-iteration:
```bash
# Check iteration name for _a, _b, _c suffix
echo "{iteration}" | grep -qE '_[a-c]$' && echo "sub-iteration" || echo "primary"
```

## Output Format

Write to `.run/execution/007b-working-tree.md`:

```markdown
# Working Tree Check

CONFLICT: true/false
UNCOMMITTED_CHANGES: {count}
IS_SUB_ITERATION: true/false

## Details
- {If no changes: "Clean working tree"}
- {If sub-iteration with changes in scope: "Uncommitted changes in scope files — expected for sub-iteration, continuing"}
- {If changes only in unrelated files: "Uncommitted changes in {N} files outside scope — may indicate mixed work"}
- {If primary iteration with unexpected changes: "Uncommitted changes in scope files on primary iteration — verify this is intended"}
```

## Key Distinction

**Do NOT block or warn dramatically about uncommitted changes in scope files during sub-iterations.** The whole point of a sub-iteration is to revise work from the prior attempt. Those changes are the starting point, not a problem to solve.
