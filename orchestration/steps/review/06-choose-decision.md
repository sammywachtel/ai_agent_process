# Step 06: Choose Decision — HIGH STAKES

**Model tier:** synthesis (use the BEST available model)
**Tools needed:** Read
**Input:** ALL `.run/review/*` files
**Output:** `.run/review/06-decision.md`

---

## Your Task

Read ALL verification gate outputs and choose EXACTLY ONE of the 4 decisions. This is the most important step in the entire AP workflow. Take your time. Use all evidence.

## Read All Evidence

- `.run/review/01-review-context.md` — criteria version, attempt count
- `.run/review/02-eval-criteria.md` — criteria evaluation results
- `.run/review/03-code-verify.md` — code verification findings
- `.run/review/035-doc-verify.md` — documentation gate
- `.run/review/036-integration-verify.md` — integration gate
- `.run/review/037-adversarial.md` — adversarial review verdicts
- `.run/review/04-05-gates.md` — aggregated gates + attempt count

## Choose EXACTLY ONE

### ✅ APPROVE
**When:** All criteria met, validation passes, no critical blockers.

### 🔄 ITERATE
**When:** Specific fixable issues found AND attempts remaining (not at `_c`).
Must specify 1-3 **concrete** fixes with file:line, before/after, acceptance test.

### 🚫 BLOCK
**When:** External blocker, framework limitation, or attempts exhausted with criteria not met.
Must be used at `_c` if criteria not met. Must document the blocker clearly.

### 🔀 PIVOT
**When:** Wrong approach, scope change needed. Requires human approval.

## Fix Specificity (ITERATE only)

Each fix MUST include:
- ✅ Exact file path and small line range (<20 lines)
- ✅ Specific action with before/after examples
- ✅ Clear acceptance test ("when done, X should show Y")

## Output Format

Write to `.run/review/06-decision.md`:

```markdown
# Review Decision: {emoji} {DECISION}

**Iteration:** {scope}/{iteration}
**Attempts used:** {N} of 4

## Evidence Summary

**Criteria Evaluation:** {N}/{total} MET
**Code Verification:** {Match/Partial/Mismatch}
**Documentation Gate:** {PASS/FAIL}
**Integration Gate:** {PASS/FAIL/FAST-TRACKED}
**Adversarial Review:** {X/Y PASS or skipped}
**Scoped Validation:** {PASS/FAIL}

## Rationale
{1-3 sentences explaining your decision based on the evidence above}

## Criteria Status
- {emoji} Criterion 1: {MET/NOT MET — brief note}
- {emoji} Criterion 2: ...

## {Decision-specific section}

{For APPROVE: Knowledge to deposit, requirement status update}
{For ITERATE: 1-3 concrete fixes with file:line, before/after, acceptance test}
{For BLOCK: Blocker description, human decision options}
{For PIVOT: Reason, proposed scope change, needs human approval}

## Next Step
{APPROVE: `/ap_release pr` or `/ap_release beta` to create PR}
{ITERATE: `/ap_exec {scope} {next_iteration}` for implementation}
{BLOCK: Escalate to human — no further automated action}
{PIVOT: Human approves revised criteria, then re-plan}
```
