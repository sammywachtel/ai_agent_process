# Step 0.7a: Session Recovery — Detect Interrupted Work

**Model tier:** cheap
**Tools needed:** Read, Bash
**Input:** scope, iteration
**Output:** `.run/execution/007a-session-recovery.md`

---

## Your Task

Check if a previous execution of this scope/iteration was interrupted or already completed.

## Checks

```bash
# Check for existing results.md
ls .agent_process/work/{scope}/{iteration}/results.md 2>/dev/null
```

**If results.md exists, check its content:**
```bash
head -10 .agent_process/work/{scope}/{iteration}/results.md
```

**Also check BEADS state for work unit progress:**
```bash
cat .agent_process/work/{scope}/{iteration}/.beads-state 2>/dev/null
```

## Output Format

Write to `.run/execution/007a-session-recovery.md`:

```markdown
# Session Recovery Check

**Scope:** {scope}
**Iteration:** {iteration}

EXISTING_RESULTS: none / template_only / complete
BEADS_STATE: {summary of .beads-state or "none"}

## Assessment
- {If "none": Clean start — proceed normally}
- {If "template_only": Previous run was interrupted. Resuming from scratch.}
- {If "complete": This iteration already has results. User must confirm re-execution.}
- {If BEADS state shows partial work units: list which completed}
```
