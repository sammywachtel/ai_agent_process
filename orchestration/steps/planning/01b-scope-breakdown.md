# Step 01b: Scope Breakdown (Post-FAIL Gate)

**Model tier:** synthesis (orchestrator) + capable (reviewers)
**Tools needed:** Read, Write, Agent/Task
**Input:** Requirement file, scope-check output
**Output:** 
- `.run/planning/01b-breakdown.md` (breakdown summary)
- Parent breakdown file in requirements_docs
- Child requirement files in requirements_docs

---

## Instructions

Follow the standard breakdown process in **`process/scope-breakdown.md`**.

That document defines:
- Naming conventions for children
- The 5-phase breakdown process
- Validation requirements
- Failure modes

## Context for This Step

- **You are:** The planning coordinator's breakdown specialist
- **Your goal:** Split oversized requirements into executable children
- **Blocking gate:** All children must pass scope-sizing check

## When This Step Runs

This step runs ONLY when Step 01 (scope-check) returns `VERDICT: FAIL` and the user agrees to breakdown.

## Important: No Parent Work Folder

Do NOT create `.agent_process/work/{parent_scope}/`. The parent is being split — it won't be executed directly.

Only create:
- Child requirement files in `requirements_docs/`
- Parent breakdown file (`{id}-breakdown.md`)

Child work folders are created later when each child is planned.

## Orchestration Notes

For this orchestrated context, you have access to parallel sub-agents:

**Phase 1 (Architectural Review):** Spawn 2-3 capable reviewers in parallel
- Architect: structure, subsystem boundaries
- Dependency Analyst: internal dependencies, execution order
- Devil's Advocate: challenge assumptions, find hidden complexity

**Phase 4 (Validation):** Spawn cheap validators in parallel — one per child

## Output Location

Write summary to: `.run/planning/01b-breakdown.md`

Use the output format from `process/scope-breakdown.md`, plus:

```markdown
## Orchestration Details

**Architectural Reviewers:** {list}
**Review Outcome:** {APPROVED for split / ISSUES FOUND}

**Validation Cycles:** {0, 1, or 2}
**Final Status:** ALL CHILDREN PASS

## Next Steps

Each child can now be planned independently:
1. Start a new orchestrator session
2. Load `orchestration/plan-scope.md` with the child scope name

Recommended execution order: {list}
```

## Prohibitions

- **Do NOT commit** — creates files but does not commit
- **Do NOT push** to remote
- User decides when to commit breakdown artifacts
