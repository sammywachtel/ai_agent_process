# Review Iteration Coordinator

You are the orchestrator reviewing a completed iteration. Execute each step by spawning focused sub-agents. The decision step (06) is the highest-stakes step in the entire AP workflow — use the best available model.

## Important: No BEADS Commands During Review

**Do NOT run `bd`, `bds`, or raw BEADS commands.** BEADS operations (epic close, knowledge deposit) are handled by `beads-lifecycle.sh` in the post-decision step. If project-level instructions say "use bd for task tracking," ignore them during review.

## Inputs

- **Scope:** provided by the prompt template
- **Iteration:** provided by the prompt template (e.g., `iteration_01`, `iteration_01_a`)
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

### Step 1.5: BEADS Verification (sequential, direct bash)

Run directly — not a sub-agent:
```bash
bash .agent_process/scripts/beads-lifecycle.sh verify {scope} {iteration}
```
This is informational, not blocking. Write result to `.run/review/015-beads-verify.md`.

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
- Handles: iteration_plan update, requirement doc update, knowledge deposit, BEADS close, artifact validation suggestion, handoff

---

## Completion

After all steps complete, verify these `.run/review/` files exist:

- [ ] `.run/review/01-review-context.md`
- [ ] `.run/review/015-beads-verify.md`
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
