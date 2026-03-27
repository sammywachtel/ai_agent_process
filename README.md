# AI Agent Process

A structured workflow framework for AI-powered development with Claude Code. Provides role separation, iteration management, and decision frameworks that turn ad-hoc AI coding into a repeatable development process.

**Philosophy:** Ship pragmatically, iterate deliberately, pivot when you learn.

---

## Quick Start

```bash
# 1. Install the framework into your project
/path/to/ai_agent_process/install.sh /path/to/your/project

# 2. Open Claude Code in your project and initialize
/ap_project init

# 3. Create your first requirement
/ap_brainstorm "improve the login experience"
# or: /ap_requirements add "user_authentication"

# 4. Execute the work
/ap_exec user_auth iteration_01

# 5. Ship it
/ap_release pr
```

That's it. The framework handles planning, validation, adversarial review, and knowledge accumulation automatically. Read on for the full picture.

---

## Dependencies

### Required

| Dependency | Purpose | Install |
|------------|---------|---------|
| **Claude Code** | AI orchestration engine (slash commands, agents, hooks) | [claude.ai/code](https://claude.ai/code) |
| **Git** | Version control, branching, history tracking | Pre-installed on most systems |
| **Bash 4+** | Install script, validation hooks, utility scripts | Pre-installed on Linux/macOS |
| **GitHub CLI (`gh`)** | PR creation, issue management, CI status checks | `brew install gh` / [cli.github.com](https://cli.github.com) |

### Optional

| Dependency | Purpose | When You Need It | Install |
|------------|---------|------------------|---------|
| **BEADS CLI** | Durable state tracking across sessions (epic/task model) | Multi-session work, session recovery | Auto-installed at runtime if `beads.enabled: true` in `quality-config.json` |
| **Dolt SQL Server** | Centralized BEADS state for teams | Multi-developer coordination | See `deploy/beads-server/README.md` |
| **Metaswarm** (Claude Code plugin) | Multi-agent brainstorming, design review gates, PR shepherd, self-reflection | Enhanced ideation and review quality | [marketplace plugin](https://github.com/dsifry/metaswarm) — enable via `quality-config.json` |
| **Docker** | Containerized dev environment with bypass permissions | Safe experimentation, CI parity | See `.docker-dev/README.md` |
| **Python 3** | Knowledge migration script, BEADS credential management | Only during `install.sh` for BEADS credential setup | Pre-installed on most systems |
| **`gcloud` CLI** | Deploying a BEADS Dolt server on GCE | Only if self-hosting BEADS server | [cloud.google.com/sdk](https://cloud.google.com/sdk) |

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Dependencies](#dependencies)
3. [Overview](#overview)
4. [The Workflow](#the-workflow)
5. [Roles & Responsibilities](#roles--responsibilities)
6. [Key Concepts](#key-concepts)
7. [Slash Commands Reference](#slash-commands-reference)
8. [Quality Configuration](#quality-configuration)
9. [Directory Structure](#directory-structure)
10. [Getting Started Guide](#getting-started-guide)
11. [Success Metrics](#success-metrics)
12. [Customization](#customization)
13. [Documentation Reference](#documentation-reference)

---

## Overview

The AI Agent Process solves a common problem: AI-assisted development often becomes a chaotic loop of "try something, see if it works, try again." This framework introduces structure through:

- **Role separation** — Human defines scope, orchestrator plans/reviews, implementation executes
- **Frozen criteria** — No moving goalposts during implementation
- **Iteration budgets** — Maximum 3 attempts before escalation prevents infinite loops
- **Decision framework** — Every review ends with a clear decision (APPROVE/ITERATE/BLOCK/PIVOT)
- **Scoped validation** — Only test what you changed, not the entire codebase
- **Knowledge base** — Patterns, gotchas, and decisions compound across iterations
- **Adversarial review** — Fresh agent verifies criteria without implementation bias

### What This Provides

| Component | Purpose |
|-----------|---------|
| **Slash Commands** | Executable workflows for planning, execution, review, and release |
| **Orchestration Prompts** | Decomposed coordinator + step file architecture for planning and review |
| **Iteration Templates** | Standardized artifacts for tracking work |
| **Validation Tools** | Scoped testing scripts with automatic hook-based execution |
| **Project Management** | Roadmap, backlog, and requirements tracking via `/ap_project` |
| **Knowledge Base** | JSONL-based patterns, gotchas, decisions accumulated across iterations |
| **Adversarial Review** | Fresh-instance code review for unbiased criterion verification |
| **Work Unit Decomposition** | DAG-based parallel execution for multi-domain scopes |
| **PR Shepherd** | Post-PR agent monitoring CI, reviews, and merge-readiness |
| **Design Review Gate** | Multi-reviewer plan assessment for complex scopes (opt-in) |
| **Quality Configuration** | Centralized feature control via `quality-config.json` |
| **BEADS Integration** | Optional durable state tracking for work units across sessions |
| **Metaswarm Integration** | Optional multi-agent brainstorming, design review, PR automation (opt-in) |

---

## The Workflow

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        THE AGENT PROCESS                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. PLAN          2. EXECUTE        3. REVIEW        4. SHIP   │
│   ─────────        ─────────         ─────────        ──────    │
│   Human defines   /ap_exec          Orchestrator    /ap_release │
│   scope + criteria implements        reviews         creates PR │
│                                                                 │
│   ┌─────────┐     ┌─────────┐       ┌─────────┐     ┌────────┐ │
│   │ Define  │────▶│ Execute │──────▶│ Review  │────▶│ Ship   │ │
│   │ Scope   │     │ Work    │       │ Results │     │ It!    │ │
│   └─────────┘     └─────────┘       └────┬────┘     └────────┘ │
│                                          │                      │
│                        ┌─────────────────┼─────────────────┐    │
│                        ▼                 ▼                 ▼    │
│                   ┌────────┐       ┌──────────┐      ┌───────┐ │
│                   │ITERATE │       │  PIVOT   │      │ BLOCK │ │
│                   │(a/b/c) │       │(new iter)│      │(human)│ │
│                   └────────┘       └──────────┘      └───────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Detailed Steps

#### Step 1: Plan (Human + Orchestrator)
1. Human defines scope name, objectives, and acceptance criteria
2. Orchestrator creates `iteration_plan.md` with **LOCKED** criteria
3. Scoped validation script is created for this work
4. **Critical:** Criteria CANNOT change once iteration starts

#### Step 2: Execute (Implementation)
```bash
/ap_exec <scope> <iteration>
```
- Reads the iteration plan
- For multi-domain scopes (3+ files across 2+ layers), decomposes into work units — a DAG of independently-executable tasks with per-unit agents and validation
- Implements changes within scope boundaries (parallel where possible)
- Runs scoped validation (hook fires automatically)
- Creates `results.md` (with Work Unit Summary if decomposed) and `test-output.txt`

#### Step 3: Review (Orchestrator)
- Evaluates results against **frozen criteria for this major iteration** (after PIVOT, uses revised criteria)
- Chooses exactly one decision: **APPROVE / ITERATE / BLOCK / PIVOT**
- Updates iteration plan with decision

#### Step 4: Ship or Continue
- **APPROVE** → `/ap_release pr` to create PR
- **ITERATE** → Creates sub-iteration (a/b/c), max 3 attempts
- **PIVOT** → New major iteration with revised criteria (requires human approval)
- **BLOCK** → Escalate to human, do not proceed

### End-to-End Process Flow

The complete lifecycle from idea to acceptance, with all optional features enabled:

```
┌───────────────────────────────────────────────────────────────────────┐
│                  IDEA → ACCEPTANCE: FULL LIFECYCLE                    │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─── IDEATION ─────────────────────────────────────────────────────┐ │
│  │                                                                  │ │
│  │  Vague idea?            Clear requirement?    Existing spec?     │ │
│  │  ────────────           ──────────────────    ──────────────     │ │
│  │  /ap_brainstorm "idea"  /ap_requirements      /ap_requirements   │ │
│  │    │                      add "title"           import "file"    │ │
│  │    ├─ Product agent              │                   │           │ │
│  │    ├─ Architecture agent         │                   │           │ │
│  │    ├─ Critical agent             │                   │           │ │
│  │    ▼                             │                   │           │ │
│  │  Brainstorm synthesis            │                   │           │ │
│  │    │                             │                   │           │ │
│  │    ├─ Optional: design review    │                   │           │ │
│  │    ▼                             ▼                   ▼           │ │
│  │  ┌───────────────────────────────────────────────────────────┐   │ │
│  │  │ Formal AP Requirement (.agent_process/requirements_docs/) │   │ │
│  │  │ • YAML frontmatter (id, type, category, status, priority) │   │ │
│  │  │ • Objective, Technical Requirements, Success Criteria      │  │ │
│  │  │ • Files Expected to Change, Out of Scope, Known Risks     │   │ │
│  │  └───────────────────────────────────────────────────────────┘   │ │
│  └───────────────────────────────────────────────────────────────────┘│
│                                  │                                    │
│                                  ▼                                    │
│  ┌─── PLANNING (Orchestrator) ──────────────────────────────────────┐ │
│  │                                                                  │ │
│  │  Human copies requirement → orchestration/plan-scope.md          │ │
│  │                                                                  │ │
│  │  Orchestrator:                                                   │ │
│  │    1. Size check — fits 1-2 weeks? Split if too large            │ │
│  │    2. Query knowledge base — patterns, gotchas, decisions        │ │
│  │    3. Create iteration_plan.md with LOCKED acceptance criteria   │ │
│  │    4. Set up scoped validation script                            │ │
│  │    5. If complexity: complex → design review gate (2-4 agents)   │ │
│  │    6. Create work/ directory and iteration_01/ folder            │ │
│  │                                                                  │ │
│  │  Output: .agent_process/work/{scope}/iteration_plan.md           │ │
│  │          .agent_process/scripts/after_edit/validate-{scope}.sh   │ │
│  └───────────────────────────────────────────────────────────────────┘│
│                                  │                                    │
│                                  ▼                                    │
│  ┌─── EXECUTION (/ap_exec) ─────────────────────────────────────────┐ │
│  │                                                                  │ │
│  │  Step 0.5:  BEADS epic tracking (breadcrumbs for orchestrator)   │ │
│  │  Step 0.7:  Pre-flight checks                                    │ │
│  │    • Session recovery — detect interrupted work                  │ │
│  │    • Working tree check — uncommitted changes in scope?          │ │
│  │    • Branch check — auto-checkout scope/{scope}                  │ │
│  │    • Git context — recent commits for files in scope             │ │
│  │  Step 1:    Load context (plan, criteria, prior results)         │ │
│  │  Step 1.25: Decomposition (3+ files, 2+ layers → work units)     │ │
│  │  Step 2:    Implement (specialized agent or parallel units)      │ │
│  │  Step 3:    Scoped validation (hook fires automatically)         │ │
│  │  Step 4:    Full validation + test-output.txt                    │ │
│  │  Step 4.5:  Adversarial review (fresh agent, zero context)       │ │
│  │  Step 5:    Document results → results.md                        │ │
│  │                                                                  │ │
│  │  Output: results.md, test-output.txt, adversarial-review.md      │ │
│  └───────────────────────────────────────────────────────────────────┘│
│                                  │                                    │
│                                  ▼                                    │
│  ┌─── REVIEW (Orchestrator) ────────────────────────────────────────┐ │
│  │                                                                  │ │
│  │  Step 1:   Load context (plan, results, test output)             │ │
│  │  Step 1.5: BEADS verification (check breadcrumbs)                │ │
│  │  Step 2:   Evaluate against frozen criteria (version-aware)      │ │
│  │  Step 3:   Code verification (read actual files, not claims)     │ │
│  │  Step 3.5: Documentation verification gate                       │ │
│  │  Step 3.6: Integration verification gate                         │ │
│  │  Step 3.7: Read adversarial review verdict                       │ │
│  │  Step 4:   CHOOSE ONE DECISION:                                  │ │
│  │                                                                  │ │
│  │    APPROVE  → Close epic, deposit knowledge, suggest release     │ │
│  │    ITERATE  → 1-3 specific fixes, create sub-iteration (a/b/c)  │ │
│  │    BLOCK    → Close epic, escalate to human immediately          │ │
│  │    PIVOT    → Requires human approval, revised criteria          │ │
│  │                                                                  │ │
│  │  Step 10: Suggest artifact evaluation                            │ │
│  └───────────────────────────────────────────────────────────────────┘│
│                                  │                                    │
│                           (on APPROVE)                                │
│                                  ▼                                    │
│  ┌─── RELEASE (/ap_release) ────────────────────────────────────────┐ │
│  │                                                                  │ │
│  │  1. Gather scope context and changes                             │ │
│  │  2. Update CHANGELOG.md (Added/Changed/Fixed/Removed/Security)   │ │
│  │  3. Create build tag (build/N)                                   │ │
│  │  4. Commit, push, create PR via gh                               │ │
│  │  5. Optional: PR shepherd monitors CI + reviews                  │ │
│  │                                                                  │ │
│  │  Modes: pr | beta | release patch|minor|major                    │ │
│  └───────────────────────────────────────────────────────────────────┘│
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Roles & Responsibilities

### Product Owner (Human)
- Supplies scope briefs, priorities, and go/no-go decisions
- Defines acceptance criteria (immutable once iteration starts)
- Makes final decisions when iteration budget exhausted
- Approves PIVOTs and unblocks BLOCKed work

### Orchestrator (AI Planning Role)
- Plans iterations with frozen criteria
- Reviews results using 4-choice framework
- Enforces iteration budget (cannot create `iteration_01_d`)
- Escalates blockers immediately (no silent failures)

### Implementation (AI Execution Role)
- Implements changes via `/ap_exec <scope> <iteration>`
- Records validation artifacts using scoped validation
- Respects scope boundaries and frozen criteria
- Does NOT modify acceptance criteria

---

## Key Concepts

### Two-Level Iteration Model

```
Major iterations (criteria changes via PIVOT):
  iteration_01  → Initial criteria (v1)
  iteration_02  → Revised criteria (v2) after PIVOT
  iteration_03  → Further revision (v3) if needed

Sub-iterations (fixes within same criteria via ITERATE):
  iteration_01_a/b/c  → Fix attempts for v1 criteria
  iteration_02_a/b/c  → Fix attempts for v2 criteria

Example progression:
  01 → 01_a → 01_b → PIVOT → 02 → 02_a → APPROVE
```

| Decision | What it means | Creates |
|----------|---------------|---------|
| **PIVOT** | Wrong approach, need revised criteria | New major iteration (02, 03...) |
| **ITERATE** | Minor fixes needed, same criteria | Sub-iteration (_a, _b, _c) |
| **APPROVE** | All criteria met | Scope complete |
| **BLOCK** | External blocker, need human help | Nothing (escalate) |

### Iteration Budget

```
iteration_01     ← First attempt
iteration_01_a   ← First fix (if needed)
iteration_01_b   ← Second fix (if needed)
iteration_01_c   ← Final attempt (if needed)

After iteration_01_c:
 → Can APPROVE if criteria met
 → MUST BLOCK if criteria not met (no iteration_01_d)
```

This prevents infinite refinement loops. After 3 sub-iterations, the human must decide: ship as-is, pivot, or abort.

### Frozen Criteria

Acceptance criteria are **LOCKED** at iteration start:

```markdown
## Acceptance Criteria (LOCKED - DO NOT MODIFY)
- [ ] Feature X implemented
- [ ] Tests pass
- [ ] Documentation updated

During iteration, discovered: Performance issue
→ Do NOT add "[ ] Fix performance" to this iteration
→ Add to backlog for future scope
```

**Why?** Prevents scope creep and moving goalposts. New discoveries become backlog items.

### Knowledge Base

The project accumulates wisdom across iterations in `.agent_process/knowledge/`:

```
knowledge/
├── patterns.jsonl       # Recommended approaches that worked
├── gotchas.jsonl        # Non-obvious pitfalls that bit us
├── decisions.jsonl      # Architectural choices with rationale
└── anti-patterns.jsonl  # Approaches that failed
```

- **Planning phase** queries the knowledge base for entries matching the scope
- **APPROVE decisions** deposit 0-3 code learnings (patterns, gotchas, decisions)
- **BLOCK/PIVOT decisions** deposit 0-2 process observations (agent behavior, scope structure issues)
- Starts empty, grows organically — no manual population needed
- Entries are JSONL (one JSON object per line) for easy grep/search
- When BEADS is enabled, knowledge lives in `.beads/knowledge/` as the primary store

See `process/knowledge-base.md` for full documentation.

### Adversarial Review

A **fresh reviewer agent** with zero implementation context independently verifies each frozen criterion against the actual code. The reviewer:

- Receives only the frozen criteria and the changed files (NOT results.md)
- Produces a binary **PASS/FAIL** per criterion with **file:line evidence**
- Cannot be influenced by watching the implementation (no anchoring bias)
- Is **advisory input** to the orchestrator's 4-choice decision, not a replacement

**Platform-adaptive execution:** The primary review runs during implementation (Step 4.5 of `/ap_exec`) using a fresh Task agent. The orchestrator reads the pre-existing verdict. If no verdict exists, the orchestrator falls back to a rubric-based self-review using the same structured criteria.

### Work Unit Decomposition

When a scope touches 3+ files across 2+ system layers (backend + frontend, schema + API + tests, etc.), `/ap_exec` automatically decomposes the scope into independently-executable work units:

```
WU-001: Schema + ORM model  ──┐
                                ├──→ WU-003: API endpoint ──→ WU-004: Integration tests
WU-002: Frontend component  ──┘
```

Each unit has its own files, agent selection, and validation. Independent units run in parallel; dependent units wait for prerequisites.

- **Trigger:** 3+ files AND 2+ system layers AND first iteration (not sub-iteration)
- **Soft cap:** 3-6 units per scope
- **Session recovery:** `current_work_unit.conf` tracks progress across interruptions
- **Results:** `## Work Unit Summary` section in results.md

See `process/work-unit-execution.md` for the full how-to guide.

### PR Shepherd

An optional post-PR agent activated with `--shepherd` that monitors the PR lifecycle:

- **CI monitoring** — Checks pipeline status, auto-fixes lint/type failures
- **Review response** — Drafts replies to reviewer comments, implements change requests within scope
- **Merge-readiness** — Reports when all checks pass and threads are resolved

The shepherd only modifies files already in the PR, never force-pushes, and never merges. It's a CI babysitter with commenting privileges — the human always clicks merge.

See `process/pr-shepherd.md` for the full how-to guide.

### Design Review Gate

An opt-in quality checkpoint for architecturally significant scopes. When a requirement has `complexity: complex` in its frontmatter and `design_review.enabled` is `true` in `quality-config.json`, 2-4 specialist reviewers assess the iteration plan before execution begins:

- **Architect Reviewer** — Always included for complex scopes
- **Security Reviewer** — When scope touches auth, tokens, encryption, user data
- **Product/UX Reviewer** — When scope touches user-facing workflows

All reviewers must APPROVE. REQUEST_CHANGES triggers plan revision (max 2 cycles, then human escalation). Disabled by default — zero overhead for normal scopes.

See `process/design-review-gate.md` for the full how-to guide.

### BEADS Durable State

Optional state tracking using the [BEADS CLI](https://github.com/steveyegge/beads). When available, work unit state persists across session interruptions:

- **Epic per scope** — Created on first `/ap_exec`, closed on APPROVE
- **Task per work unit** — Labels track `in-progress`, `complete`, `blocked`
- **Session recovery** — New session loads BEADS state and continues from last completed unit

BEADS is installed on demand (prompted during `install.sh`, auto-installed at runtime if enabled). Falls back silently to file-based state when not available.

See `process/beads-integration.md` for the full how-to guide.

### Scoped Validation

Only validate files you changed:

```bash
# Good: Scoped validation
npx eslint "path/to/changed-file.tsx"
npm test -- --testPathPattern="ScopeTests"

# Bad: Full codebase validation
npm run typecheck  # Fails on 89 unrelated errors
npm test           # Fails on 10 unrelated tests
```

Pre-existing issues are documented once in the iteration plan, not re-litigated each iteration.

---

## Slash Commands Reference

### `/ap_brainstorm` — Ideation → Requirement

```bash
/ap_brainstorm "Improve the login experience"     # Multi-agent brainstorm → formal requirement
/ap_brainstorm "We need better error handling"     # Works with or without metaswarm
```

Spawns 3 parallel agents (Product, Architecture, Critical) to explore the idea from different angles, synthesizes their output, optionally runs design review, and creates a formal AP requirement.

### `/ap_requirements` — Requirements Management

```bash
/ap_requirements add "feature name"          # Create requirement (offers brainstorm option)
/ap_requirements import "path/to/file.md"    # Import existing file as requirement
/ap_requirements list                        # Show all requirements by category
/ap_requirements list "infrastructure"       # Filter by category
```

### `/ap_project` — Project Management

```bash
/ap_project init                    # Initialize roadmap infrastructure
/ap_project discover                # Scan project and build roadmap
/ap_project status                  # Check current project status

/ap_project add-todo "description"  # Add item to backlog
/ap_project set-status "req_id complete reason"  # Set requirement status
/ap_project archive "req_id type reason"         # Archive requirement
/ap_project archive-completed       # Bulk archive approved work

/ap_project sync                    # Reconcile roadmap with work/
/ap_project report                  # Generate stakeholder report
/ap_project help                    # Show all commands
```

### `/ap_exec` — Execute Iterations

```bash
/ap_exec <scope> <iteration>
# Example: /ap_exec user_auth iteration_01
# Example: /ap_exec user_auth iteration_01_a
```

**What it does:**
1. Pre-flight checks (session recovery, working tree, branch, git context)
2. Reads iteration plan and frozen criteria
3. Decomposes into work units if multi-domain scope
4. Implements changes within scope
5. Runs scoped validation (automatic via hook)
6. Adversarial review (fresh agent, zero context)
7. Creates results artifacts

### `/ap_release` — Release Workflow

```bash
/ap_release pr                     # PR only (no version tag)
/ap_release pr --shepherd          # PR + shepherd monitoring
/ap_release beta                   # Beta tag + PR
/ap_release release patch          # Patch release (1.0.0 → 1.0.1)
/ap_release release minor          # Minor release (1.0.0 → 1.1.0)
/ap_release release major          # Major release (1.0.0 → 2.0.0)

# No-scope mode (analyze git diff instead of work/)
/ap_release noscope pr
/ap_release noscope release patch
```

**`--shepherd` flag:** After PR creation, launches a shepherd agent that monitors CI status, responds to review comments, auto-fixes lint/type issues, and reports merge-readiness. The shepherd never merges — the human always clicks merge.

### `/ap_iteration_results` — Document Results

```bash
/ap_iteration_results <scope> <iteration>
```

Creates structured `results.md` from validation output.

### `/ap_changelog_init` — Initialize Changelog

```bash
/ap_changelog_init
```

Initializes CHANGELOG.md from git history for projects not yet tracking releases.

---

## Quality Configuration

`quality-config.json` provides centralized control over all quality gates. Every feature checks its section before activating:

```json
{
  "pre_flight":              { "enabled": true, "session_recovery": true, "working_tree_check": true, "branch_check": true, "git_context": true },
  "knowledge_base":          { "enabled": true, "query_during_planning": true, "deposit_on_approve": true },
  "adversarial_review":      { "enabled": true, "skip_for_trivial": true, "trivial_threshold_files": 2 },
  "work_unit_decomposition": { "enabled": true, "trigger_threshold_files": 3, "trigger_threshold_layers": 2 },
  "design_review":           { "enabled": false, "trigger": "complexity:complex", "max_revision_cycles": 2 },
  "beads":                   { "enabled": true, "auto_install": true },
  "pr_shepherd":             { "enabled": true },
  "metaswarm":               { "enabled": false, "features": { "brainstorm": true, "design_review": true, "prime": true, "pr_shepherd": true, "self_reflect": true } }
}
```

If the file doesn't exist, all features use built-in defaults. See `process/quality-configuration.md` for the full schema reference.

---

## Directory Structure

After installation, your project will have:

```
your-project/
├── .claude/
│   └── commands/           # Slash commands (Claude Code looks here)
│       ├── ap_brainstorm.md
│       ├── ap_requirements.md
│       ├── ap_exec.md
│       ├── ap_project.md
│       ├── ap_release.md
│       ├── ap_iteration_results.md
│       └── ap_changelog_init.md
│
├── quality-config.json     # Feature control for all quality gates
│
└── .agent_process/
    ├── orchestration/      # Planning and review prompts
    │   ├── plan-scope.md                  # Planning prompt (entry point)
    │   ├── review-iteration.md            # Review prompt (entry point)
    │   ├── scope-sizing-rules.md          # Configurable scope thresholds
    │   ├── context/
    │   │   └── base-context.md            # Orchestrator onboarding
    │   ├── coordinators/                  # Decomposed prompt entry points
    │   │   ├── plan-scope.md
    │   │   ├── execute-preflight.md
    │   │   ├── execute-main.md
    │   │   ├── review-iteration.md
    │   │   ├── release.md
    │   │   └── brainstorm.md
    │   └── steps/                         # Modular step files (43 total)
    │       ├── planning/                  # 12 focused planning steps
    │       ├── execution/                 # 7 focused execution steps
    │       ├── review/                    # 9 focused review steps
    │       ├── release/                   # 9 focused release steps
    │       └── brainstorm/                # 6 focused brainstorm steps
    │
    ├── knowledge/          # Accumulated project wisdom (JSONL)
    │   ├── patterns.jsonl
    │   ├── gotchas.jsonl
    │   ├── decisions.jsonl
    │   └── anti-patterns.jsonl
    │
    ├── process/            # Process documentation
    │   ├── validation-playbook.md
    │   ├── naming_conventions.md
    │   ├── knowledge-base.md
    │   ├── work-unit-execution.md
    │   ├── pr-shepherd.md
    │   ├── design-review-gate.md
    │   ├── quality-configuration.md
    │   ├── beads-integration.md
    │   ├── metaswarm-integration.md
    │   ├── local_environment_instructions.md
    │   └── ...
    │
    ├── requirements_docs/  # Project requirements
    │   └── _TEMPLATE_requirements.md
    │
    ├── roadmap/            # Project tracking (after /ap_project init)
    │   ├── master_roadmap.md
    │   ├── backlog.md
    │   └── .roadmap_config.json
    │
    ├── scripts/
    │   ├── after_edit/     # Scoped validation scripts (auto-generated)
    │   ├── beads-lifecycle.sh
    │   ├── evaluate-scope.sh
    │   └── hook_after_edit.sh
    │
    ├── templates/          # Iteration templates
    │   ├── iteration-plan.md
    │   ├── iteration-feedback.md
    │   ├── results.md
    │   ├── adversarial-review-prompt.md
    │   ├── work-unit-decomposition.md
    │   └── design-review-prompt.md
    │
    └── work/               # Active iteration work
        └── <scope_name>/
            ├── iteration_plan.md
            └── iteration_01/
                ├── results.md
                └── test-output.txt
```

---

## Getting Started Guide

### 1. Install the Framework

```bash
# From within your project directory
/path/to/ai_agent_process/install.sh

# Or specify target directory
./install.sh /path/to/your/project
```

The installer copies slash commands to `.claude/commands/` and sets up the `.agent_process/` directory. It prompts about optional BEADS installation.

### 2. Initialize Project Management

```bash
/ap_project init      # Create roadmap infrastructure
/ap_project discover  # Scan existing project (optional)
```

### 3. Define Your First Requirement

```bash
# Brainstorm first (recommended for vague ideas)
/ap_brainstorm "improve user authentication"

# Or create directly
/ap_requirements add "user_authentication"

# Or import an existing spec
/ap_requirements import "path/to/spec.md"
```

### 4. Plan the First Iteration

Load the planning prompt and work with the orchestrator:

1. Open `orchestration/plan-scope.md`
2. Define scope name and objectives with the orchestrator
3. Create `iteration_plan.md` with frozen criteria
4. Set up scoped validation script

### 5. Execute the Work

```bash
/ap_exec user_auth iteration_01
```

### 6. Review and Decide

Load `orchestration/review-iteration.md` and:
- Review results against original criteria
- Choose: APPROVE / ITERATE / BLOCK / PIVOT

### 7. Ship It

```bash
/ap_release pr              # Creates PR with changelog updates
/ap_release pr --shepherd   # Creates PR + monitors CI and reviews
```

---

## Success Metrics

### Healthy Process

| Metric | Target | Why |
|--------|--------|-----|
| Major iterations per scope | 1-3 | PIVOTs indicate learning, not failure |
| Sub-iterations per major | 0-2 | More suggests criteria problems |
| Scope completion rate | >80% | Achievable scopes properly sized |
| Time to completion | 1-2 weeks | Reasonable cadence |

### Warning Signs

| Sign | Problem | Solution |
|------|---------|----------|
| >3 sub-iterations on same criteria | Criteria too vague or ambitious | PIVOT or BLOCK |
| PIVOTs without clear criteria changes | Misusing the mechanism | Review planning process |
| <20% scope completion rate | Scopes too large | Split into smaller scopes |
| Indefinite completion time | Scope creep or blockers | Enforce frozen criteria |

---

## Customization

### Local Environment Instructions

For projects with unique requirements, customize workflows in:

**File:** `.agent_process/process/local_environment_instructions.md`

Every coordinator reads this file before starting its workflow. Instructions are **additive** — they augment default steps, never skip them.

**Keep it short.** Agents read this on every workflow run. Only include what's different about your project.

| Section | What goes here | Example |
|---------|---------------|---------|
| **Pre-Execution Setup** | Commands to run before implementation | `source .env && verify-auth` |
| **Multi-Repository Configuration** | Polyrepo branch checking, repo mapping | Branch verification across sub-repos |
| **Release Modifications** | Custom args, multi-project ordering | Topological sort, dependency-ordered releases |
| **Validation Extensions** | Extra validation beyond scoped hooks | Cross-repo integration tests |
| **Notes** | Other project-specific context | Architecture notes affecting agent work |

**Installation behavior:** Template installed on first setup, **preserved on re-installation** (never overwritten).

### Central Sync (Multi-Project)

For teams using this framework across multiple projects, you can configure central sync to keep all projects updated from a single source. See `install.sh` for configuration options.

---

## Documentation Reference

### Core Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| Base Context | `orchestration/context/base-context.md` | Quick onboarding for orchestration |
| Plan Scope | `orchestration/coordinators/plan-scope.md` + `steps/planning/` | How to plan new scopes |
| Execute Iteration | `orchestration/coordinators/execute-*.md` + `steps/execution/` | How to execute iterations |
| Review Iteration | `orchestration/coordinators/review-iteration.md` + `steps/review/` | How to review and decide |
| Validation Playbook | `process/validation-playbook.md` | Testing patterns |
| Naming Conventions | `process/naming_conventions.md` | IDs, files, categories |

### Process Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| Knowledge Base | `process/knowledge-base.md` | Query, deposit, curate project knowledge |
| Work Unit Execution | `process/work-unit-execution.md` | Multi-domain scope decomposition and DAG execution |
| PR Shepherd | `process/pr-shepherd.md` | Post-PR CI monitoring and review response |
| Design Review Gate | `process/design-review-gate.md` | Multi-reviewer plan assessment for complex scopes |
| Quality Configuration | `process/quality-configuration.md` | `quality-config.json` schema reference |
| BEADS Integration | `process/beads-integration.md` | Optional durable state tracking setup and usage |
| Metaswarm Integration | `process/metaswarm-integration.md` | Multi-agent brainstorming and review gates |
| Local Environment | `process/local_environment_instructions.md` | Project-specific customization |
| Roadmap Schema | `process/roadmap_schema.md` | Roadmap file format |

### Templates

| Template | Location | Purpose |
|----------|----------|---------|
| Requirements | `requirements_docs/_TEMPLATE_requirements.md` | New requirements |
| Iteration Plan | `templates/iteration-plan.md` | Planning iterations |
| Results | `templates/results.md` | Documenting outcomes |
| Feedback | `templates/iteration-feedback.md` | Review feedback |
| Adversarial Review | `templates/adversarial-review-prompt.md` | Fresh reviewer prompt |
| Work Unit Decomposition | `templates/work-unit-decomposition.md` | Architect Agent decomposition prompt |
| Design Review | `templates/design-review-prompt.md` | Specialist reviewer prompt |

---

## Installation

```bash
# From within your project directory
/path/to/ai_agent_process/install.sh

# Or specify target directory
/path/to/ai_agent_process/install.sh /path/to/your/project
```

**Re-running install.sh preserves:**
- Your work in `.agent_process/work/`
- Your knowledge base in `.agent_process/knowledge/`
- Your local environment instructions
- Your central sync configuration
- Your existing requirements documents

---

## Testing

The framework includes its own test suite:

```bash
bash test/run-tests.sh
```

This runs contract tests and unit tests validating AP's own artifacts and scripts — it's not your project's test suite.

---

## Contributing

This is a personal workflow template. Fork and customize for your needs.

---

**Philosophy:** Ship pragmatically, iterate deliberately, pivot when you learn.
