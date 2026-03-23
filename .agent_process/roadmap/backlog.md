# Backlog

Items for future scopes. Sourced from metaswarm evaluation, field testing, and process observations.

---

## ap_project Enhancements (Metaswarm-Inspired)

### Knowledge-Prime `add-requirement` and `import-requirement`
**Source:** Metaswarm researcher agent priming pattern (2026-03-22)
**Type:** Enhancement

When creating or importing a requirement, auto-query the knowledge base for patterns, gotchas, and decisions matching the requirement's keywords and expected file scope. Include relevant entries directly in the generated requirement doc so the orchestrator sees them during planning — don't wait for Step 2.5.

Both `add-requirement` and `import-requirement` should share the same enrichment pipeline. The only difference is where the initial content comes from (template vs. existing file).

**Acceptance Criteria:**
- [ ] `add-requirement` queries knowledge base using requirement name/description keywords
- [ ] `import-requirement` queries knowledge base using imported file's content keywords
- [ ] Relevant entries included in a "Known Patterns & Constraints" section in the generated/enriched doc
- [ ] Pipeline is shared between both commands (no duplication)

---

### Pre-Flight Requirement Validation
**Source:** Metaswarm plan review gate, lighter version (2026-03-22)
**Type:** Enhancement

After creating or importing a requirement, run a quick validation pass:
- Are the success criteria testable and specific? (flag vague ones like "improve performance")
- Is the file scope present and reasonable?
- If file scope spans 2+ system layers, suggest adding `complexity: complex`
- Are there `depends_on` candidates? (scan existing requirements for overlapping file scopes)

**Acceptance Criteria:**
- [ ] Both `add-requirement` and `import-requirement` run validation after doc creation/import
- [ ] Vague criteria flagged with suggestions for improvement
- [ ] `complexity: complex` suggested when file scope spans multiple layers
- [ ] Overlapping file scopes with existing requirements flagged as potential dependencies

---

### `ap_project retro` — Automated Retrospective
**Source:** Metaswarm self-reflect command + knowledge curator agent (2026-03-22)
**Type:** Feature

New subcommand that scans the most recently completed scope's artifacts (results.md, adversarial-review.md, feedback.md) and any PR comments to extract learnings. Deposits to the knowledge base. Automates what the orchestrator does manually in Steps 9.5/9.6 but at a project management level — useful for extracting learnings the orchestrator missed or for scopes that were approved without thorough knowledge deposit.

**Acceptance Criteria:**
- [ ] Scans work artifacts from the most recent APPROVED scope
- [ ] Extracts candidate learnings (patterns, gotchas, decisions)
- [ ] Presents candidates to user for approval before depositing
- [ ] Deposits approved entries to knowledge base JSONL files

---

### `ap_project deps` — Dependency Visualization
**Source:** Metaswarm swarm coordinator dependency detection (2026-03-22)
**Type:** Feature

New subcommand that reads `depends_on` fields from all requirement frontmatter and renders an ASCII DAG showing dependency relationships. AP already stores this data but doesn't visualize it.

**Acceptance Criteria:**
- [ ] Scans all requirement docs for `depends_on` fields
- [ ] Renders ASCII DAG showing requirement relationships
- [ ] Highlights circular dependencies as errors
- [ ] Shows status of each node (not_started, in_progress, approved, blocked)

---

### Enrich `ap_project status` with BEADS State
**Source:** Metaswarm BEADS epic/task queries (2026-03-22)
**Type:** Enhancement

When BEADS is available (`bd` on PATH and enabled in quality-config.json), supplement the roadmap-file-based status display with live execution state from BEADS epics. Show which tasks are in-progress, which are blocked, and which are complete — information that the roadmap file doesn't track at the work-unit level.

**Acceptance Criteria:**
- [ ] `ap_project status` checks for BEADS availability
- [ ] When available, queries `bd list` for active epics and their task states
- [ ] Displays BEADS state alongside roadmap status
- [ ] Graceful fallback when BEADS unavailable (current behavior unchanged)

---

### Velocity Metrics in `ap_project report`
**Source:** Metaswarm metrics agent (2026-03-22)
**Type:** Enhancement

Add velocity and health metrics to the `report` subcommand. Analyzable from existing work/ folder data: iterations-per-scope, sub-iteration rate, APPROVE/ITERATE/BLOCK ratio, average time-to-completion. No external dependencies needed.

**Acceptance Criteria:**
- [ ] `ap_project report` includes a "Process Health" section
- [ ] Metrics derived from work/ folder analysis (iteration counts, decision types, dates)
- [ ] Trend detection: are scopes completing faster or slower over time?
- [ ] No external service dependencies

---

### `ap_project harvest-knowledge` — Backfill Knowledge from Past Scopes
**Source:** Session discussion on knowledge base gaps (2026-03-23)
**Type:** Feature

New subcommand for selectively extracting knowledge entries from completed scopes that predate the knowledge base system. Takes specific scope names (not "all"), reads `results.md`, `iteration_plan.md`, and `adversarial-review.md`, proposes candidate entries, and presents each to the user for approval before depositing.

Includes a staleness check: verifies referenced files still exist and flags entries where the codebase has significantly changed since the scope completed. This prevents polluting the knowledge base with outdated patterns from early scopes that no longer reflect the architecture.

**Acceptance Criteria:**
- [ ] Takes one or more scope names as arguments (not bulk "all")
- [ ] Reads scope artifacts: results.md, iteration_plan.md, adversarial-review.md
- [ ] Proposes candidate knowledge entries in standard JSONL format
- [ ] Staleness check: flags entries where referenced files were deleted or heavily modified since scope completion
- [ ] Presents each candidate to user for keep/edit/skip decision
- [ ] Only deposits user-approved entries to knowledge base
- [ ] Optional `--check-staleness` flag for extra validation

---

## Field Test Observations

### Investigate `bd init` Requirement
**Source:** Phase 3 field testing (2026-03-22)
**Type:** Investigation

Determine if `bd init` needs to run in the project directory before BEADS epics can be created. If so, add it to Step 0.5 of `ap_exec` (after auto-install, before epic creation). Currently Step 0.5 assumes `bd epic create` works immediately after installation.

**Acceptance Criteria:**
- [ ] Confirmed whether `bd init` is required before `bd epic create`
- [ ] If required, added to Step 0.5 with idempotency check
