---
name: /ap_iteration_results
description: Document iteration results and validation status in results.md
argument-hint: [scope] [iteration]
arguments:
  - name: scope
    type: string
    description: Scope folder under `.agent_process/work/`.
    required: true
  - name: iteration
    type: string
    description: Iteration folder name (e.g., `iteration_01`, `iteration_01_a`).
    required: true
---

## Your Role

Generate a structured results.md document summarizing the iteration's implementation, validation results, and completion status.

## Workflow

1. **Load Artifacts** - Read iteration outputs
2. **Verify Completeness** - Check test-output.txt exists and is complete
3. **Generate results.md** - Create structured summary
4. **Report** - Confirm completion

---

## Step 1: Load Artifacts

**Read these files:**

**Iteration plan (for original criteria):**
```
.agent_process/work/{scope}/iteration_plan.md
```

**Test output (validation results):**
```
.agent_process/work/{scope}/{iteration}/test-output.txt
```

If test-output.txt does NOT exist:
- Report error to user
- Request that validation be run first
- Do NOT proceed

---

## Step 2: Verify Completeness

**Check test-output.txt summary:**
- Should have "Summary" section at top
- Each validation item should be PASS, FAIL, or SKIPPED
- No PENDING entries should remain

**If PENDING entries found:**
- Report to user which validations are incomplete
- Request that validation be completed first
- Do NOT proceed

**If FAIL entries found:**
- Note these - will be documented in results.md
- Iteration is NOT ready for approval

---

## Step 3: Generate results.md

**Create the results document:**

Use this template structure:

```markdown
# Iteration Results – {scope}/{iteration}

**Date:** {current date}
**Status:** {COMPLETE - Ready for Review | INCOMPLETE - Issues Found}

---

## Summary

{1-2 paragraph summary of what was implemented}

**Acceptance Criteria Status:**
{Copy criteria from iteration_plan.md and mark which were met}

- [ ] Criterion 1: {Met/Not Met - brief explanation}
- [ ] Criterion 2: {Met/Not Met - brief explanation}
- [ ] Criterion 3: {Met/Not Met - brief explanation}

---

## Changed Files

{List each modified file with brief rationale}

- `path/to/file1.tsx` - {What was changed and why}
- `path/to/file2.ts` - {What was changed and why}
- `path/to/test.test.tsx` - {Test coverage added}

---

## Validation

**Scoped validation (hook):** {PASS | FAIL}
{Brief summary of hook validation results}

**E2E tests:** {PASS | FAIL}
{Results from Playwright E2E tests - servers auto-started by Playwright}

**Manual verification:** {PASS | FAIL | SKIPPED}
{What manual testing was done, if any}

**Detailed logs:** See `test-output.txt` for complete validation output

> ⚠️ Do NOT report E2E tests as "skipped because servers weren't running" - Playwright auto-starts servers via the `webServer` config. If E2E tests failed, report the actual error.

---

## Implementation Notes

**What went well:**
{Positive observations}

**Challenges encountered:**
{Issues faced during implementation}

**Technical decisions:**
{Key implementation choices made}

---

## Known Issues / Follow-up

{List any discovered issues, incomplete items, or follow-up work needed}

**If this iteration did not meet all criteria:**
- Specific blockers: {List blockers}
- Recommended next steps: {Suggest fixes for next sub-iteration}

**New issues discovered (out of scope):**
- {Issue 1} - Backlog for future scope
- {Issue 2} - Backlog for future scope

---

## Ready for Review?

{YES - All criteria met and validation passed}
{NO - Reason why not ready}

**Next step:** {Orchestrator review | Another iteration needed | Escalate blocker}
```

**Save results.md:**
```
.agent_process/work/{scope}/{iteration}/results.md
```

---

## Step 4: Report Completion

**Provide summary to user:**

```markdown
## Results Documented: {scope}/{iteration}

**results.md created:** `.agent_process/work/{scope}/{iteration}/results.md`

**Key findings:**
- Criteria met: {X of Y}
- Validation status: {PASS/FAIL}
- Files changed: {count}
- Ready for review: {YES/NO}

{If NO: Explain what's blocking}

**Next step:**
{If ready: Orchestrator should review results}
{If not ready: List what needs to be fixed}
```

---

## Important Notes

**Accuracy is critical:**
- Do NOT claim something is complete if it isn't
- Do NOT mark PASS if validation failed
- Do NOT hide issues or blockers
- Be honest about criteria not met

**E2E test reporting:**
- Do NOT report that E2E tests "could not run because servers weren't started"
- Do NOT claim E2E tests "require manual server startup" - they don't!
- The Playwright `webServer` config auto-starts frontend and backend servers
- If E2E tests failed, report the ACTUAL error (timeout, assertion failure, etc.)
- If servers failed to start, that IS a reportable error - but diagnose the root cause (port conflict, missing dependencies, etc.)

**Orchestrator relies on this:**
- Results.md is the primary artifact for review
- Orchestrator will cross-check against actual code
- Any inaccuracies will be caught during review

**Ready for review means:**
- All acceptance criteria met (or documented why not)
- Scoped validation passed
- No critical blockers
- Clear statement of what was accomplished

---

## Success Checklist

Before saving results.md, verify:

- [ ] Loaded iteration_plan.md for original criteria
- [ ] Verified test-output.txt exists and is complete
- [ ] Documented all changed files with rationale
- [ ] Accurately reported validation status (no exaggeration)
- [ ] Listed all known issues and incomplete items
- [ ] Clear YES/NO on "Ready for Review"
- [ ] Provided actionable next steps

---

**Remember:** This document will be read by the orchestrator during review. Accuracy and completeness are essential.
