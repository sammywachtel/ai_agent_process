# Design: Replace BEADS/Dolt with GitHub Issues + File-Based Tracking

**Date:** 2026-04-01
**Status:** Draft — Pending Design Review
**Scope:** Full system migration: beads removal, GitHub Issues integration, knowledge relocation

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State: How BEADS Works Today](#2-current-state-how-beads-works-today)
3. [Current State: Issue Types and Dependencies](#3-current-state-issue-types-and-dependencies)
4. [Target State: GitHub Issues Integration](#4-target-state-github-issues-integration)
5. [Mapping: BEADS Concepts → GitHub Issues](#5-mapping-beads-concepts--github-issues)
6. [Knowledge System Migration](#6-knowledge-system-migration)
7. [Installation Flow Changes](#7-installation-flow-changes)
8. [GitHub Issues Health Check & Halt Protocol](#8-github-issues-health-check--halt-protocol)
9. [Orchestration Changes (Claude + Codex)](#9-orchestration-changes-claude--codex)
10. [Quality Config Cleanup](#10-quality-config-cleanup)
11. [File-Based Fallback (No GitHub)](#11-file-based-fallback-no-github)
12. [Files to Remove](#12-files-to-remove)
13. [Files to Modify](#13-files-to-modify)
14. [Files to Create](#14-files-to-create)
15. [Migration Checklist](#15-migration-checklist)
16. [Risk Assessment](#16-risk-assessment)
17. [Open Questions](#17-open-questions)

---

## 1. Executive Summary

Replace the BEADS/Dolt durable state tracking system with **optional GitHub Issues integration** and **mandatory file-based tracking**. The knowledge base moves from `.beads/knowledge/` to `.agent_process/knowledge/` as the single canonical location.

**Key principles:**
- GitHub Issues is **opt-in**, not default. File-based tracking always works.
- When GitHub Issues is enabled, it's treated as a **hard dependency** — failures halt work with clear feedback.
- When GitHub Issues is disabled, the existing file-based system is the sole tracking mechanism. No degradation.
- Zero Dolt/BEADS remnants after migration. Clean removal.
- Works identically in Claude Code and Codex (OpenAI).

---

## 2. Current State: How BEADS Works Today

### Architecture

BEADS is a git-native issue tracker backed by Dolt (a MySQL-compatible versioned database). The `bd` CLI communicates with a local or remote Dolt server.

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

### Deployment Options (All Being Removed)

1. **Local Dolt binary** — `dolt` installed via Homebrew, serves on port 3307
2. **Docker container** — `beads-dolt-server` container via `dolt-docker.sh`
3. **Remote GCE VM** — `deploy/beads-server/setup.sh`, ~$7/month, IAP tunnel on port 3308

### Files Involved

| File | Role | Lines |
|------|------|-------|
| `scripts/beads-lifecycle.sh` | Core BEADS orchestrator | 405 |
| `scripts/migrate-knowledge.py` | Legacy → metaswarm knowledge migration | 160 |
| `deploy/beads-server/setup.sh` | GCE VM deployment | 298 |
| `deploy/beads-server/teardown.sh` | GCE VM cleanup | 76 |
| `deploy/beads-server/dolt-docker.sh` | Docker Dolt server | 80+ |
| `deploy/beads-server/README.md` | Deployment docs | ~100 |
| `process/beads-integration.md` | How-to guide | 350 |
| `test/contract/validate-beads-state.sh` | Breadcrumb validator | 95 |
| `test/unit/test-beads-lifecycle.bats` | Lifecycle unit tests | 100+ |
| `.agent_process/requirements_docs/decomposition/decomp_scope_07_*.md` | BEADS iteration state req | ~60 |

---

## 3. Current State: Issue Types and Dependencies

### Issue Type Taxonomy

The project uses two levels of work item types:

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
- No cross-scope dependency tracking implemented yet

### How BEADS Maps These

| AP Concept | BEADS Mapping |
|-----------|---------------|
| Requirement scope | BEADS Epic |
| Iteration | Epic state (`iteration=01`) |
| Work unit | BEADS Task (child of epic) |
| WU dependency | Label on task (no formal DAG) |
| Backlog item | Not tracked in BEADS |

### Dependency Model

**Current reality:** No cross-requirement dependencies. Each scope is planned and executed independently. Within a scope, work units have simple ordering (WU-002 depends on WU-001).

**Planned (backlog):** A `depends_on` field in requirement frontmatter, with a future `ap_project deps` command for visualization. Not yet implemented.

---

## 4. Target State: GitHub Issues Integration

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Orchestration Layer (coordinators + steps)              │
│                                                          │
│  execute-preflight.md ──► gh-lifecycle.sh start          │
│  execute-main.md ────────► gh-lifecycle.sh task-*        │
│  review-iteration.md ────► gh-lifecycle.sh close         │
│  007b-session-recovery.md► gh-lifecycle.sh get-iter      │
│  07-10-post-decision.md ► deposits to .agent_process/kb  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────┐
│  gh-lifecycle.sh (~250 lines)    │
│  - health check (gh auth status) │
│  - issue CRUD via gh CLI         │
│  - label management              │
│  - file-based state always syncd │
│  - HALT on gh failure            │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────┐
│  GitHub Issues API           │
│  (via gh CLI)                │
└──────────────────────────────┘
```

### GitHub Issues Data Model

```
GitHub Issue (type: "scope")          ← one per AP requirement scope
├── Labels: ap:scope, priority:HIGH, category:auth
├── Milestone: (optional, maps to roadmap phase)
├── Body: requirement summary + acceptance criteria
│
├── Sub-issue or Tasklist Item: WU-001  ← work units as task list items
├── Sub-issue or Tasklist Item: WU-002
└── Sub-issue or Tasklist Item: WU-003

GitHub Issue (type: "iteration")      ← one per iteration attempt
├── Labels: ap:iteration, scope:{id}
├── Body: frozen criteria, files in scope
└── Linked to parent scope issue
```

### Label Taxonomy

Labels are the backbone of the GitHub Issues integration. Created automatically during install:

```
# Type labels (prefixed for filtering)
ap:scope          — Requirement scope (maps to BEADS epic)
ap:iteration      — Single iteration attempt
ap:work-unit      — Decomposed work unit (if using sub-issues)

# Status labels
status:planning   — Scope is being planned
status:executing  — Active implementation
status:reviewing  — In review gate
status:approved   — Completed and approved
status:blocked    — External blocker
status:iterate    — Needs another iteration

# Priority labels (from requirement frontmatter)
priority:critical
priority:high
priority:medium
priority:low

# Category labels (from requirement category)
category:{name}   — Dynamic, one per requirement category

# Backlog type labels
type:feature
type:enhancement
type:bugfix
type:tech-debt
type:investigation
```

### Issue Relationships

GitHub provides two mechanisms for relating issues:

**1. Task Lists (native, recommended)**
```markdown
## Work Units
- [ ] #42 WU-001: Schema migration
- [ ] #43 WU-002: API endpoint (depends on WU-001)
- [x] #44 WU-003: Frontend integration
```
Task lists in the scope issue body track work unit progress. This is the simplest approach and works well with the AP execution model.

**2. Sub-Issues (GitHub feature, if available)**
If the repository has sub-issues enabled, work units can be created as sub-issues of the scope issue. This provides better tracking but is not universally available.

**3. Cross-Scope Dependencies**
```markdown
## Dependencies
Blocked by: #38 (database migration must complete first)
Related: #41 (shares auth middleware changes)
```
These go in the scope issue body. GitHub auto-links `#N` references. The `depends_on` field in requirement frontmatter maps to `Blocked by: #N` in the issue body.

### State Tracking Comparison

| Event | GitHub Issues | File Fallback |
|-------|--------------|---------------|
| Scope started | Create issue with `ap:scope` label | `current_iteration.conf` |
| Iteration started | Create/update issue with `ap:iteration` label | `current_iteration.conf` |
| Iteration # stored | Issue body metadata: `<!-- ap:iteration=01 -->` | `current_iteration.conf` |
| WU progress | Check/uncheck task list item + comment | `current_work_unit.conf` |
| Scope approved | Close issue, add `status:approved` label | `results.md` |
| Scope blocked | Add `status:blocked` label + comment | `results.md` |
| Session recovery | Query: `gh issue list --label ap:scope,status:executing` | `current_iteration.conf` |

---

## 5. Mapping: BEADS Concepts → GitHub Issues

| BEADS Concept | BEADS Command | GitHub Replacement | gh Command |
|--------------|---------------|-------------------|------------|
| Create epic | `bd create` | Create scope issue | `gh issue create --label ap:scope` |
| Find epic | `bd query "type=epic AND title=..."` | Find scope issue | `gh issue list --label ap:scope --search "{scope}"` |
| Create task | `bd create` (child of epic) | Add task list item / sub-issue | `gh issue edit {N} --body` or `gh issue create` |
| Update task | `bd label` | Check task item + comment | `gh issue comment {N}` |
| Set iteration | `bd set-state iteration=N` | Update issue body metadata | `gh issue edit {N} --body` |
| Get iteration | `bd state iteration` | Parse issue body metadata | `gh issue view {N} --json body` |
| Close epic | `bd close` | Close issue + label | `gh issue close {N}` + `gh issue edit {N} --add-label status:approved` |
| Verify state | `validate-beads-state.sh` | Query issue state | `gh issue view {N} --json state,labels` |
| Breadcrumbs | `.beads-state` file | Issue comments (audit trail) | `gh issue comment {N} --body "..."` |

### Key Differences

1. **No local database.** All state is in GitHub. Simpler, but requires network.
2. **Audit trail is comments.** Instead of `.beads-state` breadcrumbs, lifecycle events become issue comments.
3. **Labels replace status fields.** Status transitions are label swaps.
4. **Issue numbers replace epic IDs.** Stored in `current_iteration.conf` as `GH_ISSUE=42`.

---

## 6. Knowledge System Migration

### Current State

```
.beads/knowledge/        ← PRIMARY (when BEADS enabled)
  patterns.jsonl
  gotchas.jsonl
  decisions.jsonl
  anti-patterns.jsonl
  codebase-facts.jsonl
  api-behaviors.jsonl

.agent_process/knowledge/ ← FALLBACK (when BEADS disabled)
  README.md              ← only contains a pointer to .beads/
```

### Target State

```
.agent_process/knowledge/ ← SINGLE CANONICAL LOCATION
  patterns.jsonl
  gotchas.jsonl
  decisions.jsonl
  anti-patterns.jsonl
  codebase-facts.jsonl
  api-behaviors.jsonl
  README.md              ← updated to describe this as primary
```

### Migration Steps

1. **No runtime migration needed** — `.beads/knowledge/` doesn't exist in this repo (confirmed: no `.beads/` directory present)
2. **Update `README.md`** in `.agent_process/knowledge/` to describe it as the primary and only location
3. **Update all references** in orchestration/process docs from `.beads/knowledge` to `.agent_process/knowledge`
4. **Remove dual-directory logic** — no more "check .beads first, fall back to .agent_process"
5. **Simplify knowledge schema** — use the full metaswarm-compatible schema everywhere (no "minimal fallback" schema distinction)
6. **Keep `migrate-knowledge.py` temporarily** for installed projects that have `.beads/knowledge/` — it migrates TO `.agent_process/knowledge/` instead, then can be removed in a future release
7. **Update `process/knowledge-base.md`** — remove all BEADS/fallback language, make `.agent_process/knowledge/` the sole location

### Knowledge Schema (Unified)

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

One schema. No "minimal" variant. The `provenance` and `affectedFiles` fields are recommended but not required — simple entries still work.

---

## 7. Installation Flow Changes

### Current Flow (Beads)

```
install.sh
  ├── Prompt: "Enable BEADS? [Y/n]"
  ├── If yes:
  │   ├── Detect Dolt endpoints (local/docker/tunnel)
  │   ├── Present menu (4 options)
  │   ├── Write server config to quality-config.json
  │   ├── Create ~/.config/beads/credentials
  │   ├── Create .beads/knowledge/
  │   └── Run migrate-knowledge.py (.agent_process/knowledge → .beads/knowledge)
  └── If no:
      └── Set beads.enabled = false
```

### New Flow (GitHub Issues)

```
install.sh
  ├── Create .agent_process/knowledge/ (always — it's the primary KB now)
  ├── Prompt: "Track work with GitHub Issues? [y/N]"
  │
  ├── If yes:
  │   ├── Verify gh CLI installed
  │   │   └── If not: print install instructions, ask to retry or skip
  │   ├── Verify gh auth status
  │   │   └── If not: print `gh auth login` instructions, ask to retry or skip
  │   ├── Verify repo has GitHub remote
  │   │   └── If not: warn, ask to continue without GH
  │   ├── Create AP labels in repo (ap:scope, status:*, priority:*, type:*)
  │   │   └── Idempotent: skip labels that already exist
  │   ├── Write to quality-config.json:
  │   │   { "github_issues": { "enabled": true, "_user_configured": true } }
  │   └── Print: "GitHub Issues enabled. Work tracking will use issues."
  │
  └── If no:
      ├── Write to quality-config.json:
      │   { "github_issues": { "enabled": false, "_user_configured": true } }
      └── Print: "File-based tracking only. No GitHub Issues."
```

### Key Changes

1. **Default is NO** (not YES like BEADS). GitHub Issues adds friction; only opt in if you want it.
2. **No database to manage.** No Dolt, no Docker, no GCE, no credentials files.
3. **Upfront validation.** If the user says yes, we verify `gh` works BEFORE proceeding. No silent degradation.
4. **Label creation is idempotent.** Safe to re-run.
5. **No `.beads/` directory created.** No `~/.config/beads/` touched.
6. **Knowledge directory is always `.agent_process/knowledge/`.** No conditional creation.

### Removed From Installation

- All Dolt endpoint detection (local binary, Docker container, IAP tunnel)
- Interactive Dolt menu (4 options)
- `~/.config/beads/credentials` creation
- `.beads/` directory creation
- `migrate-knowledge.py` execution (keep script for manual migration of existing installs)
- Any `bd` or `dolt` references

---

## 8. GitHub Issues Health Check & Halt Protocol

This is the most critical new behavior. When GitHub Issues is enabled, the system treats `gh` failures as **blocking errors**, not silent degradation.

### Health Check Function

```bash
# gh-lifecycle.sh
check_gh_health() {
  local errors=()

  # 1. gh CLI exists?
  if ! command -v gh &>/dev/null; then
    errors+=("gh CLI not found. Install: https://cli.github.com/")
  fi

  # 2. gh authenticated?
  if ! gh auth status &>/dev/null 2>&1; then
    errors+=("gh not authenticated. Run: gh auth login")
  fi

  # 3. In a git repo with GitHub remote?
  if ! gh repo view --json name &>/dev/null 2>&1; then
    errors+=("Not in a GitHub repository, or remote not configured.")
  fi

  # 4. Can we read issues? (permission check)
  if ! gh issue list --limit 1 &>/dev/null 2>&1; then
    errors+=("Cannot access issues. Check repo permissions and gh auth scopes.")
  fi

  if [ ${#errors[@]} -gt 0 ]; then
    echo "HALT"
    echo "──────────────────────────────────────────────"
    echo "  GitHub Issues is ENABLED but not working."
    echo "  Work cannot proceed until these are fixed:"
    echo "──────────────────────────────────────────────"
    for err in "${errors[@]}"; do
      echo "  ✗ $err"
    done
    echo ""
    echo "  Options:"
    echo "    1. Fix the issues above and retry"
    echo "    2. Disable GitHub Issues:"
    echo "       Set github_issues.enabled=false in quality-config.json"
    echo "──────────────────────────────────────────────"
    return 1
  fi
  return 0
}
```

### When Health Checks Run

| Phase | Check Point | On Failure |
|-------|------------|------------|
| `ap_exec` Step 0.5 (preflight) | Before creating scope issue | HALT — print errors, stop execution |
| `gh-lifecycle.sh` every action | Before any `gh issue` command | HALT — print errors, return non-zero |
| Session recovery | Before querying issues | WARN — fall back to file state, suggest fixing gh |

### Halt Behavior in Orchestrators

**Claude Code:**
The coordinator prompt will include:
```markdown
## GitHub Issues Gate (Step 0.4)

If `quality-config.json` has `github_issues.enabled = true`:

1. Run: `bash .agent_process/scripts/gh-lifecycle.sh health-check`
2. If exit code ≠ 0:
   - **STOP ALL WORK IMMEDIATELY**
   - Display the error output to the user verbatim
   - Tell the user: "GitHub Issues is enabled but not working. Let's fix this before continuing."
   - Work with the user to resolve (install gh, run gh auth login, etc.)
   - Re-run health check after each fix attempt
   - Only proceed when health check passes
3. If exit code = 0: continue to Step 0.5
```

**Codex (orchestrator prompts):**
Same logic, expressed in the Codex orchestrator format:
```markdown
CRITICAL: If github_issues.enabled is true in quality-config.json, you MUST run
the gh health check before any work begins. If it fails, output the errors and
STOP. Do not continue. Do not fall back to file-based tracking silently.
The user chose GitHub Issues — respect that choice.
```

### Recovery After Fix

When the user fixes the `gh` issue:
1. Agent re-runs `gh-lifecycle.sh health-check`
2. If it passes, agent picks up where it stopped:
   - If halted during preflight → continue preflight from Step 0.5
   - If halted during execution → resume current work unit
   - State is preserved in file-based tracking (always written regardless)
3. File-based state ensures no work is lost during the halt

---

## 9. Orchestration Changes (Claude + Codex)

### Coordinator Changes

**`execute-preflight.md`**
```
BEFORE: Step 0.5 — bash beads-lifecycle.sh start {scope}
AFTER:  Step 0.4 — bash gh-lifecycle.sh health-check (if enabled)
        Step 0.5 — bash gh-lifecycle.sh start {scope} (if enabled)
```

**`execute-main.md`**
```
BEFORE: beads-lifecycle.sh task-update {scope} WU-NNN in-progress
AFTER:  gh-lifecycle.sh task-update {scope} WU-NNN in-progress
```

**`review-iteration.md`**
```
BEFORE: beads-lifecycle.sh verify, close, set-iteration
AFTER:  gh-lifecycle.sh verify, close, set-iteration
```

**`plan-scope.md`**
```
BEFORE: "Do NOT run BEADS commands during planning"
AFTER:  "Do NOT run gh-lifecycle.sh during planning" (same principle)
```

**`007b-session-recovery.md`**
```
BEFORE: beads-lifecycle.sh get-iteration → fall back to file
AFTER:  gh-lifecycle.sh get-iteration → fall back to file
        (same priority: GitHub first, file second, if GH enabled)
```

**`07-10-post-decision.md`**
```
BEFORE: Deposit to .beads/knowledge/ or .agent_process/knowledge/
AFTER:  Deposit to .agent_process/knowledge/ (always, single location)
BEFORE: beads-lifecycle.sh close {scope} approved
AFTER:  gh-lifecycle.sh close {scope} approved
```

### Key Orchestration Principle

**File-based state is ALWAYS written**, regardless of GitHub Issues being enabled or not. GitHub Issues is an enhancement layer on top, not a replacement for file-based tracking. This ensures:

1. Session recovery works even if `gh` breaks mid-execution
2. Work artifacts are always local (no network dependency for reading state)
3. The `.agent_process/work/` directory remains the canonical work history

### Claude Commands Changes

**`ap_exec.md`:**
- Remove all `beads.enabled` references
- Add `github_issues.enabled` check at Step 0.4
- Replace `beads-lifecycle.sh` calls with `gh-lifecycle.sh`

**`ap_project.md`:**
- No BEADS-specific changes needed (doesn't directly use BEADS)
- May want to add `gh issue list --label ap:scope` as a status view

**`.claude/settings.local.json`:**
- Remove all `bd *` command permissions
- Remove `dolt *` command permissions
- Add `gh issue *`, `gh label *` command permissions

---

## 10. Quality Config Cleanup

### Current `quality-config.json` (BEADS section)

```json
{
  "beads": {
    "enabled": true,
    "auto_install": true,
    "_user_configured": true,
    "server": {
      "host": "127.0.0.1",
      "port": 3308,
      "user": "sam"
    }
  }
}
```

### New `quality-config.json` (GitHub Issues section)

```json
{
  "github_issues": {
    "enabled": false,
    "_user_configured": true
  }
}
```

That's it. No server config, no auto_install, no credentials. `gh` handles all auth.

### Full Config After Cleanup

```json
{
  "pre_flight": { "enabled": true, "session_recovery": true },
  "knowledge_base": { "enabled": true, "query_during_planning": true },
  "adversarial_review": { "enabled": true, "skip_for_trivial": true },
  "work_unit_decomposition": { "enabled": true, "trigger_threshold_files": 3, "trigger_threshold_layers": 2 },
  "design_review": { "enabled": false },
  "github_issues": { "enabled": false, "_user_configured": true },
  "pr_shepherd": { "enabled": true },
  "metaswarm": { "enabled": false, "_user_configured": true, "features": { "..." } }
}
```

### Installation Cleanup for Existing Projects

When `install.sh` runs on a project that already has BEADS configured:

```bash
# Detect and clean old BEADS config
if cfg_has_key 'beads'; then
  echo "Migrating from BEADS to new config format..."

  # Remove beads section entirely
  cfg_delete 'beads'

  # Migrate .beads/knowledge/ → .agent_process/knowledge/ if exists
  if [ -d ".beads/knowledge" ] && ls .beads/knowledge/*.jsonl &>/dev/null; then
    echo "Migrating knowledge files from .beads/knowledge/ to .agent_process/knowledge/..."
    cp -n .beads/knowledge/*.jsonl .agent_process/knowledge/ 2>/dev/null
    echo "  Done. Original files preserved in .beads/knowledge/ (safe to delete)."
  fi

  # Prompt for GitHub Issues (new feature)
  # ...
fi
```

---

## 11. File-Based Fallback (No GitHub)

When the user chooses NOT to use GitHub Issues, the system works exactly as it does today with BEADS disabled — which is already battle-tested.

### What Stays the Same

| Feature | Mechanism |
|---------|-----------|
| Iteration tracking | `current_iteration.conf` (SCOPE=, ITERATION=) |
| Work unit tracking | `current_work_unit.conf` (CURRENT_UNIT=) |
| Session recovery | Read `current_iteration.conf` |
| Work history | `.agent_process/work/{scope}/iteration_*/` |
| Knowledge base | `.agent_process/knowledge/*.jsonl` |
| Roadmap status | `.agent_process/roadmap/master_roadmap.md` |
| Backlog | `.agent_process/roadmap/backlog.md` |

### What Changes

1. **`gh-lifecycle.sh` exits silently** when `github_issues.enabled = false` — same pattern as `beads-lifecycle.sh` today
2. **No breadcrumb file** (`.beads-state` goes away) — breadcrumbs are replaced by issue comments when GH enabled, or simply not generated when disabled
3. **No audit trail beyond git** — this is acceptable for file-based-only mode

### Seamless Experience

The orchestration coordinators call `gh-lifecycle.sh` regardless. The script checks the config and returns silently if disabled. Coordinators don't need conditional logic — the script handles it.

```bash
# In any coordinator:
bash .agent_process/scripts/gh-lifecycle.sh start "$SCOPE"
# If GH disabled: exits 0 silently
# If GH enabled: creates issue, writes state
# File-based state is written by the coordinator directly (not by the script)
```

---

## 12. Files to Remove

### Complete Removal

| File | Reason |
|------|--------|
| `scripts/beads-lifecycle.sh` | Replaced by `gh-lifecycle.sh` |
| `scripts/migrate-knowledge.py` | One-time migration, keep for 1 release then remove |
| `deploy/beads-server/setup.sh` | No more Dolt server |
| `deploy/beads-server/teardown.sh` | No more Dolt server |
| `deploy/beads-server/dolt-docker.sh` | No more Docker Dolt |
| `deploy/beads-server/README.md` | No more server docs |
| `deploy/beads-server/` (directory) | Empty after above |
| `process/beads-integration.md` | Replaced by github-issues-integration.md |
| `test/contract/validate-beads-state.sh` | No more breadcrumb validation |
| `test/unit/test-beads-lifecycle.bats` | Tests for removed script |
| `.agent_process/requirements_docs/decomposition/decomp_scope_07_beads_iteration_state.md` | Requirement for removed system |

### Files to Clean (remove BEADS references)

| File | What to Remove |
|------|---------------|
| `.gitignore` | `deploy/beads-server/.beads-server-info` entry |
| `.claude/settings.local.json` | All `bd *` and `dolt *` permission entries |
| `quality-config.json` | Entire `beads` section |
| `process/quality-configuration.md` | BEADS config documentation section |
| `process/knowledge-base.md` | Dual-directory logic, `.beads/knowledge` references |
| `README.md` | BEADS/Dolt references |

---

## 13. Files to Create

| File | Purpose |
|------|---------|
| `scripts/gh-lifecycle.sh` | GitHub Issues lifecycle script (replaces beads-lifecycle.sh) |
| `process/github-issues-integration.md` | How-to guide (replaces beads-integration.md) |
| `test/unit/test-gh-lifecycle.bats` | Unit tests for new script |
| `test/contract/validate-gh-state.sh` | Contract validator for GH issue state |

---

## 14. `gh-lifecycle.sh` — Detailed Design

### Actions

| Action | Description | gh Commands |
|--------|------------|-------------|
| `health-check` | Verify gh CLI, auth, repo access | `gh auth status`, `gh repo view`, `gh issue list` |
| `start {scope}` | Create or find scope issue | `gh issue list --search`, `gh issue create` |
| `set-iteration {scope} {N}` | Update iteration in issue body | `gh issue edit`, `gh issue comment` |
| `get-iteration {scope}` | Read iteration from issue | `gh issue view --json body` |
| `task-create {scope} WU-NNN {desc}` | Add work unit to task list | `gh issue edit` (update body) |
| `task-update {scope} WU-NNN {status}` | Check/uncheck task + comment | `gh issue edit`, `gh issue comment` |
| `close {scope} {decision}` | Close issue with label | `gh issue close`, `gh issue edit --add-label` |
| `verify {scope}` | Check issue state consistency | `gh issue view --json` |

### Issue Body Format

```markdown
## Scope: {scope_id}

**Requirement:** {requirement_id}
**Priority:** {priority}
**Category:** {category}

### Acceptance Criteria
{criteria from iteration_plan.md}

### Work Units
- [ ] WU-001: {description}
- [ ] WU-002: {description} (depends on WU-001)
- [x] WU-003: {description}

### Iteration History
| # | Status | Decision |
|---|--------|----------|
| 01 | Complete | ITERATE |
| 02 | Active | — |

<!-- ap:metadata
scope={scope_id}
iteration=02
issue_created=2026-04-01T10:00:00Z
-->
```

The HTML comment block stores machine-readable metadata that `gh-lifecycle.sh` parses. Human-readable content is above.

### State File Integration

`gh-lifecycle.sh` writes to `current_iteration.conf` on every state change:

```bash
# current_iteration.conf format (extended)
SCOPE=auth_middleware_01
ITERATION=iteration_02
GH_ISSUE=42          # NEW: GitHub issue number (when GH enabled)
```

The `GH_ISSUE` field lets the script find the right issue without searching every time.

### Error Handling

```bash
# Every gh command wrapped:
run_gh() {
  local output
  output=$("$@" 2>&1)
  local rc=$?
  if [ $rc -ne 0 ]; then
    echo "HALT: GitHub CLI command failed" >&2
    echo "Command: $*" >&2
    echo "Output: $output" >&2
    echo "" >&2
    echo "GitHub Issues is enabled. Work cannot continue until this is resolved." >&2
    echo "Fix the issue and re-run, or disable GitHub Issues in quality-config.json." >&2
    return 1
  fi
  echo "$output"
}
```

---

## 15. Migration Checklist

### Phase 1: Knowledge System (no breaking changes)

- [ ] Update `.agent_process/knowledge/README.md` — describe as primary location
- [ ] Update `process/knowledge-base.md` — remove dual-directory logic
- [ ] Update all orchestration files — replace `.beads/knowledge` references
- [ ] Update `07-10-post-decision.md` — always deposit to `.agent_process/knowledge/`
- [ ] Update `025-knowledge-query.md` — single directory, no fallback logic

### Phase 2: Create GitHub Issues System

- [ ] Write `scripts/gh-lifecycle.sh` — full implementation
- [ ] Write `process/github-issues-integration.md` — how-to guide
- [ ] Write `test/unit/test-gh-lifecycle.bats` — unit tests
- [ ] Write `test/contract/validate-gh-state.sh` — contract tests

### Phase 3: Update Orchestration

- [ ] Update `execute-preflight.md` — add Step 0.4 health check, replace Step 0.5
- [ ] Update `execute-main.md` — replace beads-lifecycle.sh calls
- [ ] Update `review-iteration.md` — replace beads-lifecycle.sh calls
- [ ] Update `007b-session-recovery.md` — use gh-lifecycle.sh
- [ ] Update `07-10-post-decision.md` — replace beads-lifecycle.sh calls
- [ ] Update `plan-scope.md` — update "don't run BEADS" warning

### Phase 4: Update Installation

- [ ] Rewrite install.sh — remove BEADS, add GitHub Issues prompt
- [ ] Add label creation logic to install.sh
- [ ] Add BEADS config migration logic to install.sh
- [ ] Add `.beads/knowledge/` → `.agent_process/knowledge/` migration
- [ ] Update quality-config.json template — remove beads, add github_issues

### Phase 5: Update Claude Commands & Settings

- [ ] Update `claude/commands/ap_exec.md` — replace beads references
- [ ] Update `.claude/settings.local.json` — remove bd/dolt, add gh permissions
- [ ] Update `claude/commands/ap_project.md` — add GH issue status view

### Phase 6: Remove BEADS

- [ ] Delete `scripts/beads-lifecycle.sh`
- [ ] Delete `deploy/beads-server/` (entire directory)
- [ ] Delete `process/beads-integration.md`
- [ ] Delete `test/contract/validate-beads-state.sh`
- [ ] Delete `test/unit/test-beads-lifecycle.bats`
- [ ] Delete `.agent_process/requirements_docs/decomposition/decomp_scope_07_*`
- [ ] Clean `.gitignore` — remove beads-server-info entry
- [ ] Clean `process/quality-configuration.md` — remove BEADS section
- [ ] Clean `README.md` — remove BEADS/Dolt references

### Phase 7: Documentation

- [ ] Update `process/quality-configuration.md` — add github_issues schema
- [ ] Write migration guide (how-to) for existing BEADS users
- [ ] Update `README.md` — reflect new architecture
- [ ] Verify all cross-references updated (grep for "beads", "dolt", "bd ")

### Phase 8: Testing

- [ ] Run `test/unit/test-gh-lifecycle.bats`
- [ ] Run `test/contract/validate-gh-state.sh` against real repo
- [ ] Manual test: install.sh with GH enabled (fresh project)
- [ ] Manual test: install.sh with GH disabled (fresh project)
- [ ] Manual test: install.sh upgrade (existing BEADS project)
- [ ] Manual test: full ap_exec cycle with GH enabled
- [ ] Manual test: full ap_exec cycle with GH disabled
- [ ] Manual test: gh failure mid-execution (disconnect network)
- [ ] Verify Codex orchestrator prompts work with new scripts

---

## 16. Risk Assessment

### High Risk

| Risk | Mitigation |
|------|-----------|
| Existing projects have `.beads/knowledge/` with data | Migration step in install.sh copies to `.agent_process/knowledge/`, preserves originals |
| `gh` rate limiting on large projects | Cache issue numbers in `current_iteration.conf`, minimize API calls |
| Network dependency for GitHub Issues | File-based state always written; recovery works offline |

### Medium Risk

| Risk | Mitigation |
|------|-----------|
| Label conflicts with existing repo labels | Use `ap:` prefix for all AP labels |
| Issue body format parsing breaks | Use HTML comment block for machine data, human-readable above |
| Codex agents don't have `gh` access | Health check catches this immediately; clear error message |
| `gh` CLI version differences | Test against gh 2.x (current stable); document minimum version |

### Low Risk

| Risk | Mitigation |
|------|-----------|
| Users miss BEADS features | GitHub Issues provides equivalent tracking; knowledge system unchanged |
| Performance (API calls vs local db) | Acceptable for the frequency of calls (~5-10 per scope execution) |

---

## 17. Open Questions

1. **Sub-issues vs task lists?** GitHub sub-issues are newer and not available in all orgs. Task list checkboxes in the issue body are universally available. **Recommendation:** Use task lists as default, document sub-issues as an optional enhancement.

2. **Should we create a GitHub Issue for each iteration, or just the scope?** Creating per-iteration issues adds noise. **Recommendation:** One issue per scope, iteration state tracked in the issue body metadata and comments.

3. **What about the `metaswarm:create-issue` skill?** It's an external metaswarm skill. We should ensure our GitHub Issues format is compatible with what metaswarm expects, but we don't control that skill's implementation. **Recommendation:** Use standard `gh` label conventions that metaswarm can query.

4. **Should `migrate-knowledge.py` be kept or removed?** It's needed for one release cycle to help existing installs migrate `.beads/knowledge/` data. **Recommendation:** Keep it in Phase 1, mark as deprecated, remove in next major release.

5. **Should the health check run on every `gh-lifecycle.sh` call or just at preflight?** Every call adds ~1s latency. **Recommendation:** Full health check at preflight only; individual commands just catch `gh` errors inline with HALT messaging.

---

## Appendix A: Metaswarm Compatibility

Metaswarm's knowledge system (`/metaswarm:prime`, `/metaswarm:self-reflect`) currently reads from `.beads/knowledge/`. After this migration:

- Metaswarm should be configured to read from `.agent_process/knowledge/` instead
- The knowledge schema remains metaswarm-compatible (same fields)
- If metaswarm has hardcoded `.beads/knowledge/`, a symlink can bridge temporarily:
  ```bash
  ln -s .agent_process/knowledge .beads/knowledge
  ```
- Long-term: metaswarm should respect the same config or discover the knowledge directory dynamically

## Appendix B: `gh-lifecycle.sh` Action Reference

```
Usage: gh-lifecycle.sh <action> [args...]

Actions:
  health-check                  Verify gh CLI, auth, and repo access
  start <scope>                 Create or find scope issue, set initial state
  set-iteration <scope> <N>     Update iteration pointer in issue metadata
  get-iteration <scope>         Read current iteration from issue (or file fallback)
  task-create <scope> <id> <desc>  Add work unit to scope issue task list
  task-update <scope> <id> <status>  Update work unit status (in-progress|complete|blocked)
  close <scope> <decision>      Close scope issue (approved|blocked)
  verify <scope>                Check issue state consistency
  comment <scope> <message>     Add audit comment to scope issue

Environment:
  Reads github_issues.enabled from .agent_process/quality-config.json
  Exits silently (0) if disabled or config missing
  Exits with error (1) if enabled but gh not working — HALT behavior
```
