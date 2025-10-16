---
name: /ap_exec
description: Execute one iteration - implement changes, validate, and document results
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

You are the implementation agent executing a planned iteration. Your job: read the plan, implement the changes, validate your work, and document the results.

## Workflow Overview

1. **Load Context** - Read the iteration plan
2. **Implement** - Make the code changes
3. **Validate** - Verify your work (hook fires automatically)
4. **Document** - Create results.md (via /ap_iteration_results)
5. **Report** - Summarize completion status

---

## Step 1: Load Context

**Read the iteration plan:**
```bash
.agent_process/work/{scope}/iteration_plan.md
```

**Extract from the plan:**
- Acceptance Criteria (LOCKED - these are your requirements)
- Technical Assessment (implementation guidance from orchestrator)
- Files in Scope (what you're allowed to change)
- Validation Requirements (how to verify your work)
- Out of Scope (what NOT to do)

**If this is a sub-iteration (iteration_01_a/b/c), ALSO read:**

Sub-iterations focus on specific fixes from orchestrator review. Load these additional files:

1. **Current iteration placeholder** (created by orchestrator):
   ```bash
   .agent_process/work/{scope}/{iteration}/results.md
   ```
   **Extract:**
   - Required fixes (1-3 specific issues to address)
   - What the orchestrator found incomplete

2. **Previous iteration results** (what was already tried):
   ```bash
   .agent_process/work/{scope}/{parent_iteration}/results.md
   ```
   Where `{parent_iteration}` is:
   - iteration_01_a → read iteration_01/results.md
   - iteration_01_b → read iteration_01_a/results.md
   - iteration_01_c → read iteration_01_b/results.md

   **Extract:**
   - What was already implemented (don't break these parts)
   - What didn't work (don't repeat mistakes)

**Focus for sub-iterations:**
- Address the 1-3 specific fixes from orchestrator review
- Build on what already works
- Don't re-attempt everything from scratch

**Check for vague instructions (CRITICAL):**

If the required fixes are too vague, STOP and ask the human for clarification.

**Vague indicators (ask for clarification):**
- ❌ Line ranges >50 lines (e.g., "lines 152-399")
- ❌ No before/after examples for CSS/markup changes
- ❌ Action verbs without specifics ("scope", "refactor", "improve")
- ❌ "Remaining" or "various" without enumeration
- ❌ Missing specific selector/method/variable names

**Good indicators (proceed):**
- ✅ Small line ranges (<20 lines)
- ✅ Concrete before/after examples
- ✅ Enumerated list of specific items
- ✅ Clear acceptance test provided

**If fixes are vague, respond:**
```markdown
⚠️ Cannot proceed - Required fixes are too vague:

Fix #N is unclear:
- What: [Quote the vague instruction]
- Missing: [What information is needed]

Please provide:
1. Exact line numbers or selector names
2. Before/after example showing the change
3. Clear acceptance test (e.g., "grep should show X")

Example of what I need:
[Provide a specific example based on the vague instruction]
```

**Only proceed if fixes are specific enough to execute confidently.**

**Create iteration folder if needed:**
```bash
mkdir -p .agent_process/work/{scope}/{iteration}
```

---

## Step 2: Implement Changes

**Work within the defined scope:**
- Implement ONLY what the acceptance criteria require
- Follow the Technical Assessment guidance
- Modify ONLY files listed in "Files in Scope"
- Do NOT expand scope beyond locked criteria

**Add/update tests:**
- Write tests for new functionality
- Update existing tests for modified behavior
- Ensure tests are comprehensive and meaningful

**Use Task tool for implementation:**

Launch a general-purpose Task agent to do the actual coding.

**For first iteration (iteration_01):**
```
Execute iteration work for {scope}/{iteration}:

1. Read iteration_plan.md for objectives and acceptance criteria
2. Follow the Technical Assessment implementation guidance
3. Implement all required code changes
4. Add or update automated tests
5. Perform manual spot checks to confirm behavior

Work directly on the code - do NOT launch additional subagents.
Report completion status when done.
```

**For sub-iterations (iteration_01_a/b/c):**
```
Execute iteration work for {scope}/{iteration}:

1. Read iteration_plan.md for original acceptance criteria
2. Read {iteration}/results.md for the 1-3 specific fixes required
3. Read {parent_iteration}/results.md to see what was already tried
4. Focus ONLY on addressing the specific fixes from orchestrator review
5. Build on what already works - don't break working parts
6. Add or update tests for the fixes
7. Perform manual spot checks to confirm fixes work

Work directly on the code - do NOT launch additional subagents.
Report completion status when done.
```

**Why use Task tool:**
- The SubagentStop hook fires automatically when Task completes
- Hook runs the scoped validation script (`.agent_process/scripts/after_edit/validate-{scope}.sh`)
- Provides immediate feedback on lint/test issues

---

## Step 3: Validate Your Work

**After Task completes, the hook has already run.**

**Where to find hook output:**
The SubagentStop hook runs automatically and its output appears in your terminal/chat immediately after the Task agent completes. Look for lines starting with:
```
[hook_after_edit] Running scoped validation for {scope}/{iteration}
[hook_after_edit] Running validate-{scope}.sh
```

**Check hook results:**
- **PASS**: Hook exits with code 0, you'll see `[hook_after_edit] Complete`
- **FAIL**: Hook exits non-zero, you'll see error output from ESLint or Jest

**If hook FAILED (exit non-zero):**
1. Scroll up in terminal to see the validation errors
2. Look for ESLint errors or test failures in the hook output
3. Fix the issues (lint errors, test failures)
4. Re-run the Task (maximum 3 attempts)
5. Each retry will re-trigger the hook
6. If still failing after 3 attempts, STOP and report blockers

**If hook PASSED (exit 0):**
- Proceed to Step 4 to capture the output

**Do NOT proceed until hook validation passes.**

---

## Step 4: Run Full Validation Commands

**Create test-output.txt with header:**
```bash
cat > .agent_process/work/{scope}/{iteration}/test-output.txt <<EOF
# Validation Results - {scope}/{iteration}

## Summary
- Scoped validation (hook): PENDING
- Manual verification: PENDING

## Detailed Logs

EOF
```

**Capture scoped validation results:**

The hook output is in your terminal/chat where the Task completed. To capture it:

1. Scroll up to find the hook output section (starts with `[hook_after_edit]`)
2. Copy the relevant output (ESLint results, Jest test results)
3. Append to test-output.txt:

```bash
cat >> .agent_process/work/{scope}/{iteration}/test-output.txt <<EOF

=== Scoped Validation ($(date -Iseconds)) ===
[Paste hook output here - the ESLint and Jest results]
EOF
```

4. Update the summary line:
```bash
# Change "PENDING" to "PASS (hook)"
sed -i '' 's/Scoped validation (hook): PENDING/Scoped validation (hook): PASS (hook)/' .agent_process/work/{scope}/{iteration}/test-output.txt
```

**Note:** If you cannot access the terminal output, the validation script can be re-run manually:
```bash
bash .agent_process/scripts/after_edit/validate-{scope}.sh {scope} {iteration}
```

**Run manual verification (if needed):**

If the iteration_plan.md specifies manual QA:
- Perform the manual tests
- Document findings in test-output.txt
- Update summary line

**Optional: Run broader validation commands**

The iteration_plan.md may list additional validation:
- Full test suite (if different from scoped tests)
- E2E tests for specific scenarios
- Visual checks

Run these if specified, append output to test-output.txt.

---

## Step 5: Document Results

**Call /ap_iteration_results to create results.md:**
```
/ap_iteration_results {scope} {iteration}
```

This command will:
- Read test-output.txt
- Generate results.md with structured summary
- List changed files
- Document validation status
- Note any known issues

**Do NOT create results.md manually** - let /ap_iteration_results do it.

---

## Step 6: Report Completion

**Provide summary to user:**

```markdown
## Iteration Complete: {scope}/{iteration}

**Acceptance Criteria Status:**
- [ ] Criterion 1: [Met/Not Met - brief note]
- [ ] Criterion 2: [Met/Not Met - brief note]
- [ ] Criterion 3: [Met/Not Met - brief note]

**Validation Status:**
- Scoped validation (hook): [PASS/FAIL]
- Manual verification: [PASS/FAIL/SKIPPED]

**Files Changed:** {count} files

**Known Issues:**
[List any issues discovered or criteria not met]

**Artifacts Created:**
- `.agent_process/work/{scope}/{iteration}/results.md`
- `.agent_process/work/{scope}/{iteration}/test-output.txt`

**Ready for Review:** [YES/NO - explain if NO]
```

**If validation failed or criteria not met:**
- Clearly state what's incomplete
- List specific blockers
- Do NOT claim iteration is ready for review

**If everything passed:**
- State that iteration is ready for orchestrator review
- Summarize what was accomplished

---

## Important Rules

**Scope boundaries:**
- Implement ONLY the locked acceptance criteria
- Do NOT expand scope based on "nice to have" findings
- New issues → backlog, not this iteration

**Validation enforcement:**
- Hook must PASS before proceeding to full validation
- Maximum 3 retry attempts on hook failures
- Stop and report if unable to pass validation

**No scope creep:**
- Acceptance criteria are FROZEN
- Cannot add new requirements mid-iteration
- Follow Technical Assessment guidance exactly

**Iteration budget:**
- This is attempt {iteration} (e.g., iteration_01, iteration_01_a)
- Maximum 3 sub-iterations (a/b/c) before escalation
- If you're on iteration_01_c, this is the final attempt

---

## Troubleshooting

**Hook keeps failing:**
- Review validation script at `.agent_process/scripts/after_edit/validate-{scope}.sh`
- Check that you're only modifying files in scope
- Verify tests are properly written and passing
- After 3 attempts, stop and report blocker

**Can't meet acceptance criteria:**
- Document specifically what's blocking progress
- Note in results.md "Known Issues" section
- Mark iteration as NOT ready for review
- Orchestrator will decide: ITERATE/BLOCK/PIVOT

**Discovered new issues:**
- Document in results.md "Known Issues" section
- Do NOT add to acceptance criteria
- These become backlog items for future scopes

---

## Success Checklist

Before reporting completion, verify:

- [ ] All acceptance criteria addressed (met or documented why not)
- [ ] Tests written/updated for changes
- [ ] Scoped validation (hook) PASSED
- [ ] test-output.txt contains validation results
- [ ] results.md created via /ap_iteration_results
- [ ] Only files in scope were modified
- [ ] No scope creep beyond locked criteria
- [ ] Clear statement of ready/not-ready for review

---

**Remember:** This is implementation only. Orchestrator review comes next.
