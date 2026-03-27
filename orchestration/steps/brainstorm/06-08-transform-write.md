# Steps 06-08: Transform, Confirm, Write

**Model tier:** capable
**Tools needed:** Read, Write, Bash
**Input:** synthesis (`.run/04-synthesis.md`), design review (`.run/05-design-review.md`), idea
**Output:** Requirement file in `requirements_docs/{category}/`

---

## Your Task

Transform the brainstorm synthesis into a formal AP requirement file, confirm with the user, and write it.

## Step 6: Transform to Requirement

Map synthesis fields to requirement template:

```markdown
---
id: {requirement_id}
type: requirement
category: {category}
status: not_started
priority: {priority}
complexity: {simple | moderate | complex}
source: ap-brainstorm
---

# Requirements: {derived_title}

## Objective
{From Problem Statement — one clear sentence}

## Background
{From Problem Statement — expanded context}

## Technical Requirements
{From Proposed Approach — numbered list}

## Success Criteria
{From Success Criteria — checkboxes}

## Files Expected to Change
{From Technical Assessment}

## Out of Scope
{From Scope Boundaries}

## Known Risks
{From Risks & Mitigations}

## Notes

### Brainstorm Source
- **Brainstorm doc:** `.agent_process/brainstorms/{name}.md`
- **Date:** {today}
- **Perspectives:** Product, Architecture, Critical

### Design Review
{Summary or "Not run."}

### Open Questions
{Items needing human input}
```

## Step 7: Confirm with User

Present key fields for review:
- **Title:** {derived}
- **Category:** {suggest, ask if not obvious}
- **Priority:** {suggest from urgency signals}
- **Complexity:** {from Architecture agent}

Wait for user confirmation or adjustments.

## Step 8: Write and Register

1. Determine location: `requirements_docs/{category}/`
2. Generate ID (find existing IDs, suggest next)
3. Write the requirement file
4. Update master roadmap with NOT_STARTED status

## Report

```
✓ Brainstorm complete: {id}
  Requirement: requirements_docs/{category}/{id}.md
  Brainstorm:  .agent_process/brainstorms/{name}.md
  Criteria:    {count} acceptance criteria

Next: Review the requirement, then feed to orchestrator for planning
```
