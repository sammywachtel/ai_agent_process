# Metaswarm Integration — Commit Log

Branch: `scope/metaswarm-integration`

| # | Commit | Date | Phase | Summary |
|---|--------|------|-------|---------|
| 1 | `79a081e` | 2026-03-21 | Phase 1 | Knowledge base (JSONL, Step 2.5 query, Step 9.5 deposit) + adversarial review template |
| 2 | `f0c9d61` | 2026-03-21 | Phase 1 | Process knowledge deposit on BLOCK/PIVOT (Step 9.6) |
| 3 | `01033c1` | 2026-03-21 | — | Move requirements docs to `.agent_process/` |
| 4 | `c321d1f` | 2026-03-21 | Phase 2 | Work unit decomposition (Steps 1.25, 1.3) + PR shepherd (`--shepherd` flag, Step 9.5 of ap_release) |
| 5 | `2f17e2a` | 2026-03-22 | Phase 2 | Adversarial review platform-adaptive: primary in ap_exec Step 4.5, orchestrator falls back to rubric |
| 6 | `2d6c74e` | 2026-03-22 | Fix | Enforce valid status values (no "INCOMPLETE"), require self-unblocking before BLOCKED, exclude process artifacts from work unit file count |
| 7 | `6dc646e` | 2026-03-22 | Phase 3 | quality-config.json: centralized feature control for all metaswarm features |
| 8 | `794ae08` | 2026-03-22 | Phase 3 | Design review gate, BEADS integration, install.sh prompts, complexity frontmatter field |
| 9 | `a30c57a` | 2026-03-22 | — | Commit log update |
| 10 | `97f47d9` | 2026-03-22 | Fix | BEADS prompt skipped on first install (fresh config treated as user choice) |
| 11 | `b3c2f80` | 2026-03-22 | Fix | Stray `fi` syntax error in install.sh |
| 12 | `b44192c` | 2026-03-22 | Fix | Always prompt for BEADS on first configuration (even if bd already on PATH) |
| 13 | `3ef56dc` | 2026-03-22 | — | Backlog: metaswarm-inspired ap_project enhancements |
| 14 | `a2d2403` | 2026-03-22 | Enhancement | ap_project discover/init: knowledge summary, dependency analysis, BEADS state, complexity suggestions |
| 15 | `3cc63b8` | 2026-03-22 | — | Commit log update + branch rename |
| 16 | `95febdb` | 2026-03-22 | Fix | Require Dolt as prerequisite for BEADS (never auto-install ~100MB server), add `bd init` to install.sh + ap_exec |

### Files changed per commit

<details>
<summary>79a081e — Knowledge base + adversarial review</summary>

- `orchestration/02_review_iteration_instructions.md` — Steps 3.7 (adversarial review), 9.5 (knowledge deposit)
- `claude/commands/ap_exec.md` — Step 2.5 (knowledge query)
- `templates/adversarial-review-prompt.md` — New: reviewer prompt template
- `templates/results.md` — Added Adversarial Review section
- `process/knowledge-base.md` — New: how-to guide
- `orchestration/00_base_context.md` — Knowledge deposit mention
- `README.md` — Knowledge base + adversarial review docs
</details>

<details>
<summary>f0c9d61 — BLOCK/PIVOT knowledge deposit</summary>

- `orchestration/02_review_iteration_instructions.md` — Step 9.6 (process knowledge on BLOCK/PIVOT)
- `process/knowledge-base.md` — Deposit decision matrix, process knowledge section
</details>

<details>
<summary>01033c1 — Requirements docs relocated</summary>

- `.agent_process/requirements_docs/metaswarm/metaswarm_scope_01_knowledge_review.md` — Moved from `.local_docs/`
- `.agent_process/requirements_docs/metaswarm/metaswarm_scope_02_execution_enhancement.md` — Moved from `.local_docs/`
- `.agent_process/requirements_docs/metaswarm/metaswarm_scope_03_optional_gates.md` — Moved from `.local_docs/`
</details>

<details>
<summary>c321d1f — Work unit decomposition + PR shepherd</summary>

- `claude/commands/ap_exec.md` — Steps 1.25 (assess decomposition), 1.3 (decompose into work units)
- `claude/commands/ap_release.md` — `--shepherd` flag, Step 9.5 (PR shepherd)
- `templates/results.md` — Work Unit Summary section
- `templates/work-unit-decomposition.md` — New: Architect Agent prompt template
- `process/work-unit-execution.md` — New: how-to guide
- `process/pr-shepherd.md` — New: how-to guide
- `orchestration/00_base_context.md` — Work unit mentions
- `README.md` — Work unit + PR shepherd docs
- `.gitignore` — `.local-docs/` → `.local_docs/`
</details>

<details>
<summary>2f17e2a — Adversarial review platform-adaptive</summary>

- `claude/commands/ap_exec.md` — Step 4.5 (adversarial review, fresh Task agent)
- `claude/commands/ap_iteration_results.md` — Loads adversarial-review.md, includes verdict in results
- `orchestration/02_review_iteration_instructions.md` — Step 3.7 rewritten: Path A/B/C
- `orchestration/00_base_context.md` — Review step mentions adversarial-review.md
- `templates/results.md` — Adversarial Review section now populated by impl agent
- `README.md` — Platform-adaptive explanation
- `.agent_process/requirements_docs/metaswarm/metaswarm_scope_02_execution_enhancement.md` — Status → completed
</details>

<details>
<summary>2d6c74e — Status enforcement + self-unblocking (field test fix)</summary>

- `claude/commands/ap_iteration_results.md` — Status options aligned with template; explicit rules forbidding invented statuses
- `claude/commands/ap_exec.md` — Troubleshooting: must attempt to resolve blockers before BLOCKED; work unit trigger excludes process artifacts
- `templates/results.md` — HTML comment explaining valid status values
- `orchestration/02_review_iteration_prompt.md` — "complete" → "approved" terminology
</details>

<details>
<summary>6dc646e — quality-config.json foundation</summary>

- `quality-config.json` — New: centralized feature control with defaults
- `process/quality-configuration.md` — New: full schema reference doc
- `install.sh` — Creates/preserves quality-config.json
- `claude/commands/ap_exec.md` — Loads config, Steps 1.25 and 4.5 check enabled flags and thresholds
- `orchestration/02_review_iteration_instructions.md` — Steps 3.7, 9.5, 9.6 check config
</details>

<details>
<summary>794ae08 — Design review gate + BEADS + install.sh prompts</summary>

- `orchestration/01_plan_scope_instructions.md` — Step 8.5 (design review gate, platform-adaptive)
- `claude/commands/ap_exec.md` — Step 0.5 (BEADS detect/install/epic lifecycle)
- `install.sh` — BEADS Y/n prompt, auto-install (npm → brew → curl), config update
- `templates/design-review-prompt.md` — New: specialist reviewer prompt template
- `templates/iteration-plan.md` — Design Review section
- `process/design-review-gate.md` — New: how-to guide
- `process/beads-integration.md` — New: how-to guide
- `process/naming_conventions.md` — `complexity` field in frontmatter schema
- `README.md` — Design review, quality config, BEADS documentation
- `.agent_process/requirements_docs/metaswarm/metaswarm_scope_03_optional_gates.md` — Status → completed
</details>

<details>
<summary>95febdb — Dolt prerequisite for BEADS</summary>

- `install.sh` — Check for `dolt` before installing `bd`; run `bd init` if `.beads/` missing; Dolt install instructions in prompt
- `claude/commands/ap_exec.md` — Step 0.5: require both `dolt` and `bd`; `bd init` before `bd epic create`
- `process/beads-integration.md` — Prerequisites section: Dolt never auto-installed, manual install instructions
</details>
