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

## 2. Identify Removed Surfaces

**Before writing the validation script, ask:** does this scope remove or
rename any public surface — HTTP route, MCP tool, CLI command, env var,
config key, exported function used by another repo, etc.?

- **If no:** record `Removed Surfaces: N/A — no public surfaces removed or renamed.` in the iteration plan and proceed to step 3.
- **If yes:** populate the iteration plan's **Removed Surfaces** section per `.agent_process/process/removal-scope-checklist.md`. For each surface, list the grep pattern and the initial whitelist (paths + reason — historical, guardrail, name-collision, etc.). Generate the per-surface whitelist files at `.agent_process/work/{scope}/.removal-whitelist/{surface}.txt` (one `path:line-range` per line).

Heuristic for the call: if the removed identifier appears in any of
`README*`, `docs/`, `scripts/`, or `*.md` files outside the implementation
module, populate the section. Otherwise skip.

---

## 3. Create Validation Script

Write to `.agent_process/scripts/after_edit/validate-{scope}.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCOPE="$1"
ITERATION="$2"

# Scope-specific validation
{commands from RUN list}

# Stale-surface scrub — INCLUDE THIS BLOCK ONLY IF "Removed Surfaces" is
# non-empty in the iteration plan. See process/removal-scope-checklist.md
# for the full template. Removed scopes without it cannot satisfy Gate 1
# during review.
#
# printf "[%s-validation] Stale-surface scrub...\n" "$SCOPE"
# SURFACE_VIOLATIONS=0
# for SURFACE in <surface-keys>; do
#   ...grep workspace, filter against per-surface whitelist...
# done
# [[ "$SURFACE_VIOLATIONS" -eq 0 ]] || exit 1

echo "✅ Scoped validation passed"
```

Make executable: `chmod +x`

---

## 4. Design Review Gate (if complex)

If requirement has `complexity: complex`:
- Trigger design review
- Document architectural decisions
- Get approval before proceeding

If simple/moderate: skip this gate.

---

## 5. Write Iteration Plan

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
8. **Removed Surfaces** — populated per step 2 above (default `N/A` for additive scopes)
9. Validation Requirements (SKIP vs RUN)
10. Out of Scope
11. Time Budget (2-4 hours/iteration)

---

## 6. Finalize

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
