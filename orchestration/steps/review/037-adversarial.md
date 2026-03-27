# Step 3.7: Adversarial Review Verification

**Model tier:** capable
**Tools needed:** Read, Bash
**Input:** scope, iteration
**Output:** `.run/review/037-adversarial.md`

---

## Your Task

Check whether an independent adversarial review was performed during execution. If it exists, verify it. If not, handle per the platform-adaptive paths below.

## Check Config

Read `quality-config.json`. If `adversarial_review.enabled` is `false`, write "Skipped — disabled via quality-config.json" and stop.

## Path A — Verdict Already Exists (preferred)

```bash
cat .agent_process/work/{scope}/{iteration}/adversarial-review.md 2>/dev/null
```

If the file exists with per-criterion PASS/FAIL verdicts:
1. Read the verdict
2. Note agreements/disagreements with your own assessment
3. Record summary

## Path B — No Verdict, You Have Agent/Task Tool

If `adversarial-review.md` doesn't exist and you can spawn agents:
1. Get changed files: `git diff --name-only <base_branch>..HEAD`
2. Read the frozen criteria from iteration_plan.md
3. Spawn a fresh agent with `templates/adversarial-review-prompt.md`
4. Save the verdict to `adversarial-review.md`

## Path C — No Verdict, No Agent Tool (Codex fallback)

Perform rubric-based self-review:
1. For each frozen criterion, find specific file:line evidence
2. Assign PASS or FAIL — no hedging
3. Flag method: "Rubric-based self-review (no Task tool)"

## How to Use the Verdict

- **All PASS:** Strong signal toward APPROVE
- **Any FAIL with strong evidence:** Likely warrants ITERATE
- **Any FAIL with weak evidence:** Your judgment overrides — note why you disagree
- The verdict is **advisory** — it informs but does not make the decision

## Output Format

Write to `.run/review/037-adversarial.md`:

```markdown
# Adversarial Review

**Method:** Existing verdict / Fresh agent / Rubric self-review / Skipped
**Result:** {X}/{Y} criteria PASS

## Per-Criterion Verdicts
| # | Criterion | Verdict | Evidence |
|---|-----------|---------|----------|
| 1 | {criterion} | PASS/FAIL | {file:line or reason} |

## Notes
{Agreements/disagreements with other verification gates}
```
