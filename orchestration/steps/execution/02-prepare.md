# Step 02: Prepare Execution

**Input:** Preflight results
**Output:** `.run/execution/02-prepare.md`

---

## Guiding Principle

For sub-iterations: the executor must understand the SEMANTIC INTENT of each fix, not just make mechanical changes. Extract and surface the WHY.

---

## 1. Load Context

Read:
- `.agent_process/work/{scope}/iteration_plan.md` — criteria, guidance, files
- `.agent_process/work/{scope}/{iteration}/results.md` — for sub-iterations, the fixes required
- `.agent_process/work/{scope}/human-prereqs.md` — optional human checkpoint (if exists)

Extract:
- **Acceptance Criteria** (LOCKED)
- **Files in Scope**
- **Removed Surfaces** (if non-empty in the plan — see step §1.1 below)
- **Validation Commands** (RUN vs SKIP)
- **Technical Guidance**
- **Human checkpoint requirements** (if `human-prereqs.md` exists)

### 1.1 Removed Surfaces (if non-empty)

If `iteration_plan.md` declares any **Removed Surfaces**, surface them in
the prepare doc verbatim and add the following instruction for the
implementer:

> Before declaring this iteration complete, run the stale-surface scrub
> block from the validator. If the scrub flags a reference outside the
> whitelist, the implementer must either (a) update that reference to
> remove or replace the removed surface, or (b) extend the per-surface
> whitelist file at
> `.agent_process/work/{scope}/.removal-whitelist/{surface}.txt` with
> the new entry AND record a justification in `results.md`. Pasting an
> entry into the whitelist without a justification is not acceptable —
> the reviewer's Gate 1 will fail it.

The implementer's `results.md` must include a **Removed-Surface Scrub**
section per `process/removal-scope-checklist.md`. The reviewer reads it
during Gate 1; missing or incomplete sections fail the gate.

If the plan declares `Removed Surfaces: N/A`, skip this sub-step.

### Sub-iteration Context

For `_a`/`_b`/`_c` iterations, also extract from the placeholder results.md:
- Each fix's **mechanical change** (file:line, before/after)
- Each fix's **semantic intent** (WHY this solves the problem)
- Each fix's **acceptance test** (outcome-based verification)

Read previous iteration's results to understand what worked/didn't.

### Human Checkpoint Context

If `.agent_process/work/{scope}/human-prereqs.md` exists:
- Treat it as a required execution checkpoint, not optional context
- Extract the concrete actions the human must complete
- Surface exactly when execution must pause (e.g., before live validation, before deploy)
- Carry forward the allowed human responses (e.g., proceed, blocked, local-only)

**Format is not fixed.** Real files may use the strict template (Pause Point / Human Actions / Allowed Responses) OR a looser structure (e.g. "Required Decisions and Actions" with numbered items, "Blocking Assumptions", "Operator Actions"). Do not require the strict template — extract what's there and classify it yourself:

- **pre_execution** — decisions, confirmations, credentials, environment setup needed before any code runs. Default bucket when the file doesn't say otherwise.
- **mid_execution** — things that must be done before live validation / before touching external systems / before deploy.
- **post_execution** — cutover, user notifications, follow-up work, prod parity confirmation.

If a file only lists items without classifying them, put them in `pre_execution` — the coordinator will surface them to the human before spawning the implementer. Better to ask up front than silently skip.

The coordinator (main conversation) is what holds the actual gate — this step just extracts and classifies. Do not try to pause inside this sub-agent.

This file is created during plan-scope and may be modified during review if checkpoint needs change between iterations.

---

## 2. Decomposition Assessment

**Skip if:**
- `quality-config.json` has `work_unit_decomposition.enabled: false`
- This is a sub-iteration (execute directly against fixes)
- Files < 3 or layers < 2

**If triggered:**
- Group files by layer (backend, frontend, tests, etc.)
- Create work units with dependencies
- Each unit independently validatable

---

## 3. Agent Selection

Match file patterns to specialized agents:

| Files | Agent |
|-------|-------|
| Backend API, routes | `backend-security:backend-expert` |
| React, `.tsx` | `frontend-excellence:react-specialist` |
| Tests | `dev-accelerator:test-automator` |
| CI/CD, Docker | `infra-pipeline:cicd-engineer` |
| General/mixed | `general-purpose` |

For work units: one agent per unit.

---

## Output

```markdown
# Execution Preparation

**Scope:** {scope}
**Iteration:** {iteration}
**Type:** first_iteration / sub_iteration

## Criteria (LOCKED)
- [ ] {criterion 1}
- [ ] {criterion 2}

## Files in Scope
{list}

## Validation
- **RUN:** {commands}
- **SKIP:** {commands with reasons}

## Human Checkpoint
- **Required:** YES / NO
- **Source file:** `.agent_process/work/{scope}/human-prereqs.md` (present YES/NO)
- **Pre-execution items:** {list, or "none"}
- **Mid-execution items:** {list with trigger, or "none"}
- **Post-execution items:** {list, or "none"}
- **Allowed Responses:** {proceed / blocked / local-only / etc. — default set if file didn't specify}

**Note for coordinator:** the actual gate runs in the main conversation (Steps 0.5 and 6 of `execute.md`). This section is input for that gate, not a place to claim the gate already ran.

## Sub-iteration Fixes (if applicable)

### Fix 1: {Title}
- **Change:** {file:line, before/after}
- **Semantic Intent:** {WHY — executor must understand this}
- **Acceptance Test:** {outcome-based verification}

## Decomposition
DECOMPOSE: skip / yes
{If yes: work unit DAG}

## Agent Selection
- **Mode:** single / multi-agent
- **Agent(s):** {agent_type}
- **Reasoning:** {why this agent}
```
