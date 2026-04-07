# Brainstorm Coordinator

You are orchestrating a multi-agent brainstorm. Take a vague idea and turn it into a well-structured AP requirement through diverse perspectives, synthesis, and mandatory feasibility review.

## Inputs

- **Idea:** provided by the user (freeform text from `{{ idea }}`)

## Brainstorm Directory

Before starting, propose 2-3 short directory names derived from the idea and ask the user to pick one (or suggest their own). Use snake_case, max ~40 chars.

Example for "Improve the login experience for returning users":
> 1. `improve_login_returning_users`
> 2. `returning_user_login_ux`
> 3. `login_experience_improvement`

Once confirmed, create the directory:
```bash
mkdir -p .agent_process/brainstorms/{chosen_name}/.run
```

All step outputs go to `.agent_process/brainstorms/{chosen_name}/.run/`.
The final synthesis saves to `.agent_process/brainstorms/{chosen_name}/brainstorm.md`.

## Model Tiers

| Tier | Use For | Claude Code | Codex |
|------|---------|-------------|-------|
| **cheap** | Config check | haiku | gpt-5.4-mini |
| **capable** | Context + code review, brainstorm agents, feasibility review, requirement writing | sonnet | gpt-5.4 |
| **synthesis** | Aggregating 3 perspectives into unified analysis | opus | gpt-5.4 |

## Data Flow

Step outputs go to `.agent_process/brainstorms/{chosen_name}/.run/`.

---

## Local Environment Instructions

Read `.agent_process/process/local_environment_instructions.md` before starting steps. If any section is not `<none>`, pass relevant content to sub-agents that need it. These instructions are ADDITIVE — they augment but never skip default steps.

---

## Step Sequence

### Step 01: Config Check (sequential)

Spawn a **cheap** sub-agent with `orchestration/steps/brainstorm/01-config-check.md`.
- **Output:** `.run/01-config.md`

### Step 02: Gather Context + Code Review (sequential)

Spawn a **capable** sub-agent with `orchestration/steps/brainstorm/02-gather-context.md`.
- Pass: idea
- **Output:** `.run/02-context.md`

This step now does actual code exploration — not just README scanning — so brainstorm agents have grounded technical context.

### Step 03: Brainstorm Agents (3 in parallel)

Spawn THREE **capable** sub-agents **simultaneously** with `orchestration/steps/brainstorm/03-spawn-agents.md`.
- Pass: idea, context output
- **Outputs:** `.run/03-product.md`, `.run/03-architect.md`, `.run/03-critical.md`

Wait for all three.

### Step 04: Synthesize (sequential)

Spawn a **synthesis** sub-agent with `orchestration/steps/brainstorm/04-synthesize.md`.
- Pass: all 3 agent outputs
- **Output:** `.run/04-synthesis.md`
- Also saves to `.agent_process/brainstorms/{chosen_name}/brainstorm.md`

### Step 05: Feasibility Review (MANDATORY)

Spawn a **capable** sub-agent with `orchestration/steps/brainstorm/05-feasibility-review.md`.
- Pass: synthesis output, idea
- **Output:** `.run/05-feasibility-review.md`

This step runs the same checks plan-scope uses — knowledge base query, CLAUDE.md review, actual code review. It ensures the requirement is grounded in codebase reality before writing.

**Gate behavior:**
- If `CLARIFICATION_NEEDED: false` → Proceed to Step 06
- If `CLARIFICATION_NEEDED: true` → Present questions to user, resolve, then proceed

**Do NOT skip this step.** It prevents idealistic requirements that get rejected later.

### Steps 06-08: Transform + Confirm + Write (sequential)

Spawn a **capable** sub-agent with `orchestration/steps/brainstorm/06-08-transform-write.md`.
- Pass: synthesis output, feasibility review output, idea
- **Output:** The requirement `.md` file in `requirements_docs/{category}/`
- Also: confirm with user (title, category, priority, complexity), update roadmap

The feasibility review findings inform:
- Technical Requirements (from knowledge patterns)
- Known Risks (from knowledge gotchas + code review)
- Out of Scope (from knowledge anti-patterns)
- Implementation guidance

---

## Verification Checklist

- [ ] `.run/01-config.md`
- [ ] `.run/02-context.md`
- [ ] `.run/03-product.md`
- [ ] `.run/03-architect.md`
- [ ] `.run/03-critical.md`
- [ ] `.run/04-synthesis.md`
- [ ] `.run/05-feasibility-review.md`
- [ ] `CLARIFICATION_NEEDED: false` in feasibility review
- [ ] Requirement file in `requirements_docs/`
