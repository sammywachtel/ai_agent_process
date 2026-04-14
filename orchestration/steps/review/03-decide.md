# Step 03: Decision + Actions

**Input:** `.run/review/01-verify.md`, `.run/review/02-gates.md`
**Output:** `.run/review/03-decision.md`

---

## Choose ONE Decision

### APPROVE
All criteria MET, gates PASS, no blockers.
→ Knowledge deposit, update requirement status, suggest release

### ITERATE  
Specific fixable issues AND attempts remaining (not at `_c`).
→ Create next iteration folder, write fix specifications

### BLOCK
External blocker, framework limitation, OR at `_c` with criteria not met.
→ Escalate to human with options

### PIVOT
Wrong approach, scope change needed.
→ Requires human approval before proceeding

---

## Fix Specifications (ITERATE only)

Each fix MUST include:

```markdown
**Fix N: {Title}**
- **File:** `path:NN-MM`
- **Before:** {current state}
- **After:** {required state}
- **Semantic Intent:** {WHY this solves the problem — the executor must understand this to implement correctly}
- **Acceptance Test:** {Outcome-based test proving the fix WORKS, not just that a change was made}
```

**Bad:** "Add checkout step" (mechanical)
**Good:** "Git operations must query ai-lab's history, not nap-gcp-platform's. The checkout alone doesn't change which repo's history is diffed." (semantic)

**Bad acceptance test:** "Checkout step added"
**Good acceptance test:** "Workflow no longer emits 'No changes' when ai-lab sources changed"

---

## Post-Decision Actions

### If APPROVE
1. Update `iteration_plan.md`: decision = APPROVE
2. Update requirement status to `approved`
3. Close scope tracking: `github-issues-lifecycle.sh close {scope} approved`
4. Deposit 0-3 learnings to knowledge base (if enabled)
5. Suggest: `/ap_release pr`

### If ITERATE
1. Create folder: `.agent_process/work/{scope}/{next_iteration}/`
2. Write `results.md` placeholder with fixes (include semantic intent!)
3. Update `iteration_plan.md`: latest iteration, decision = ITERATE
4. Advance tracking: `github-issues-lifecycle.sh set-iteration {scope} {next}`
5. Hand off: `/ap_exec {scope} {next_iteration}`

### If BLOCK
1. Update `iteration_plan.md`: decision = BLOCK, reason
2. Update requirement status to `blocked`
3. Close tracking: `github-issues-lifecycle.sh close {scope} blocked`
4. Present human decision options (ship as-is, pivot, abort)

### If PIVOT
1. Update `iteration_plan.md`: decision = PIVOT, proposed changes
2. Close tracking
3. Wait for human approval of scope change

---

## Output

```markdown
# Review Decision: {emoji} {DECISION}

**Iteration:** {scope}/{iteration}
**Attempt:** {N} of 4

## Evidence
- Criteria: {N}/{total} MET
- Gates: {summary}
- Validation: PASS/FAIL

## Rationale
{1-2 sentences — why this decision}

## Criteria Status
- {emoji} Criterion 1: {MET/PARTIAL/NOT MET}
- {emoji} Criterion 2: ...

## {ITERATE Fixes / BLOCK Reason / APPROVE Next Steps}

{For ITERATE: 1-3 fixes with semantic intent and outcome tests}
{For BLOCK: What's blocking, human options}
{For APPROVE: Knowledge deposited, release suggestion}

## Next Step
{Single clear action}
```
