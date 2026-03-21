---
id: metaswarm_scope_03_optional_gates
type: requirement
category: metaswarm
status: not_started
priority: low
---

# Requirements: Optional Quality Gates & Durable State

---

## Objective
Add opt-in design review gates for complex scopes and optional BEADS-backed durable execution state, giving teams the choice to add metaswarm-level rigor where it's warranted without imposing it universally.

## Background
The first two metaswarm integration scopes add knowledge/review to the orchestrator (Scope 01) and structured execution to the implementation agent (Scope 02). This third scope adds two features that are powerful but carry overhead — they should be available to teams that need them, but never mandatory.

1. **Design Review Gate**: For scopes tagged `complexity: complex` in requirement frontmatter, insert a multi-reviewer design review between planning and execution. 2-4 specialist agents (e.g., Security Agent, Architect Agent) independently evaluate the iteration plan before implementation begins. All must approve; max 2 revision cycles before human escalation. This catches design-level issues that are expensive to fix post-implementation.

2. **BEADS Durable State**: For teams with the BEADS CLI (`bd`) installed, execution state is persisted to `.beads/` with labeled task tracking. This enables seamless session recovery when context is compacted mid-execution — the new session loads the BEADS epic and continues from the last completed work unit. Falls back gracefully to file-based state (`current_iteration.conf`) when BEADS is not installed.

Both features are strictly optional. The framework must work identically without them.

**Dependencies**:
- `metaswarm_scope_01_knowledge_review` (the design review gate benefits from knowledge base priming)
- `metaswarm_scope_02_execution_enhancement` (BEADS tracks work unit state from Scope 02's decomposition)

**Reference**: [metaswarm](https://github.com/dsifry/metaswarm) — `skills/design-review-gate/` for multi-reviewer pattern, BEADS integration for durable state.

---

## Technical Requirements

### Design Review Gate

1. Add optional `complexity` field to requirement frontmatter: `complexity: simple | moderate | complex` (default: omitted, treated as `moderate`)
2. When `complexity: complex` is set, the orchestrator's planning phase (`01_plan_scope_instructions.md`) inserts a design review gate between plan creation and execution handoff
3. The design review spawns 2-4 specialist reviewers in parallel, selected based on scope characteristics:
   - **Security-touching scopes** (auth, tokens, encryption, user data): Security Design Agent
   - **Multi-system scopes** (API + frontend + database): Architect Agent
   - **User-facing scopes** (UI, UX, workflows): Product/UX Agent
   - **All complex scopes**: at minimum Architect Agent + one domain specialist
4. Each reviewer receives: the iteration plan (frozen criteria, technical assessment, files in scope) and relevant knowledge base entries (from Scope 01)
5. Each reviewer produces a structured verdict: APPROVE or REQUEST_CHANGES with specific, actionable feedback tied to plan sections
6. ALL reviewers must APPROVE before execution proceeds
7. If any reviewer issues REQUEST_CHANGES, the orchestrator revises the plan and re-submits — max 2 revision cycles
8. After 2 failed revision cycles, escalate to human with all reviewer feedback compiled
9. The design review gate is skipped entirely for scopes without `complexity: complex` — zero overhead for normal scopes
10. Add `## Design Review` section to `templates/iteration-plan.md` documenting review outcomes (or "N/A — not a complex scope")

### Configurable Quality Thresholds

11. Add `.agent_process/quality-config.json` for project-level quality gate configuration:
    ```json
    {
      "design_review": {
        "enabled": true,
        "trigger": "complexity:complex",
        "max_revision_cycles": 2,
        "min_reviewers": 2,
        "max_reviewers": 4
      },
      "adversarial_review": {
        "enabled": true,
        "skip_for_trivial": true
      },
      "work_unit_decomposition": {
        "enabled": true,
        "trigger_threshold_files": 3,
        "trigger_threshold_layers": 2,
        "max_work_units": 6
      }
    }
    ```
12. `install.sh` preserves `quality-config.json` on reinstall
13. All metaswarm integration features (from Scopes 01-03) check `quality-config.json` before activating — disabled features are fully skipped
14. Default config enables adversarial review and work unit decomposition; design review gate defaults to disabled (opt-in)

### BEADS Durable State (Optional)

15. Detect BEADS CLI availability at execution start: `which bd` or `command -v bd`
16. If BEADS is available, create a BEADS epic for the current scope on first `/ap_exec` invocation:
    - Epic name matches requirement ID (e.g., `auth_oauth2_integration`)
    - Tasks created for each work unit (from Scope 02 decomposition)
    - Labels track status: `in-progress`, `complete`, `blocked`, `retry:N`
17. If BEADS is NOT available, fall back to file-based tracking (`current_iteration.conf`, `current_work_unit.conf`, results.md) — no error, no warning, just silent fallback
18. On session recovery: if BEADS epic exists, load execution state from BEADS; otherwise reconstruct from file artifacts (existing behavior)
19. On iteration APPROVE: close BEADS epic with completion label
20. BEADS state is complementary to (not a replacement for) file-based artifacts — results.md and iteration folders remain the source of truth for the orchestrator's review
21. Add BEADS status to results.md Work Unit Summary when available (e.g., "BEADS epic: auth_oauth2_integration — 3/4 tasks complete")

---

## Success Criteria
- [ ] `complexity` field documented in requirement frontmatter schema (naming_conventions.md or roadmap_schema.md)
- [ ] Design review gate triggers ONLY when `complexity: complex` is set — verified by explicit skip logic for all other values
- [ ] 2-4 specialist reviewers selected based on scope characteristics (security, multi-system, user-facing)
- [ ] All reviewers must APPROVE; REQUEST_CHANGES triggers plan revision (max 2 cycles, then human escalation)
- [ ] Design review results recorded in iteration plan (`## Design Review` section)
- [ ] `quality-config.json` exists with documented schema and sensible defaults
- [ ] `install.sh` preserves `quality-config.json` on reinstall
- [ ] All metaswarm features (Scopes 01-03) respect `quality-config.json` enabled/disabled flags
- [ ] BEADS integration activates only when `bd` CLI is detected — silent fallback to file-based state otherwise
- [ ] BEADS epic lifecycle: create on first `/ap_exec`, update per work unit, close on APPROVE
- [ ] Session recovery works with or without BEADS (both paths tested)
- [ ] Developer documentation updated: README.md, process docs for design review gate and BEADS integration, quality-config.json schema reference

---

## Files Expected to Change
- `orchestration/01_plan_scope_instructions.md` (add design review gate step, complexity detection)
- `claude/commands/ap_exec.md` (add BEADS detection and epic lifecycle)
- `templates/iteration-plan.md` (add Design Review section)
- `process/naming_conventions.md` or `process/roadmap_schema.md` (document complexity field)
- `install.sh` (preserve quality-config.json on reinstall)
- `README.md` (document optional gates and BEADS)

**New files:**
- `quality-config.json` (quality gate configuration with defaults)
- `templates/design-review-prompt.md` (specialist reviewer prompt template)
- `process/design-review-gate.md` (how-to guide for design review usage)
- `process/beads-integration.md` (how-to guide for BEADS setup and usage)
- `process/quality-configuration.md` (reference doc for quality-config.json schema)

**Estimated:** 10-12 files

---

## Out of Scope
- Metaswarm's full 6-reviewer design gate (AP uses 2-4 reviewers — leaner)
- Swarm Coordinator for multi-scope parallel work (AP works one scope at a time)
- BEADS as a required dependency (must always be optional with graceful fallback)
- Custom reviewer agent definitions (use existing AP agent types + metaswarm-inspired prompts)
- Automated BEADS installation or setup (user installs `bd` CLI separately if they want it)
- 100% code coverage enforcement (AP uses scoped validation; coverage thresholds are project-specific, not framework-mandated)
- Multi-model design review (e.g., Gemini reviewers) — standard Task agents for now
- Changes to the 4-choice decision framework (APPROVE/ITERATE/BLOCK/PIVOT stays exactly as-is)

---

## Known Risks
- **Design review gate as bottleneck**: If reviewers are too strict or prompts too vague, the gate could block execution repeatedly. Mitigation: max 2 revision cycles, then human escalation. Reviewer prompts should evaluate plan feasibility, not subjective quality.
- **BEADS CLI version drift**: BEADS is an external dependency; CLI changes could break integration. Mitigation: use only stable BEADS commands (`bd epic create`, `bd task update`, `bd epic close`). Pin to documented CLI interface, not internals.
- **quality-config.json proliferation**: Adding another config file to `.agent_process/` increases cognitive overhead. Mitigation: defaults are sensible (most features enabled, design review disabled), so most teams never touch this file. The config is optional — framework works with built-in defaults if the file doesn't exist.
- **Interaction between Scope 01, 02, and 03 features**: All three scopes add features that interact (knowledge → design review, work units → BEADS). Mitigation: each feature checks its own enabled flag independently. Features degrade gracefully when prerequisites are missing (e.g., design review works without knowledge base, just with less context).

---

## References
- [metaswarm design-review-gate skill](https://github.com/dsifry/metaswarm) — multi-reviewer parallel gate pattern
- [BEADS CLI](https://github.com/dsifry/metaswarm) — git-native issue tracking for durable state
- `metaswarm_scope_01_knowledge_review` — prerequisite (knowledge base feeds design reviewers)
- `metaswarm_scope_02_execution_enhancement` — prerequisite (work unit decomposition feeds BEADS tracking)
- `orchestration/01_plan_scope_instructions.md` — planning instructions (will be modified for design review gate)
- `claude/commands/ap_exec.md` — execution flow (will be modified for BEADS lifecycle)

---

## Estimated Size
- **Duration:** 2-3 weeks
- **Iterations:** 3-4 estimated
- **Complexity:** HIGH

---

## Notes
This scope is intentionally the last in the sequence and the lowest priority. The knowledge base (Scope 01) and execution enhancement (Scope 02) deliver value independently and should be validated in real usage before adding more gates. Think of this scope as the "power user" tier — teams that have internalized AP's workflow and want additional rigor can opt in.

The `quality-config.json` is arguably the most important deliverable in this scope, even though it sounds mundane. It retroactively makes ALL metaswarm integration features configurable, including those from Scopes 01 and 02. This means a team can install the full framework but disable features they don't want — no forking, no conditional install flags, just a config file.

The design review gate should feel like a "senior engineer gut check" on the plan, not a bureaucratic approval process. The prompts should ask reviewers to identify likely failure modes, missing edge cases, and security blind spots — things that are cheap to catch in a plan but expensive to fix in code. If the gate starts producing boilerplate approvals, the prompts need sharpening.

BEADS integration is the most speculative feature here. It's valuable for long-running complex scopes where session interruption is likely, but most AP scopes complete within a single session. Track adoption and remove if it doesn't earn its keep.
