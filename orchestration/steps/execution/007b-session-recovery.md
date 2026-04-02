# Step 0.7a: Session Recovery — Detect Interrupted Work

**Model tier:** cheap
**Tools needed:** Read, Bash
**Input:** scope, iteration
**Output:** `.run/execution/007a-session-recovery.md`

---

## Your Task

Check if a previous execution of this scope/iteration was interrupted or already completed.

## Checks

**Check scope tracker for iteration state:**
```bash
# Get current iteration from scope-tracker.jsonl (authoritative source)
jq -r 'select(.scope=="{scope}") | .iteration' .agent_process/work/scope-tracker.jsonl 2>/dev/null
```
If the tracker returns an iteration value, it's the authoritative source. Compare it to the requested iteration — if they differ, the scope may have moved on.

**Check for existing results.md:**
```bash
ls .agent_process/work/{scope}/{iteration}/results.md 2>/dev/null
```

**If results.md exists, check its content:**
```bash
head -10 .agent_process/work/{scope}/{iteration}/results.md
```

**Check scope event log for work unit progress:**
```bash
grep "{scope}" .agent_process/work/scope-events.log 2>/dev/null | tail -10
```

## Output Format

Write to `.run/execution/007a-session-recovery.md`:

```markdown
# Session Recovery Check

**Scope:** {scope}
**Iteration:** {iteration}

EXISTING_RESULTS: none / template_only / complete
TRACKER_STATE: {summary from scope-tracker.jsonl or "none"}

## Assessment
- {If "none": Clean start — proceed normally}
- {If "template_only": Previous run was interrupted. Resuming from scratch.}
- {If "complete": This iteration already has results. User must confirm re-execution.}
- {If event log shows partial work units: list which completed}
```
