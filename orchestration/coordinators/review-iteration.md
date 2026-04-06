# Review Iteration Coordinator

You are the orchestrator reviewing a completed iteration. Execute each step by spawning focused sub-agents. The decision step (06) is the highest-stakes step in the entire AP workflow — use the best available model.

## Prohibitions

- **Do NOT commit** during review — artifacts are created but not committed
- **Do NOT push** to remote
- **Do NOT modify application code** — only create review artifacts in `.agent_process/`
- The user decides when to commit review artifacts

## GitHub Issues: Verify and Transition

**GitHub Issues:** Follow `process/github-issues-handling.md` for all issue operations.

Issue verification happens in Step 1.5. Post-decision label transitions and issue close happen in Steps 07-10. Review sub-agents do NOT call lifecycle commands directly.

## Inputs (Flexible)

The user can provide ANY of these input formats:
- **GitHub issue number:** `#123`, `123`, or full URL (`https://github.com/owner/repo/issues/123`)
- **Scope name:** `my_feature_scope`

**Step 0.0: Resolve Input**

Run this command FIRST to resolve the input to structured scope info:

```bash
bash .agent_process/scripts/github-issues-lifecycle.sh resolve-input "{{input}}"
```

This returns JSON:
```json
{
  "scope": "my_feature_scope",
  "requirement_path": ".agent_process/requirements_docs/category/my_feature_scope.md",
  "gh_issue": "123",
  "input_type": "issue"
}
```

Use these values:
- **Scope:** Use `scope` from the JSON
- **Iteration:** provided separately (e.g., `iteration_01`, `iteration_01_a`)
- **Run directory:** `.agent_process/work/{scope}/.run/review/`

## Model Tiers

| Tier | Use For | Claude Code | Codex |
|------|---------|-------------|-------|
| **cheap** | File reads, gate counting, validation checks | haiku | gpt-5.4-mini |
| **capable** | Code verification, doc verification, criteria evaluation | sonnet | gpt-5.4 |
| **synthesis** | The 4-choice decision — HIGH STAKES, use best model | opus | gpt-5.4 |

---

## Local Environment Instructions

Read `.agent_process/process/local_environment_instructions.md` before starting steps. If any section is not `<none>`, pass relevant content to sub-agents that need it. These instructions are ADDITIVE — they augment but never skip default steps.

---

## Step Sequence

### Step 01: Load Context (sequential)

Spawn a **cheap** sub-agent with `orchestration/steps/review/01-load-context.md`.
- Pass: scope, iteration
- **Output:** `.run/review/01-review-context.md`

### Step 1.5: Scope Event Verification + GH Issue Check (sequential)

Run directly — not a sub-agent:
```bash
bash .agent_process/scripts/github-issues-lifecycle.sh verify {scope}
```
This is informational, not blocking. Write result to `.run/review/015-scope-verify.md`.

**GitHub Issues status update (if enabled):**

Spawn a **cheap** sub-agent with `process/github-issues-handling.md`:
- **Task:** "If GH issue exists for scope {scope}, update status to `status:reviewing`. If no issue exists, log a warning but do not block review."
- **Input:** `process/github-issues-handling.md` + `.run/gh-issue-context.md` (if exists)

The review is about the code, not the issue — a missing issue should never block review.

### Parallel Verification Gates (5 sub-agents simultaneously)

This is the **biggest parallelization win**. These 5 gates have no data dependencies on each other — all read from the iteration artifacts, not each other's output.

Spawn FIVE sub-agents **simultaneously**:

1. **capable** agent with `orchestration/steps/review/02-eval-criteria.md`
   - Pass: scope, iteration
   - **Output:** `.run/review/02-eval-criteria.md`

2. **capable** agent with `orchestration/steps/review/03-code-verify.md`
   - Pass: scope, iteration
   - **Output:** `.run/review/03-code-verify.md`

3. **cheap** agent with `orchestration/steps/review/035-doc-verify.md`
   - Pass: scope, iteration
   - **Output:** `.run/review/035-doc-verify.md`

4. **capable** agent with `orchestration/steps/review/036-integration-verify.md`
   - Pass: scope, iteration
   - **Output:** `.run/review/036-integration-verify.md`

5. **capable** agent with `orchestration/steps/review/037-adversarial.md`
   - Pass: scope, iteration
   - **Output:** `.run/review/037-adversarial.md`

Wait for all five to complete.

### Step 04-05: Gate Aggregation + Attempt Count (sequential)

Spawn a **cheap** sub-agent with `orchestration/steps/review/04-05-gates.md`.
- Pass: scope, iteration, ALL gate outputs
- **Output:** `.run/review/04-05-gates.md`

### Step 06: Choose Decision — HIGH STAKES (sequential)

Spawn a **synthesis** sub-agent with `orchestration/steps/review/06-choose-decision.md`.

**Use the best available model.** This step reads ALL `.run/review/*` files and produces the 4-choice decision (APPROVE/ITERATE/BLOCK/PIVOT) with structured reasoning.

- Pass: scope, iteration, ALL `.run/review/*` files
- **Output:** `.run/review/06-decision.md`

### Steps 07-10: Post-Decision (sequential)

Spawn a **capable** sub-agent with `orchestration/steps/review/07-10-post-decision.md`.
- Pass: scope, iteration, decision output (`.run/review/06-decision.md`)
- **Output:** `.run/review/07-10-post-decision.md`
- Handles: iteration_plan update, requirement doc update, **scope tracking state update** (via `github-issues-lifecycle.sh set-iteration`), knowledge deposit, artifact validation suggestion, handoff

**GitHub Issues post-decision (if enabled):**

After the post-decision sub-agent completes, spawn a **cheap** sub-agent with `process/github-issues-handling.md`:
- **Task based on decision:**
  - **APPROVE:** `lifecycle.sh set-status {scope} status:approved` then `lifecycle.sh close {scope} approved`
  - **ITERATE:** `lifecycle.sh set-status {scope} status:iterate` and `lifecycle.sh comment {scope} "Iteration decision: {brief reason}"`
  - **BLOCK:** `lifecycle.sh set-status {scope} status:blocked` then `lifecycle.sh close {scope} blocked`
  - **PIVOT:** `lifecycle.sh comment {scope} "Scope pivoted: {brief reason}"` (no close — new scope takes over)
- **Input:** `process/github-issues-handling.md` + `.run/gh-issue-context.md` + `.run/review/06-decision.md`

---

## Completion

After all steps complete, verify these `.run/review/` files exist:

- [ ] `.run/review/01-review-context.md`
- [ ] `.run/review/015-scope-verify.md`
- [ ] `.run/review/02-eval-criteria.md`
- [ ] `.run/review/03-code-verify.md`
- [ ] `.run/review/035-doc-verify.md`
- [ ] `.run/review/036-integration-verify.md`
- [ ] `.run/review/037-adversarial.md`
- [ ] `.run/review/04-05-gates.md`
- [ ] `.run/review/06-decision.md`
- [ ] `.run/review/07-10-post-decision.md`

Present the decision from `.run/review/06-decision.md` to the user and follow the post-decision actions from `.run/review/07-10-post-decision.md`.

⏸️ **Wait for human approval before executing post-decision actions (ITERATE folder creation, APPROVE marking, PIVOT scope changes).**
