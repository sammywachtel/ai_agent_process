---
id: decomp_scope_02_execution
type: requirement
category: decomposition
status: completed
priority: high
---

# Requirements: Execution Prompt Decomposition

---

## Objective
Replace the monolithic `claude/commands/ap_exec.md` (1,205 lines) with a hybrid two-part system: a preflight coordinator (~100 lines) that spawns sub-agents for setup steps, plus a focused main prompt (~200 lines) that handles implementation in the main session where the Agent/Task tools are available.

## Background
The execution prompt is the largest single file at 1,205 lines. It handles everything from session recovery to implementation to adversarial review. The key constraint: implementation steps (02-06) require the Agent/Task tool which is only available in the main session — not in CLI sub-agent calls. This means a pure coordinator approach won't work.

The solution is a **hybrid**: preflight checks run as sub-agents (they only need Read/Bash), then the main session loads a focused prompt (~200 lines instead of 1,205) that reads preflight outputs from `.run/` and handles implementation with full tool access.

**Reference**: Full architecture in `.local_docs/orchestrator-decomposition-plan.md`, Scope 2 section.

---

## Acceptance Criteria

### AC-1: Preflight coordinator exists and is well-formed ✅
- [x] `orchestration/coordinators/execute-preflight.md` exists (103 lines)
- [x] Branch check (007a) runs first sequentially — prevents race condition with git context
- [x] Remaining 3 pre-flight checks (007b-d) run in parallel after branch is settled
- [x] Runs sequential steps: load-context, decomposition, agent-selection
- [x] All preflight outputs written to `.agent_process/work/{scope}/.run/`
- [x] "No BEADS during sub-agents" warning included

### AC-2: All 7 preflight step files exist ✅
- [x] Each step file in `orchestration/steps/execution/`:
  - `007a-branch-check.md` (56 lines) — runs FIRST, flags existing branches for human decision
  - `007b-session-recovery.md` (49 lines)
  - `007c-working-tree.md` (42 lines)
  - `007d-git-context.md` (45 lines)
  - `01-load-context.md` (109 lines) — handles sub-iteration context, vague instruction detection
  - `0125-decomposition.md` (80 lines) — work unit DAG with layer detection
  - `015-select-agent.md` (65 lines) — pattern-based agent selection
- [x] Each specifies model tier, inputs, outputs, required tools

### AC-3: Focused main prompt replaces monolithic prompt ✅
- [x] `orchestration/coordinators/execute-main.md` exists (201 lines)
- [x] Reads preflight outputs from `.run/` — does not repeat preflight logic
- [x] Handles: implementation (02), validation (03-04), adversarial review (045), documentation/reporting (05-06)
- [x] Supports single-agent, sub-iteration, and multi-agent (decomposed) execution modes
- [x] "No BEADS commands during implementation" warning included

### AC-4: Slash command updated ✅
- [x] `claude/commands/ap_exec.md` rewritten as thin wrapper (105 lines, was 1,205)
- [x] Loads quality-config, local env instructions, then delegates to preflight → main coordinators
- [x] Workflow summary diagram included

### AC-5: BEADS lifecycle integration preserved ✅
- [x] `beads-lifecycle.sh start` runs as Step 0.5 in preflight coordinator (direct bash, not sub-agent)
- [x] BEADS work unit tracking in execute-main.md via `beads-lifecycle.sh task-update`

### AC-6: Monolithic file deleted ✅
- [x] Old monolithic content (1,205 lines) replaced with thin wrapper (105 lines)
- [x] Validated: decomposed version produces correct artifacts on real project

### AC-7: Real-project validation ✅
- [x] Executed a real iteration on audio project (`gemini_hybrid_09_cloud_run_orchestrator_02_functions_cleanup/iteration_01`)
- [x] All 7 preflight `.run/` files exist: `007a-branch-check`, `007b-session-recovery`, `007c-working-tree`, `007d-git-context`, `01-context`, `0125-decomposition`, `015-agent-selection`
- [x] Implementation completed: 4 files deleted, 8 files modified across Functions backend and React frontend
- [x] Validation passed: scoped hook PASS, frontend tsc/build/tests all clean (136/136 tests)
- [x] Adversarial review completed: fresh agent, 8/8 criteria PASS with file:line evidence
- [x] `results.md` produced with all expected sections (summary, changed files, validation, adversarial review, implementation notes, known issues)
- [x] `test-output.txt` and `adversarial-review.md` artifacts produced

### AC-8: Documentation updated ✅
- [x] README.md directory tree shows coordinators + steps for execution
- [x] README.md reference table includes execution entry
- [x] `process/quality-configuration.md` updated — BEADS section reflects native `bd` config
- [x] `process/validation-playbook.md` — no changes needed (references file path which is unchanged)
- [x] `process/work-unit-execution.md` — references specific step file (`0125-decomposition.md`)
- [x] `process/beads-integration.md` — already updated (credentials path, no bds, agent warning)
- [x] `claude/commands.md` — no changes needed (references slash command name, not internals)

---

## Files Expected to Change

**New files (coordinators):**
- `orchestration/coordinators/execute-preflight.md`
- `orchestration/coordinators/execute-main.md`

**New files (steps):**
- `orchestration/steps/execution/007a-branch-check.md`
- `orchestration/steps/execution/007b-session-recovery.md`
- `orchestration/steps/execution/007c-working-tree.md`
- `orchestration/steps/execution/007d-git-context.md`
- `orchestration/steps/execution/01-load-context.md`
- `orchestration/steps/execution/0125-decomposition.md`
- `orchestration/steps/execution/015-select-agent.md`

**Modified files:**
- `claude/commands/ap_exec.md` — rewritten as thin wrapper (105 lines)

**Deleted files:**
- Old monolithic `ap_exec.md` content (replaced, not separate file deletion)

---

## Dependencies
- **Scope 1 (Planning)** ✅ — uses the coordinator pattern, model tier mapping, `.run/` data flow convention, and step file structure template established there.

---

## Testing Strategy
1. Install updated framework on dendwrite or audio project
2. Execute a real iteration using the decomposed preflight + main prompt
3. Verify all `.run/` preflight files exist
4. Verify implementation, validation, and adversarial review produce correct artifacts
5. Verify session recovery works (kill mid-execution, restart)
6. Verify branch check stops for existing branches

---

## Design Decisions

**Branch check runs first (sequential):** Originally all 4 pre-flight checks ran in parallel. But branch check may switch branches, which would cause git context (running simultaneously) to read from the wrong branch. Fix: 007a runs alone, 007b-d run in parallel after.

**Existing branches flag for human input:** Instead of silently switching to an existing `scope/` branch, 007a stops and asks the user whether to resume or start fresh. An existing branch from a prior run is ambiguous enough to warrant human decision.

**Hybrid architecture:** Steps 2-6 need Agent/Task tool (only in main session), so they can't be sub-agent calls. Preflight steps only need Read/Bash, so they decompose cleanly into sub-agents. The split at "preflight vs main" is the natural boundary.
