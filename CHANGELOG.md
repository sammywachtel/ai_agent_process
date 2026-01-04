# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
