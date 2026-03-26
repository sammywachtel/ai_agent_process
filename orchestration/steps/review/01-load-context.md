# Step 01: Load Review Context

**Model tier:** cheap
**Tools needed:** Read, Bash
**Input:** scope, iteration
**Output:** `.run/review/01-review-context.md`

---

## Your Task

Load all artifacts needed for review and determine the iteration state.

## Read These Files

1. `orchestration/context/base-context.md` — refresh on process rules
2. `.agent_process/work/{scope}/iteration_plan.md` — frozen acceptance criteria
3. `.agent_process/work/{scope}/{iteration}/results.md` — what was done
4. `.agent_process/work/{scope}/{iteration}/test-output.txt` — validation results

## Determine Iteration Count

| Iteration | Attempt | Remaining | Can ITERATE? |
|-----------|---------|-----------|--------------|
| `iteration_01` | 1 of 4 | 3 (a,b,c) | Yes |
| `iteration_01_a` | 2 of 4 | 2 (b,c) | Yes |
| `iteration_01_b` | 3 of 4 | 1 (c) | Yes |
| `iteration_01_c` | 4 of 4 | 0 | No — APPROVE or BLOCK only |

For `iteration_02+`, same pattern resets (02, 02_a, 02_b, 02_c).

## Determine Correct Criteria Version

After a PIVOT, criteria change. Check `## Criteria History` in iteration_plan.md:

| Reviewing | Use criteria |
|-----------|-------------|
| `iteration_01` or `_a/_b/_c` | v1 (original) |
| `iteration_02` or `_a/_b/_c` | v2 (post-PIVOT) |

## Output Format

Write to `.run/review/01-review-context.md`:

```markdown
# Review Context

**Scope:** {scope}
**Iteration:** {iteration}
**Attempt:** {N} of 4
**Can ITERATE:** YES/NO
**Criteria version:** v{N}

## Frozen Criteria
{Copy criteria verbatim from the correct version}

## Results Summary
{Key claims from results.md}

## Validation Summary
{Pass/fail from test-output.txt}
```
