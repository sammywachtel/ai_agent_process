# Step 8.5: Design Review Gate (CONDITIONAL)

**Model tier:** capable (x2-4 parallel reviewers)
**Tools needed:** Read, Write
**Input:** Iteration plan, quality-config.json, requirement frontmatter
**Output:** `.run/planning/085-design-review.md`

---

## Gate Conditions

**Both must be true to trigger this step:**
1. `.agent_process/quality-config.json` → `design_review.enabled: true`
2. Requirement frontmatter → `complexity: complex`

**If either is false:** Write "N/A — not triggered" to output and stop.

## Reviewer Selection

Choose reviewers based on scope characteristics (min/max from quality-config.json):

| Scope Characteristic | Reviewer |
|---------------------|----------|
| All complex scopes | Architect (always) |
| Touches auth, tokens, encryption, user data | Security |
| Touches UI, UX, user-facing workflows | Product/UX |
| Crosses 3+ system layers | Additional domain specialist |

## Review Process

**If Agent/Task tool available (Claude Code):**
Spawn reviewers in parallel. Each reviewer receives:
- The iteration plan
- The files-in-scope list
- The technical assessment

Each reviewer uses the rubric from `.agent_process/templates/design-review-prompt.md`.

**If no Agent/Task tool (Codex):**
Walk through each reviewer's lens sequentially using the same rubric.

## Verdict Processing

Each reviewer produces: **APPROVE** or **REQUEST_CHANGES** with evidence.

- **All APPROVE** → Record, proceed
- **Any REQUEST_CHANGES** → Revise the plan. Max revision cycles from `design_review.max_revision_cycles` (default: 2)
- **Unresolved after max cycles** → Escalate to human. Do NOT proceed.

## Output Format

Write to `.run/planning/085-design-review.md`:

```markdown
# Design Review Results

**Gate triggered:** YES/NO
**Reason:** {why triggered or why not}

## Reviewers
- **{Domain}:** {APPROVE/REQUEST_CHANGES} — {one-line summary}

## Revision History
{If revisions were needed, document each cycle}

## Outcome: {APPROVED / ESCALATED / N/A}
```
