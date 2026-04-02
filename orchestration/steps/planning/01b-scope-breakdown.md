# Step 01b: Scope Breakdown (Post-FAIL Gate)

**Model tier:** synthesis (orchestrator) + capable (reviewers)
**Tools needed:** Read, Write, Agent/Task
**Input:** Requirement file, scope-check output (`.run/planning/01-scope-check.md`)
**Output:** 
- `.run/planning/01b-breakdown.md` (breakdown summary)
- Parent breakdown file in requirements_docs
- Child requirement files in requirements_docs

---

## When This Step Runs

This step runs ONLY when Step 01 (scope-check) returns `VERDICT: FAIL`. The orchestrator should offer to run this automated breakdown process.

## Important: No Parent Work Folder

Do NOT create `.agent_process/work/{parent_scope}/`. The parent scope is being broken down — it will never be executed directly. Only create:
- Child requirement files in `requirements_docs/`
- Parent breakdown file (`{id}-breakdown.md`) in `requirements_docs/`
- Child work folders are created later when each child is planned via `plan-scope`

---

## Naming Convention (CRITICAL)

**Child scopes MUST follow this pattern:**

```
{original_requirement_id}-01.md
{original_requirement_id}-02.md
{original_requirement_id}-03.md
```

**Example:**
- Original: `phase_07_user_log_auto_linking.md`
- Children:
  - `phase_07_user_log_auto_linking-01.md` (NOT `phase_07_user_log_entity_linking.md`)
  - `phase_07_user_log_auto_linking-02.md` (NOT `phase_07_user_log_review_experience.md`)
  - `phase_07_user_log_auto_linking-03.md`

**Rationale:** Descriptive names are tempting but break traceability. Sequential suffixes:
1. Make parent-child relationships obvious
2. Preserve git history continuity
3. Prevent naming bikeshedding
4. Make dependency graphs readable

**The parent file becomes:** `{original_requirement_id}-breakdown.md`

---

## Process Overview

```
┌──────────────────────────────────────────────────────────────────┐
│  1. ARCHITECTURAL REVIEW (before any splitting)                  │
│     - Review entire requirement for soundness                    │
│     - Identify internal dependencies                             │
│     - Flag architectural issues that affect ALL splits           │
│     - Document decisions that apply to all children              │
├──────────────────────────────────────────────────────────────────┤
│  2. DEPENDENCY MAPPING                                           │
│     - Map criteria to subsystems                                 │
│     - Identify cross-cutting concerns                            │
│     - Determine split boundaries                                 │
│     - Define execution order (if dependencies exist)             │
├──────────────────────────────────────────────────────────────────┤
│  3. CREATE CHILD REQUIREMENTS (DRAFT)                            │
│     - Generate {id}-01.md, {id}-02.md, etc.                      │
│     - Each child is a valid, standalone requirement              │
│     - Include `split_from:` and `depends_on:` frontmatter        │
├──────────────────────────────────────────────────────────────────┤
│  4. VALIDATE CHILDREN (scope-check each one)            ◄── NEW  │
│     - Run 01-scope-check against EACH child                      │
│     - If ANY child fails → adjust breakdown, re-validate         │
│     - Loop until ALL children pass or escalate to human          │
│     - Max 2 adjustment cycles before escalation                  │
├──────────────────────────────────────────────────────────────────┤
│  5. FINALIZE CHILDREN + CREATE PARENT BREAKDOWN FILE             │
│     - Move draft children to final location                      │
│     - Rename original to {id}-breakdown.md                       │
│     - Add coverage map                                           │
│     - Preserve original content for reference                    │
├──────────────────────────────────────────────────────────────────┤
│  6. GITHUB ISSUES (if enabled)                                   │
│     - Call lifecycle.sh split to close parent, create children   │
└──────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Architectural Review (REQUIRED)

Before splitting, spawn 2-3 **capable** reviewers in parallel to analyze the WHOLE requirement:

### Reviewer Roles

| Reviewer | Focus |
|----------|-------|
| **Architect** | Overall structure, subsystem boundaries, technical feasibility |
| **Dependency Analyst** | Internal dependencies, execution order, integration points |
| **Devil's Advocate** | Challenge assumptions, identify risks, find hidden complexity |

### Reviewer Questions

Each reviewer answers:

1. **Is this requirement sound?** Any contradictions, undefined terms, or impossible criteria?
2. **What are the internal dependencies?** Which criteria must come before others?
3. **Are there cross-cutting concerns?** Things that affect ALL children (e.g., a shared schema)?
4. **What's the natural split boundary?** Data layer vs API vs UI? Phase 1 vs Phase 2?
5. **Are there deferred/out-of-scope items?** Things to explicitly exclude from ALL children?

### Architectural Decisions Document

Synthesize reviewer feedback into decisions that apply to ALL children:

```markdown
## Architectural Decisions (from Breakdown Review)

1. **{Decision}** — {rationale}
2. **{Decision}** — {rationale}

## Cross-Cutting Concerns

- {Concern}: handled in {child-N}
- {Concern}: deferred to {future scope}

## Execution Order

1. {child-01}: {reason it's first — e.g., "establishes schema"}
2. {child-02}: {depends on child-01 because...}
3. {child-03}: {can run in parallel with child-02}
```

---

## Phase 2: Dependency Mapping

Create a mapping table:

```markdown
## Criteria to Child Mapping

| Criterion | Child | Depends On | Notes |
|-----------|-------|------------|-------|
| 1. User log table | -01 | — | Foundation |
| 2. Journal CRUD | -01 | — | Same child as schema |
| 3. Entity extraction | -02 | -01 | Needs entries to extract from |
| 4. Review UX | -03 | -02 | Needs entities to review |
```

**Rules for splitting:**
- Keep tightly coupled criteria together (same table + CRUD = same child)
- Backend before frontend (if they touch same data)
- Schema/foundation first, features second
- Each child must be independently shippable

---

## Phase 3: Create Child Requirements

For each child, create a file following this template:

```markdown
---
id: {parent_id}-{NN}
type: requirement
category: {same as parent}
status: not_started
priority: {same as parent}
split_from: {parent_id}
depends_on: [{list of child IDs this depends on, if any}]
---

# {Parent Title} — Part {N}: {Brief Subtitle}

**Split from:** `{parent_id}` (see `{parent_id}-breakdown.md` for full context)

{If this child has dependencies:}
**Prerequisites:** {list what must be done first and why}

## Objective
{Focused objective for THIS child only}

## Technical Requirements
{Only the criteria assigned to this child}

## Success Criteria
{Only the criteria assigned to this child}

## Documentation Requirements
{Only docs relevant to this child}

## Files Expected to Change
{Scoped to this child}

## Architectural Context
{Copy relevant decisions from Phase 1 that affect this child}

---

*This requirement is part {N} of {total} from the breakdown of `{parent_id}`. See `{parent_id}-breakdown.md` for the complete original requirement and coverage map.*
```

---

## Phase 4: Validate Children (REQUIRED GATE)

**Before finalizing, validate EVERY child through the scope-check process.**

This prevents creating children that will immediately fail when planned. The breakdown isn't done until all children pass.

### Validation (Parallel Sub-Agents)

Spawn **cheap** sub-agents in parallel — one per child — to run scope-check simultaneously.

**IMPORTANT:** Validators must read `orchestration/scope-sizing-rules.md` for current thresholds. Do not hardcode values — the rules file is the source of truth.

1. **Spawn parallel validators:**
   ```
   For each child ({id}-01, {id}-02, {id}-03, ...):
     Spawn cheap sub-agent with:
       - Input: 
         - Child requirement file path
         - `orchestration/scope-sizing-rules.md` (for thresholds)
       - Task: Run scope-check logic from `orchestration/steps/planning/01-scope-check.md`
       - Check for `scope_override: true` in child frontmatter — if present, use Warning thresholds only
       - Output: PASS/FAIL/WARN + metrics (criteria count, file count, subsystem count)
   ```
   
   **Threshold reference (from scope-sizing-rules.md):**
   - Criteria: Target 3–7, Warning 8–10, Fail >10
   - Files: Target 4–10, Warning 11–15, Fail >15
   - Subsystems: Target 1–3, Warning 4, Fail >4
   
   **Override behavior:** If a child has `scope_override: true`, shift Fail thresholds to Warning (still flag but don't block).

2. **Wait for all to complete, then aggregate:**
   ```markdown
   | Child | Criteria | Files | Subsystems | Verdict |
   |-------|----------|-------|------------|---------|
   | -01   | 5        | 4     | 2          | PASS    |
   | -02   | 10       | 8     | 6          | FAIL    |
   | -03   | 4        | 3     | 1          | PASS    |
   ```

3. **If ANY child fails:**
   - Identify which child(ren) failed and why
   - Adjust the breakdown:
     - Split the failing child further (create -02a, -02b OR renumber as -02, -03, -04...)
     - Move criteria between children to rebalance
     - Create an additional child to absorb overflow
   - **Re-validate ALL children in parallel** (spawn new batch of sub-agents)
   - **Max 2 adjustment cycles** — if still failing after 2 adjustments, escalate to human

4. **If ALL children pass:** Proceed to Phase 5

### Adjustment Strategy

When a child fails, analyze the failure mode:

**Too many criteria (>7):**
- Split by layer (schema vs API vs UI)
- Split by feature cluster (group related criteria)
- Create a "foundation" child for shared infrastructure

**Too many subsystems (>3):**
- The child is doing too many different things
- Each child should focus on one cohesive area
- Cross-cutting concerns may need their own dedicated child

**Too many files (>12):**
- Often a symptom of too many subsystems
- Consider whether some files are actually in a different child's domain

### Example Adjustment

```
Initial breakdown (Phase 3):
  -01: schema + API + workers (FAIL: 10 criteria, 6 subsystems)
  -02: UI components (PASS)
  
Adjusted breakdown (after validation):
  -01: schema + migrations (PASS: 4 criteria, 2 subsystems)
  -02: API endpoints (PASS: 3 criteria, 1 subsystem)
  -03: workers + queues (PASS: 3 criteria, 2 subsystems)
  -04: UI components (PASS — renumbered from original -02)
```

### Output

Add validation results to `.run/planning/01b-breakdown.md`:

```markdown
## Child Validation

### Attempt 1
| Child | Criteria | Files | Subsystems | Verdict |
|-------|----------|-------|------------|---------|
| -01   | 10       | 8     | 6          | FAIL    |
| -02   | 4        | 3     | 1          | PASS    |

**Adjustment:** Split -01 into -01 (schema), -02 (API), -03 (workers). Renumbered original -02 to -04.

### Attempt 2 (Final)
| Child | Criteria | Files | Subsystems | Verdict |
|-------|----------|-------|------------|---------|
| -01   | 4        | 3     | 2          | PASS    |
| -02   | 3        | 2     | 1          | PASS    |
| -03   | 3        | 3     | 2          | PASS    |
| -04   | 4        | 3     | 1          | PASS    |

**All children validated. Proceeding to finalization.**
```

---

## Phase 5: Finalize Children + Create Parent Breakdown File

**Only run this phase after ALL children pass validation in Phase 4.**

Rename the original file to `{id}-breakdown.md` and prepend:

```markdown
---
id: {original_id}
type: breakdown
category: {original}
status: split
priority: {original}
children: [{id}-01, {id}-02, {id}-03]
---

# {Original Title} — BREAKDOWN

**Status:** This requirement was too large for a single scope. It has been split into smaller requirements.

## Child Requirements

1. `{id}-01.md` — {brief description}
2. `{id}-02.md` — {brief description}
3. `{id}-03.md` — {brief description}

## Execution Order

{From Phase 1/2, explain if children have dependencies or can run in parallel}

## Architectural Decisions

{Copy from Phase 1}

## Coverage Map

{Table showing which original criteria went to which child}

## Deferred Items

{Items explicitly excluded from all children, with rationale}

---

## Original Content

{Preserve the entire original requirement below for reference}

---

{original content here}
```

---

## Phase 6: GitHub Issues (if enabled)

If `quality-config.json` has `github_issues.enabled: true`:

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh split \
  {original_scope} \
  {original_scope}-01 \
  {original_scope}-02 \
  {original_scope}-03
```

This will:
- Close the parent issue with `status:split`
- Create child issues for each new scope
- Link children back to parent

---

## Output Format

Write to `.run/planning/01b-breakdown.md`:

```markdown
# Scope Breakdown Results

**Original Requirement:** {id}
**Reason for Split:** {from scope-check: criteria count, subsystems, etc.}

## Architectural Review

**Reviewers:** {list}
**Outcome:** {APPROVED for split / ISSUES FOUND}

### Key Decisions
{numbered list}

### Cross-Cutting Concerns
{list}

## Children Created

| Child | Description | Depends On | Criteria | Files | Subsystems |
|-------|-------------|------------|----------|-------|------------|
| {id}-01 | {description} | — | {N} | {N} | {N} |
| {id}-02 | {description} | -01 | {N} | {N} | {N} |

## Child Validation

**Adjustment cycles:** {0, 1, or 2}
**Final verdict:** ALL PASS

{Include validation table from Phase 4}

## GitHub Issues

{Created #N, #M, #O for children; closed #P as split}

## Next Steps

Each child can now be planned independently via `plan-scope`.
Recommended execution order: {list}
```

---

## Failure Modes

**Stop and escalate if:**
- Architectural review finds fundamental issues with the requirement itself
- Dependencies form a cycle (A needs B, B needs A)
- **Child validation fails after 2 adjustment cycles** — the requirement may be too complex to split mechanically
- Reviewers can't agree on split boundaries after 2 revision cycles
- Adjustment cycles create more than 6 children (indicates the original scope was massive)

---

## Prohibitions

- **Do NOT commit** — breakdown creates files but does not commit them
- **Do NOT push** to remote
- The user decides when to commit the breakdown artifacts
