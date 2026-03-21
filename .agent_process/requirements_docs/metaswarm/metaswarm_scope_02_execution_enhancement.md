---
id: metaswarm_scope_02_execution_enhancement
type: requirement
category: metaswarm
status: in_progress
priority: medium
---

# Requirements: Execution Phase Enhancement

---

## Objective
Upgrade AP's implementation phase (`/ap_exec`) with structured work unit decomposition and post-PR lifecycle management, enabling multi-domain scopes to execute as coordinated parallel work units and PRs to be shepherded through CI and review.

## Background
AP's `/ap_exec` currently operates as a single execution pass: read frozen criteria, select a specialized agent (or multiple agents ad-hoc), implement everything, validate via scoped hook, produce results.md. This works well for focused, single-domain scopes but becomes unwieldy when a scope touches multiple systems (database + API + frontend + tests).

Metaswarm's execution model addresses this with two patterns:

1. **Work Unit Decomposition**: An Architect Agent analyzes the scope's acceptance criteria and decomposes them into a Directed Acyclic Graph (DAG) of work units. Each unit has explicit scope (files, functions), dependencies (what must complete first), and a mini-validation step. Independent units execute in parallel; dependent units respect blocking relationships.

2. **PR Shepherd**: After `/ap_release` creates a PR, a shepherd agent monitors CI status, responds to reviewer comments, fixes lint/type issues, and reports merge-readiness. This extends AP's workflow from "PR created" to "PR merged."

Both patterns require changes to the implementation-side commands (`ap_exec.md`, `ap_release.md`) but do NOT change the orchestrator's decision framework. The Codex orchestrator still reviews against frozen criteria and makes 4-choice decisions — it just receives results from a better-organized execution.

**Dependency**: This scope benefits from (but does not strictly require) `metaswarm_scope_01_knowledge_review`. The Architect Agent's decomposition is better informed when knowledge base patterns are available.

**Reference**: [metaswarm](https://github.com/dsifry/metaswarm) — `skills/orchestrated-execution/` for 4-phase loop, `agents/architect-agent.md` for decomposition, `agents/pr-shepherd-agent.md` for PR lifecycle.

---

## Technical Requirements

### Work Unit Decomposition

1. Add optional decomposition step to `ap_exec.md` — after reading the iteration plan, if the scope touches 3+ files across 2+ system layers (e.g., backend + frontend, or schema + API + tests), trigger the Architect Agent to decompose acceptance criteria into work units
2. Each work unit specifies: unit ID (e.g., WU-001), description, files in scope, dependencies (other WU IDs that must complete first), and which acceptance criteria it addresses
3. Work units form a DAG — independent units may execute in parallel, dependent units block until prerequisites complete
4. The decomposition must stay within frozen acceptance criteria — work units are a tactical breakdown, not new scope. If the Architect identifies missing criteria, those go to the backlog, not into work units
5. Each work unit selects its own specialized agent based on file patterns (existing agent selection logic, scoped to the unit's files)
6. Per-unit validation runs the scoped validation hook against only the unit's files (not all files in the full scope)
7. Add `## Work Unit Summary` section to `templates/results.md` showing unit-by-unit completion status
8. For simple scopes (2-3 files, single domain), decomposition is skipped — direct execution proceeds as today

### Execution Tracking

9. Add `current_work_unit.conf` alongside `current_iteration.conf` to track which work unit is in progress (for session recovery)
10. Work unit status tracked in results.md with per-unit entries: WU-ID, status (complete/in-progress/blocked), files changed, validation result
11. If a session is interrupted mid-execution, the orchestrator can resume from the last completed work unit by reading the work unit summary

### PR Shepherd

12. Add optional PR shepherd step to `ap_release.md` — after PR creation, if the user opts in (flag or prompt), launch a shepherd agent to monitor the PR
13. The shepherd monitors: CI pipeline status, review comments, lint/type/test failures
14. On CI failure, the shepherd diagnoses the issue and either auto-fixes (lint, formatting) or reports to the user with specific failure context
15. On review comments, the shepherd drafts responses and suggests code changes (but does not push without user approval)
16. The shepherd reports merge-readiness when all checks pass and all review threads are resolved
17. Add `--shepherd` flag to `/ap_release` command to activate PR lifecycle management
18. Shepherd operates on the scope branch, not main — all fixes are additional commits on the PR branch

---

## Success Criteria
- [ ] `ap_exec.md` includes work unit decomposition step with clear trigger conditions (3+ files across 2+ layers)
- [ ] Work unit format defined: ID, description, files, dependencies, criteria addressed
- [ ] DAG execution logic documented: parallel for independent units, blocking for dependent units
- [ ] Scope constraint enforced: decomposition cannot introduce criteria beyond the frozen set
- [ ] Per-unit agent selection uses existing file-pattern matching, scoped to unit files
- [ ] Per-unit validation runs scoped hook against unit files only
- [ ] `templates/results.md` includes `## Work Unit Summary` section
- [ ] Simple scopes (single domain, <3 files) skip decomposition — documented as explicit bypass condition
- [ ] `current_work_unit.conf` tracks active work unit for session recovery
- [ ] `ap_release.md` includes `--shepherd` flag documentation
- [ ] PR shepherd monitors CI, responds to comments, reports merge-readiness
- [ ] Developer documentation updated: README.md, process docs explain work unit decomposition and PR shepherd

---

## Files Expected to Change
- `claude/commands/ap_exec.md` (add decomposition step, per-unit execution, tracking)
- `claude/commands/ap_release.md` (add --shepherd flag and PR lifecycle step)
- `templates/results.md` (add Work Unit Summary section)
- `orchestration/00_base_context.md` (mention work units in execution overview)
- `README.md` (document new capabilities)

**New files:**
- `templates/work-unit-decomposition.md` (Architect Agent prompt template for decomposition)
- `process/work-unit-execution.md` (how-to guide for work unit workflow)
- `process/pr-shepherd.md` (how-to guide for PR shepherd usage)

**Estimated:** 8-10 files

---

## Out of Scope
- Knowledge base integration (separate scope: `metaswarm_scope_01_knowledge_review`)
- Adversarial review pattern (separate scope: `metaswarm_scope_01_knowledge_review`)
- Design review gate (separate scope: `metaswarm_scope_03_optional_gates`)
- BEADS durable state tracking (separate scope: `metaswarm_scope_03_optional_gates`)
- Multi-model work unit execution (e.g., Gemini for some units, Claude for others) — all units use Claude for now
- Swarm coordinator for multi-scope parallel work — AP intentionally works one scope at a time
- Changing the orchestrator's review process — Codex still reviews results.md and makes 4-choice decisions as today
- Automatic merge (the shepherd reports readiness; human clicks merge)

---

## Known Risks
- **Over-decomposition**: The Architect Agent might create too many work units for a medium-complexity scope, adding coordination overhead that exceeds the benefit. Mitigation: set a soft cap (3-6 work units per scope); if more are needed, the scope should probably be split at the requirements level instead.
- **DAG dependency errors**: Incorrect dependency ordering could cause a unit to start before its prerequisites are ready. Mitigation: the decomposition step validates the DAG for cycles and missing dependencies before execution begins.
- **PR shepherd scope creep**: The shepherd might make changes that go beyond the original scope (e.g., "fixing" unrelated lint warnings). Mitigation: the shepherd operates only on files already changed in the PR; new files require user approval.
- **Session recovery complexity**: Tracking work unit state alongside iteration state adds recovery complexity. Mitigation: `current_work_unit.conf` is a simple key-value file (same pattern as `current_iteration.conf`); results.md Work Unit Summary is the source of truth for completion status.

---

## References
- [metaswarm orchestrated-execution skill](https://github.com/dsifry/metaswarm) — 4-phase loop (IMPLEMENT→VALIDATE→REVIEW→COMMIT)
- [metaswarm architect-agent.md](https://github.com/dsifry/metaswarm/blob/main/agents/architect-agent.md) — work unit decomposition patterns
- [metaswarm pr-shepherd-agent.md](https://github.com/dsifry/metaswarm/blob/main/agents/pr-shepherd-agent.md) — PR lifecycle management
- `claude/commands/ap_exec.md` — current execution flow (will be modified)
- `claude/commands/ap_release.md` — current release flow (will be modified)
- `metaswarm_scope_01_knowledge_review` — prerequisite scope (knowledge base feeds Architect's decomposition)

---

## Estimated Size
- **Duration:** 2-3 weeks
- **Iterations:** 3-4 estimated
- **Complexity:** HIGH

---

## Notes
The work unit decomposition is the most architecturally significant change in this integration — it transforms `/ap_exec` from a single-pass execution into a structured multi-step pipeline. The key constraint is that **AP's convergence mechanisms still govern**: frozen criteria, iteration budgets, scoped validation. The decomposition is a tactic *within* the execution phase, not a replacement for AP's strategic control.

The PR shepherd is operationally simpler but has important boundaries. It should feel like a helpful assistant monitoring the PR, not an autonomous agent making decisions. The human remains the merge authority. Think of it as "CI babysitter with commenting privileges."

The trigger condition for decomposition (3+ files across 2+ layers) should be tunable. Some teams may want it at 2 files; others may prefer 5+. Consider making it configurable in `local_environment_instructions.md` so projects can override the default threshold.
