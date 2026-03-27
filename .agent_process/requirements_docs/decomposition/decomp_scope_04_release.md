---
id: decomp_scope_04_release
type: requirement
category: decomposition
status: completed
priority: medium
---

# Requirements: Release Prompt Decomposition

---

## Objective
Replace the monolithic `claude/commands/ap_release.md` (1,189 lines) with a coordinator prompt (~100 lines) and 9 focused step files. The release workflow has a clear sequential spine with a parallel context-gathering phase at the start and a conditional PR shepherd at the end.

## Background
The release prompt handles the full release lifecycle: gathering git context, detecting project structure, determining version, classifying change type, updating changelogs, updating version files, committing, tagging, pushing, creating PRs, and optionally launching PR shepherd. At 1,189 lines it's the second-largest monolithic file.

Key constraints:
- Steps 07-09 (commit → tag → push → PR) MUST stay as a single sequential step — git operations cannot be parallelized
- Steps 01-02 (gather context + detect structure) CAN run in parallel
- PR shepherd (095) is already a sub-agent — decomposition just gives it its own step file

**Reference**: Full architecture in `.local_docs/orchestrator-decomposition-plan.md`, Scope 4 section.

---

## Acceptance Criteria

### AC-1: Coordinator prompt exists and is well-formed ✅
- [x] `orchestration/coordinators/release.md` exists (116 lines)
- [x] Accepts args: `[noscope] $MODE [$VERSION] [--shepherd/--no-shepherd]`
- [x] Specifies parallel context-gathering phase (steps 01+02)
- [x] Marks steps 07-09 as MUST BE SEQUENTIAL
- [x] Marks step 095 (PR shepherd) and step 06 (update version) as conditional

### AC-2: All 9 step files exist with correct structure ✅
- [x] Each step file in `orchestration/steps/release/`:
  - `01-gather-context.md` (61 lines)
  - `02-detect-structure.md` (48 lines)
  - `03-get-version.md` (53 lines)
  - `04-change-type.md` (51 lines)
  - `05-update-changelog.md` (49 lines)
  - `06-update-version.md` (47 lines, conditional: release mode only)
  - `07-09-commit-tag-push.md` (90 lines)
  - `095-pr-shepherd.md` (58 lines, conditional: config/flag)
  - `10-report.md` (44 lines)
- [x] Each specifies model tier, inputs, outputs, required tools

### AC-3: Parallel context gathering ✅
- [x] Steps 01 and 02 specified as parallel in coordinator — "Spawn TWO cheap sub-agents simultaneously"
- [x] Step 03 waits for both before proceeding

### AC-4: Git operations stay sequential ✅
- [x] Step 07-09 is a single step: commit → tag → push → PR
- [x] Coordinator explicitly marks "MUST BE SEQUENTIAL"

### AC-5: Conditional steps work correctly ✅
- [x] Step 06 coordinator says "If mode is NOT release: Skip"
- [x] Step 095 coordinator checks config + CLI flags with 4-way logic

### AC-6: Slash command updated ✅
- [x] `claude/commands/ap_release.md` rewritten as thin wrapper (96 lines, was 1,189)
- [x] All CLI arguments documented, delegates to coordinator

### AC-7: Monolithic file deleted ✅
- [x] Old monolithic content (1,189 lines) replaced with thin wrapper (96 lines)
- [x] Validated: decomposed version produces correct release on real project

### AC-8: Real-project validation ✅
- [x] Run decomposed release on audio project (PR mode) — commit `60877fc`, build/39, PR #139
- [ ] Run decomposed release on a real project (full release mode) — **deferred, PR mode validated**
- [x] Verify CHANGELOG.md correctly updated — Added, Changed, Fixed, Removed sections under [Unreleased]
- [x] Verify commit, tag, and PR created correctly — build/39 tag, PR created via `gh pr create`
- [x] Verify PR shepherd launches when configured — launched and monitoring in background
- [x] `.run/release/` files in scope work folder (user moved from project root after first run used noscope incorrectly; coordinator updated to prevent recurrence)
- [x] All 9 `.run/release/` step output files present
- [x] Central sync config properly referenced from step file

### AC-9: Documentation updated ✅
- [x] README.md directory tree shows release coordinator + steps
- [x] Process docs — no direct references to release internals needed updating

---

## Files Expected to Change

**New files (coordinator):**
- `orchestration/coordinators/release.md`

**New files (steps):**
- `orchestration/steps/release/01-gather-context.md`
- `orchestration/steps/release/02-detect-structure.md`
- `orchestration/steps/release/03-get-version.md`
- `orchestration/steps/release/04-change-type.md`
- `orchestration/steps/release/05-update-changelog.md`
- `orchestration/steps/release/06-update-version.md`
- `orchestration/steps/release/07-09-commit-tag-push.md`
- `orchestration/steps/release/095-pr-shepherd.md`
- `orchestration/steps/release/10-report.md`

**Modified files:**
- `claude/commands/ap_release.md` — becomes thin wrapper loading coordinator

**Deleted files:**
- Old `claude/commands/ap_release.md` content (after validation)

---

## Dependencies
- **Scope 1 (Planning)** — coordinator pattern, model tiers, `.run/` data flow convention
- **Scope 2 (Execution)** — slash command wrapper pattern

---

## Testing Strategy
1. Install updated framework on dendwrite project
2. Run changelog-only release — verify changelog update and commit
3. Run full release — verify version bump, tag, push, and PR creation
4. Test with `--shepherd` flag — verify PR shepherd launches
5. Test with `--no-shepherd` flag — verify it doesn't launch
6. Delete old monolithic `ap_release.md` — confirm nothing breaks
