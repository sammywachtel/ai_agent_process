---
id: decomp_scope_05_brainstorm
type: requirement
category: decomposition
status: in_progress
priority: medium
---

# Requirements: Brainstorm Prompt Decomposition

---

## Objective
Replace the monolithic `claude/commands/ap_brainstorm.md` (352 lines) with a coordinator prompt (~60 lines) and 6 focused step files. This is the smallest and most straightforward decomposition — the brainstorm prompt is already well-structured with 3 parallel agents, so this is primarily a structural alignment with the coordinator pattern.

## Background
The brainstorm prompt is the smallest monolithic file at 352 lines. It already uses a good pattern: gather context, spawn 3 parallel brainstorm agents (Product, Architect, Critical), synthesize, optionally run design review, then transform output into a requirement file.

The decomposition here is about consistency — all 5 workflows should follow the same coordinator + step file pattern — and about giving each step its own focused context. The parallel agent spawn is already validated, so the main work is extracting each phase into its own step file.

**Reference**: Full architecture in `.local_docs/orchestrator-decomposition-plan.md`, Scope 5 section.

---

## Acceptance Criteria

### AC-1: Coordinator prompt exists and is well-formed ✅
- [x] `orchestration/coordinators/brainstorm.md` exists (82 lines)
- [x] Specifies the 3-agent parallel group
- [x] Marks design review (step 05) as conditional — user prompt + complexity
- [x] References step files by path

### AC-2: All 6 step files exist with correct structure ✅
- [x] Each step file in `orchestration/steps/brainstorm/`:
  - `01-config-check.md` (30 lines)
  - `02-gather-context.md` (47 lines)
  - `03-spawn-agents.md` (46 lines)
  - `04-synthesize.md` (59 lines)
  - `05-design-review.md` (47 lines)
  - `06-08-transform-write.md` (92 lines)
- [x] Each specifies model tier, inputs, outputs, required tools

### AC-3: 3 brainstorm agents run in parallel ✅
- [x] Product, Architect, and Critical agents specified as parallel in step 03
- [x] Each writes independent output (`.run/03-product.md`, `.run/03-architect.md`, `.run/03-critical.md`)
- [x] Synthesis step reads all 3 outputs

### AC-4: Design review is conditional ✅
- [x] Step 05 asks user before running (with recommendation for complex features)
- [x] When it runs, 2-3 reviewers spawn in parallel

### AC-5: Output is a valid requirement file ✅
- [x] Step 06-08 produces requirement in AP format with frontmatter
- [x] Template includes id, type, category, status, priority, complexity, source
- [x] Template includes objective, background, technical requirements, success criteria, files, risks

### AC-6: Slash command updated ✅
- [x] `claude/commands/ap_brainstorm.md` rewritten as thin wrapper (52 lines, was 352)
- [x] Delegates to coordinator

### AC-7: Monolithic file deleted
- [ ] Old monolithic content replaced with thin wrapper — **pending real-project validation**

### AC-8: Real-project validation — **PENDING**
- [ ] Run decomposed brainstorm on a real feature idea
- [ ] Verify all 3 brainstorm agent outputs exist in `.run/`
- [ ] Verify synthesis output combines all 3 perspectives
- [ ] Verify output requirement file is valid and well-formed

### AC-9: Documentation updated ✅
- [x] README.md directory tree shows brainstorm coordinator + steps
- [x] Process docs — no direct references to brainstorm internals needed updating

---

## Files Expected to Change

**New files (coordinator):**
- `orchestration/coordinators/brainstorm.md`

**New files (steps):**
- `orchestration/steps/brainstorm/01-config-check.md`
- `orchestration/steps/brainstorm/02-gather-context.md`
- `orchestration/steps/brainstorm/03-spawn-agents.md`
- `orchestration/steps/brainstorm/04-synthesize.md`
- `orchestration/steps/brainstorm/05-design-review.md`
- `orchestration/steps/brainstorm/06-08-transform-write.md`

**Modified files:**
- `claude/commands/ap_brainstorm.md` — becomes thin wrapper loading coordinator

**Deleted files:**
- Old `claude/commands/ap_brainstorm.md` content (after validation)

---

## Dependencies
- **Scope 1 (Planning)** — coordinator pattern, model tiers, `.run/` data flow convention
- **Scope 4 (Release)** — validates the conditional step pattern (design review here mirrors PR shepherd there)

---

## Testing Strategy
1. Install updated framework on dendwrite project
2. Run decomposed brainstorm on a real feature idea
3. Verify all `.run/` step output files exist
4. Verify output requirement file is valid AP format
5. Test with complexity high enough to trigger design review
6. Test with low complexity to verify design review is skipped
7. Delete old monolithic `ap_brainstorm.md` — confirm nothing breaks
