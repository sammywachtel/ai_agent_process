# Execution Coordinator (Lean)

Execute an iteration in 2 preparation steps + implementation.

## Prohibitions

- Do NOT commit during execution — validation runs, then results documented
- Do NOT push to remote
- The user reviews and commits after successful iteration

---

## Step 0: Resolve Input

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh resolve-input "{{scope}}"
```

Use `scope` and `iteration` from result.

---

## Step 1: Preflight

Spawn **cheap** agent:

```
Agent({
  description: "Preflight {scope}/{iteration}",
  prompt: "Read orchestration/steps/execution/01-preflight.md and execute.
    Scope: {scope}
    Iteration: {iteration}
    
    Check branch, working state, git context.
    Output: .run/execution/01-preflight.md"
})
```

**Gate:** If `PREFLIGHT: BLOCKED`, stop and present options to user.

---

## Step 2: Prepare

Spawn **capable** agent:

```
Agent({
  description: "Prepare {scope}/{iteration}",
  prompt: "Read orchestration/steps/execution/02-prepare.md and execute.
    Scope: {scope}
    Iteration: {iteration}
    
    Load context, assess decomposition, select agent.
    For sub-iterations: extract semantic intent from each fix.
    Output: .run/execution/02-prepare.md"
})
```

---

## Step 3: Implement

Read `.run/execution/02-prepare.md` for agent selection and context.

### First Iteration

```
Agent({
  subagent_type: "{selected_agent}",
  description: "Implement {scope}/{iteration}",
  prompt: "Implement {scope}/{iteration}:
    1. Read iteration_plan.md for criteria and guidance
    2. Implement changes to meet acceptance criteria
    3. Add/update tests
    4. Update docs per plan

    **Scope boundaries are guidance, not walls.** If solving the problem
    correctly requires touching files outside the plan:
    - Do it if necessary for correctness
    - Document what you added and why in results.md
    - Update the validation script to cover new files
    - The reviewer will assess whether the expansion was justified

    You are the problem-solver. Meet the criteria correctly.
    Report completion status."
})
```

### Sub-iteration (semantic comprehension required)

```
Agent({
  subagent_type: "{selected_agent}",
  description: "Fix {scope}/{iteration}",
  prompt: "Fix issues for {scope}/{iteration}:

    BEFORE implementing, explain for EACH fix:
    - What is the underlying problem?
    - Why does this fix solve it?
    - What would fail if you made only the mechanical change?

    If you can't explain the semantic intent, STOP and ask.

    Then implement, and verify each fix's acceptance test passes.
    Report: comprehension summary, changes made, test results."
})
```

---

## Step 4: Validate

Hook fires automatically after edits. If fails, fix and retry (max 3 attempts).

Then run full validation:
```bash
bash .agent_process/scripts/after_edit/validate-{scope}.sh {scope} {iteration} \
  | tee .agent_process/work/{scope}/{iteration}/test-output.txt
```

---

## Step 5: Document Results

```
/ap_iteration_results {scope} {iteration}
```

Update GitHub issue status:
```bash
bash .agent_process/scripts/github-issues-lifecycle.sh set-status {scope} status:awaiting_review
```

---

## Completion

```markdown
## Iteration Complete: {scope}/{iteration}

**Criteria:** {N}/{total} addressed
**Validation:** {PASS/FAIL}
**Files Changed:** {count}

**Next:** Review with `orchestration/review-iteration.md`
```
