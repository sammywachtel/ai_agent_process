---
id: decomp_scope_03_review
type: requirement
category: decomposition
status: completed
priority: high
---

# Requirements: Review Prompt Decomposition

---

## Objective
Replace the monolithic `orchestration/instructions/review-iteration.md` (1,322 lines) with a coordinator prompt (~130 lines) and 9 focused step files. This scope has the **biggest parallelization win**: 5 verification gates can run concurrently.

## Background
The review instructions file is the largest at 1,322 lines. It handles context loading, BEADS verification, criteria evaluation, code verification, doc verification, integration verification, adversarial review checks, gate counting, decision-making, and post-decision artifacts. The decision step (APPROVE/ITERATE/BLOCK/PIVOT) is the highest-stakes step in the entire AP workflow — it must run on the best available model with complete evidence.

Currently all 5 verification gates run sequentially. Decomposition enables them to run in parallel, significantly reducing review wall-clock time.

**Reference**: Full architecture in `.local_docs/orchestrator-decomposition-plan.md`, Scope 3 section.

---

## Acceptance Criteria

### AC-1: Coordinator prompt exists and is well-formed ✅
- [x] `orchestration/coordinators/review-iteration.md` exists (110 lines)
- [x] Specifies the 5-gate parallel group clearly
- [x] Marks the decision step (06) as HIGH STAKES — must use synthesis/best model
- [x] References step files by path — never embeds step instructions

### AC-2: All 9 step files exist with correct structure ✅
- [x] Each step file in `orchestration/steps/review/`:
  - `01-load-context.md` (62 lines)
  - `02-eval-criteria.md` (55 lines)
  - `03-code-verify.md` (55 lines)
  - `035-doc-verify.md` (68 lines)
  - `036-integration-verify.md` (82 lines)
  - `037-adversarial.md` (68 lines)
  - `04-05-gates.md` (68 lines)
  - `06-choose-decision.md` (82 lines)
  - `07-10-post-decision.md` (103 lines)
- [x] Each specifies model tier, inputs, outputs, required tools

### AC-3: 5 verification gates run in parallel ✅
- [x] Steps 02, 03, 035, 036, 037 have no data dependencies on each other
- [x] Coordinator specifies these as a parallel group — "Spawn FIVE sub-agents simultaneously"
- [x] Each gate writes independent output to `.run/review/`
- [x] Gate aggregation step (04-05) reads all 5 outputs
- [x] **Confirmed on audio project:** orchestrator spawned 5 agents, waited for all to complete

### AC-4: Decision step uses synthesis model ✅
- [x] Step 06-choose-decision is explicitly marked as synthesis tier
- [x] It reads ALL `.run/review/*` files as input — complete evidence
- [x] Produces one of 4 decisions: APPROVE, ITERATE, BLOCK, PIVOT
- [x] Decision output includes structured reasoning
- [x] **Confirmed on audio project:** ITERATE decision with specific fix instructions

### AC-5: BEADS verification preserved ✅
- [x] BEADS lifecycle verify step runs (015-beads-verify.md produced)
- [x] BEADS close in post-decision step (07-10-post-decision.md)

### AC-6: Prompt template updated ✅
- [x] `orchestration/review-iteration.md` references the coordinator
- [x] Review workflow loads coordinator instead of instructions file

### AC-7: Monolithic file deleted ✅
- [x] `orchestration/instructions/review-iteration.md` deleted
- [x] References updated across all process docs and base-context

### AC-8: Real-project validation ✅
- [x] Run the decomposed review on a real completed iteration — **confirmed on audio project** (`gemini_hybrid_09_cloud_run_orchestrator_02_functions_cleanup/iteration_01`)
- [x] All `.run/review/` output files exist (10 files — all gates produced output)
- [x] Decision is ITERATE with structured reasoning and specific fixes
- [x] Orchestrator correctly stopped before post-decision actions (waited for human approval)
- [x] Orchestrator identified artifact inconsistency (test-output.txt vs results.md on AC-8) and flagged it as the ITERATE reason

### AC-9: Documentation updated ✅
- [x] README.md directory tree and reference table reflect review decomposition
- [x] Process docs (`quality-configuration.md`, `validation-playbook.md`, `knowledge-base.md`) references updated
- [x] `orchestration/context/base-context.md` references updated

### Additional: Phase-scoped `.run/` directories
- [x] All coordinators updated: planning → `.run/planning/`, execution → `.run/execution/`, review → `.run/review/`
- [x] All step files updated to match phase-scoped output paths
- [x] Prevents naming collisions across planning/execution/review phases

---

## Files Expected to Change

**New files (coordinator):**
- `orchestration/coordinators/review-iteration.md`

**New files (steps):**
- `orchestration/steps/review/01-load-context.md`
- `orchestration/steps/review/02-eval-criteria.md`
- `orchestration/steps/review/03-code-verify.md`
- `orchestration/steps/review/035-doc-verify.md`
- `orchestration/steps/review/036-integration-verify.md`
- `orchestration/steps/review/037-adversarial.md`
- `orchestration/steps/review/04-05-gates.md`
- `orchestration/steps/review/06-choose-decision.md`
- `orchestration/steps/review/07-10-post-decision.md`

**Modified files:**
- `orchestration/review-iteration.md` — reference coordinator

**Deleted files:**
- `orchestration/instructions/review-iteration.md` (after validation)

---

## Dependencies
- **Scope 1 (Planning)** — coordinator pattern, model tiers, `.run/` data flow convention
- **Scope 2 (Execution)** — validates the hybrid pattern (may inform how review handles tool constraints)

---

## Testing Strategy
1. Install updated framework on dendwrite project
2. Complete an iteration, then run decomposed review
3. Verify all 5 verification gate `.run/` files exist
4. Verify decision step produces valid APPROVE/ITERATE/BLOCK/PIVOT
5. Verify post-decision artifacts are complete
6. Time comparison: parallel gates vs sequential (expect significant improvement)
7. Delete old instructions file — confirm nothing breaks
