# Step 08: Create Iteration Plan (AGGREGATOR)

**Model tier:** synthesis
**Tools needed:** Read, Write
**Input:** ALL `.run/planning/*` files, requirement file path, scope name
**Output:** `.agent_process/work/{scope}/iteration_plan.md`

---

## Your Task

This is the synthesis step. Read every `.run/planning/` output file and the requirement document, then produce the iteration plan. Use the template at `.agent_process/templates/iteration-plan.md` as your structural guide.

## Required Inputs

Read ALL of these before writing:
- `.run/planning/01-scope-check.md` — scope validation results
- `.run/planning/02-folder-name.txt` — scope folder name
- `.run/planning/025-knowledge.md` — knowledge base findings
- `.run/planning/03-code-review.md` — technical feasibility assessment
- `.run/planning/04-files-in-scope.md` — definitive file list
- `.run/planning/05-frozen-criteria.md` — locked acceptance criteria
- `.run/planning/055-doc-impact.md` — documentation impact
- `.run/planning/06-preexisting-issues.md` — pre-existing validation failures
- `.run/planning/07-validation-script.md` — validation script details
- Requirement file (original)

## Plan Structure

The iteration plan MUST include these sections:

1. **Scope Overview** — name, date, one-sentence summary
2. **Current Status** — `iteration_01 (not started)`
3. **Acceptance Criteria (LOCKED)** — from `.run/planning/05-frozen-criteria.md`, verbatim
4. **Technical Assessment** — from `.run/planning/03-code-review.md`:
   - Code review findings
   - Relevant CLAUDE.md patterns
   - Implementation approach
   - Known risks
   - Implementation guidance
5. **Known Patterns & Constraints** — from `.run/planning/025-knowledge.md`
6. **Iteration Model** — major iterations for criteria changes, sub-iterations for fixes
7. **Criteria History** — v1 (iteration_01) with current criteria
8. **Files in Scope** — from `.run/planning/04-files-in-scope.md`
9. **Documentation in Scope** — from `.run/planning/055-doc-impact.md`
10. **Validation Requirements** — from `.run/planning/07-validation-script.md` and `.run/planning/06-preexisting-issues.md`
11. **Contract Consumers** — if applicable, from `.run/planning/04-files-in-scope.md`
12. **Out of Scope** — from requirement
13. **Time Budget** — target 2-4 hours/iteration, max 1-3 weeks total
14. **Success Metrics** — all criteria checked, scoped validation passes

## Writing Rules

- Copy acceptance criteria EXACTLY from the frozen criteria step — do not reword
- Include the LOCKED/DO NOT MODIFY warning on criteria
- Implementation guidance should be actionable, not vague
- Pre-existing issues should clearly state which commands to SKIP vs RUN

## Output

Write to `.agent_process/work/{scope}/iteration_plan.md`
