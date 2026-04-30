# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Removal-scope checklist & stale-surface scrub gate** — New `process/removal-scope-checklist.md` encodes the migration lesson from CLAUDE.md so removal scopes can no longer ship with stale public-surface references via the "out of scope" channel. Planning step 04 now generates a per-surface whitelist; execution step 02 hands the executor a contract for extending it with justifications; review Gate 1 fails the iteration when the scrub is missing or whitelist entries lack justification. Additive scopes are unaffected — the gate falls back to its prior behavior when `Removed Surfaces` is `N/A`.
- **`templates/results.md` — Removed-Surface Scrub section** — Reserved slot the executor populates with the hit/resolved/whitelisted table when the plan declares removed surfaces. Default `N/A` for additive scopes.
- **Quality-gate artifact rule (executor instruction)** — When a fix targets a validator, audit hook, scrub block, gate test, lint/type-check config, or adversarial-review prompt, the prepare doc MUST include a negative-case acceptance test (introduce a synthetic violation, prove the artifact catches it) alongside the operational "exit 0" check. New §1.2 in `steps/execution/02-prepare.md`, mirrored upstream in `steps/review/03-decide.md` so ITERATE fix specs that target quality gates carry the negative case from the start. Closes the failure mode where a silently-broken validator passes "exit 0" while never catching anything.
- **Scope-boundary flexibility carry-forward (executor instruction)** — Sub-iteration prepare docs that narrow the file list relative to `iteration_plan.md` must include a verbatim flexibility clause; the iteration-plan rule already says "boundaries are guidance, not walls," but in practice a narrowed sub-iteration list has been read by implementers as a hard prohibition. New §1.3 in `steps/execution/02-prepare.md` re-states the rule explicitly so soundness fixes that need to step outside the named files are not silently walled off.
- **Spec Concerns channel (executor instruction)** — Implementers who notice a gap in *the prepare doc itself* — missing acceptance test, instruction conflicting with the iteration plan, soundness question about a quality-gate artifact, fix spec that names a symptom not a root cause — pause and write the concern under a `## Spec Concerns` heading in `results.md`, then either apply a safe local fix or stop for coordinator revision. New §1.4 in `steps/execution/02-prepare.md`; reviewer's Gate 1 (`steps/review/02-gates.md`) reads the section and refuses APPROVE while a concern is unresolved.
- **Contract-change rule (§1.4 hardening)** — Tightens the Spec Concerns channel to forbid "weakening-not-fixing" as a local fix. New triggers: about-to-weaken-a-failing-check (remove assertion, relax test, comment-out guard, rephrase-to-dodge-validator, document regression as "future work"); test-failure-points-at-production-code (production code is the bug, not the test — §1.3 lets you fix it). Explicit prohibition: weakening a failing assertion is a *contract change*, not a local fix; coordinator escalation is required even when the edit is mechanically simple. Reviewer's Gate 1 (`steps/review/02-gates.md`) gains a **Weakened-Assertion FAIL** rule that fails the iteration when results.md acknowledges weakening a check AND the underlying production fix did not land in the same iteration. Closes the failure mode where an executor classifies a contract-erosion as a "safe local fix" under §1.4 and ships the iteration with the contract surface silently reduced.
- **AC Enumeration Coverage rule (executor instruction)** — When ACs use universal quantifiers ("every", "each", "all") or enumerate multiple subjects with "and" ("X and Y"), the prepare doc must expand each enumeration into a per-subject coverage list. A single happy-path test passes exit-0 while leaving N−1 cells unproven; the rule forces per-cell proof. Combines with §1.2 to build a (subject × surface × {operational, negative}) coverage matrix. New §1.5 in `steps/execution/02-prepare.md`. Closes the failure mode where ACs that say "every X across surfaces Y and Z" get compressed during AC-to-test translation into a single operational check, leaving the validator unable to catch the coverage gap.
- **Append-instead-of-update anti-pattern (canonical records)** — New anti-pattern entry in `process/removal-scope-checklist.md` covering scopes that rename or replace a surface and append a "Phase X Implementation Index" or "see new section" pointer to canonical records (catalog entries, owner tables, decision logs) instead of updating the original entries in place. Two-sources-of-truth failure: the stale entry is the one a reader hits first, and the stale-surface scrub doesn't catch structured-field staleness in canonical records.
- **Bash 3.2 portability rule for validator scripts (planner instruction)** — `steps/planning/04-plan.md` Step 3 gains a portability section enumerating forbidden bash-4+ features (`declare -A`, `${var^^}`, `&>>`, `mapfile`, `[[ -v ]]`) and the recommended substitutes, with a worked example for the recurring surface→pattern lookup pattern that uses a `case`-statement function instead of an associative array. macOS default `/bin/bash` is 3.2.57; `#!/usr/bin/env bash` resolves to it unless Homebrew bash is on PATH. Includes a `bash -n` syntax-check smoke test for handoff. Closes the recurring failure mode where validator scripts pass under the planner's modern shell but FAIL Gate 4 (Scoped Validation) because the recorded pass isn't reproducible under the documented invocation shell. Three occurrences across two scopes (07e iteration_01_b, 08-phase1c iteration_01) before the rule was added.
- **§1.2 operational test must use documented invocation shell (executor instruction)** — Tightens `steps/execution/02-prepare.md` §1.2 to require the operational acceptance test for shell validators run under the same shell the documented invocation produces (e.g., macOS `/bin/bash` 3.2 for `#!/usr/bin/env bash`), with `bash --version` in the recorded transcript. A Homebrew-bash-5 pass when the documented invocation is `bash <script>` no longer satisfies the operational check.

### Changed
- **`templates/iteration-plan.md`** — Added a `Removed Surfaces` section between Documentation in Scope and Validation Requirements; default is `N/A` so additive scopes are unaffected.
- **`orchestration/steps/planning/04-plan.md`** — New step 2 ("Identify Removed Surfaces") between pre-existing-issues and validation-script generation; section list and step numbering updated accordingly.
- **`orchestration/steps/execution/02-prepare.md`** — Added §1.1 (Removed Surfaces handoff to the implementer), §1.2 (Quality-Gate Artifact Check), §1.3 (Scope Boundary Flexibility carry-forward), §1.4 (Spec Concerns Channel).
- **`orchestration/steps/review/02-gates.md`** — Gate 1 now has explicit FAIL conditions when `Removed Surfaces` is non-empty (missing scrub section, unjustified whitelist entries, operator-facing surfaces whitelisted as "historical") AND a new sub-section that fails Gate 1 when an unresolved Spec Concern is paired with an APPROVE decision.
- **`orchestration/steps/review/03-decide.md`** — Fix Specifications section gains a sub-section requiring negative-case acceptance tests when an ITERATE fix targets a quality-gate artifact; this is the upstream half of the §1.2 prepare-step rule.

## [3.3.0-beta.1] - 2026-03-27

### Added
- **Coordinator + step file architecture** — Decomposed monolithic orchestration prompts into 6 coordinators and 43 focused step files across planning (12), execution (7), review (9), release (9), and brainstorm (6) workflows
- **`/ap_brainstorm` command** — Multi-agent ideation spawning Product, Architecture, and Critical agents in parallel, with optional design review gate, producing formal AP requirements
- **`/ap_requirements` command** — Create, import, and list requirements with optional brainstorm routing and design review for imports
- **Knowledge base system** — JSONL-based accumulation of patterns, gotchas, decisions, and anti-patterns across iterations; queried during planning, deposited on APPROVE/BLOCK/PIVOT decisions
- **Adversarial review** — Fresh reviewer agent with zero implementation context independently verifies frozen criteria with PASS/FAIL per criterion and file:line evidence; platform-adaptive for Codex orchestrators
- **Work unit decomposition** — DAG-based parallel execution for multi-domain scopes (3+ files, 2+ layers) with per-unit agents, validation, and session recovery via `current_work_unit.conf`
- **PR shepherd** — Post-PR agent monitoring CI status, responding to review comments, auto-fixing lint/type failures, and reporting merge-readiness; activated with `--shepherd` flag
- **Design review gate** — Opt-in multi-reviewer plan assessment (2-4 specialist agents: Architect, Security, Product/UX) for complex scopes; max 2 revision cycles before human escalation
- **`quality-config.json`** — Centralized feature control for all quality gates: pre-flight, knowledge base, adversarial review, work unit decomposition, design review, PR shepherd, and metaswarm
- **Metaswarm integration** — Optional multi-agent brainstorming, design review gates, PR shepherd, knowledge priming, and self-reflection; controlled via `quality-config.json`
  - Auto-install metaswarm plugin during `install.sh` when enabled
  - Requirements and brainstorm commands route through metaswarm when available
- **Pre-flight checks** — Session recovery, working tree check (polyrepo-aware), branch auto-checkout (`scope/{scope}`), and git context for files in scope
- **Local environment instructions** — Every coordinator reads `.agent_process/process/local_environment_instructions.md` before each workflow for project-specific customization
- **Test suite** — Contract tests (adversarial review, results, iteration plan, knowledge entry) and unit tests (install) with `run-tests.sh` runner
- **Artifact evaluation** — `evaluate-scope.sh` validates AP's own artifacts (plans, results, reviews) against expected schema
- **Presentation materials** — Agent process flow deck, before-and-after comparison deck, and new system usage guide in `.local_docs/`

### Changed
- **README overhaul** — Restructured with quick start on top, required/optional dependency tables, quality configuration reference, testing section, and updated directory structure reflecting all current tooling
- **`claude/commands/README.md`** — Expanded with quick start, all subcommands and flags, dependency notes, and logical command groupings
- **Orchestration prompts** — Replaced monolithic `01_plan_scope_*.md` and `02_review_iteration_*.md` with decomposed coordinators and step files for maintainability
- **Install script** — Major expansion: metaswarm plugin auto-install, polyrepo support, scroll-up reminder
- **`/ap_exec`** — Streamlined to coordinator-based dispatch; pre-flight checks, work unit decomposition, adversarial review all integrated as numbered steps
- **`/ap_release`** — Streamlined to coordinator-based dispatch with step files
- **`/ap_project`** — Enhanced discover/init with knowledge base and dependency detection

### Fixed
- Preflight coordinator handles polyrepo for working tree and git context checks
- PR shepherd runs automatically when enabled in `quality-config.json` (was requiring manual activation)
- Orchestrator uses correct criteria version after PIVOT (replaced "ORIGINAL criteria" with version-aware language)
- Adversarial review loophole for qualified passes closed (no "passes with caveats")
- Various ASCII diagram alignment fixes across all documentation

---

## [3.2.0] - 2026-01-25

### Added
- **`/ap_project archive-completed` command** - Automated bulk archiving of approved work scopes
  - Scans `work/` for scopes with "Decision: APPROVE" in iteration_plan.md
  - Shows archive plan and asks for confirmation before proceeding
  - Moves scopes using `git mv` to preserve complete git history
  - Updates requirement frontmatter with approval metadata:
    - `status: approved`
    - `approved_date: [date from orchestrator decision]`
    - `work_location: work_archive/approved/[scope]/`
  - Generates/updates `completed_work.md` historical record grouped by category
  - Creates atomic git commit for all archive operations
  - Replaces manual Python script workflow with integrated command

### Technical Details
The archive-completed command automates what was previously a manual Python script process:
- **Identification**: Reads iteration_plan.md for "Decision: ✅ APPROVE" markers
- **History preservation**: Uses `git mv` for tracked files (falls back to `mv` + `git add` for untracked)
- **Requirement updates**: Modifies frontmatter YAML to track approval state and archive location
- **Historical record**: Groups completed work by category in `completed_work.md`
- **Safety**: Only processes explicitly approved scopes - in-progress or blocked work remains in `work/`

### Usage
```bash
/ap_project archive-completed   # Interactive bulk archive with confirmation
```

**Use this command to**:
- Declutter active `work/` directory after completing multiple scopes
- Maintain clean project metrics for status reports
- Create structured historical record of completed work
- Prepare for project milestones or quarterly reviews

---

## [3.1.5] - 2026-01-19

### Fixed
- **Config value extraction** in install.sh final status message
  - Now uses `head -20 | grep "^FIELD:"` to only match configuration block
  - Prevents false matches in documentation sections
  - Correctly displays "Central repo sync: enabled" when configured
- **Empty path validation** when configuring central repo sync
  - Prompt now loops until user provides a valid path
  - Prevents silent failures from empty CENTRAL_REPO_PATH values
- **VERSION file path** in central repo sync instructions
  - Fixed reference to use `$SOURCE_DIR/VERSION` instead of bare `VERSION`

### Technical Details
The extraction logic was matching ALL lines containing field names, including
documentation. Changed from:
```bash
grep "ENABLED:"  # Matches everywhere
```
To:
```bash
head -20 | grep "^ENABLED:"  # Only config block
```

---

## [3.1.4] - 2026-01-19

### Fixed
- **Command deployment issues** in install.sh
  - ap_project.md was not being deployed to `.claude/commands/`
  - Commands were incorrectly copied to source directory (`.claude/`) instead of template directory (`claude/`)
  - Duplicate command files in `.agent_process/claude/commands/` (old installs)
  - Recursive copy was duplicating all template files unnecessarily

### Changed
- **Command file structure** now properly separated:
  - `.claude/commands/*.md` - actual command files (where Claude Code looks)
  - `.agent_process/claude/commands/README.md` - placeholder pointing users to `.claude/`
  - `.agent_process/claude/*.md` - documentation only (commands.md, hooks.md)
- Install script now cleans up duplicate commands from previous installations

### Added
- `claude/commands/README.md` placeholder in template for reference

---

## [3.1.3] - 2026-01-19

### Fixed
- **Migration from old central sync format** in install.sh
  - Detects old format (no ENABLED field but has real paths)
  - Automatically migrates to new format with `ENABLED: true`
  - Prevents silent failures and unwanted user prompts
  - Handles three scenarios: old format, new enabled, new disabled

### Details
Old format (pre-v3.1.2):
```
CENTRAL_REPO_PATH: ~/path/to/repo
PROJECT_FOLDER: project-name
```

New format (v3.1.2+):
```
ENABLED: true
CENTRAL_REPO_PATH: ~/path/to/repo
PROJECT_FOLDER: project-name
```

Install now automatically migrates old → new without user intervention.

---

## [3.1.2] - 2026-01-19

### Changed
- **Central sync config now always created** for consistency
  - `process/ap_release_central_sync.md` created in all projects (not just enabled ones)
  - File uses `ENABLED: true` or `ENABLED: false` to control behavior
  - Makes configuration explicit rather than implicit (missing file = disabled)
  - Clearer documentation with enabled/disabled states explained
- **Updated `/ap_release` Step 9.5** to check `ENABLED:` field instead of file existence
- **Updated `install.sh`** to always create config file with appropriate state

### Benefits
- More consistent installation across all projects
- Explicit opt-out instead of implicit (no file = no sync)
- Configuration file documents itself (disabled state is self-explanatory)
- Easier for users to understand and modify sync behavior

---

## [3.1.1] - 2026-01-19

### Fixed
- **Central repo sync reminder** in install.sh
  - Installation now detects symlinked `.agent_process` directories
  - Displays actionable reminder to commit/push central repo after updates
  - Prevents uncommitted changes from accumulating in central repo
  - Shows exact commands needed to sync central repo
  - Only triggers when both symlink and central sync config exist

---

## [3.1.0] - 2026-01-19

### Changed
- **Orchestration planning integration** with roadmap system
  - Step 11 added to planning workflow: automatic roadmap update when scoping new work
  - Updates work scope count, status (📋→🚧), and Active Work section
  - Ensures roadmap stays synchronized with actual development activity
- **Iteration model clarification** in planning instructions
  - Renamed "Iteration Budget" to "Iteration Model" for clarity
  - Added explicit distinction between major iterations (for PIVOT) and sub-iterations (for fixes)
  - Documented human approval requirement for PIVOT decisions
- **Criteria history tracking** in iteration plans
  - Added "Criteria History" section to track v1, v2, v3 criteria across PIVOTs
  - Locked criteria versions make it clear what changed between iterations
- **Priority value standardization**
  - Updated from lowercase (high/medium/low) to uppercase (CRITICAL/HIGH/MEDIUM/LOW)
  - Matches roadmap system priority format
- **Extended time budget** in planning template
  - Changed from "1-2 weeks total" to "1-3 weeks total"
  - Accommodates multiple iterations and PIVOT cycles

### Fixed
- Planning workflow now references roadmap update procedures when roadmap exists
- Checklist in prompt includes roadmap update step

---

## [3.0.0] - 2026-01-18

### Added
- **Roadmap Management System** - comprehensive project visibility and status tracking
  - New `/ap_project` command with 10 actions: init, discover, status, set-status, archive, add-todo, add-requirement, sync, report, help
  - Automated project discovery scans `requirements_docs/` and `work/` to build roadmap
  - Live completion metrics with category breakdown (e.g., "86.1% complete, 68/79 requirements")
  - Smart requirement matching using frontmatter IDs, manual mappings, and fuzzy matching
  - Structured backlog system with prioritized work queue and acceptance criteria
  - Status tracking: ✅ Complete | 🚧 In Progress | ❌ Blocked | 📋 Not Started
  - Consolidated `master_roadmap.md` format (replaces separate work_scope_details.md and phase_status.md)
  - Configuration file (`.roadmap_config.json`) for project-specific mappings and status markers
  - Audit trail support (`.roadmap_audit.jsonl`) for status change history
  - Stakeholder reporting (executive, detailed, weekly formats)

- **Process Documentation** - comprehensive roadmap system guides
  - `process/naming_conventions.md` - single source of truth for requirement IDs, filenames, categories
  - `process/roadmap_discovery.md` - automated discovery process and matching algorithms
  - `process/roadmap_schema.md` - roadmap file format specification and structure
  - `process/roadmap_update.md` - update procedures and workflow guidance

### Changed
- **Philosophy update**: "Ship pragmatically, iterate deliberately, **pivot when you learn**" (was "converge forcefully")
- **Two-level iteration model** clarified in README
  - Major iterations (01, 02, 03) for criteria changes via PIVOT
  - Sub-iterations (_a, _b, _c) for fixes within same criteria via ITERATE
  - Max 3 sub-iterations per major iteration before PIVOT or BLOCK
- **`/ap_exec` command** updated with iteration_02+ examples for clarity
- **README.md** restructured with:
  - Two-level iteration model explanation
  - Success metrics section
  - Updated documentation references
  - Clearer PIVOT vs ITERATE guidance

### Breaking Changes
- Roadmap files now use consolidated format (single `master_roadmap.md` instead of separate files)
- Projects using old roadmap format should run `/ap_project discover` to migrate to new structure
- Status markers standardized to: `**Status:** COMPLETE`, `**Status:** BLOCKED`, `**Status:** IN_PROGRESS`, `**Status:** FAILED`

### Deprecated
- Separate `work_scope_details.md` and `phase_status.md` files (consolidated into `master_roadmap.md`)
- Discovery-based status marker detection (now uses standardized markers)

---

## [2.0.0] - 2026-01-13

### Added
- **Build tags** (`build/N`) for all release modes - monotonically increasing artifact tracking independent of semantic versions
  - Every `/ap_release` invocation (pr, beta, release) now creates a build tag
  - Build numbers included in commit messages, PR descriptions, and tag annotations
  - Enables fast rollbacks and deployment tracking without version lookup
- **Central repo sync** (Step 9.5) for projects using symlinked `.agent_process/`
  - New optional `process/ap_release_central_sync.md` configuration file
  - Automatically syncs changes to central tracking repo after releases
  - Preserves commit traceability between project and central repos
- **Installer improvements**
  - Detects and preserves `.agent_process/` symlinks during re-installation
  - Prompts for central repo sync configuration during install
  - Updates templates while preserving user-configured values
  - All paths now use `$AGENT_PROCESS_DIR` variable for symlink compatibility

### Changed
- Step 8 renamed from "Create Tag (beta and release modes only)" to "Create Tags" (now applies to all modes)
- Mode Reference table now shows separate "Creates Build Tag" and "Creates Release Tag" columns
- Tag conventions updated to distinguish lightweight (build) vs annotated (release/beta) tags

---

## [1.4.0] - 2026-01-09

### Added
- Automated requirements file breakdown in scope planning workflow
  - Orchestrator now offers to split oversized requirements files automatically
  - Renames original to `*-breakdown[.ext]` using `git mv` to preserve history
  - Creates numbered split files (`*-01[.ext]`, `*-02[.ext]`, etc.) maintaining alphanumeric order
  - Updates breakdown file with references to new split files
  - Each split file references the original and indicates which part it is (X of N)
  - Reduces manual work when requirements exceed single-scope sizing
  - Added "Large Requirements File Breakdown" section to `01_plan_scope_instructions.md`
  - Updated `01_plan_scope_prompt.md` with automated vs manual splitting options

---

## [1.3.0] - 2026-01-07

### Added
- Integration Verification Gate (Step 3.6) in iteration review workflow
  - Catches frontend/backend schema mismatches before they reach production
  - Verifies component interface compatibility across call sites
  - Checks database schema changes against query usage
  - Validates configuration changes against consumers
  - Allows scope expansion to include out-of-scope files when integration issues found
  - Includes grep commands and manual verification checklists
  - Updated APPROVE/ITERATE templates to require integration status reporting
  - Added integration verification to validation checklist

### Fixed
- Orchestrator now verifies related code outside scope to prevent runtime integration failures
  - Prevents the specific case where frontend changes API calls but backend schema not checked
  - Reduces production bugs caused by schema drift and interface incompatibilities

---

## [1.2.0] - 2026-01-04

### Fixed
- Documentation now includes version format examples for beta mode
  - Added `(vX.Y.Z-beta.N)` format examples to `claude/commands.md`
  - Added `(vX.Y.Z-beta.N)` format examples to `orchestration/02_review_iteration_instructions.md`
  - Ensures users understand the exact tag format they'll get

---

## [1.1.0] - 2026-01-04

### Added
- USER_CHANGELOG.md generation in `/ap_release` command for user-facing release notes
  - Automatic transformation from technical changelog to user-friendly language
  - Permission-based update workflow (never modifies existing entries without asking)
  - Supports emojis and benefit-focused descriptions

### Fixed
- Command front matter now conforms to Claude Code specification
  - Removed invalid `name` and `arguments` fields
  - Moved argument documentation to command body with `$1`, `$2` placeholders
  - All commands (`ap_release`, `ap_changelog_init`, `ap_exec`, `ap_iteration_results`) updated

---

## [1.1.0-beta.1] - 2026-01-04

### Added
- `/ap_release` command for changelog updates, PR creation, and release tagging
  - Three modes: `pr` (changelog only), `beta` (+ beta tag), `release` (+ version bump)
  - Smart project structure detection (Python, TypeScript, full-stack)
  - Conventional commit messages with scope/iteration trailers
- `/ap_changelog_init` command for retroactive changelog creation from git history
  - Analyzes tags and commits to generate historical summary
  - Groups changes by era/milestone with key commit references
- Orchestrator now suggests `/ap_release` after APPROVE decisions

### Changed
- Updated commands documentation with release workflow section

---

## [1.0.0] - 2026-01-04

**Detailed changelog tracking begins with this version.**

This release marks the AI Agent Process Template as stable and ready for adoption. The workflow has been battle-tested across multiple projects and refined based on real-world usage.

For historical context, see the summary below and the [full git history](https://github.com/sammywachtel/ai_agent_process/commits/main).

---

## Historical Summary

### Documentation & Release Workflow (Dec 2025 - Jan 2026)

**Highlights:**
- Integrated "Zero Documentation Drift" into every workflow phase
- Added dual-audience documentation framework (end users vs developers)
- Created documentation verification gate (blocking requirement for approval)
- Added `/ap_release` command for changelog and version management
- Added `/ap_changelog_init` for retroactive changelog creation

**Key commits:**
- `b07fc7e` Integrate documentation maintenance into .agent_process workflow (2025-12-30)
- `a30f275` Update hooks documentation with correct Claude Code configuration (2025-12-11)
- `87239a1` Fix critical bugs in after_edit hook preventing proper execution (2025-12-11)

### Agent Specialization & Git Automation (Dec 2025)

**Highlights:**
- Added specialized agent selection framework (frontend, backend, testing, DevOps)
- Automatic git branch creation for scope isolation (`scope/{scope}` naming)
- Enhanced Task tool templates for first iterations vs sub-iterations
- Documented Playwright's auto-server startup (prevents "servers not running" confusion)

**Key commits:**
- `c0eef3d` Merge pull request #1 - Enhance agent process commands (2025-12-09)
- `9919e6c` Enhance agent process commands with specialized agents and git automation (2025-12-08)

### Planning & Validation Enhancements (Oct - Nov 2025)

**Highlights:**
- CLAUDE.md integration into planning workflow (captures project patterns)
- Auto-generated scope naming from requirements filenames
- Scope boundary enforcement (stop-and-ask for out-of-scope changes)
- Contract validation playbook for shared-API changes
- Automated test capture with tee-based logging

**Key commits:**
- `a92f299` Enhance planning workflow with CLAUDE.md integration (2025-11-19)
- `4d3a1cf` Enhance agent process workflow with validation and scope controls (2025-10-25)
- `6686201` Add validation script update instructions (2025-10-16)

### Project Inception (Oct 2025)

Initial release of the AI Agent Process Template, establishing the core workflow:
- Iteration budgets with maximum 3 sub-iterations before escalation
- Frozen acceptance criteria (no scope creep mid-iteration)
- 4-choice decision framework: APPROVE / ITERATE / BLOCK / PIVOT
- Scoped validation (only test files you changed)
- Orchestration prompts for planning and review phases

**Key commits:**
- `b71bfe2` Initial commit: AI Agent Process Template (2025-10-16)

---

*For complete historical details, see the [commit history](https://github.com/sammywachtel/ai_agent_process/commits/main).*
