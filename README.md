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
- `/ap_project` – Manage roadmap, requirements, and backlog
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

### What This Provides

| Component | Purpose |
|-----------|---------|
| **Slash Commands** | Executable workflows for common tasks |
| **Orchestration Prompts** | Planning and review templates |
| **Iteration Templates** | Standardized artifacts for tracking work |
| **Validation Tools** | Scoped testing scripts |
| **Project Management** | Roadmap, backlog, and requirements tracking |

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
│   Human defines    /ap_exec          Orchestrator     /ap_release
│   scope + criteria implements        reviews          creates PR │
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
- Implements changes within scope boundaries
- Runs scoped validation (hook fires automatically)
- Creates `results.md` and `test-output.txt`

#### Step 3: Review (Orchestrator)
- Evaluates results against **ORIGINAL** frozen criteria
- Chooses exactly one decision: **APPROVE / ITERATE / BLOCK / PIVOT**
- Updates iteration plan with decision

#### Step 4: Ship or Continue
- **APPROVE** → `/ap_release pr` to create PR
- **ITERATE** → Creates sub-iteration (a/b/c), max 3 attempts
- **PIVOT** → New major iteration with revised criteria (requires human approval)
- **BLOCK** → Escalate to human, do not proceed

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

### `/ap_project` – Project Management

```bash
/ap_project init                    # Initialize roadmap infrastructure
/ap_project discover                # Scan project and build roadmap
/ap_project status                  # Check current project status

/ap_project add-todo "description"  # Add item to backlog
/ap_project add-requirement "name"  # Create new requirement
/ap_project import-requirement "file_path"  # Import existing file

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
/ap_release beta                   # Beta tag + PR
/ap_release release patch          # Patch release (1.0.0 → 1.0.1)
/ap_release release minor          # Minor release (1.0.0 → 1.1.0)
/ap_release release major          # Major release (1.0.0 → 2.0.0)

# No-scope mode (analyze git diff instead of work/)
/ap_release noscope pr
/ap_release noscope release patch
```

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
│       ├── ap_exec.md
│       ├── ap_project.md
│       ├── ap_release.md
│       └── ...
│
└── .agent_process/
    ├── orchestration/      # Planning and review prompts
    │   ├── 00_base_context.md
    │   ├── 01_plan_scope_instructions.md
    │   ├── 01_plan_scope_prompt.md
    │   ├── 02_review_iteration_instructions.md
    │   └── 02_review_iteration_prompt.md
    │
    ├── process/            # Process documentation
    │   ├── validation-playbook.md
    │   ├── naming_conventions.md
    │   ├── roadmap_schema.md
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
    │   └── results.md
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
/ap_project add-requirement "user_authentication"
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

1. Open `orchestration/01_plan_scope_prompt.md`
2. Define scope name and objectives with the orchestrator
3. Create `iteration_plan.md` with frozen criteria
4. Set up scoped validation script

### 5. Execute the Work

```bash
/ap_exec user_auth iteration_01
```

### 6. Review and Decide

Load `orchestration/02_review_iteration_prompt.md` and:
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

This file is read by `/ap_exec` and `/ap_release` to apply:
- Multi-repository coordination (polyrepo architectures)
- Custom validation or deployment steps
- Environment-specific configuration
- Extended arguments and workflow modifications

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
| Base Context | `orchestration/00_base_context.md` | Quick onboarding for orchestration |
| Plan Scope | `orchestration/01_plan_scope_instructions.md` | How to plan new scopes |
| Review Iteration | `orchestration/02_review_iteration_instructions.md` | How to review and decide |
| Validation Playbook | `process/validation-playbook.md` | Testing patterns |
| Naming Conventions | `process/naming_conventions.md` | IDs, files, categories |

### Process Documentation

| Document | Location | Purpose |
|----------|----------|---------|
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
- Your local environment instructions
- Your central sync configuration
- Your existing requirements documents

---

## Contributing

This is a personal workflow template. Fork and customize for your needs.

---

**Philosophy:** Ship pragmatically, iterate deliberately, pivot when you learn.
