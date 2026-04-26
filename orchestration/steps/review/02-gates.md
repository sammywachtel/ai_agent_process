# Step 02: Quality Gates

**Input:** `.run/review/01-verify.md`
**Output:** `.run/review/02-gates.md`

---

## Fast-Track Check

If ALL true, most gates can be fast-tracked:
- Internal refactor only (no API/UI/behavior changes)
- Test-only or doc-only changes
- results.md notes "No external impact"

Fast-tracked gates still need quick verification, not full analysis.

---

## Gate 1: Documentation

**Check:** Docs updated in same commit as code changes (Zero Documentation Drift).

- End user docs updated? (if behavior changed)
- Developer docs updated? (if API/architecture changed)
- Orphaned references to removed code?

### When the iteration plan declares `Removed Surfaces`

If the plan's **Removed Surfaces** section is non-empty (i.e. this scope
removes or renames a public surface), the "orphaned references" check is
no longer a yes/no judgment. The reviewer MUST:

1. Read the **Removed-Surface Scrub** section of the iteration's
   `results.md`. If it is missing, **FAIL Gate 1**.
2. For at least one declared surface, run the validator's stale-surface
   scrub block manually — do not trust the implementer's count alone.
3. Inspect each whitelist addition the executor made beyond the planner's
   initial whitelist. Each addition must have an inline justification
   (historical record, guardrail test, internal name collision, explicit
   "is removed" note). **FAIL Gate 1** if any of these are true:
   - A whitelist entry has no justification.
   - The justification is *"out of scope"* / *"deferred to follow-up scope"* — those are valid reasons to defer entire AC, not to whitelist a specific stale reference while still claiming the AC is met.
   - An operator-facing surface (smoke scripts, READMEs, runbooks, observability docs) is whitelisted as "historical" when it is in fact still serving as live operator guidance.

When **Removed Surfaces** is empty (additive scope), this gate falls back
to its existing yes/no check on orphaned references.

See `process/removal-scope-checklist.md` for the full contract.

**PASS:** Docs appropriately updated OR clear justification why N/A
**FAIL:** External behavior changed with no doc update; OR removed-surface
scrub missing/incomplete; OR a whitelist entry is unjustified

---

## Gate 2: Integration

**Check:** Changes don't break integration points outside scope.

For files with changed interfaces:
```bash
grep -r "functionName\|ComponentName\|api/endpoint" src/
```

**PASS:** All integration points verified compatible OR internal-only changes
**FAIL:** Interface changed but call sites not updated

---

## Gate 3: Adversarial Review

**Check:** Independent verification of criteria compliance.

If `adversarial-review.md` exists from execution:
- Read the verdicts
- Note agreements/disagreements with your assessment

If not, perform rubric self-review:
- For each criterion, find file:line evidence
- Assign PASS/FAIL with no hedging

**The verdict is advisory** — informs but doesn't make the decision.

---

## Gate 4: Scoped Validation

**Check:** Validation was scoped to this work, not entire codebase.

Read `test-output.txt`:
- Did scoped validation run?
- Pre-existing issues excluded?

---

## Output

```markdown
# Quality Gates

## Gate Summary

| Gate | Status | Notes |
|------|--------|-------|
| Documentation | PASS/FAIL/N/A | {brief reason} |
| Integration | PASS/FAIL/FAST-TRACKED | {brief reason} |
| Adversarial | {X}/{Y} PASS | {method used} |
| Scoped Validation | PASS/FAIL | {from test-output.txt} |

## Overall Signal

- Toward APPROVE: {N} gates
- Toward ITERATE: {N} gates  
- Toward BLOCK: {N} gates

## Details

{Only include if gates failed — don't pad with "everything passed" text}
```
