---
id: metaswarm_scope_01_knowledge_review
type: requirement
category: metaswarm
status: approved
priority: high
---

# Requirements: Knowledge Base & Adversarial Review Integration

---

## Objective
Add a persistent project knowledge base and fresh adversarial review pattern to AP's planning and review phases, giving the orchestrator better evidence without changing AP's decision framework.

## Background
The AI Agent Process orchestrator (typically Codex) plans and reviews iterations with strong structural discipline — frozen criteria, iteration budgets, 4-choice decisions. But it currently starts each planning phase cold (no accumulated project wisdom) and reviews with a single perspective (its own reading of code + results.md).

Metaswarm's two most portable innovations address both gaps:

1. **Knowledge Base**: A JSONL-based fact store (`patterns.jsonl`, `gotchas.jsonl`, `decisions.jsonl`, `anti-patterns.jsonl`) queried before planning. This prevents re-discovering known pitfalls and surfaces established patterns. The knowledge compounds over iterations — each APPROVE can deposit new learnings.

2. **Adversarial Review**: A fresh agent instance (no prior context from the implementation phase) independently checks each acceptance criterion with file:line evidence and issues a binary PASS/FAIL. This is an *input* to the orchestrator's 4-choice decision, not a replacement for it. The fresh-instance pattern prevents anchoring bias — the reviewer can't be influenced by having watched the implementation happen.

Both additions are strictly additive. No existing AP workflows change; the orchestrator simply gets richer inputs.

**Reference**: [metaswarm](https://github.com/dsifry/metaswarm) — `knowledge/` directory structure, `agents/code-review-agent.md` for adversarial review pattern.

---

## Technical Requirements

### Knowledge Base

1. Add `knowledge/` directory to `.agent_process/` with JSONL files: `patterns.jsonl`, `gotchas.jsonl`, `decisions.jsonl`, `anti-patterns.jsonl`
2. Entries follow a consistent schema: `{"id": "...", "scope": "...", "summary": "...", "detail": "...", "source_iteration": "...", "date": "..."}`
3. `install.sh` preserves `knowledge/` on reinstall (same treatment as `work/`)
4. Add a "Knowledge Query" step to `01_plan_scope_instructions.md` — orchestrator queries knowledge base for entries matching the scope's category and file paths before creating `iteration_plan.md`
5. Add a "Knowledge Deposit" step to `02_review_iteration_instructions.md` — on APPROVE, orchestrator extracts 0-3 learnings (patterns discovered, gotchas encountered, decisions made) and appends to knowledge base
6. Add `## Known Patterns & Constraints` section to `templates/iteration-plan.md` for knowledge base findings
7. Knowledge entries are append-only in normal operation; manual curation via direct file editing

### Adversarial Review

8. Add adversarial review step to `02_review_iteration_instructions.md` — after implementation completes and before the orchestrator's 4-choice decision, spawn a fresh Task agent with no implementation context
9. The fresh reviewer receives ONLY: the frozen acceptance criteria, the list of files changed (`git diff --name-only`), and the current file contents — NOT the results.md or implementation rationale
10. The reviewer produces a structured verdict: PASS or FAIL per criterion, with file:line evidence for each assessment
11. The orchestrator receives the adversarial review verdict as additional input alongside results.md and its own code reading
12. The adversarial review is advisory — it informs but does not override the orchestrator's 4-choice decision
13. Add an `adversarial_review` field to `templates/results.md` for documenting the verdict
14. The adversarial reviewer should be a fresh instance per review (no context carryover between sub-iterations)

---

## Success Criteria
- [ ] `knowledge/` directory exists in `.agent_process/` with the four JSONL files (can be empty initially)
- [ ] `install.sh` preserves `knowledge/` directory on reinstall
- [ ] `01_plan_scope_instructions.md` includes knowledge query step with search instructions
- [ ] `templates/iteration-plan.md` includes `## Known Patterns & Constraints` section
- [ ] `02_review_iteration_instructions.md` includes adversarial review step (spawn fresh Task, receive structured verdict)
- [ ] `02_review_iteration_instructions.md` includes knowledge deposit step on APPROVE
- [ ] `templates/results.md` includes `## Adversarial Review` section for recording the verdict
- [ ] Adversarial reviewer prompt template exists (specifies: frozen criteria only, file:line evidence required, binary PASS/FAIL per criterion, no access to results.md)
- [ ] Developer documentation updated: README.md reflects new capabilities, process docs explain knowledge base and adversarial review

---

## Files Expected to Change
- `orchestration/01_plan_scope_instructions.md` (add knowledge query step)
- `orchestration/02_review_iteration_instructions.md` (add adversarial review step + knowledge deposit)
- `templates/iteration-plan.md` (add Known Patterns section)
- `templates/results.md` (add Adversarial Review section)
- `install.sh` (preserve knowledge/ directory on reinstall)
- `README.md` (document new capabilities)

**New files:**
- `knowledge/patterns.jsonl`
- `knowledge/gotchas.jsonl`
- `knowledge/decisions.jsonl`
- `knowledge/anti-patterns.jsonl`
- `templates/adversarial-review-prompt.md` (fresh reviewer prompt template)
- `process/knowledge-base.md` (how-to guide for knowledge curation)

**Estimated:** 10-12 files

---

## Out of Scope
- BEADS integration (separate scope: `metaswarm_scope_03_optional_gates`)
- Work unit decomposition within /ap_exec (separate scope: `metaswarm_scope_02_execution_enhancement`)
- Design review gate (separate scope: `metaswarm_scope_03_optional_gates`)
- PR Shepherd automation (separate scope: `metaswarm_scope_02_execution_enhancement`)
- Automated knowledge curation agent (manual curation is fine for now)
- Multi-model adversarial review (e.g., using Gemini as reviewer) — standard Task agent is sufficient

---

## Known Risks
- **Knowledge base bloat**: Over time, the JSONL files could grow large enough to exceed context windows. Mitigation: the query step filters by scope category and file paths, not full-file loading. Process doc should include curation guidance.
- **Adversarial review adding latency**: Spawning a fresh Task adds time to each review cycle. Mitigation: the reviewer gets a tightly scoped prompt (frozen criteria + changed files only), keeping it fast. The orchestrator can skip adversarial review for trivial scopes if documented in the plan.
- **False confidence from PASS verdicts**: Teams may over-trust the adversarial review and under-invest in the orchestrator's own code reading. Mitigation: the review instructions explicitly state the adversarial review is advisory input, not a substitute for orchestrator verification.

---

## References
- [metaswarm knowledge/ directory](https://github.com/dsifry/metaswarm) — JSONL schema and priming patterns
- [metaswarm code-review-agent.md](https://github.com/dsifry/metaswarm/blob/main/agents/code-review-agent.md) — fresh reviewer pattern
- `orchestration/01_plan_scope_instructions.md` — current planning instructions (will be modified)
- `orchestration/02_review_iteration_instructions.md` — current review instructions (will be modified)
- `process/documentation-checklist.md` — documentation standards this scope must follow

---

## Estimated Size
- **Duration:** 1-2 weeks
- **Iterations:** 2-3 estimated
- **Complexity:** MEDIUM

---

## Notes
The knowledge base and adversarial review are intentionally decoupled from each other — either could be implemented independently. However, they're grouped in one scope because both are additive changes to the orchestration instructions and neither requires changes to the implementation phase (`ap_exec`). They share a theme: giving the orchestrator better information to make better decisions.

The adversarial review prompt template is the trickiest piece — it must be specific enough to produce useful file:line evidence but generic enough to work across any scope type. Study metaswarm's code-review-agent.md for patterns, but adapt to AP's frozen-criteria model rather than metaswarm's DoD model.

---

## Implementation Status

**Status:** ✅ APPROVED
**Date:** 2026-03-21
**Branch:** `scope/metaswarm_scope_01_knowledge_review`
**Iterations Used:** 1 (no sub-iterations needed)

**Summary:**
All 9 success criteria met. Knowledge base (query, deposit) and adversarial review (fresh reviewer, binary verdicts) implemented in orchestration instructions, templates, and process docs. README updated. Field-tested on two real scopes on the audio-transcript-analysis-app project.

**Beyond original scope:**
- Added Step 9.6: Process knowledge deposit on BLOCK/PIVOT. Born from field testing where a BLOCK revealed valid process observations (stale doc references, ops gate behavior) that would have been lost under the APPROVE-only deposit rule.

**Field testing results:**
- Step 2.5 (knowledge query): Confirmed working — entries surfaced in both test scopes' iteration plans
- Step 9.5 (knowledge deposit on APPROVE): Confirmed working — `extract_shared_helper_before_deleting_legacy_module` deposited after second scope
- Step 9.6 (process deposit on BLOCK): Not yet tested (added after the BLOCK that inspired it)
- Compound learning loop: Confirmed — scope 2's planner used knowledge deposited from scope 1's BLOCK
- Adversarial review (Step 3.7): Orchestrator performed criterion-by-criterion verification with file:line evidence on both scopes; fresh-instance spawning pattern needs further confirmation

**Follow-up:**
- One knowledge entry manually seeded (`ops_gate_always_blocks_first_pass`) was later found to be based on incorrect assumptions and was removed. The stale-docs gotcha entry remains valid.
