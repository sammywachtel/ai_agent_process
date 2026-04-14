# Step 04: Create Plan

**Input:** All `.run/planning/` outputs, requirement file
**Output:** `.agent_process/work/{scope}/iteration_plan.md`

---

## 1. Document Pre-existing Issues

Run validation commands and identify failures OUTSIDE this scope:

```bash
npm run typecheck 2>&1 | tail -5
npm run lint 2>&1 | tail -5
ruff check . 2>&1 | tail -5
```

For each failure: is it in a scope file? If not, it's pre-existing debt.

Document:
- **SKIP:** Commands that fail on pre-existing issues
- **RUN:** Commands that must pass for this scope

---

## 2. Create Validation Script

Write to `.agent_process/scripts/after_edit/validate-{scope}.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCOPE="$1"
ITERATION="$2"

# Scope-specific validation
{commands from RUN list}

echo "✅ Scoped validation passed"
```

Make executable: `chmod +x`

---

## 3. Design Review Gate (if complex)

If requirement has `complexity: complex`:
- Trigger design review
- Document architectural decisions
- Get approval before proceeding

If simple/moderate: skip this gate.

---

## 4. Write Iteration Plan

Synthesize ALL `.run/planning/` outputs into the final plan.

Use template structure from `.agent_process/templates/iteration-plan.md`.

**Required sections:**
1. Scope Overview
2. Current Status (`iteration_01 - not started`)
3. Acceptance Criteria (LOCKED) — copy verbatim from define step
4. Technical Assessment — include Design Decisions table
5. Known Patterns & Constraints
6. Files in Scope
7. Documentation in Scope
8. Validation Requirements (SKIP vs RUN)
9. Out of Scope
10. Time Budget (2-4 hours/iteration)

---

## 5. Finalize

Create infrastructure:

```bash
mkdir -p .agent_process/work/{scope}/iteration_01
```

Write placeholder results:
```markdown
# Iteration Results — {scope}/iteration_01
**Status:** TODO - Awaiting execution
Run: /ap_exec {scope} iteration_01
```

Update requirement status to `scoped`.

Update roadmap if exists.

---

## Output

The iteration plan at `.agent_process/work/{scope}/iteration_plan.md`.

Report to coordinator:

```markdown
# Planning Complete

**Scope:** {scope}
**Plan:** `.agent_process/work/{scope}/iteration_plan.md`

## Summary
- Files: {N}
- Criteria: {N}
- Pre-existing issues: {N} documented (will SKIP)
- Design review: {Triggered / Not needed}

## Handoff
Ready for execution: `/ap_exec {scope} iteration_01`
```
