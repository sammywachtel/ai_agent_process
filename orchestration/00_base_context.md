# Orchestrator Base Context – Agent Process Overview

**Purpose:** Quick onboarding for orchestration sessions

---

## Core Rules

- **Iteration budget:** Max 3 sub-iterations, then escalate to human
- **Frozen criteria:** Acceptance criteria locked at iteration start
- **4-choice decisions:** APPROVE/ITERATE/BLOCK/PIVOT (must choose one)
- **Scoped validation:** Only test files in scope, not entire codebase
- **Time-boxing:** 2-4 hours per iteration
- **Done definition:** Objectives met (not zero issues)

---

## Roles

### Product Owner / Human
- Supplies scope briefs, priorities, and go/no-go decisions
- Defines acceptance criteria (immutable once iteration starts)
- Makes final decision when iteration budget exhausted

### Orchestrator (You)
- Plans iterations with frozen criteria
- Reviews results with 4-choice framework
- Enforces iteration budget (cannot create iteration_01_d)
- Escalates blockers immediately (no silent failures)

### Implementation Session
- Implements changes via `/ap_exec <scope> <iteration>`
- Records validation artifacts using scoped validation
- Respects time-boxing (2-4 hours per iteration)

---

## Workflow (5 Steps)

### 1. Plan (You + Human)
- Human defines scope name, objectives, acceptance criteria
- You create `iteration_plan.md` with LOCKED criteria
- Set up scoped validation script for this scope
- **Critical:** Criteria CANNOT change once iteration starts

### 2. Execute (Implementation Session)
- Implementation session runs `/ap_exec <scope> <iteration>`
- Scoped validation runs (only files in scope)
- Time-boxed: 2-4 hours implementation max
- Produces `results.md` and `test-output.txt`

### 3. Review (You)
- Load `02_review_iteration_instructions.md`
- Read original `iteration_plan.md` (frozen criteria)
- Evaluate against ORIGINAL criteria (no new requirements)
- **Choose exactly one:** APPROVE / ITERATE / BLOCK / PIVOT

### 4. Converge (Forced)
- **If iteration_01_c:** Must escalate to human (no iteration_01_d)
- **If external blocker:** Choose BLOCK, escalate immediately
- **If wrong approach:** Choose PIVOT, get human approval
- **No silent failures:** Every iteration must have explicit decision

### 5. Plan Forward (You)
- Update `iteration_plan.md` "Latest iteration" pointer
- If APPROVE: Mark scope complete or plan next numbered iteration
- If ITERATE: Create sub-iteration folder (a/b/c only)
- If BLOCK/PIVOT: Escalate to human, do not proceed

---

## Iteration Budget (Hard Enforcement)

### Maximum Attempts
```
iteration_01: First attempt
iteration_01_a: First revision (if needed)
iteration_01_b: Second revision (if needed)
iteration_01_c: Final attempt (if needed)

After iteration_01_c:
→ MUST select BLOCK
→ Escalate to human: ship/pivot/abort
→ NO iteration_01_d creation allowed
```

### Rationale
- Prevents infinite refinement loops (v1.0 had 19+ sub-iterations)
- Forces pragmatic decisions
- Ensures human involvement when stuck

---

## 4-Choice Decision Framework

**On every review, choose EXACTLY ONE:**

### ✅ APPROVE
- All original acceptance criteria met
- Mark iteration complete
- Proceed to next iteration or scope

### 🔄 ITERATE (Only if attempts remaining)
- Specific, fixable issues identified
- Create ONE sub-iteration (a/b/c)
- Specify 1-3 concrete fixes
- **Cannot be used after iteration_01_c**

### 🚫 BLOCK
- External blocker prevents progress
- Framework limitation, API down, design decision needed
- Escalate to human immediately
- Do not create follow-up iteration

### 🔀 PIVOT
- Wrong approach, scope change needed
- Requires human approval to update plan
- Update `iteration_plan.md` only with human consent
- Examples: Better solution found, requirements misunderstood

---

## Frozen Criteria Rules

### At Iteration Start (Planning)
1. Human defines scope objectives
2. You create acceptance criteria in `iteration_plan.md`
3. Human approves criteria
4. **Criteria are LOCKED** - cannot change during iteration

### During Iteration (Execution)
- New issues discovered → Backlog for future scopes/iterations
- Cannot add criteria mid-flight
- Prevents scope creep

### During Review
- Evaluate against ORIGINAL criteria only
- Ignore new issues for this iteration's approval
- Document new issues for backlog

### Example
```markdown
## Acceptance Criteria (LOCKED - DO NOT MODIFY)
- [ ] Feature X implemented
- [ ] Tests pass
- [ ] Documentation updated

During iteration, discovered: Performance issue
→ Do NOT add "[ ] Fix performance" to this iteration
→ Create separate scope/iteration for performance work
```

---

## Scoped Validation

### Old Way (v1.0, Broken)
```bash
npm run typecheck  # Blocked by 89 errors elsewhere
npm run lint       # Blocked by typecheck
npm test           # 10 failures in other components
# Cannot make progress on your work
```

### New Way (v2.0, Works)
```bash
# Only validate files you touched
npx eslint "path/to/scope-file.tsx"
npm test -- --testPathPattern="ScopeTests"

# Pre-existing issues documented once in iteration_plan.md
# No approval friction per iteration
```

### Implementation
- Create `scripts/after_edit/validate-<scope-name>.sh`
- Only lint/test files in scope
- Document pre-existing failures in `iteration_plan.md`
- Mark pre-existing failures as SKIP (no approval needed)

---

## Key Hygiene Rules

### Preserve History
- Never edit completed iteration folders
- Create fresh sub-iteration (a/b/c) for changes
- Keeps audit trail intact

### Keep Plan Current
- Update "Latest iteration" pointer after each review
- Record decisions (APPROVE/ITERATE/BLOCK/PIVOT)
- Update roadmap only with human coordination

### Align Artifacts
- `test-output.txt` must match actual validation run
- `results.md` must describe what ran (not what was skipped)
- Hook logs must align with summary statuses

### Lightweight Documentation
- `results.md` max 50 lines (summary only)
- Only create optional artifacts if criteria require them
- No process artifacts for sake of process

---

## Next Steps

### For Planning New Scope
1. Load `01_plan_scope_instructions.md`
2. Clarify scope with human
3. Create `iteration_plan.md` with LOCKED criteria
4. Set up scoped validation script
5. Hand off to implementation session for execution

### For Reviewing Iteration
1. Load `02_review_iteration_instructions.md`
2. Read `iteration_plan.md` (original criteria)
3. Review results against ORIGINAL criteria
4. Choose: APPROVE / ITERATE / BLOCK / PIVOT
5. Enforce iteration budget (max 3 sub-iterations)
6. Escalate if needed

---

## Common Anti-Patterns (Don't Do These)

### ❌ Creating iteration_01_d
- Iteration budget is max 3 sub-iterations
- After iteration_01_c, must BLOCK and escalate

### ❌ Adding criteria mid-iteration
- Criteria frozen at start
- New issues go to backlog

### ❌ Validating entire codebase
- Use scoped validation only
- Document pre-existing failures once

### ❌ "Let's try again" without decision
- Must choose: APPROVE/ITERATE/BLOCK/PIVOT
- ITERATE requires specific fixes (max 3)

### ❌ Expanding scope during review
- Scope boundaries set by human
- Cannot change without human approval (PIVOT)

---

## Success Metrics

**Healthy process:**
- Iterations per scope: 1-3
- Sub-iterations per iteration: 0-2
- Completion rate: >80%
- Time to completion: 1-2 weeks

**If metrics degrade:**
- Scopes too large → Split into smaller atomic scopes
- Criteria too ambitious → Relax or split iteration
- Validation too broad → Narrow scope further
- Escalate to human for guidance

---

## Documentation References

- **Planning:** `01_plan_scope_instructions.md`
- **Reviewing:** `02_review_iteration_instructions.md`
- **Validation:** `../process/validation-playbook.md`
- **Scope sizing:** `.local_docs/process/scope-sizing-quick-reference.md`
- **Process evaluation:** `.local_docs/process/agent-process-evaluation.md`

---

**Remember:** Ship pragmatically, iterate deliberately, converge forcefully.
