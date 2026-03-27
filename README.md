# AI Agent Process

A structured workflow framework for AI-powered development with Claude Code. Provides role separation, iteration management, and decision frameworks that turn ad-hoc AI coding into a repeatable development process.

**Philosophy:** Ship pragmatically, iterate deliberately, pivot when you learn.

---

## Quick Start

```bash
# Install the framework into your project
./install.sh /path/to/your/project

# Or from within your project
/path/to/ai_agent_process/install.sh
```

After installation, you'll have access to slash commands:
- `/ap_brainstorm` – Multi-agent brainstorm → formal requirement
- `/ap_requirements` – Create, import, and list requirements
- `/ap_project` – Manage roadmap, backlog, and project status
- `/ap_exec` – Execute implementation iterations
- `/ap_release` – Update changelog, create PRs, and release

---

## Table of Contents

1. [Overview](#overview)
2. [The Workflow](#the-workflow)
3. [Roles & Responsibilities](#roles--responsibilities)
4. [Key Concepts](#key-concepts)
5. [Slash Commands Reference](#slash-commands-reference)
6. [Directory Structure](#directory-structure)
7. [Getting Started Guide](#getting-started-guide)
8. [Success Metrics](#success-metrics)
9. [Customization](#customization)
10. [Documentation Reference](#documentation-reference)

---

## Overview

The AI Agent Process solves a common problem: AI-assisted development often becomes a chaotic loop of "try something, see if it works, try again." This framework introduces structure through:

- **Role separation** – Human defines scope, orchestrator plans/reviews, implementation executes
- **Frozen criteria** – No moving goalposts during implementation
- **Iteration budgets** – Maximum 3 attempts before escalation prevents infinite loops
- **Decision framework** – Every review ends with a clear decision (APPROVE/ITERATE/BLOCK/PIVOT)
- **Scoped validation** – Only test what you changed, not the entire codebase
- **Knowledge base** – Patterns, gotchas, and decisions compound across iterations
- **Adversarial review** – Fresh agent verifies criteria without implementation bias

### What This Provides

| Component | Purpose |
|-----------|---------|
| **Slash Commands** | Executable workflows for common tasks |
| **Orchestration Prompts** | Planning and review templates |
| **Iteration Templates** | Standardized artifacts for tracking work |
| **Validation Tools** | Scoped testing scripts |
| **Project Management** | Roadmap, backlog, and requirements tracking |
| **Knowledge Base** | Accumulated patterns, gotchas, decisions across iterations |
| **Adversarial Review** | Fresh-instance code review for unbiased criterion verification |
| **Work Unit Decomposition** | DAG-based parallel execution for multi-domain scopes |
| **PR Shepherd** | Post-PR agent monitoring CI, reviews, and merge-readiness |
| **Design Review Gate** | Multi-reviewer plan assessment for complex scopes (opt-in) |
| **Quality Configuration** | Centralized feature control via `quality-config.json` |
| **BEADS Integration** | Optional git-native durable state tracking for work units |
| **Metaswarm Integration** | Optional brainstorming, design review, and PR automation (opt-in) |

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
│   ┌─────────┐     ┌─────────┐       ┌─────────┐     ┌────────┐  │
│   │ Define  │────▶│ Execute │──────▶│ Review  │────▶│ Ship    │ │
│   │ Scope   │     │ Work    │       │ Results │     │ It!     │ │
│   └─────────┘     └─────────┘       └────┬────┘     └────────┘  │
│                                          │                      │
│                        ┌─────────────────┼─────────────────┐    │
│                        ▼                 ▼                 ▼    │
│                   ┌────────┐       ┌──────────┐      ┌───────┐  │
│                   │ITERATE │       │  PIVOT   │      │ BLOCK  │ │
│                   │(a/b/c) │       │(new iter)│      │(human) │ │
│                   └────────┘       └──────────┘      └───────┘  │
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
│  │    ✅ APPROVE                                                     │ │
│  │    │  Close BEADS epic, update requirement → approved,           │ │
│  │    │  deposit knowledge (0-3 learnings),                         │ │
│  │    │  suggest /ap_release and evaluate-scope.sh                  │ │
│  │    │                                                             │ │
│  │    🔄 ITERATE                                                     │ │
│  │    │  1-3 specific fixes with file:line evidence,                │ │
│  │    │  create sub-iteration (a/b/c), max 3 attempts               │ │
│  │    │  ◄── loops back to EXECUTION                                │ │
│  │    │                                                             │ │
│  │    🚫 BLOCK                                                       │ │
│  │    │  Close BEADS epic, escalate to human immediately,           │ │
│  │    │  deposit process knowledge (0-2 observations)               │ │
│  │    │                                                             │ │
│  │    🔀 PIVOT                                                       │ │
│  │       Requires human approval, update criteria → new major       │ │
│  │       iteration, BEADS epic stays open,                          │ │
│  │       deposit process knowledge (0-2 observations)               │ │
│  │       ◄── loops back to EXECUTION with v2 criteria               │ │
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
│  │  4. Commit, push, create PR                                      │ │
│  │  5. Optional: PR shepherd monitors CI + reviews                  │ │
│  │                                                                  │ │
│  │  Modes: pr | beta | release patch|minor|major                    │ │
│  └───────────────────────────────────────────────────────────────────┘│
│                                  │                                    │
│                                  ▼                                    │
│  ┌─── ARTIFACT VALIDATION (optional) ────────────────────────────────┐│
│  │                                                                  │ │
│  │  bash .agent_process/scripts/evaluate-scope.sh work/{scope}      │ │
│  │                                                                  │ │
│  │  Checks scope artifacts conform to expected schema:              │ │
│  │  iteration_plan.md, results.md, adversarial-review.md,           │ │
│  │  .beads-state, knowledge/*.jsonl                                 │ │
│  │                                                                  │ │
│  │  Not the test suite — this validates AP's own artifacts,         │ │
│  │  not your project's code. See process/artifact-evaluation.md     │ │
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

See `process/knowledge-base.md` for full documentation.

### Adversarial Review

A **fresh reviewer agent** with zero implementation context independently verifies each frozen criterion against the actual code. The reviewer:

- Receives only the frozen criteria and the changed files (NOT results.md)
- Produces a binary **PASS/FAIL** per criterion with **file:line evidence**
- Cannot be influenced by watching the implementation (no anchoring bias)
- Is **advisory input** to the orchestrator's 4-choice decision, not a replacement

**Platform-adaptive execution:** The primary review runs during implementation (Step 4.5 of `/ap_exec`) using a fresh Task agent — this always works because `/ap_exec` runs in Claude Code. The orchestrator (which may run in Codex, where Task isn't available) reads the pre-existing verdict. If no verdict exists, the orchestrator falls back to a rubric-based self-review using the same structured criteria.

Inspired by [metaswarm's](https://github.com/dsifry/metaswarm) adversarial review pattern. See `templates/adversarial-review-prompt.md` for the reviewer prompt template.

### Work Unit Decomposition

When a scope touches 3+ files across 2+ system layers (backend + frontend, schema + API + tests, etc.), `/ap_exec` automatically decomposes the scope into independently-executable work units:

```
WU-001: Schema + ORM model  ──┐
                                ├──→ WU-003: API endpoint ──→ WU-004: Integration tests
WU-002: Frontend component  ──┘
```

Each unit has its own files, agent selection, and validation. Independent units run in parallel; dependent units wait for prerequisites. The decomposition stays within frozen criteria — it's a tactical breakdown, not scope expansion.

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

### Quality Configuration

`quality-config.json` provides centralized control over all quality gates. Every metaswarm-integrated feature checks its section before activating:

```json
{
  "adversarial_review": { "enabled": true, "skip_for_trivial": true },
  "work_unit_decomposition": { "enabled": true, "trigger_threshold_files": 3 },
  "design_review": { "enabled": false },
  "beads": { "enabled": true, "auto_install": true },
  "knowledge_base": { "enabled": true },
  "pr_shepherd": { "enabled": true }
}
```

If the file doesn't exist, all features use built-in defaults. See `process/quality-configuration.md` for the full schema reference.

### BEADS Durable State

Optional git-native state tracking using the [BEADS CLI](https://github.com/steveyegge/beads). When available, work unit state persists across session interruptions:

- **Epic per scope** — Created on first `/ap_exec`, closed on APPROVE
- **Task per work unit** — Labels track `in-progress`, `complete`, `blocked`
- **Session recovery** — New session loads BEADS state and continues from last completed unit

BEADS is installed on demand (prompted during `install.sh`, auto-installed at runtime if enabled). Falls back silently to file-based state when not available.

See `process/beads-integration.md` for the full how-to guide.

### Scoped Validation

Only validate files you changed:

```bash
# ✅ Good: Scoped validation
npx eslint "path/to/changed-file.tsx"
npm test -- --testPathPattern="ScopeTests"

# ❌ Bad: Full codebase validation
npm run typecheck  # Fails on 89 unrelated errors
npm test           # Fails on 10 unrelated tests
```

Pre-existing issues are documented once in the iteration plan, not re-litigated each iteration.

---

## Slash Commands Reference

### `/ap_brainstorm` – Ideation → Requirement

```bash
/ap_brainstorm "Improve the login experience"     # Multi-agent brainstorm → formal requirement
/ap_brainstorm "We need better error handling"     # Works with or without metaswarm
```

Spawns 3 parallel agents (Product, Architecture, Critical) to explore the idea from different angles, synthesizes their output, optionally runs design review, and creates a formal AP requirement. See `process/metaswarm-integration.md` for details.

### `/ap_requirements` – Requirements Management

```bash
/ap_requirements add "feature name"          # Create requirement (offers brainstorm option)
/ap_requirements import "path/to/file.md"    # Import existing file as requirement
/ap_requirements list                        # Show all requirements by category
/ap_requirements list "infrastructure"       # Filter by category
```

**Metaswarm-enhanced:** When metaswarm is enabled, `add` offers to route through `/ap_brainstorm` and `import` offers design review. Without metaswarm, all commands work normally.

### `/ap_project` – Project Management

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

### `/ap_exec` – Execute Iterations

```bash
/ap_exec <scope> <iteration>
# Example: /ap_exec user_auth iteration_01
# Example: /ap_exec user_auth iteration_01_a
```

**What it does:**
1. Reads iteration plan and frozen criteria
2. Selects appropriate specialized agent
3. Implements changes within scope
4. Runs scoped validation (automatic via hook)
5. Creates results artifacts
6. Reports completion status

### `/ap_release` – Release Workflow

```bash
/ap_release pr                     # PR only (no version tag)
/ap_release pr --shepherd          # PR + shepherd monitoring
/ap_release beta                   # Beta tag + PR
/ap_release release patch          # Patch release (1.0.0 → 1.0.1)
/ap_release release minor          # Minor release (1.0.0 → 1.1.0)
/ap_release release major          # Major release (1.0.0 → 2.0.0)
/ap_release release minor --shepherd  # Release + shepherd monitoring

# No-scope mode (analyze git diff instead of work/)
/ap_release noscope pr
/ap_release noscope release patch
```

**`--shepherd` flag:** After PR creation, launches a shepherd agent that monitors CI status, responds to review comments, auto-fixes lint/type issues, and reports merge-readiness. The shepherd only modifies files already in the PR — it never merges (human clicks merge). See `process/pr-shepherd.md` for details.

### `/ap_iteration_results` – Document Results

```bash
/ap_iteration_results <scope> <iteration>
```

Creates structured `results.md` from validation output.

### `/ap_changelog_init` – Initialize Changelog

```bash
/ap_changelog_init
```

Initializes CHANGELOG.md from git history for projects not yet tracking releases.

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
│       └── ...
│
└── .agent_process/
    ├── orchestration/      # Planning and review prompts
    │   ├── plan-scope.md                  # Planning prompt (entry point)
    │   ├── review-iteration.md            # Review prompt (entry point)
    │   ├── scope-sizing-rules.md          # Configurable scope thresholds
    │   ├── context/
    │   │   └── base-context.md            # Orchestrator onboarding
    │   ├── coordinators/
    │   │   ├── plan-scope.md              # Decomposed planning coordinator
    │   │   ├── execute-preflight.md       # Execution preflight coordinator
    │   │   ├── execute-main.md            # Execution main prompt (~200 lines)
    │   │   ├── review-iteration.md        # Decomposed review coordinator
    │   │   ├── release.md                 # Decomposed release coordinator
    │   │   └── brainstorm.md              # Decomposed brainstorm coordinator
    │   └── steps/
    │       ├── planning/                  # 12 focused planning step files
    │       ├── execution/                 # 7 focused execution step files
    │       ├── review/                    # 9 focused review step files
    │       ├── release/                   # 9 focused release step files
    │       └── brainstorm/                # 6 focused brainstorm step files
    │
    ├── knowledge/          # Accumulated project wisdom (JSONL)
    │   ├── patterns.jsonl
    │   ├── gotchas.jsonl
    │   ├── decisions.jsonl
    │   └── anti-patterns.jsonl
    │
    ├── quality-config.json  # Feature control for all quality gates
    │
    ├── process/            # Process documentation
    │   ├── validation-playbook.md
    │   ├── naming_conventions.md
    │   ├── roadmap_schema.md
    │   ├── knowledge-base.md
    │   ├── work-unit-execution.md
    │   ├── pr-shepherd.md
    │   ├── design-review-gate.md
    │   ├── quality-configuration.md
    │   ├── beads-integration.md
    │   └── local_environment_instructions.md
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
    │   └── after_edit/     # Scoped validation scripts
    │
    ├── templates/          # Iteration templates
    │   ├── iteration-plan.md
    │   ├── iteration-feedback.md
    │   ├── results.md
    │   └── work-unit-decomposition.md
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
./install.sh /path/to/your/project
```

### 2. Initialize Project Management

```bash
/ap_project init      # Create roadmap infrastructure
/ap_project discover  # Scan existing project (optional)
```

### 3. Define Your First Requirement

Create a requirements document:

```bash
/ap_requirements add "user_authentication"
# Or brainstorm first:
/ap_brainstorm "improve user authentication"
```

Or manually create `.agent_process/requirements_docs/user_auth/requirements.md`:

```markdown
---
id: user_auth_01
category: authentication
priority: HIGH
---
# User Authentication

## Objective
Implement basic user login/logout functionality.

## Acceptance Criteria
- [ ] Login form with email/password
- [ ] Session management
- [ ] Logout clears session
- [ ] Tests for auth flow

## Files Expected to Change
- `src/auth/login.tsx`
- `src/auth/session.ts`
- `tests/auth.test.ts`
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
/ap_release pr  # Creates PR with changelog updates
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

**Keep it short.** Agents read this on every workflow run. Only include what's different about your project — don't repeat standard AP steps. Use `<none>` for sections that don't apply.

**Sections:**

| Section | What goes here | Example |
|---------|---------------|---------|
| **Pre-Execution Setup** | Commands to run before implementation | `source .env && verify-auth` |
| **Multi-Repository Configuration** | Polyrepo branch checking, repo mapping | Branch verification across 6 sub-repos |
| **Release Modifications** | Custom args, multi-project ordering | Topological sort, dependency-ordered releases |
| **Validation Extensions** | Extra validation beyond scoped hooks | Cross-repo integration tests |
| **Notes** | Other project-specific context | Architecture notes affecting agent work |

**What NOT to put here:**
- Standard AP workflow steps (they're in the coordinators already)
- General coding guidelines (put those in CLAUDE.md)
- Requirement details (put those in requirements_docs/)
- Architecture documentation (put those in docs/)

**Installation behavior:**
- Template installed on first setup
- **Preserved on re-installation** (never overwritten)

### Central Sync (Multi-Project)

For teams using this framework across multiple projects, you can configure central sync to keep all projects updated from a single source. See install.sh for configuration options.

---

## Documentation Reference

### Core Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| Base Context | `orchestration/context/base-context.md` | Quick onboarding for orchestration |
| Plan Scope | `orchestration/coordinators/plan-scope.md` + `steps/planning/` | How to plan new scopes |
| Execute Iteration | `orchestration/coordinators/execute-preflight.md` + `execute-main.md` + `steps/execution/` | How to execute iterations |
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
| Roadmap Schema | `process/roadmap_schema.md` | Roadmap file format |
| Roadmap Discovery | `process/roadmap_discovery.md` | How discovery works |
| Roadmap Update | `process/roadmap_update.md` | How updates work |

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

## Contributing

This is a personal workflow template. Fork and customize for your needs.

---

**Philosophy:** Ship pragmatically, iterate deliberately, pivot when you learn.
