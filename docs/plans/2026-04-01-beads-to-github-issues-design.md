# Design: Replace BEADS/Dolt with GitHub Issues + File-Based Tracking

**Date:** 2026-04-01
**Revision:** 2 (incorporates Round 1 review feedback + 3 research spikes)
**Status:** Draft — Round 2 Design Review
**Scope:** Full system migration: beads removal, GitHub Issues integration, knowledge relocation

---

## Table of Contents

1. [Motivation & User Benefit](#1-motivation--user-benefit)
2. [User Stories](#2-user-stories)
3. [Success Criteria](#3-success-criteria)
4. [Current State: How BEADS Works Today](#4-current-state-how-beads-works-today)
5. [Current State: Issue Types and Dependencies](#5-current-state-issue-types-and-dependencies)
6. [Target State: GitHub Issues Integration](#6-target-state-github-issues-integration)
7. [Mapping: BEADS Concepts → GitHub Issues](#7-mapping-beads-concepts--github-issues)
8. [Scope Tracker: Replacing current_iteration.conf](#8-scope-tracker-replacing-current_iterationconf)
9. [Knowledge System Migration](#9-knowledge-system-migration)
10. [Ad-Hoc Knowledge Workflow](#10-ad-hoc-knowledge-workflow)
11. [Installation Flow Changes](#11-installation-flow-changes)
12. [GitHub Issues Health Check & Halt Protocol](#12-github-issues-health-check--halt-protocol)
13. [Orchestration Changes (Claude + Codex)](#13-orchestration-changes-claude--codex)
14. [Quality Config Cleanup](#14-quality-config-cleanup)
15. [File-Based Fallback (No GitHub)](#15-file-based-fallback-no-github)
16. [Polyrepo Support](#16-polyrepo-support)
17. [Standalone Migration Script](#17-standalone-migration-script)
18. [Files to Remove](#18-files-to-remove)
19. [Files to Modify](#19-files-to-modify)
20. [Files to Create](#20-files-to-create)
21. [`github-issues-lifecycle.sh` — Detailed Design](#21-github-issues-lifecyclesh--detailed-design)
22. [Test Specifications](#22-test-specifications)
23. [Migration Checklist](#23-migration-checklist)
24. [Risk Assessment](#24-risk-assessment)
25. [Decisions (Resolved)](#25-decisions-resolved)

---

## Important: Source vs. Destination

This project (`ai_agent_process`) is the **framework source** — the repo from which AP gets installed into destination projects. Everything in this design describes changes to the source framework. When we say "install.sh creates labels," we mean the install.sh that ships with this framework and runs in the user's destination project.

---

## 1. Motivation & User Benefit

### The Problem

BEADS/Dolt adds significant complexity to the AI Agent Process framework for a resilience benefit most users never need:

- **Installation friction:** Dolt is ~100MB, requires manual install (Homebrew/curl), and the install.sh Dolt endpoint detection spans 120+ lines with 4 interactive options (local binary, Docker, remote GCE, custom host:port)
- **Infrastructure burden:** Remote Dolt requires a GCE VM (~$7/month), IAP tunnel configuration, credential files in `~/.config/beads/credentials`, and ongoing maintenance
- **Complexity for contributors:** `beads-lifecycle.sh` is 405 lines handling auto-install, Docker host rewriting, credential loading, and breadcrumb tracking — all for optional state persistence
- **Low adoption signal:** BEADS is designed as a resilience enhancement for multi-session scopes. The file-based fallback handles the common case (single-session scopes) identically

### The Solution

Replace BEADS with **optional GitHub Issues integration** — a tool developers already have, requiring zero additional infrastructure:

- `gh` CLI is already installed in most dev environments (confirmed available in both Claude Code and Codex)
- Authentication is already handled (`gh auth login` or `GH_TOKEN`)
- GitHub Issues provides structured tracking (sub-issues, dependencies, labels) that BEADS approximated with a database
- File-based tracking remains the mandatory default — always works, no dependencies

### Who Benefits

- **Solo developers:** Simpler install (no Dolt), optional GH tracking if they want visibility
- **Teams:** GitHub Issues is shared by default — no Dolt server to deploy and maintain
- **CI/Codex agents:** `gh` works via `GH_TOKEN` — no database credentials to manage
- **Framework contributors:** 405-line lifecycle script drops to ~250 lines with simpler logic

---

## 2. User Stories

**US-1:** As a developer installing AP on a new project, I want setup to complete without needing Docker or a database, so that I can start using agent-driven development in under 2 minutes.

**US-2:** As a developer who uses GitHub daily, I want my AP scope tracking visible in GitHub Issues, so that I can see progress without switching tools.

**US-3:** As a developer who does NOT want GitHub Issues tracking, I want file-based tracking to work seamlessly without any GitHub prompts or errors during execution.

**US-4:** As an agent (Claude/Codex) executing a scope, I want a clear halt signal when GitHub Issues is enabled but broken, so that I don't silently lose tracking state.

**US-5:** As a developer with an existing BEADS/Dolt setup, I want a migration script that discovers what I have and migrates it safely, so that I don't lose knowledge or tracking state.

**US-6:** As a developer working in a polyrepo, I want to configure which repo holds my AP issues, so that issues land in the right place regardless of which subrepo I'm working in.

**US-7:** As a developer mid-conversation with an agent, I want to say "add a note to the task" and have it go to the GitHub Issue, so that context is preserved for the next session.

---

## 3. Success Criteria

### Migration Complete (verifiable)

```bash
# Zero BEADS/Dolt references in shipped framework files
grep -ri 'beads\|\.beads\|bd \|bd$\|dolt' orchestration/ process/ scripts/ claude/ templates/ \
  | grep -v 'migration-script' | grep -v 'CHANGELOG' | wc -l
# Expected: 0

# quality-config.json has no beads section
python3 -c "import json; c=json.load(open('quality-config.json')); assert 'beads' not in c"

# Knowledge lives in single canonical location
test -d .agent_process/knowledge && echo "PASS"
```

### Functional (testable)

- `install.sh` completes successfully with GitHub Issues enabled (fresh project)
- `install.sh` completes successfully with GitHub Issues disabled (fresh project)
- Full `ap_exec` cycle completes with GH enabled — scope issue created, work units as sub-issues, issue closed on APPROVE
- Full `ap_exec` cycle completes with GH disabled — file-based tracking works identically to pre-migration behavior
- `github-issues-lifecycle.sh health-check` returns clear, actionable errors for each failure mode
- Health check + halt stops agent work; agent resumes after fix
- Scope tracker file survives git merge from two developers working on different scopes
- `test/unit/test-github-issues-lifecycle.bats` passes with 100% action coverage
- Standalone migration script discovers and migrates `.beads/knowledge/` and `bd remember` data

### Non-Functional

- Health check completes in < 5 seconds (parallel network calls)
- Per-scope GH API call budget: < 25 calls for a 5-work-unit scope
- Process/instruction files remain small — no large GH context loaded into agent prompts
- Minimum `gh` CLI version: >= 2.20.0

---

## 4. Current State: How BEADS Works Today

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Orchestration Layer (coordinators + steps)              │
│                                                          │
│  execute-preflight.md ──► beads-lifecycle.sh start       │
│  execute-main.md ────────► beads-lifecycle.sh task-*     │
│  review-iteration.md ────► beads-lifecycle.sh close      │
│  007b-session-recovery.md► beads-lifecycle.sh get-iter   │
│  07-10-post-decision.md ► deposits to .beads/knowledge/  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────┐
│  beads-lifecycle.sh (405 lines)  │
│  - auto-installs bd CLI          │
│  - Docker host rewriting         │
│  - credential loading            │
│  - breadcrumb tracking           │
│  - 8 actions: start, close, etc  │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────┐    ┌──────────────────────┐
│  bd CLI                      │───►│  Dolt SQL Server     │
│  (npm/brew/curl installed)   │    │  (local/docker/GCE)  │
└──────────────────────────────┘    └──────────────────────┘
```

### What BEADS Tracks

| Concept | BEADS Implementation | File Fallback |
|---------|---------------------|---------------|
| Scope lifecycle | `bd epic create/close {scope}` | `current_iteration.conf` |
| Iteration pointer | `bd set-state {epic} iteration={N}` | `current_iteration.conf` |
| Work unit status | `bd task create/update WU-NNN` | `current_work_unit.conf` |
| Session recovery | `bd state {epic} iteration` | `current_iteration.conf` |
| Breadcrumb audit | `.beads-state` file | `.beads-state` file |

### Metaswarm Relationship

AP does NOT invoke any metaswarm skills directly. Every metaswarm capability (prime, brainstorm, pr-shepherd, self-reflect) has a built-in AP alternative. Metaswarm's own `/prime` and `/self-reflect` skills read/write `.beads/knowledge/`, but AP never calls those skills — AP uses grep-based knowledge queries and direct file writes. Removing BEADS breaks nothing in AP's metaswarm integration.

If metaswarm is installed separately and expects `.beads/knowledge/`, users can create a symlink or metaswarm can be configured to use `.agent_process/knowledge/`. AP wraps any metaswarm functionality it needs through `/ap_*` commands (e.g., `/ap_brainstorm` has its own built-in 3-agent brainstorm that works without metaswarm).

---

## 5. Current State: Issue Types and Dependencies

### Issue Type Taxonomy

**Level 1 — Backlog items** (in `.agent_process/roadmap/backlog.md`):
- **Feature** — New capability
- **Enhancement** — Improve existing functionality
- **Bug Fix** — Fix defect
- **Tech Debt** — Refactoring/quality improvements
- **Investigation** — Research (may lead to Feature)

**Level 2 — Requirement frontmatter** (in `requirements_docs/*.md`):
```yaml
---
id: lexical_epic_06_save
type: requirement
category: lexical_editor
status: not_started|scoped|in_progress|blocked|completed|approved
priority: CRITICAL|HIGH|MEDIUM|LOW
complexity: simple|moderate|complex
---
```

**Level 3 — Work units** (within execution, ephemeral):
- `WU-001`, `WU-002`, etc. — decomposed from a single requirement scope
- Dependencies tracked within scope only: `WU-001 → WU-003`

### Dependency Model (Current)

No cross-requirement dependencies. Each scope is planned and executed independently. Within a scope, work units have simple ordering. A `depends_on` field in requirement frontmatter is planned but not yet implemented.

---

## 6. Target State: GitHub Issues Integration

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Orchestration Layer (coordinators + steps)              │
│                                                          │
│  execute-preflight.md ──► github-issues-lifecycle.sh     │
│  execute-main.md ────────► github-issues-lifecycle.sh    │
│  review-iteration.md ────► github-issues-lifecycle.sh    │
│  007b-session-recovery.md► github-issues-lifecycle.sh    │
│  07-10-post-decision.md ► .agent_process/knowledge/      │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────┐
│  github-issues-lifecycle.sh (~250 ln)│
│  - health check (gh auth status)     │
│  - scope issue CRUD via gh CLI       │
│  - sub-issues for work units (API)   │
│  - dependencies via gh api           │
│  - always writes scope tracker file  │
│  - HALT on gh failure (when enabled) │
│  - always uses --repo for safety     │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────┐
│  GitHub Issues API           │
│  (via gh CLI + gh api)       │
└──────────────────────────────┘
```

### GitHub Issues Data Model

**One issue per scope.** Issue body is a lightweight dashboard with links — not a data store.

```markdown
## Scope: {scope_id}

**Requirement:** {requirement_id}
**Priority:** {priority}
**Category:** {category}
**Current Iteration:** iteration_02

### Acceptance Criteria
[Link to .agent_process/work/{scope}/iteration_02/iteration_plan.md]

### Work
Sub-issues track individual work units.
See .agent_process/work/{scope}/ for full artifacts.

### Notes
(Agent and user can add notes/reminders here as comments)
```

**Work units are GitHub sub-issues** (not task list checkboxes). Sub-issues are GA on all GitHub plans, support up to 50 per parent and 8 levels of nesting, and are created via REST API:

```bash
# Create work unit as sub-issue
CHILD=$(gh issue create --repo "$TARGET_REPO" --title "WU-001: Schema migration" --body "..." | grep -o '[0-9]*$')
gh api repos/OWNER/REPO/issues/PARENT_NUMBER/sub_issues -f sub_issue_id="$CHILD"
```

This eliminates the body-mutation concurrency hazard identified in Round 1 review. Sub-issues are independent API objects — no read-modify-write race.

### Dependencies (Same-Repo Only)

GitHub dependencies are GA (August 2025). Structured, queryable via REST API:

```bash
# Mark issue #10 as blocked by issue #5
gh api repos/OWNER/REPO/issues/10/dependencies/blocked_by -f blocked_by_issue_id=5

# Query what blocks issue #10
gh api repos/OWNER/REPO/issues/10/dependencies/blocked_by
```

**Cross-repo dependencies are NOT supported** by GitHub's structured dependency API. Cross-repo blocking is text-only (`org/other-repo#42` autolinks but creates no structured relationship).

### Label Taxonomy

Created automatically during install (idempotent), re-verified at `start` time:

```
# Type labels
ap:scope          — Requirement scope (parent issue)
ap:iteration      — Iteration tracking label

# Status labels
status:planning
status:executing
status:reviewing
status:approved
status:blocked
status:iterate

# Priority labels (from requirement frontmatter)
priority:critical
priority:high
priority:medium
priority:low

# Category labels (dynamic, one per requirement category)
category:{name}

# Backlog type labels
type:feature
type:enhancement
type:bugfix
type:tech-debt
type:investigation
```

---

## 7. Mapping: BEADS Concepts → GitHub Issues

| BEADS Concept | BEADS Command | GitHub Replacement | Implementation |
|--------------|---------------|-------------------|----------------|
| Create epic | `bd create` | Create scope issue | `gh issue create --repo $REPO --label ap:scope` |
| Find epic | `bd query "type=epic..."` | Find scope issue | `gh issue list --repo $REPO --label ap:scope --search "{scope}"` |
| Create task | `bd create` (child) | Create sub-issue | `gh issue create` + `gh api .../sub_issues` |
| Update task | `bd label` | Close/label sub-issue | `gh issue close` / `gh issue edit --add-label` |
| Set iteration | `bd set-state iteration=N` | Update scope tracker + comment | Write to tracker, `gh issue comment` |
| Get iteration | `bd state iteration` | Read scope tracker | Parse scope-tracker.jsonl |
| Close epic | `bd close` | Close issue + label | `gh issue close` + `--add-label status:approved` |
| Dependencies | Not implemented | `gh api .../dependencies/blocked_by` | Same-repo only; cross-repo uses text |
| Breadcrumbs | `.beads-state` | `scope-events.log` | Lightweight local audit (always written) |
| Ad-hoc notes | Not supported | Issue comments | `gh issue comment` — agent evaluates for knowledge |

### Key Differences from BEADS

1. **No local database.** All GH state is remote. Simpler, but requires network.
2. **Sub-issues replace tasks.** First-class GH objects, no body mutation.
3. **Labels replace status fields.** Status transitions are label swaps.
4. **Scope tracker file is always written.** Local state is canonical; GH is the shared view.
5. **`--repo` always explicit.** Never infer repo from CWD (polyrepo safety).

---

## 8. Scope Tracker: Replacing current_iteration.conf

`current_iteration.conf` is a single-value file that gets overwritten on every scope change. It doesn't survive git merges when two developers work on different scopes, and it loses history.

### New: `.agent_process/work/scope-tracker.jsonl`

One JSONL line per scope. Lines are **updated in place** when status or iteration changes. Each line contains the full scope state including all iterations:

```jsonl
{"scope":"auth_middleware_01","status":"executing","gh_issue":42,"current_iteration":"iteration_02","iterations":{"iteration_01":{"status":"approved","ts":"2026-04-01T10:00:00Z"},"iteration_02":{"status":"executing","ts":"2026-04-01T14:00:00Z"}},"ts":"2026-04-01T14:00:00Z"}
{"scope":"db_migration_03","status":"approved","gh_issue":45,"current_iteration":"iteration_01","iterations":{"iteration_01":{"status":"approved","ts":"2026-04-01T11:30:00Z"}},"ts":"2026-04-01T11:30:00Z"}
```

### Design Properties

- **One line per scope** — easy to grep, easy to parse
- **Merge-friendly** — different scopes = different lines, git merges cleanly
- **Historical** — iteration status nested within the line
- **Lightweight** — JSONL, efficient after hundreds of scopes
- **Pointers** — links to `.agent_process/work/{scope}/` for full artifacts
- **Machine-readable** — `jq` or simple JSON parsing
- **GH_ISSUE cached** — avoids re-querying GitHub

### Reading and Writing

```bash
# Read current iteration for a scope
jq -r 'select(.scope=="auth_middleware_01") | .current_iteration' .agent_process/work/scope-tracker.jsonl

# The lifecycle script owns all writes — coordinators only read
```

### Scope Events Log

A simple append-only audit log replacing `.beads-state`:

```
# .agent_process/work/{scope}/scope-events.log
2026-04-01T10:00:00Z SCOPE_START scope=auth_middleware_01 iteration=iteration_01
2026-04-01T10:05:00Z WU_CREATE scope=auth_middleware_01 wu=WU-001 desc="Schema migration"
2026-04-01T10:30:00Z WU_UPDATE scope=auth_middleware_01 wu=WU-001 status=complete
2026-04-01T11:00:00Z ITERATION_CLOSE scope=auth_middleware_01 iteration=iteration_01 decision=ITERATE
2026-04-01T11:05:00Z ITERATION_START scope=auth_middleware_01 iteration=iteration_02
```

Written by `github-issues-lifecycle.sh` on every action. The review coordinator's verification step reads this instead of `.beads-state`.

### Replaces

| Old File | New Location |
|----------|-------------|
| `current_iteration.conf` | `scope-tracker.jsonl` |
| `current_work_unit.conf` | Can add `current_wu` field to tracker or keep within `.run/` |
| `.beads-state` | `scope-events.log` per scope |

---

## 9. Knowledge System Migration

### Current State

```
.beads/knowledge/        ← PRIMARY (when BEADS enabled) — does not exist in this repo
.agent_process/knowledge/ ← FALLBACK (when BEADS disabled) — contains only README.md
```

Legacy projects may also have knowledge in `bd remember` (Dolt database, not files).

### Target State

```
.agent_process/knowledge/ ← SINGLE CANONICAL LOCATION
  patterns.jsonl
  gotchas.jsonl
  decisions.jsonl
  anti-patterns.jsonl
  codebase-facts.jsonl
  api-behaviors.jsonl
  README.md
```

### Unified Knowledge Schema

```json
{
  "id": "unique_snake_case_id",
  "type": "pattern|gotcha|decision|anti_pattern|api_behavior|code_quirk|performance|security",
  "fact": "Clear description of the knowledge",
  "recommendation": "What to do about it",
  "confidence": "high|medium|low",
  "provenance": [
    {
      "source": "agent|human|documentation|test|production",
      "reference": "scope_name/iteration_XX",
      "date": "YYYY-MM-DD"
    }
  ],
  "tags": ["auth", "middleware"],
  "affectedFiles": ["src/middleware/auth.ts"],
  "createdAt": "YYYY-MM-DDTHH:MM:SSZ",
  "updatedAt": "YYYY-MM-DDTHH:MM:SSZ"
}
```

One schema everywhere. `provenance` and `affectedFiles` recommended but not required.

### Knowledge Discovery

`process/knowledge-base.md` must be easily discoverable by any fresh agent. Referenced in:
- `orchestration/context/base-context.md` (loaded into every orchestration session)
- Planning coordinator (Step 2.5)
- Review coordinator (Steps 9.5/9.6)

### Migration of Legacy Knowledge

Handled by standalone script. See Section 17.

---

## 10. Ad-Hoc Knowledge Workflow

### User-Initiated Notes on Issues

When a user tells the agent "add a note to the task" or "don't forget to...":

1. Agent adds note as a **GitHub Issue comment** (if GH enabled)
2. Agent **evaluates for knowledge value** using criteria in `process/knowledge-base.md`
3. If knowledge-worthy: "This might be useful for future scopes. Add to knowledge?"
4. If user consents: write to `.agent_process/knowledge/` with `"source": "human"` provenance

### ITERATE Decision Knowledge Deposit

When the iteration reviewer spots a **generalizable lesson or pattern across iterations** and the decision is ITERATE, the reviewer can deposit 0-2 process observations.

**Why safe:** Knowledge is about the *process* (what went wrong), not the *code* (which isn't verified yet). Process observations are valid regardless of code correctness.

### Updated Deposit Table

| Decision | What to deposit | Trigger |
|----------|----------------|---------|
| **APPROVE** | Code patterns, gotchas, decisions, anti-patterns (0-3) | Automatic |
| **BLOCK/PIVOT** | Process observations (0-2) | Automatic |
| **ITERATE** | Process observations (0-2) | Conditional — reviewer spots generalizable lesson |
| **Ad-hoc** | User-initiated note → knowledge | User consent required |

### Updates to `process/knowledge-base.md`

Add "Ad-Hoc Knowledge Evaluation Criteria":
- Is this specific to this scope or generalizable?
- Would a future agent benefit from knowing this?
- Is there a concrete recommendation (not just "be careful")?
- Does this duplicate existing knowledge?

---

## 11. Installation Flow Changes

### New Flow

```
install.sh
  ├── Create .agent_process/knowledge/ (always)
  ├── Prompt: "Track work with GitHub Issues? [y/N]"
  │
  ├── If yes:
  │   ├── Verify gh CLI installed (>= 2.20.0)
  │   ├── Verify gh auth status
  │   ├── Verify repo has GitHub remote
  │   ├── Detect repo (auto from git remote; confirm if polyrepo)
  │   ├── Create AP labels (idempotent)
  │   ├── Write: { "github_issues": { "enabled": true, "repo": "owner/name" } }
  │   └── Print: "GitHub Issues enabled for owner/name."
  │
  └── If no:
      ├── Write: { "github_issues": { "enabled": false } }
      └── Print: "File-based tracking only."
```

### Removed From Installation

- All Dolt endpoint detection, Docker, GCE, credentials
- `~/.config/beads/credentials` creation
- `.beads/` directory creation
- Knowledge migration (standalone script now)

---

## 12. GitHub Issues Health Check & Halt Protocol

### Health Check (parallel network calls, < 5s target)

```bash
check_gh_health() {
  local errors=()

  if ! command -v gh &>/dev/null; then
    errors+=("gh CLI not found. Install: https://cli.github.com/"); fi

  # Version check
  local ver=$(gh --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')
  if ! version_gte "$ver" "2.20.0"; then
    errors+=("gh $ver below minimum 2.20.0. Run: gh upgrade"); fi

  # Parallel: auth + repo access
  if ! gh auth status &>/dev/null 2>&1; then
    errors+=("Not authenticated. Run: gh auth login"); fi
  if ! gh repo view "$REPO" --json name &>/dev/null 2>&1; then
    errors+=("Cannot access '$REPO'. Check permissions."); fi

  [ ${#errors[@]} -gt 0 ] && { print_halt "${errors[@]}"; return 1; }
  return 0
}
```

### Retry Strategy

```bash
run_gh() {
  local output rc
  output=$("$@" 2>&1); rc=$?
  if [ $rc -ne 0 ]; then
    # One retry for transient errors
    if echo "$output" | grep -qiE '502|503|504|timeout|rate limit|API rate'; then
      sleep 3; output=$("$@" 2>&1); rc=$?; fi
    [ $rc -ne 0 ] && { echo "HALT: $output" >&2; return 1; }
  fi
  echo "$output"
}
```

---

## 13. Orchestration Changes (Claude + Codex)

### Files to Update

| File | Change |
|------|--------|
| `execute-preflight.md` | Add Step 0.4 health check; Step 0.5 → github-issues-lifecycle.sh |
| `execute-main.md` | Swap lifecycle script |
| `review-iteration.md` | Swap lifecycle; verify via scope-events.log |
| `plan-scope.md` | Update warning text |
| `007b-session-recovery.md` | scope-tracker.jsonl + lifecycle script |
| `07-10-post-decision.md` | Single KB dir; ITERATE deposit; lifecycle calls |
| `025-knowledge-query.md` | Single KB directory |
| `base-context.md` | Remove all BEADS/bd references |
| `02-gather-context.md` | Remove `.beads/knowledge` reference |
| `templates/iteration-plan.md` | Remove `.beads/knowledge` reference |

### Small Context Principle

GH integration adds minimal context to agent prompts:
- `github_issues.repo` config field (one string)
- Issue numbers in scope-tracker.jsonl (one integer per scope)
- No issue bodies loaded into agent context — agents reference by number, use `gh` commands only when needed

---

## 14. Quality Config Cleanup

### New Section

```json
{
  "github_issues": {
    "enabled": false,
    "_user_configured": true,
    "repo": "owner/repo-name"
  }
}
```

No server config, no auto_install, no credentials. The `repo` field ensures `--repo` is always explicit.

---

## 15. File-Based Fallback (No GitHub)

Default and primary mode. `github-issues-lifecycle.sh` exits silently when disabled but **still writes local state** (scope-tracker.jsonl + scope-events.log).

| Feature | Mechanism |
|---------|-----------|
| Scope tracking | `scope-tracker.jsonl` (one line per scope, mutable) |
| Iteration tracking | Nested in tracker line |
| Audit trail | `scope-events.log` per scope |
| Work history | `.agent_process/work/{scope}/iteration_*/` |
| Knowledge | `.agent_process/knowledge/*.jsonl` |
| Roadmap | `.agent_process/roadmap/master_roadmap.md` |

---

## 16. Polyrepo Support

### Solution

1. `github_issues.repo` in quality-config.json — always explicit
2. `--repo` flag on every `gh` command — never infer from CWD
3. Install-time detection — auto-detect from git remote, confirm if polyrepo

### Cross-Repo Capabilities

- References (`org/root-repo#42`) autolink in commits, PRs, comments
- `Closes org/root-repo#42` in a sub-repo PR closes the root issue on merge
- Sub-issues CAN be cross-repo
- Dependencies CANNOT be cross-repo (GitHub limitation)

---

## 17. Standalone Migration Script

`scripts/migrate-from-beads.sh` — NOT run during install. Interactive, per-step permission.

| Source | Discovery | Migration |
|--------|-----------|-----------|
| `.beads/knowledge/*.jsonl` | Check directory, count entries | Copy to `.agent_process/knowledge/`, skip duplicates |
| `bd remember` data | Query `bd` if installed | Export to `.agent_process/knowledge/` as JSONL |
| `.beads-state` files | Glob `**/.beads-state` | Convert to `scope-events.log` format |
| `current_iteration.conf` | Glob | Convert to `scope-tracker.jsonl` entries |
| `quality-config.json` beads section | Check for key | Remove section, prompt for github_issues |

After migration, prints cleanup reminders (delete `.beads/`, `~/.config/beads/credentials`, uninstall dolt, tear down servers).

---

## 18. Files to Remove

| File | Reason |
|------|--------|
| `scripts/beads-lifecycle.sh` | Replaced by `github-issues-lifecycle.sh` |
| `deploy/beads-server/` (entire directory) | No more Dolt server |
| `process/beads-integration.md` | Replaced by `github-issues-integration.md` |
| `test/contract/validate-beads-state.sh` | Replaced by scope-events validation |
| `test/unit/test-beads-lifecycle.bats` | Tests for removed script |
| `scripts/migrate-knowledge.py` | Absorbed by migrate-from-beads.sh |
| `.agent_process/requirements_docs/decomposition/decomp_scope_07_*` | Requirement for removed system |

---

## 19. Files to Modify

| File | What Changes |
|------|-------------|
| `quality-config.json` | Remove `beads`, add `github_issues` |
| `process/quality-configuration.md` | Swap config docs |
| `process/knowledge-base.md` | Single dir, ad-hoc knowledge, ITERATE deposit, discovery |
| All 10 orchestration files (Section 13) | Lifecycle script swap, KB path |
| `.gitignore` | Remove beads-server-info entry |
| `.claude/settings.local.json` | Swap `bd`/`dolt` → `gh` permissions |
| `claude/commands/ap_exec.md` | Replace beads refs |
| `claude/commands/ap_brainstorm.md` | Ensure built-in fallback is primary |
| `install.sh` | Remove BEADS, add GitHub Issues |
| `README.md` | Remove BEADS/Dolt references |

---

## 20. Files to Create

| File | Purpose |
|------|---------|
| `scripts/github-issues-lifecycle.sh` | GitHub Issues lifecycle script |
| `scripts/migrate-from-beads.sh` | Standalone migration for BEADS users |
| `process/github-issues-integration.md` | How-to guide |
| `test/unit/test-github-issues-lifecycle.bats` | Unit tests |
| `test/contract/validate-scope-events.sh` | Scope events validator |

---

## 21. `github-issues-lifecycle.sh` — Detailed Design

### Actions

| Action | GH Commands | Always Writes Locally |
|--------|-------------|----------------------|
| `health-check` | `gh auth status`, `gh repo view` | Nothing |
| `start {scope}` | `gh issue create/list --repo` | scope-tracker + events |
| `set-iteration {scope} {N}` | `gh issue comment --repo` | scope-tracker + events |
| `get-iteration {scope}` | None (reads tracker) | Nothing |
| `task-create {scope} {id} {desc}` | `gh issue create` + `gh api .../sub_issues` | events |
| `task-update {scope} {id} {status}` | `gh issue edit/close --repo` | events |
| `close {scope} {decision}` | `gh issue close` + `--add-label` | scope-tracker + events |
| `verify {scope}` | `gh issue view --json --repo` | Nothing |
| `comment {scope} {message}` | `gh issue comment --repo` | events |

### Safety

- `validate_scope_name()` — `[a-zA-Z0-9_-]` only, called first in every action
- All variables double-quoted in `gh` commands
- Never `eval` or `source` issue body content
- `--repo` on every `gh` command

### When Disabled

Writes scope-tracker.jsonl and scope-events.log, then exits 0. No `gh` commands run.

---

## 22. Test Specifications

### Mock Strategy

**PATH override** (same as test-beads-lifecycle.bats): mock `gh` script in `$TEST_DIR/bin/`, records calls, returns configurable output.

### Test Cases Per Action

**health-check:** gh missing → error; not authenticated → error; repo inaccessible → error; version too old → error; all pass → exit 0

**start:** GH disabled → local state only; no existing issue → create + tracker; existing issue → reuse; gh fails → HALT + local state written; bad scope name → rejected

**set-iteration / get-iteration:** Round-trip consistency; GH disabled → tracker only; scope not found → error

**task-create / task-update:** Sub-issue created via `gh api`; GH disabled → events only; validates WU ID

**close:** Closes issue, labels, updates tracker; GH disabled → tracker only

**Transient retry:** Mock 502 first call, 200 second → success; Mock 401 → no retry, immediate HALT

---

## 23. Migration Checklist

### Phase 1: Knowledge System
Update KB to single directory, add ad-hoc knowledge section, ITERATE deposit.

### Phase 2: Scope Tracker + Events Log
Design and test the new file formats.

### Phase 3: GitHub Issues Lifecycle (TDD)
Write tests first, implement against them.

### Phase 4: Update Orchestration (atomic with Phase 3)
Update all 10+ orchestration files. Merge with Phase 3.

### Phase 5: Update Installation
Rewrite install.sh. Remove BEADS, add GH prompt.

### Phase 6: Claude Commands & Settings
Swap permissions and references.

### Phase 7: Remove BEADS
Delete all files from Section 18. Clean references.

### Phase 8: Migration Script + Docs
Write migrate-from-beads.sh. Write how-to guide. Update README.

### Phase 9: Testing
Full test matrix: GH enabled/disabled, fresh/upgrade, halt/resume, migration, merge-friendliness.

---

## 24. Risk Assessment

| Level | Risk | Mitigation |
|-------|------|-----------|
| High | Existing `.beads/knowledge/` data | Standalone migration script, per-step permission |
| High | `gh` rate limiting | Cache in tracker; ~25 calls/scope; 5000/hr headroom |
| Medium | Label conflicts | `ap:` prefix on all labels |
| Medium | Polyrepo wrong repo | `--repo` always explicit from config |
| Medium | Concurrent tracker writes | Per-scope lines don't conflict; one agent per scope |
| Medium | BEADS users perceive churn | Clear migration, motivation docs, zero data loss |
| Low | 50 sub-issue limit | Rare; document; comments for overflow |
| Low | `bd remember` data loss | Migration script explicitly extracts |

---

## 25. Decisions (Resolved)

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 1 | Sub-issues vs task lists? | **Sub-issues** | GA all plans; eliminates body-mutation concurrency; proper parent-child |
| 2 | Per-iteration or per-scope issues? | **Per-scope** | Less noise; iteration tracked in scope-tracker.jsonl + comments |
| 3 | Health check frequency? | **Preflight only** | Per-command errors caught by `run_gh` wrapper |
| 4 | Metaswarm compatibility? | **AP wraps in `/ap_*` commands** | Can't modify metaswarm; AP is self-sufficient |
| 5 | Codex compatibility? | **Works** | gh installed + GH_TOKEN authenticated in Codex |
| 6 | Session recovery deadlock? | **Not possible** | No network = no LLM = no agent |
| 7 | Issue body length? | **Keep light — links, not data** | Artifacts in `.agent_process/work/` |
| 8 | File attachments? | **Not needed** | No API support; issue links to local files |
| 9 | Script naming? | **`github-issues-lifecycle.sh`** | Names the feature, not the CLI tool |
| 10 | File-state ownership? | **Lifecycle script owns all writes** | Centralized, consistent, coordinators only read |
