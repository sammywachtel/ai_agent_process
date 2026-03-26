# Step 02: Evaluate Against Frozen Criteria

**Model tier:** capable
**Tools needed:** Read
**Input:** scope, iteration (reads iteration_plan.md + results.md directly)
**Output:** `.run/review/02-eval-criteria.md`

---

## Your Task

Compare the implementation results against the LOCKED acceptance criteria. Evaluate only the frozen criteria for this major iteration — do not add or invent new criteria.

## Rules

- ✅ Evaluate against the frozen criteria for THIS major iteration
- ❌ Do NOT add new criteria discovered during iteration
- ❌ Do NOT expand scope based on new findings
- ❌ Do NOT evaluate post-PIVOT iterations against pre-PIVOT criteria
- ✅ New issues go to backlog for future scopes

## Read

1. `.agent_process/work/{scope}/iteration_plan.md` — `## Acceptance Criteria` section
2. `.agent_process/work/{scope}/{iteration}/results.md` — `## Acceptance Criteria Status` section

## Evaluation

For each criterion:
1. State the criterion exactly as written
2. Check what results.md claims
3. Assign: MET / NOT MET / PARTIAL
4. Note any discrepancies between claim and evidence

## Output Format

Write to `.run/review/02-eval-criteria.md`:

```markdown
# Criteria Evaluation

**Criteria version:** v{N}
**Total:** {count}

## Results

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| 1 | {criterion text} | MET/NOT MET/PARTIAL | {evidence or concern} |
| 2 | ... | ... | ... |

## Summary
- {N} MET, {N} NOT MET, {N} PARTIAL
- {Overall assessment: all met / gaps remain / blocked}
```
