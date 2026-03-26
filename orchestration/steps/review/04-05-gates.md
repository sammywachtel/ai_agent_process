# Steps 04-05: Gate Aggregation + Attempt Count

**Model tier:** cheap
**Tools needed:** Read
**Input:** scope, iteration, ALL gate outputs from `.run/review/`
**Output:** `.run/review/04-05-gates.md`

---

## Your Task

Aggregate the 5 verification gate results and count remaining iteration attempts. This feeds into the decision step.

## Read All Gate Outputs

1. `.run/review/02-eval-criteria.md` — criteria evaluation
2. `.run/review/03-code-verify.md` — code verification
3. `.run/review/035-doc-verify.md` — documentation gate
4. `.run/review/036-integration-verify.md` — integration gate
5. `.run/review/037-adversarial.md` — adversarial review

## Verify Scoped Validation

Check that validation was scoped (not entire codebase). Read `test-output.txt` — it should show scoped validation, not full suite runs.

If full validation ran despite pre-existing debt, note it but don't block.

For shared-API scopes: confirm contract snapshot, backend guard tests, and consumer validation evidence.

## Count Attempts

| Iteration | Used | Remaining | Can ITERATE? |
|-----------|------|-----------|--------------|
| `iteration_01` | 1 | 3 | Yes |
| `iteration_01_a` | 2 | 2 | Yes |
| `iteration_01_b` | 3 | 1 | Yes |
| `iteration_01_c` | 4 | 0 | **No — APPROVE or BLOCK only** |

## Output Format

Write to `.run/review/04-05-gates.md`:

```markdown
# Gate Aggregation

## Gate Results
| Gate | Status | Key Finding |
|------|--------|-------------|
| Criteria Evaluation | {N} MET / {N} NOT MET | {summary} |
| Code Verification | Match/Partial/Mismatch | {summary} |
| Documentation | PASS/FAIL | {summary} |
| Integration | PASS/FAIL/FAST-TRACKED | {summary} |
| Adversarial Review | {X}/{Y} PASS | {summary} |

## Validation
- Scoped validation: {PASS/FAIL}
- Full suite issues: {none / pre-existing only}

## Iteration Budget
- Attempt: {N} of 4
- Can ITERATE: YES/NO
- If NO: Must APPROVE (if criteria met) or BLOCK (if not)

## Overall Signal
- Toward APPROVE: {count} gates
- Toward ITERATE: {count} gates
- Toward BLOCK: {count} gates
```
