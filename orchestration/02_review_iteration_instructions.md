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
→ Can APPROVE if all criteria met
→ MUST select BLOCK if criteria not met (escalate: ship as-is / change scope / abort)
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

### Step 3.5: Documentation Verification Gate

**Verify documentation was updated per CLAUDE.md "Zero Documentation Drift" rule:**

Per CLAUDE.md, documentation must be updated **in the same commit** as code changes. This is a **blocking requirement** for approval.

#### Documentation Checkpoint

Review the "Documentation Changes" section in `results.md`:

1. **Check dual-audience coverage:**
   - **End User Documentation**: Were user-facing docs updated (if needed)?
   - **Developer Documentation**: Were API/architecture docs updated (if needed)?

2. **Verify documentation matches code:**
   ```markdown
   ## Documentation Verification

   Code changes that typically require doc updates:
   - ✅ API endpoint added/changed → Reference docs updated?
   - ✅ Workflow modified → How-to guides updated?
   - ✅ Architecture decision → Explanation docs updated?
   - ✅ System replaced → Migration guide created?
   - ✅ Config option changed → Reference docs updated?
   - ✅ New dependency → README updated?

   Documentation actually updated (from results.md):
   - [List docs that were modified]

   Documentation gaps (if any):
   - [Missing updates that should have been made]
   ```

3. **Search for orphaned references:**
   ```bash
   # If code was renamed/removed, search for broken doc references
   grep -r "OldComponentName" docs/
   grep -r "/old/api/endpoint" docs/
   grep -r "deprecatedFunction" docs/
   ```

#### Documentation Gate Decision Criteria

**BLOCK iteration approval if:**
- ❌ Code changes external behavior (UI, API, config) AND no docs updated AND no explanation in results.md
- ❌ System migration completed but no migration guide created
- ❌ Breaking change introduced but no documentation of migration path
- ❌ New dependency added but README not updated
- ❌ Public API changed but no API reference docs updated
- ❌ results.md claims "no docs needed" but code review shows user-facing changes

**Allow iteration approval if:**
- ✅ Docs appropriately updated for both audiences (end users AND developers)
- ✅ Clear justification in results.md why no docs needed (with evidence)
- ✅ Internal-only changes with no external impact
- ✅ Documentation debt explicitly tracked with follow-up issue

#### Documentation Quality Check

If documentation was updated, verify:
- [ ] **Accuracy**: Docs reflect actual current behavior (not old behavior)
- [ ] **Examples**: Code examples compile/run with current version
- [ ] **Cross-references**: Links to related docs are valid
- [ ] **Diátaxis organization**: Docs placed in correct category (tutorial/how-to/reference/explanation)
- [ ] **Audience clarity**: Clear whether docs are for end users or developers
- [ ] **Migration path**: If breaking change, migration steps are clear

#### Fast-Track for Simple Cases

**If all true, documentation is likely adequate:**
- Internal refactor (no API/UI changes)
- Bug fix with no behavior change
- Test-only changes
- results.md explicitly notes "Internal implementation, no external impact"

**Otherwise, review documentation thoroughly.**

#### Include in Review Decision

Add documentation assessment to decision rationale:

```markdown
**Documentation Status:**
- ✅ End user docs updated: [List or "N/A - no user-facing changes"]
- ✅ Developer docs updated: [List or "N/A - internal only"]
- ✅ Documentation verified accurate with code changes
- Or: ⚠️ Documentation debt tracked in issue #123 with justification
- Or: ❌ Documentation gap - MUST address before APPROVE
```

**Why this matters:**
- CLAUDE.md mandates zero documentation drift
- Documentation is code - it must stay synchronized
- Both end users AND developers depend on accurate docs
- Open source projects: developer docs ARE user-facing docs
- Documentation debt compounds - catch it now when context is fresh

**For open source projects:**
Remember that API documentation, architecture guides, and integration docs are user-facing documentation for your developer audience. Treat them with the same importance as end-user docs.

---

### Step 3.6: Integration Verification Gate

**Verify that changes don't break integration points with related code outside scope:**

Per system reliability principles, changes to one component must maintain compatibility with connected components. This is a **blocking requirement** for approval.

#### Integration Checkpoint

**The problem:** Files in scope often interact with code NOT in scope. Changes can break these integration points even when in-scope validation passes.

**Common integration failures:**
- Frontend changes API call structure → Backend expects different schema
- Backend changes response format → Frontend can't parse response
- Component changes props interface → Parent components pass wrong props
- Service changes method signature → Callers use old signature
- Database schema changes → Queries use old column names
- Config changes → Consumers expect old config structure

#### Integration Verification Steps

For each file in scope, identify and check related code:

1. **Frontend ↔ Backend Integration:**
   ```markdown
   ## Frontend/Backend Integration Check

   Files in scope that make API calls:
   - [List frontend files that call backend APIs]

   For each API endpoint touched:
   - ✅ Request schema matches backend expectations
   - ✅ Response schema matches frontend usage
   - ✅ Error handling covers new error cases
   - ✅ Authentication/authorization requirements unchanged (or coordinated)

   Backend files checked (even if not in scope):
   - [List backend endpoints/controllers verified]

   Integration gaps (if any):
   - [Schema mismatches, contract violations]
   ```

2. **Component Interface Changes:**
   ```markdown
   ## Component Integration Check

   Components in scope with changed interfaces:
   - [List components with modified props/events/slots]

   For each interface change:
   - ✅ All call sites updated (search codebase)
   - ✅ Parent components pass correct props
   - ✅ Child components receive expected data
   - ✅ Event handlers match new signatures

   Related files checked (even if not in scope):
   - [List parent/child components verified]

   Integration gaps (if any):
   - [Call sites using old interface, prop mismatches]
   ```

3. **Database Schema Changes:**
   ```markdown
   ## Database Integration Check

   Schema changes in scope:
   - [List table/column changes, migrations]

   For each schema change:
   - ✅ All queries updated to use new schema
   - ✅ ORM models reflect new structure
   - ✅ Indexes still valid
   - ✅ Foreign key constraints maintained

   Query files checked (even if not in scope):
   - [List query files, repositories verified]

   Integration gaps (if any):
   - [Queries using old column names, missing migrations]
   ```

4. **Configuration Changes:**
   ```markdown
   ## Configuration Integration Check

   Config files changed in scope:
   - [List config files modified]

   For each config change:
   - ✅ All config consumers updated
   - ✅ Environment variables match
   - ✅ Deployment configs synchronized
   - ✅ Documentation reflects new config

   Consumer files checked (even if not in scope):
   - [List files that read these configs]

   Integration gaps (if any):
   - [Code expecting old config structure]
   ```

5. **Service/API Signature Changes:**
   ```markdown
   ## Service Integration Check

   Services/methods with changed signatures:
   - [List services with modified interfaces]

   For each signature change:
   - ✅ All callers use new signature
   - ✅ Return type matches caller expectations
   - ✅ Error handling updated for new exceptions

   Caller files checked (even if not in scope):
   - [List files that call these services]

   Integration gaps (if any):
   - [Callers using old signatures, missing parameters]
   ```

#### How to Check Integration Points

**Use these techniques to find related code:**

```bash
# Find API endpoint usages
grep -r "api/endpoint-path" frontend/src/

# Find component usages
grep -r "<ComponentName" frontend/src/
grep -r "from.*ComponentName" frontend/src/

# Find function call sites
grep -r "functionName(" src/

# Find config readers
grep -r "config\.settingName" src/

# Find database table references
grep -r "table_name" src/
```

**Manual verification:**
- Open related files and read the code
- Verify schema/interface compatibility
- Check that changes are coordinated
- Look for type mismatches, missing parameters

#### Integration Gate Decision Criteria

**BLOCK iteration approval if:**
- ❌ Frontend API call doesn't match backend endpoint schema
- ❌ Backend response format doesn't match frontend parsing
- ❌ Component interface changed but call sites use old interface
- ❌ Database schema changed but queries use old column names
- ❌ Service signature changed but callers use old signature
- ❌ Config changed but consumers expect old structure
- ❌ Integration verification not performed (no evidence in results.md)

**ITERATE if integration gaps found:**
- Specify exact files and lines that need coordination
- Include both in-scope and out-of-scope files in fix list
- Update validation script to include newly-identified files

**Allow iteration approval if:**
- ✅ All integration points verified compatible
- ✅ Coordinated changes documented (e.g., "backend PR #123 deployed first")
- ✅ No interface/schema changes (internal refactor only)
- ✅ Integration verification explicitly documented in results.md

#### Integration Quality Check

When integration points are identified, verify:
- [ ] **Bidirectional compatibility**: Both sides of integration checked
- [ ] **Type safety**: TypeScript/type checking passes across boundary
- [ ] **Runtime testing**: Integration tests or manual verification performed
- [ ] **Error scenarios**: Error handling compatible on both sides
- [ ] **Deployment coordination**: If changes must deploy together, documented

#### Fast-Track for Simple Cases

**If all true, integration verification likely not needed:**
- Internal implementation only (no API/interface changes)
- Test-only changes
- Documentation-only changes
- Bug fix with no signature/schema changes
- results.md explicitly notes "No integration points affected"

**Otherwise, perform integration verification thoroughly.**

#### Include in Review Decision

Add integration assessment to decision rationale:

```markdown
**Integration Status:**
- ✅ Frontend/backend schemas verified compatible
- ✅ Component interfaces checked across call sites
- ✅ Database queries updated for schema changes
- ✅ Related code verified: [list files checked]
- Or: ⚠️ Integration risk documented and accepted
- Or: ❌ Integration gap found - MUST address before APPROVE

**Files checked outside scope:**
- [List any files verified that weren't in original scope]
```

#### When to Expand Scope

**If you find integration issues in related code:**

1. **Use ITERATE decision** with specific fixes
2. **Include out-of-scope files in fix list:**
   ```markdown
   Required fixes:
   1. In frontend/src/api/client.ts (IN SCOPE), change request to {...}
   2. In backend/src/routes/api.py (OUT OF SCOPE), update endpoint to {...}
   ```
3. **Update validation script** to include newly-identified files
4. **Document scope expansion** in iteration_plan.md

**Why this matters:**
- Integration bugs are the hardest to debug in production
- Schema mismatches cause runtime errors, not compile errors
- Frontend/backend drift creates silent failures
- Catching integration issues early saves hours of debugging
- Scoped validation can pass while breaking production

**Real-world example that motivated this gate:**
- Frontend changed API call structure
- Backend code not in scope, so not checked
- Validation passed (frontend code was correct)
- Runtime failure: backend expected different schema
- Required emergency fix after merge

**Remember:** Changes don't exist in isolation. Always check the integration points.

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

**For shared-API scopes:** Confirm `results.md` shows the recorded contract snapshot, backend guard tests, and validation evidence for each consumer (type-check output, targeted tests, manual proof). Missing artifacts → ITERATE.

---

### Step 5: Count Remaining Attempts

**Based on current iteration name:**

| Current Iteration | Attempts Used | Remaining | Can ITERATE? |
|-------------------|---------------|-----------|--------------|
| iteration_01 | 1 of 4 | 3 (a,b,c) | Yes |
| iteration_01_a | 2 of 4 | 2 (b,c) | Yes |
| iteration_01_b | 3 of 4 | 1 (c) | Yes |
| iteration_01_c | 4 of 4 | 0 | No - Can APPROVE if criteria met |

**If iteration_01_c:**
- Cannot select ITERATE (no _d iteration)
- Can select APPROVE if all criteria met
- Must select BLOCK if criteria not met (escalate to human)

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

**Documentation Status:**
[Summary of Step 3.5 findings - docs updated or justification why not needed]

**Integration Status:**
[Summary of Step 3.6 findings - integration points verified or fast-tracked]
- Related code checked: [list files outside scope that were verified]
- Frontend/backend compatibility: [verified/N/A]
- Component interfaces: [verified/N/A]

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

**Documentation Status:**
[Summary of Step 3.5 findings - what docs need updating]

**Integration Status:**
[Summary of Step 3.6 findings - what integration gaps found]
- Related code checked: [list files outside scope that were verified]
- Integration gaps: [list schema mismatches, interface incompatibilities]

**Rationale:**
[1-2 sentences explaining specific issues]

**Required fixes (max 3):**
1. [Specific fix with file:line, before/after, acceptance test]
2. [Specific fix with file:line, before/after, acceptance test - may include OUT OF SCOPE files]
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
- **OR attempts exhausted AND criteria not met (iteration_01_c)**

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
- Already used 4 attempts AND criteria not met (iteration_01_c)
- External issue blocks progress

**Note:** If iteration_01_c meets all criteria, use APPROVE instead of BLOCK

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

**If ITERATE requires changes to different files, update validation script:**

If your required fixes touch NEW files not in the original scope:

1. **Update `.agent_process/scripts/after_edit/validate-<scope>.sh`:**
   ```bash
   # Add new files to FILES_TO_LINT array
   FILES_TO_LINT=(
     "path/to/original-file1.tsx"
     "path/to/original-file2.ts"
     "path/to/new-file-from-fix.tsx"  # Added for iteration_01_a fix #2
   )

   # Add new test patterns if needed
   TEST_PATTERNS=(
     "OriginalTestSuite"
     "NewTestSuite"  # Added for iteration_01_a fix #3
   )
   ```

2. **Update iteration_plan.md Files in Scope section:**
   ```markdown
   ## Files in Scope
   - `path/to/original-file1.tsx`
   - `path/to/original-file2.ts`
   - `path/to/new-file-from-fix.tsx` *(added iteration_01_a)*

   **Total:** X files
   ```

3. **Document the change:**
   Add a note to iteration_plan.md explaining why scope expanded:
   ```markdown
   ## Scope Changes
   - **iteration_01_a:** Added `new-file.tsx` to validation (required for Fix #2)
   ```

**When NOT to update validation script:**
- Fixes are in already-scoped files → No change needed
- Fixes are documentation/comments only → No change needed

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

**After APPROVE is confirmed, suggest the release workflow:**
```markdown
## Ready for Release

The scope work is approved. To update the changelog and create a PR, run:

`/ap_release <mode>`

**Mode options:**
- `pr` - Update changelog under [Unreleased], create PR, no tag
- `beta` - Move [Unreleased] to beta version, create beta tag (vX.Y.Z-beta.N), create PR
- `release patch|minor|major` - Move [Unreleased] to new version, tag release

**Recommended for this scope:**
- If this is ongoing work (more scopes coming): `/ap_release pr`
- If ready for user testing: `/ap_release beta`
- If ready to ship:
  - Bug fixes only → `/ap_release release patch`
  - New features → `/ap_release release minor`
  - Breaking changes → `/ap_release release major`
```

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

### Step 9: Update Requirements Doc Status (APPROVE or BLOCK only)

**When scope reaches terminal state (APPROVE or BLOCK), update the original requirements document:**

1. **Read the requirements source path** from `iteration_plan.md` → "Requirements Source" section

2. **Update the top-level status field** (if present):
   - Search for line matching `**Status:** TODO`, `**Status:** IN_PROGRESS`, or `**Status:** COMPLETED`
   - Replace with `**Status:** APPROVED` (for APPROVE) or `**Status:** BLOCKED` (for BLOCK)

3. **Append detailed status section** to the requirements document:

**For APPROVE:**
```markdown
---

## Implementation Status

**Status:** ✅ APPROVED
**Date:** YYYY-MM-DD
**Work Folder:** `.agent_process/work/<scope_name>`
**Iterations Used:** X of 4

**Summary:**
[Brief description of what was implemented]

**Notes:**
[Any deviations from original requirements, or follow-up work needed]
```

**For BLOCK:**
```markdown
---

## Implementation Status

**Status:** 🚫 BLOCKED
**Date:** YYYY-MM-DD
**Work Folder:** `.agent_process/work/<scope_name>`
**Iterations Used:** X of 4

**Blocker:**
[Description of what blocked completion]

**Partial Work:**
[What was completed before blocking, if anything]

**Recommendations:**
[Next steps - split scope, address blocker, or abandon]
```

4. **Why this matters:**
   - Creates bidirectional traceability (requirements ↔ work)
   - Top-level status enables quick scanning of requirements status
   - Detailed Implementation Status preserves context and decisions
   - Future planners can see which requirements are done
   - Prevents duplicate work on completed requirements
   - Documents decisions for historical reference

**Note:** If the requirements doc doesn't have a top-level `**Status:**` field, skip step 2 and just append the detailed Implementation Status section.

---

## Decision Matrix (Quick Reference)

| Situation | Decision | Next Step |
|-----------|----------|-----------|
| All criteria met (any iteration) | ✅ APPROVE | Mark complete, next iteration/scope |
| Fixable issues, attempts left | 🔄 ITERATE | Create sub-iteration (a/b/c) |
| External blocker | 🚫 BLOCK | Escalate to human |
| Wrong approach | 🔀 PIVOT | Get human approval for change |
| Criteria not met after iteration_01_c | 🚫 BLOCK | Escalate to human (attempts exhausted) |
| Criteria need change mid-iteration | 🔀 PIVOT | Get human approval |

---

## Common Review Mistakes (Avoid These)

### ❌ Creating iteration_01_d
- Iteration budget is max 3 sub-iterations (a/b/c)
- After iteration_01_c: Can APPROVE if criteria met, must BLOCK if not (cannot ITERATE to _d)

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
- [ ] Verified documentation updates (Step 3.5)
- [ ] Verified integration points with related code (Step 3.6)
- [ ] Checked frontend/backend schema compatibility (if applicable)
- [ ] Checked component interface compatibility (if applicable)
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
