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
- **Validation Commands** (RUN vs SKIP)
- **Technical Guidance**
- **Human checkpoint requirements** (if `human-prereqs.md` exists)

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
- **Pause Point:** {before live validation / before deploy / none}
- **Human Actions:** {summary of what human must do}
- **Allowed Responses:** {proceed / blocked / local-only / etc.}

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
