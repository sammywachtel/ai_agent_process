# Iteration Results – {{scope}}/{{iteration}}

**Date:** {{date}}
**Status:** ✅ COMPLETE | ⚠️ NEEDS REVISION | 🚫 BLOCKED

---

## Summary

**Objective:** [One sentence: what this iteration aimed to accomplish]

**Outcome:** [One sentence: what was achieved]

**Status Details:** [Brief explanation of status]

---

## Changes

| File | Change Description |
|------|-------------------|
| path/to/file1.tsx | [What changed] |
| path/to/file2.ts | [What changed] |
| path/to/test.test.tsx | [What changed] |

**Total files changed:** {{count}}

---

## Documentation Changes

**End User Documentation:**
- [List docs updated for application users, or "None - no user-facing changes"]
- Example: ✅ Updated `docs/how-to/using-feature-x.md` with new workflow
- Example: ❌ Not needed - internal refactor only

**Developer Documentation:**
- [List docs updated for code users/contributors, or "None - internal implementation only"]
- Example: ✅ Updated `docs/reference/api/endpoints.md` with new endpoint
- Example: ✅ Added `docs/explanation/architecture/caching-decision.md`
- Example: ✅ Updated `README.md` installation requirements
- Example: ❌ Not needed - no API changes

**Documentation Verification:**
- [ ] Checked for cross-references to changed code (grep results: [summary])
- [ ] Migration guide created (if system replaced)
- [ ] Examples tested and work with current code
- [ ] Followed Diátaxis organization

**Documentation Debt (if any):**
- [List docs that should be updated but weren't, with justification]
- Example: "Architecture diagram for caching layer - requires design time (2-3 hours), tracked in issue #123"
- Or: *None - all documentation up to date*

---

## Validation

| Command | Status | Notes |
|---------|--------|-------|
| Hook: validate-{{scope}} | PASS/FAIL/SKIP | [Brief note or reason] |
| [Additional command] | PASS/FAIL/SKIP | [Brief note] |

**Overall validation:** ✅ All PASS | ⚠️ Some FAIL | 🚫 BLOCKED

---

## Acceptance Criteria Status

Based on original criteria from iteration_plan.md:

- [ ] Criterion 1: [Status summary]
- [ ] Criterion 2: [Status summary]
- [ ] Criterion 3: [Status summary]

**Criteria met:** {{count}}/{{total}}

---

## Work Unit Summary

*Only populated when work unit decomposition was used (multi-domain scopes). Omit this section for single-pass executions.*

| Unit | Description | Status | Files Changed | Validation |
|------|-------------|--------|---------------|------------|
| WU-001 | [description] | ✅ Complete | `file1.ts`, `file2.ts` | PASS |
| WU-002 | [description] | ✅ Complete | `component.tsx` | PASS |
| WU-003 | [description] | ✅ Complete | `test.test.ts` | PASS |

**Decomposition trigger:** [3+ files across 2+ layers — list the layers]
**Parallel groups executed:** [N]
**Session recovery:** [Not needed | Resumed from WU-NNN]

---

## Adversarial Review

*Populated by the implementation agent (Step 4.5 of ap_exec) using a fresh Task agent with zero implementation context. Full verdict saved to `adversarial-review.md` in this iteration folder.*

**Method:** Fresh Task agent | Rubric-based self-review | Skipped — [reason]
**Overall verdict:** X/Y criteria PASS
**Per-criterion results:**
- [ ] Criterion 1: PASS/FAIL — [file:line evidence]
- [ ] Criterion 2: PASS/FAIL — [file:line evidence]
- [ ] Criterion 3: PASS/FAIL — [file:line evidence]

**Blocking issues:** [List any FAIL verdicts, or "None"]

*See `templates/adversarial-review-prompt.md` for the review process and verdict format.*

---

## Next Steps

[One of:]
- **If COMPLETE:** Ready for orchestrator review (expect APPROVE)
- **If NEEDS REVISION:** Issues to address: [list 1-3 specific issues]
- **If BLOCKED:** Blocker: [description] - Requires human decision

---

**Total lines:** Aim for <50 lines (this template included)
