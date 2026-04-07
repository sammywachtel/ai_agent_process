# Step 03: Code Feasibility Review

**Model tier:** capable
**Tools needed:** Read, Grep, Glob
**Input:** Requirement file path
**Output:** `.run/planning/03-code-review.md`

---

## Instructions

Follow the standard feasibility review process in **`process/code-feasibility-review.md`**.

This step grounds the requirement in codebase reality before creating the iteration plan.

## Context for This Step

- **You are:** The planning coordinator's code reviewer
- **Your goal:** Assess whether this requirement is ready for implementation
- **Blocking gate:** If `CLARIFICATION_NEEDED: true`, planning stops until resolved

## What Happens Next

- If `CLARIFICATION_NEEDED: false` → Planning continues to Step 04 (Define Files)
- If `CLARIFICATION_NEEDED: true` → Coordinator presents questions to user

## Output Location

Write your review to: `.run/planning/03-code-review.md`

Use the output template from `process/code-feasibility-review.md`.
