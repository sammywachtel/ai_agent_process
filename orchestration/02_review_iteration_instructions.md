# Instructions – Review Iteration Results

**Purpose:** Review iteration with iteration budget enforcement and 4-choice decisions

---

## CRITICAL: Iteration Budget Enforcement

### Hard Rules

**Maximum 3 sub-iterations:**
```
iteration_01   → First attempt
iteration_01_a → First revision (if ITERATE decision)
iteration_01_b → Second revision (if ITERATE decision)
iteration_01_c → Final attempt (if ITERATE decision)

After iteration_01_c:
→ MUST select BLOCK
→ Escalate to human: ship as-is / change scope / abort
→ NO iteration_01_d creation allowed
```

**Why:** Prevents infinite refinement (v1.0 had 19+ sub-iterations without completion)

---

## Review Steps

### Step 1: Load Context

**Open these files:**
1. `00_base_context.md` - Refresh on v2.0 rules
2. `.agent_process/work/<scope>/iteration_plan.md` - Original acceptance criteria (LOCKED)
3. `.agent_process/work/<scope>/<iteration>/results.md` - What was done
4. `.agent_process/work/<scope>/<iteration>/test-output.txt` - Validation results

**Determine iteration count:**
- `iteration_01` = Attempt 1 of 4
- `iteration_01_a` = Attempt 2 of 4
- `iteration_01_b` = Attempt 3 of 4
- `iteration_01_c` = Attempt 4 of 4 (final)

---

### Step 2: Evaluate Against ORIGINAL Criteria

**Compare results to LOCKED acceptance criteria in iteration_plan.md**

**CRITICAL RULES:**
- ✅ Evaluate against ORIGINAL criteria only
- ❌ Do NOT add new criteria discovered during iteration
- ❌ Do NOT expand scope based on new findings
- ✅ New issues go to backlog for future scopes

**Example:**
```markdown
Original Criteria (LOCKED):
- [ ] Feature X implemented
- [ ] Tests pass
- [ ] Documentation updated

During iteration, discovered:
- Performance issue
- Edge case bug
- Missing error handling

REVIEW DECISION:
→ Evaluate ONLY original 3 criteria
→ New issues go to backlog (NOT this iteration's criteria)
```

---

### Step 3: Review Actual Code (Code Verification)

**Before making decision, verify what was actually done:**

1. **Read files that were changed:**
   - Open each file listed in "Files in Scope"
   - Review the actual code changes
   - Compare to what results.md claims was done

2. **Cross-check documentation vs code:**
   ```markdown
   ## Code Verification

   Claimed in results.md:
   - [Claim 1 from results]
   - [Claim 2 from results]

   Actual changes found:
   - [What actually exists in code]
   - [Match or mismatch with claims]
   ```

3. **Technical assessment:**
   - Code quality: Clean, maintainable, follows patterns?
   - Test coverage: Do tests actually exercise the changes?
   - Architecture: Fits with existing codebase?
   - Completeness: Are changes actually complete?

4. **Document findings:**
   ```markdown
   ## Code Verification Results

   **Documentation accuracy:** [Match / Partial / Mismatch]

   **Code quality assessment:**
   - [Quality observation 1]
   - [Quality observation 2]

   **Completeness check:**
   - ✅ [Completed aspect]
   - ⚠️ [Incomplete aspect]
   - ❌ [Missing aspect]

   **Recommendation basis:**
   [Why APPROVE/ITERATE/BLOCK/PIVOT based on actual code, not just documentation]
   ```

**Why this matters:**
- Results.md is implementation session's self-report (may be incomplete/inaccurate)
- Code review provides ground truth
- Prevents approving work that wasn't actually done
- Catches quality issues early

**Include verification in decision:**
- Use code findings (not just documentation) to make decision
- Call out any discrepancies in review feedback
- Base recommendation on actual code state

---

### Step 4: Verify Scoped Validation

**Check that validation was scoped (not entire codebase):**

```markdown
Expected (scoped validation):
- Hook: validate-<scope-name> → PASS/FAIL
- Linted only files in scope
- Tested only scope-specific patterns

NOT expected (full validation):
- Full typecheck (has pre-existing errors)
- Full lint (blocked by typecheck)
- Full test suite (has unrelated failures)
```

**If full validation ran despite pre-existing debt:**
- Note in review: "Validation should be scoped, not full codebase"
- Don't block iteration for pre-existing failures

---

### Step 5: Count Remaining Attempts

**Based on current iteration name:**

| Current Iteration | Attempts Used | Remaining | Can ITERATE? |
|-------------------|---------------|-----------|--------------|
| iteration_01 | 1 of 4 | 3 (a,b,c) | Yes |
| iteration_01_a | 2 of 4 | 2 (b,c) | Yes |
| iteration_01_b | 3 of 4 | 1 (c) | Yes |
| iteration_01_c | 4 of 4 | 0 | No - Must BLOCK |

**If iteration_01_c:**
- Cannot select ITERATE
- Must select BLOCK and escalate to human

---

### Step 6: Choose Decision (4-Choice Framework)

**Select EXACTLY ONE:**

### ✅ APPROVE
**When to use:**
- All original acceptance criteria met
- Scoped validation passes
- No critical blockers

**Actions:**
1. Mark iteration complete in iteration_plan.md
2. Update "Latest iteration" to next iteration or "complete"
3. Proceed to next iteration/scope

**Output template:**
```markdown
## Review Decision: ✅ APPROVE

**Iteration:** <scope>/<iteration>
**Attempts used:** X of 4

**Code Verification:**
[Summary of Step 3 findings - what was actually changed]

**Rationale:**
[1-2 sentences explaining why criteria met]

**Criteria status:**
- ✅ Criterion 1 met
- ✅ Criterion 2 met
- ✅ Criterion 3 met

**Next step:**
[Mark scope complete OR proceed to iteration_02 OR hand to human]
```

---

### 🔄 ITERATE
**When to use:**
- Specific, fixable issues identified
- Original criteria not met
- **AND attempts remaining (not on iteration_01_c)**

**Actions:**
1. Create ONE sub-iteration folder (a/b/c)
2. Specify 1-3 concrete fixes (no more)
3. Update iteration_plan.md "Latest iteration"

**CRITICAL: Fix Specificity Requirements**

Each fix MUST include:
- ✅ Exact file path and small line range (<20 lines preferred)
- ✅ Specific action with before/after examples
- ✅ Clear acceptance test ("when done, X should show Y")

**Good fix examples:**
```markdown
1. In frontend/src/components/lexical/ui/StressContextMenu.tsx lines 83-96,
   replace direct node mutations with command dispatches:

   Before: node.setStressPattern(pattern)
   After:  editor.dispatchCommand(UPDATE_STRESS_PATTERN_COMMAND, {nodeKey, pattern})

   Acceptance: Grep should find no setStressPattern calls in StressContextMenu.tsx

2. In frontend/src/styles/prosody.css, add .rich-text-lyrics-editor prefix to:
   - Line 195: .stress-context-menu
   - Line 246: .stress-context-menu-item
   - Line 394: .stress-context-menu-button

   Example:
   Before: .stress-context-menu { position: absolute; }
   After:  .rich-text-lyrics-editor .stress-context-menu { position: absolute; }

   Acceptance: Grep "^\\.stress-context" should return 0 matches
```

**Bad fix examples (TOO VAGUE):**
```markdown
❌ "Scope the remaining prosody selectors"
   → Missing: which selectors? what line numbers? what does "scope" mean?

❌ "Refactor StressContextMenu to use commands"
   → Missing: which methods? what before/after looks like?

❌ "Fix CSS in prosody.css lines 152-399"
   → Missing: 247 line range is too broad! which specific lines?
```

**Output template:**
```markdown
## Review Decision: 🔄 ITERATE

**Iteration:** <scope>/<iteration>
**Attempts used:** X of 4
**Remaining attempts:** Y

**Code Verification:**
[Summary of Step 3 findings - what's incomplete/incorrect]

**Rationale:**
[1-2 sentences explaining specific issues]

**Required fixes (max 3):**
1. [Specific fix with file:line, before/after, acceptance test]
2. [Specific fix with file:line, before/after, acceptance test]
3. [Specific fix with file:line, before/after, acceptance test]

**Next iteration:** <scope>/<iteration>_{a/b/c}

**Next step:**
Create <next_iteration>/ folder and hand back to implementation session
```

**Cannot be used if:**
- Already at iteration_01_c (no attempts left)
- Issues are not fixable (use BLOCK instead)
- Scope needs change (use PIVOT instead)

---

### 🚫 BLOCK
**When to use:**
- External blocker prevents progress
- Framework limitation discovered
- API/service unavailable
- Design decision needed from human
- **OR attempts exhausted (iteration_01_c)**

**Actions:**
1. Stop immediately
2. Escalate to human
3. Do NOT create follow-up iteration
4. Document blocker clearly

**Output template:**
```markdown
## Review Decision: 🚫 BLOCK

**Iteration:** <scope>/<iteration>
**Attempts used:** X of 4
**Reason:** [External blocker / Attempts exhausted]

**Code Verification:**
[Summary of Step 3 findings - what was attempted]

**Blocker description:**
[Detailed explanation of what's blocking progress]

**Examples of blocker:**
- Lexical.js framework limitation with cursor positioning
- Backend API endpoint not available
- Architectural decision needed
- Iteration budget exhausted (4 attempts used)

**Human decision needed:**
- Ship current state as-is?
- Change scope to work around blocker?
- Abort scope entirely?

**Next step:**
Escalate to human for go/no-go decision
```

**Must be used if:**
- Already used 4 attempts (iteration_01_c)
- External issue blocks progress

---

### 🔀 PIVOT
**When to use:**
- Wrong approach identified
- Better solution found
- Requirements misunderstood
- Scope change needed

**Actions:**
1. Stop current iteration
2. Document why pivot needed
3. Propose scope change
4. **Get human approval** before updating plan
5. Update iteration_plan.md only with human consent

**Output template:**
```markdown
## Review Decision: 🔀 PIVOT

**Iteration:** <scope>/<iteration>
**Attempts used:** X of 4

**Code Verification:**
[Summary of Step 3 findings - why current approach isn't working]

**Reason for pivot:**
[Explanation of why current approach won't work]

**Proposed change:**
[What should change in scope/approach]

**Examples:**
- Requirements were misunderstood
- Better technical approach discovered
- Scope boundaries need adjustment

**Human approval required:**
- Approve proposed scope change?
- Update iteration_plan.md acceptance criteria?
- Continue with modified scope?

**Next step:**
Get human approval, then update iteration_plan.md and resume
```

**Must get human approval:**
- Cannot change scope without human consent
- Criteria were LOCKED by human

---

### Step 7: Document Decision

**Update iteration_plan.md:**
```markdown
## Current Status
- Latest iteration: <iteration_just_reviewed>
- Decision: APPROVE / ITERATE / BLOCK / PIVOT (date: YYYY-MM-DD)
- Next: [What happens next]
```

**If ITERATE, create follow-up folder:**
```bash
mkdir -p .agent_process/work/<scope>/<next_iteration>/

cat > .agent_process/work/<scope>/<next_iteration>/results.md <<EOF
# Iteration Results – <scope>/<next_iteration>

**Status:** TODO - Awaiting execution

**Required fixes from review:**
1. [Fix 1]
2. [Fix 2]
3. [Fix 3]

Run: /ap_exec <scope> <next_iteration>
EOF
```

**Update current iteration config:**
```bash
cat > .agent_process/work/current_iteration.conf <<EOF
SCOPE=<scope>
ITERATION=<next_iteration>
EOF
```

---

### Step 8: Plan Forward and Get Human Approval

**After providing your decision in Step 6, ask the human for approval to proceed:**

**If ITERATE:**
```
Should I proceed to create iteration_01_a folder and update iteration_plan.md?
```
On human approval:
- Create next iteration folder
- Populate placeholder results.md with required fixes
- Update iteration_plan.md "Current Status"
- Hand back to implementation session

**If APPROVE:**
```
Should I mark the scope complete and update iteration_plan.md?
```
On human approval:
- Update iteration_plan.md to mark scope complete
- Or plan next numbered iteration (iteration_02) if scope continues

**If BLOCK:**
```
This requires human decision - no further action from me.
```
- Escalate to human immediately
- Provide decision options (ship/pivot/abort)
- No iteration artifacts to create

**If PIVOT:**
```
Should I update iteration_plan.md with the proposed scope change (requires your approval first)?
```
- Get human approval for scope change FIRST
- Update iteration_plan.md only with approval
- Resume with modified scope

**Do NOT proceed with Steps 7-8 until human responds.**

---

## Decision Matrix (Quick Reference)

| Situation | Decision | Next Step |
|-----------|----------|-----------|
| All criteria met | ✅ APPROVE | Mark complete, next iteration/scope |
| Fixable issues, attempts left | 🔄 ITERATE | Create sub-iteration (a/b/c) |
| External blocker | 🚫 BLOCK | Escalate to human |
| Wrong approach | 🔀 PIVOT | Get human approval for change |
| 4 attempts used (iteration_01_c) | 🚫 BLOCK | Escalate to human |
| Criteria need change mid-iteration | 🔀 PIVOT | Get human approval |

---

## Common Review Mistakes (Avoid These)

### ❌ Creating iteration_01_d
- Iteration budget is max 3 sub-iterations (a/b/c)
- After iteration_01_c, must BLOCK and escalate

### ❌ Adding new criteria during review
- Criteria were LOCKED at iteration start
- New issues go to backlog, not this iteration

### ❌ "Let's try again" without specific fixes
- ITERATE requires 1-3 concrete fixes
- Cannot be vague ("fix issues")

### ❌ Blocking for pre-existing failures
- Scoped validation should only test in-scope files
- Pre-existing failures documented in iteration_plan.md

### ❌ Changing scope without human approval
- Use PIVOT, get approval, then update plan
- Cannot silently expand scope

### ❌ Evaluating against new requirements
- Review against ORIGINAL criteria only
- Ignore issues discovered during iteration

---

## Validation Checklist (Before Decision)

**Verify these before making decision:**

- [ ] Read original acceptance criteria (iteration_plan.md)
- [ ] Reviewed actual code changes (Step 3)
- [ ] Cross-checked results.md claims vs actual code
- [ ] Counted attempts used (1/2/3/4 of 4)
- [ ] Verified scoped validation (not full codebase)
- [ ] Checked for external blockers
- [ ] Evaluated against ORIGINAL criteria (not new ones)
- [ ] Chose exactly one: APPROVE/ITERATE/BLOCK/PIVOT
- [ ] If ITERATE: Specified 1-3 concrete fixes
- [ ] If ITERATE: Verified attempts remaining
- [ ] If BLOCK: Documented blocker clearly
- [ ] If PIVOT: Will get human approval before updating plan

---

## Success Metrics (Track These)

**After each review, note:**
- Iterations used: Target 1-3 per scope
- Sub-iterations: Target 0-2 per iteration
- Decision type: APPROVE rate should be >50%
- Time to completion: Target 1-2 weeks per scope

**If metrics degrade:**
- Too many ITERATE: Criteria too ambitious, split scope
- Too many BLOCK: External dependencies, address blockers
- Too many PIVOT: Unclear requirements, improve planning

---

## Documentation References

- **Base context:** `00_base_context.md`
- **Planning:** `01_plan_scope_instructions.md`
- **Validation patterns:** `../process/validation-playbook.md`
- **Scope sizing:** `.local_docs/process/scope-sizing-quick-reference.md`

---

**Remember:** Evaluate against ORIGINAL criteria, enforce iteration budget, make explicit decisions.
