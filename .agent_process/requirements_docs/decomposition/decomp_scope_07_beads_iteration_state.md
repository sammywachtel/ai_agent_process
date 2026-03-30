---
id: decomp_scope_07_beads_iteration_state
type: requirement
category: decomposition
status: in_progress
priority: medium
---

# Requirements: BEADS as Single Source of Iteration State

---

## Objective
When BEADS is enabled, store the current iteration pointer in BEADS (via `bd set-state`) instead of relying on `current_iteration.conf`. Eliminates dual state tracking — one source of truth per project.

## Background
Currently there are two parallel state systems:
- `current_iteration.conf` — file-based, tells `ap_exec` which scope/iteration is active
- BEADS epic — tracks scope lifecycle but doesn't store the current iteration pointer

Both get updated independently, creating drift risk. When BEADS is enabled, it should be authoritative. `current_iteration.conf` becomes a fallback for BEADS-disabled projects only.

`bd set-state` is the right mechanism — it creates an event bead (audit trail) and sets a label (fast lookup):
```bash
bd set-state {epic_id} iteration=iteration_01_a --reason "ITERATE decision"
bd state {epic_id} iteration  # → iteration_01_a
```

---

## Acceptance Criteria

### AC-1: Iteration state stored in BEADS ✅
- [x] `beads-lifecycle.sh start` sets `iteration={iteration}` state on the epic via `bd set-state`
- [x] Review post-decision step (ITERATE) uses `beads-lifecycle.sh set-iteration` for handoff
- [x] `close` action records final iteration in BEADS before closing epic

### AC-2: Preflight reads from BEADS when available ✅
- [x] `beads-lifecycle.sh get-iteration` checks BEADS first via `bd state`
- [x] Falls back to `current_iteration.conf` when BEADS disabled, `bd` unavailable, or no epic found

### AC-3: current_iteration.conf becomes fallback ✅
- [x] `set-iteration` always writes conf file alongside BEADS
- [x] `get-iteration` reads BEADS first, conf file second
- [x] No behavior change for BEADS-disabled projects (conf file is only source)

### AC-4: Session recovery uses BEADS ✅
- [x] `007b-session-recovery.md` calls `get-iteration` to check BEADS for iteration state
- [x] Falls back to file-based check when BEADS disabled

### AC-5: Documentation updated ✅
- [x] `process/beads-integration.md` documents iteration state tracking with BEADS authority note
- [ ] `process/quality-configuration.md` notes BEADS as authoritative when enabled — **pending**

### AC-6: Real-project validation — **PENDING**
- [ ] Run `ap_exec` with BEADS enabled — verify `bd state` shows correct iteration
- [ ] Review with ITERATE — verify BEADS iteration updates to `_a`
- [ ] Disable BEADS — verify `current_iteration.conf` fallback works

---

## Files Expected to Change

**Modified files:**
- `scripts/beads-lifecycle.sh` — add `bd set-state` for iteration tracking
- `orchestration/coordinators/execute-preflight.md` — read iteration from BEADS
- `orchestration/steps/execution/007b-session-recovery.md` — check BEADS for interrupted work
- `orchestration/steps/review/07-10-post-decision.md` — update BEADS iteration state on ITERATE
- `process/beads-integration.md` — document iteration state
- `process/quality-configuration.md` — note BEADS authority

---

## Dependencies
- **Scope 2 (Execution)** — preflight coordinator and step files must exist
- **Scope 3 (Review)** — post-decision step must exist

---

## Testing Strategy
1. Run `ap_exec` with BEADS enabled — verify `bd state` shows correct iteration
2. Review with ITERATE — verify BEADS iteration updates to `_a`
3. Run `ap_exec` for sub-iteration — verify BEADS shows `_a`
4. Disable BEADS — verify `current_iteration.conf` fallback works unchanged
5. Interrupt mid-execution — verify session recovery reads from BEADS
