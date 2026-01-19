# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
