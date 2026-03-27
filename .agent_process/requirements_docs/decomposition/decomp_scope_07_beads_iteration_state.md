---
id: decomp_scope_07_beads_iteration_state
type: requirement
category: decomposition
status: planned
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

### AC-1: Iteration state stored in BEADS
- [ ] `beads-lifecycle.sh start` sets `iteration={iteration}` state on the epic
- [ ] Review post-decision step (ITERATE) updates iteration state in BEADS
- [ ] Review post-decision step (APPROVE) records final iteration in BEADS before close

### AC-2: Preflight reads from BEADS when available
- [ ] Execute preflight checks BEADS for current iteration when `beads.enabled` is true
- [ ] Falls back to `current_iteration.conf` when BEADS is disabled or `bd` unavailable

### AC-3: current_iteration.conf becomes fallback
- [ ] Still written on every state change (backwards compatibility)
- [ ] Preflight prefers BEADS when available, conf file when not
- [ ] No behavior change for BEADS-disabled projects

### AC-4: Session recovery uses BEADS
- [ ] `007b-session-recovery.md` checks BEADS epic state for interrupted work when BEADS enabled
- [ ] Falls back to file-based check when BEADS disabled

### AC-5: Documentation updated
- [ ] `process/beads-integration.md` documents iteration state tracking
- [ ] `process/quality-configuration.md` notes BEADS as authoritative when enabled

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
