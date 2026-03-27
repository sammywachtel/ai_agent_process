# Execute Main — Implementation Prompt

You are the implementation agent. Preflight checks have already run — read their outputs from `.run/execution/` and proceed directly to implementation.

## Important: No BEADS Commands

BEADS lifecycle was handled in preflight (Step 0.5). Do not run `bd`, `bds`, or `beads-lifecycle.sh` during implementation. For work unit state updates during decomposed execution, use:
```bash
bash .agent_process/scripts/beads-lifecycle.sh task-update {scope} WU-NNN in-progress
bash .agent_process/scripts/beads-lifecycle.sh task-update {scope} WU-NNN complete
```

## Local Environment Instructions

If the preflight coordinator passed local environment context (from `.agent_process/process/local_environment_instructions.md`), apply it:
- **Validation Extensions:** Run additional validation commands in Step 4 alongside the standard scoped validation

These instructions are ADDITIVE — they augment but never skip default steps.

---

## Read Preflight Outputs

Before implementing, read these files from `.agent_process/work/{scope}/.run/execution/`:

1. **`.run/execution/01-context.md`** — acceptance criteria, implementation guidance, files in scope, validation commands
2. **`.run/execution/0125-decomposition.md`** — work unit DAG (or "skip" for single-pass)
3. **`.run/execution/015-agent-selection.md`** — which agent(s) to use
4. **`.run/execution/007d-git-context.md`** — recent changes to scope files (if pre-flight ran)

---

## Step 2: Implement Changes

**Work within the defined scope:**
- Implement ONLY what the acceptance criteria require
- Follow the Technical Assessment guidance from `.run/execution/01-context.md`
- Modify ONLY files listed in scope
- Do NOT expand scope — new issues go to backlog
- If a change requires an out-of-scope file, STOP and ask the user

**Launch the agent(s) from `.run/execution/015-agent-selection.md`:**

### Single Agent (most scopes)

```
Agent({
  subagent_type: "{selected_agent}",
  description: "Implement {scope} {iteration}",
  prompt: "Execute iteration work for {scope}/{iteration}:
    1. Read iteration_plan.md at .agent_process/work/{scope}/iteration_plan.md
    2. Review acceptance criteria (LOCKED)
    3. Follow the Technical Assessment implementation guidance
    4. Implement all required code changes
    5. Add or update automated tests
    6. Update documentation per iteration_plan.md 'Documentation in Scope' section
    7. Perform manual spot checks
    Work directly on the code — do NOT launch additional subagents.
    Report completion status when done."
})
```

### Sub-iteration Agent

For `_a`/`_b`/`_c` iterations, focus the agent on specific fixes:

```
Agent({
  subagent_type: "{selected_agent}",
  description: "Fix issues for {scope} {iteration}",
  prompt: "Execute fixes for {scope}/{iteration}:
    1. Read iteration_plan.md for full context
    2. Read {iteration}/results.md for 1-3 specific fixes required
    3. Read {parent_iteration}/results.md for what was already tried
    4. Focus ONLY on the specific fixes — don't redo working parts
    5. Add/update tests for the fixes
    Report which fixes were addressed and any remaining issues."
})
```

### Multi-Agent (decomposed scopes)

When `.run/execution/0125-decomposition.md` contains work units, spawn agents per the DAG:

- **Independent units:** Launch ALL in a single response (parallel)
- **Dependent units:** Wait for prerequisites to complete first
- Each agent gets ONLY its work unit's files — no overlap
- Update work unit tracking after each completes:
  ```bash
  bash .agent_process/scripts/beads-lifecycle.sh task-update {scope} WU-NNN complete
  ```

---

## Step 3: Validate Your Work

**After the implementation agent completes, the hook fires automatically.**

Look for output lines starting with:
```
[hook_after_edit] Running scoped validation for {scope}/{iteration}
```

- **PASS (exit 0):** Proceed to Step 4
- **FAIL (exit non-zero):** Fix issues and re-run the agent (max 3 attempts)

**Do NOT proceed until hook validation passes.**

---

## Step 4: Run Full Validation

Capture validation results in `test-output.txt`:

```bash
bash .agent_process/scripts/after_edit/validate-{scope}.sh {scope} {iteration} \
  | tee .agent_process/work/{scope}/{iteration}/test-output.txt
```

Run any additional validation commands from the iteration plan's "Validation Requirements" section. Append results to `test-output.txt`.

**Every iteration MUST produce its own `test-output.txt`** — even sub-iterations that only fix process artifacts. If no application code changed, run the validation script anyway (it should pass) and capture the output. If the validation script is irrelevant (e.g., evidence-repair pass), write a minimal file:

```bash
cat > .agent_process/work/{scope}/{iteration}/test-output.txt <<EOF
# Validation Results - {scope}/{iteration}

## Summary
- No application code changes in this sub-iteration
- Evidence-repair pass — see {parent_iteration}/test-output.txt for canonical validation
- Scoped validation: PASS (no code to validate)
EOF
```

The orchestrator's review gates check for this file. Missing it causes the adversarial review to flag incomplete evidence.

---

## Step 4.5: Adversarial Review (Fresh Agent)

**Check `quality-config.json`:** If `adversarial_review.enabled` is `false`, skip to Step 5.

**Skip if trivial:** Scopes with `trivial_threshold_files` or fewer changed files AND `trivial_threshold_criteria` or fewer criteria.

**Run the review:**

1. Get changed files:
   ```bash
   git diff --name-only HEAD~1..HEAD
   ```

2. Read the frozen criteria from the iteration plan

3. Spawn a fresh agent with zero implementation context:
   ```
   Agent({
     subagent_type: "general-purpose",
     description: "Adversarial review for {scope}",
     prompt: "You are a fresh adversarial reviewer. You have NO context about
       the implementation process.

       ACCEPTANCE CRITERIA:
       {paste frozen criteria from plan}

       CHANGED FILES:
       {paste git diff --name-only output}

       Read each changed file. For each criterion, produce PASS or FAIL
       with file:line evidence. Do NOT assess code quality — only spec compliance.
       Follow the verdict format in templates/adversarial-review-prompt.md."
   })
   ```

4. Save the verdict:
   ```bash
   # Write reviewer output to file for orchestrator
   cat > .agent_process/work/{scope}/{iteration}/adversarial-review.md <<EOF
   {reviewer verdict}
   EOF
   ```

---

## Step 5: Document Results

Call the results command:
```
/ap_iteration_results {scope} {iteration}
```

This creates `results.md` with structured summary. Do NOT create it manually.

After results.md is created, update requirement status to `completed` if ready for review (all criteria addressed), or leave as `in_progress` if not.

---

## Step 6: Report Completion

Provide summary to user:

```markdown
## Iteration Complete: {scope}/{iteration}

**Acceptance Criteria Status:**
- [ ] Criterion 1: [Met/Not Met]
- [ ] Criterion 2: [Met/Not Met]

**Documentation Updated:** [list or "None — internal change"]
**Validation:** Scoped hook [PASS/FAIL], Manual [PASS/FAIL/SKIPPED]
**Files Changed:** {count}
**Known Issues:** [list or none]
**Adversarial Review:** [PASS/FAIL per criterion or skipped]
**Ready for Review:** [YES/NO]

**Next step:** Open a fresh orchestrator session and load `orchestration/review-iteration.md` for {scope} {iteration}. There is no `/ap_review` command — review is a separate orchestrator session, not a slash command.
```

---

## Rules

- Acceptance criteria are FROZEN — no mid-iteration scope creep
- Maximum 3 retry attempts on validation failures
- New issues discovered → backlog, not this iteration
- Sub-iterations: max 3 per major iteration (_a, _b, _c)
- After 3 sub-iterations: must BLOCK (escalate to human)
- **There is no `/ap_review` command.** Review is done by loading `orchestration/review-iteration.md` in a fresh orchestrator session. Do not suggest `/ap_review`.
- Orchestrator review comes next — this is implementation only
