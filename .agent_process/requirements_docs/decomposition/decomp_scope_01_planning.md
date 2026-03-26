---
id: decomp_scope_01_planning
type: requirement
category: decomposition
status: completed
priority: high
---

# Requirements: Planning Prompt Decomposition

---

## Objective
Replace the monolithic planning instructions file (890 lines) with a thin coordinator prompt (~120 lines) that spawns focused sub-agents, each with ~40-80 lines of instructions. This is the **foundational scope** — it establishes the coordinator pattern, model tier mapping, and data flow convention that all subsequent scopes follow.

## Background
The orchestrator's planning prompt has grown to 890 lines. Critical checks like scope sizing are buried in hundreds of lines of other instructions, causing agents to skip them. Every feature addition dilutes attention on everything else. Sub-agent spikes confirmed that both `claude -p` and `codex exec` work as focused sub-agent mechanisms with parallel execution.

The fix: each step gets its own prompt file (~40-80 lines) containing ONLY its instructions. A coordinator prompt (~120 lines) orchestrates the sequence, specifying which steps run in parallel and how data flows between them via `.run/` output files.

**Reference**: Full architecture in `.local_docs/orchestrator-decomposition-plan.md`.

---

## Acceptance Criteria

### AC-1: Coordinator prompt exists and is well-formed ✅
- [x] `orchestration/coordinators/plan-scope.md` exists (178 lines)
- [x] Contains model tier mapping (cheap/capable/synthesis) with platform-agnostic descriptions
- [x] Contains data flow convention: all step outputs go to `.agent_process/work/{scope}/.run/`
- [x] Specifies step sequence with explicit parallel groups (A and B) and gate logic
- [x] References step files by relative path — never embeds step instructions inline

### AC-2: All 12 step files exist with correct structure ✅
- [x] Each step file in `orchestration/steps/planning/` follows the naming from the plan:
  - `01-scope-check.md`, `02-derive-folder.md`, `025-knowledge-query.md`, `03-code-review.md`, `04-define-files.md`, `05-frozen-criteria.md`, `055-doc-impact.md`, `06-preexisting-issues.md`, `07-validation-script.md`, `08-create-plan.md`, `085-design-review.md`, `09-12-finalize.md`
- [x] Each step file specifies: model tier, required tools, input files, output file path
- [x] Each step file is self-contained (53-85 lines) — no references to "see above" or external instructions
- [x] Step `01-scope-check.md` is a hard gate: if FAIL, the coordinator must stop

### AC-3: Parallel execution groups are correctly defined ✅
- [x] **Parallel Group A** (025-knowledge-query + 03-code-review) runs concurrently — no data dependency between them
- [x] **Parallel Group B** (055-doc-impact + 06-preexisting-issues + 07-validation-script) runs concurrently
- [x] Sequential dependencies are respected: 04-define-files depends on 03-code-review output; 05-frozen-criteria depends on 04-define-files output

### AC-4: Data flow via `.run/` directory works end-to-end ✅
- [x] Each step writes its output to `.agent_process/work/{scope}/.run/XX-name.md`
- [x] The aggregator step (08-create-plan) reads ALL `.run/*` files and produces `iteration_plan.md`
- [x] After a full planning run, all 11 `.run/` output files exist (aggregator output is `iteration_plan.md` itself, not a `.run/` file) — **confirmed on audio project**

### AC-5: Prompt template updated ✅
- [x] `orchestration/plan-scope.md` references the coordinator instead of the old instructions file
- [x] Scope sizing rules extracted to `orchestration/scope-sizing-rules.md`

### AC-6: Monolithic file deleted ✅
- [x] Monolithic planning instructions file deleted after validation
- [x] References updated to point to coordinator + step files

### AC-7: Real-project validation ✅
- [x] Run the decomposed planning workflow on a real requirement — **confirmed on audio project** (`gemini_hybrid_09_cloud_run_orchestrator_02_functions_cleanup`)
- [x] Compare: produces the same artifacts as the monolithic version — iteration_plan.md with all expected sections (scope overview, frozen criteria, technical assessment, knowledge, files in scope, doc impact, validation, out of scope, time budget)
- [x] Verify: the scope sizing gate (step 01) actually blocks oversized scopes — **confirmed on audio project** (earlier run on `_02_cleanup` returned VERDICT: FAIL, split into 3)
- [x] Verify: `.run/` directory contains all expected step output files — **11/11 files present** (aggregator writes directly to iteration_plan.md)
- [x] Orchestrator spawned sub-agents for parallel groups as designed
- [x] Orchestrator raised CLARIFICATION_NEEDED from code review step and waited for answers

---

## Files Expected to Change

**New files (coordinator):**
- `orchestration/coordinators/plan-scope.md`

**New files (steps):**
- `orchestration/steps/planning/01-scope-check.md`
- `orchestration/steps/planning/02-derive-folder.md`
- `orchestration/steps/planning/025-knowledge-query.md`
- `orchestration/steps/planning/03-code-review.md`
- `orchestration/steps/planning/04-define-files.md`
- `orchestration/steps/planning/05-frozen-criteria.md`
- `orchestration/steps/planning/055-doc-impact.md`
- `orchestration/steps/planning/06-preexisting-issues.md`
- `orchestration/steps/planning/07-validation-script.md`
- `orchestration/steps/planning/08-create-plan.md`
- `orchestration/steps/planning/085-design-review.md`
- `orchestration/steps/planning/09-12-finalize.md`

**Modified files:**
- `orchestration/plan-scope.md` — reference coordinator instead of instructions file

**Deleted files:**
- Monolithic planning instructions (was `orchestration/01_plan_scope_instructions.md`, deleted after validation)

---

## Dependencies
- **None** — this is the foundational scope. Establishes patterns used by scopes 2-5.

## Shared Infrastructure (ships with this scope)
- Coordinator prompt pattern (template for all subsequent coordinators)
- Model tier mapping convention (cheap/capable/synthesis)
- Data flow convention (`.run/` output files with numbered prefixes)
- Step file structure template (inputs, outputs, model tier, tools)

---

## Testing Strategy
1. Install updated framework on dendwrite project via `install.sh`
2. Plan a REAL requirement using the decomposed coordinator
3. Verify all `.run/` step output files exist
4. Verify `iteration_plan.md` has all expected sections
5. Intentionally feed an oversized scope — confirm step 01 blocks it
6. Delete monolithic planning instructions — confirm nothing breaks
7. Compare wall-clock time vs monolithic (expect improvement from parallel groups)
