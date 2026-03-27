# Step 05: Design Review (CONDITIONAL)

**Model tier:** capable (x2-3 parallel reviewers)
**Tools needed:** Agent/Task, Read
**Input:** synthesis output (`.run/04-synthesis.md`)
**Output:** `.run/05-design-review.md`

---

## Your Task

If the user opts in (or complexity is high), run a multi-agent design review on the brainstorm synthesis.

## Gate

**Ask the user:**
> "Brainstorm complete. Want to run a multi-agent design review before creating the requirement?
> 1. **Yes, run design review** (recommended for complex features)
> 2. **Skip, create requirement now**"

**If skipped:** Write "Skipped — user declined" and stop.

## Review Agents (2-3 in parallel)

Spawn reviewers using the rubric from `templates/design-review-prompt.md`. Feed them the synthesis as the "plan" to review.

Select reviewers based on the synthesis content:
- **Architect** — always included
- **Security** — if the idea touches auth, data, or user input
- **Product/UX** — if the idea affects user-facing workflows

Each produces: **APPROVE** or **REQUEST_CHANGES** with reasoning.

## Output Format

```markdown
# Design Review

**Triggered:** YES/NO
**Reviewers:** {list}

## Verdicts
- **{Domain}:** {APPROVE/REQUEST_CHANGES} — {summary}

## Feedback to Incorporate
{If REQUEST_CHANGES: specific items to address in the requirement}
```
