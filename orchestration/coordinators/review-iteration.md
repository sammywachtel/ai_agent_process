# Review Iteration Coordinator (Lean)

Review a completed iteration in 3 steps instead of 10.

## Prohibitions

- Do NOT commit, push, or modify application code during review
- Review artifacts go to `.run/review/` only

## Model Tiers

| Tier | Use For |
|------|---------|
| **cheap** | File reads, gate counting, validation checks |
| **capable** | Code verification, doc verification, criteria evaluation |
| **synthesis** | The 4-choice decision — HIGH STAKES, use best model |

## Local Environment Instructions

Read `.agent_process/process/local_environment_instructions.md` before starting. Pass relevant content to sub-agents if any section is not `<none>`.

---

## Step 0: Resolve Input

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh resolve-input "{{input}}"
```

Returns: `scope`, `iteration`, `gh_issue`. Use these values throughout.

**Iteration Resolution:**
1. If `iteration` is non-null → use it (tracker's current iteration)
2. If `iteration` is null → list `.agent_process/work/{scope}/iteration_*` directories and use the **latest** one (sort alphanumerically, e.g., `iteration_01_c` > `iteration_01_b` > `iteration_01`)
3. If user manually specified a different iteration than resolved → **STOP and ask** which to review

**GH Issue status (if gh_issue is set):**
```bash
bash .agent_process/scripts/github-issues-lifecycle.sh set-status {scope} reviewing
```

---

## Step 1: Verify Implementation

Spawn **capable** agent:

```
Agent({
  description: "Verify {scope}/{iteration}",
  prompt: "Read orchestration/steps/review/01-verify.md and execute.
    Scope: {scope}
    Iteration: {iteration}
    
    Load context, evaluate criteria, verify code matches claims.
    Check if executor understood semantic intent, not just made mechanical changes.
    Output: .run/review/01-verify.md"
})
```

---

## Step 2: Quality Gates

Spawn **capable** agent:

```
Agent({
  description: "Gates for {scope}/{iteration}",
  prompt: "Read orchestration/steps/review/02-gates.md and execute.
    Scope: {scope}
    Iteration: {iteration}
    Input: .run/review/01-verify.md
    
    Run documentation, integration, adversarial, and validation gates.
    Fast-track if internal-only changes.
    Output: .run/review/02-gates.md"
})
```

---

## Step 3: Decision + Actions

Spawn **synthesis** (best model) agent:

```
Agent({
  description: "Decision for {scope}/{iteration}",
  prompt: "Read orchestration/steps/review/03-decide.md and execute.
    Scope: {scope}
    Iteration: {iteration}
    Inputs: .run/review/01-verify.md, .run/review/02-gates.md
    
    Choose APPROVE/ITERATE/BLOCK/PIVOT.
    For ITERATE: specify fixes with semantic intent and outcome-based tests.
    Output: .run/review/03-decision.md"
})
```

---

## Post-Decision (after human approval)

Based on decision in `.run/review/03-decision.md`:

**APPROVE:**
```bash
bash .agent_process/scripts/github-issues-lifecycle.sh set-status {scope} approved
bash .agent_process/scripts/github-issues-lifecycle.sh close {scope} approved
```

**ITERATE:**
```bash
bash .agent_process/scripts/github-issues-lifecycle.sh set-status {scope} iterate
mkdir -p .agent_process/work/{scope}/{next_iteration}
# Copy fix specifications to next iteration's plan
bash .agent_process/scripts/github-issues-lifecycle.sh set-iteration {scope} {next_iteration}
```
If human checkpoint needs change (prereqs satisfied, or new checkpoint needed), update `.agent_process/work/{scope}/human-prereqs.md`.

Then: `/ap_exec {scope} {next_iteration}`

**BLOCK:**
```bash
bash .agent_process/scripts/github-issues-lifecycle.sh set-status {scope} blocked
bash .agent_process/scripts/github-issues-lifecycle.sh close {scope} blocked
```
Present options to human.

**PIVOT:**
```bash
bash .agent_process/scripts/github-issues-lifecycle.sh comment {scope} "Scope pivoted: {reason}"
```
No close — new scope takes over.

---

## Completion

Verify outputs exist:
- `.run/review/01-verify.md`
- `.run/review/02-gates.md`
- `.run/review/03-decision.md`

Present decision to user. Wait for approval before executing post-decision actions.
