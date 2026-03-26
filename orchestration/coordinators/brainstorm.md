# Brainstorm Coordinator

You are orchestrating a multi-agent brainstorm. Take a vague idea and turn it into a well-structured AP requirement through diverse perspectives, synthesis, and optional design review.

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
| **cheap** | Config check, context gathering | haiku | gpt-5.4-mini |
| **capable** | Brainstorm agents, design review, requirement writing | sonnet | gpt-5.4 |
| **synthesis** | Aggregating 3 perspectives into unified analysis | opus | gpt-5.4 |

## Data Flow

Step outputs go to `.agent_process/brainstorms/{chosen_name}/.run/`.

---

## Step Sequence

### Step 01: Config Check (sequential)

Spawn a **cheap** sub-agent with `orchestration/steps/brainstorm/01-config-check.md`.
- **Output:** `.run/01-config.md`

### Step 02: Gather Context (sequential)

Spawn a **cheap** sub-agent with `orchestration/steps/brainstorm/02-gather-context.md`.
- Pass: idea
- **Output:** `.run/02-context.md`

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

### Step 05: Design Review (CONDITIONAL)

Read `orchestration/steps/brainstorm/05-design-review.md`.

**Ask the user:** "Want to run a multi-agent design review before creating the requirement?"
- If yes (or complexity is high): spawn 2-3 **capable** reviewer sub-agents in parallel
- If no: skip, write "Skipped — user declined" to `.run/05-design-review.md`

### Steps 06-08: Transform + Confirm + Write (sequential)

Spawn a **capable** sub-agent with `orchestration/steps/brainstorm/06-08-transform-write.md`.
- Pass: synthesis output, design review (if any), idea
- **Output:** The requirement `.md` file in `requirements_docs/{category}/`
- Also: confirm with user (title, category, priority, complexity), update roadmap

---

## Verification Checklist

- [ ] `.run/01-config.md`
- [ ] `.run/02-context.md`
- [ ] `.run/03-product.md`
- [ ] `.run/03-architect.md`
- [ ] `.run/03-critical.md`
- [ ] `.run/04-synthesis.md`
- [ ] `.run/05-design-review.md`
- [ ] Requirement file in `requirements_docs/`
