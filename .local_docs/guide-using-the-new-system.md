# Guide: Using the Agent Process (New System)

A step-by-step guide for the decomposed coordinator + step file architecture.

---

## 1. Installation

### Fresh Install

```bash
# From the AI Agent Process repo
bash install.sh /path/to/your/project
```

The installer:
- Copies orchestration files (coordinators, steps, context)
- Copies process docs and templates
- Creates `quality-config.json` with feature selection prompt
- Sets up BEADS credentials (if enabled)
- Creates `.agent_process/.gitignore` (excludes `.run/` and session state)

### Upgrading an Existing Project

```bash
# Delete old orchestration (cp -r won't remove deleted files)
rm -rf /path/to/project/.agent_process/orchestration/

# Re-run installer
bash install.sh /path/to/project
```

The installer preserves:
- `work/` (iteration history)
- `knowledge/` (accumulated wisdom)
- `requirements_docs/` (your requirements)
- `local_environment_instructions.md` (project customizations)
- `quality-config.json` (feature settings)

---

## 2. The Complete Workflow

### Overview

```
┌───────────────────────────────────────────────────────────────┐
│                                                               │
│   HUMAN                                                       │
│   writes requirement ──────────────────────────────────┐      │
│                                                        │      │
│   ┌────────────────────────────────────────────────────▼──┐   │
│   │  1. BRAINSTORM (optional)                             │   │
│   │     /ap_brainstorm "idea"                             │   │
│   │     → requirement file                                │   │
│   └───────────────────────────────────────────┬───────────┘   │
│                                               │               │
│   ┌───────────────────────────────────────────▼───────────┐   │
│   │  2. PLAN                                              │   │
│   │     Orchestrator loads orchestration/plan-scope.md     │   │
│   │     → iteration_plan.md                               │   │
│   │     ⏸️ STOP for human approval                        │   │
│   └───────────────────────────────────────────┬───────────┘   │
│                                               │               │
│   ┌───────────────────────────────────────────▼───────────┐   │
│   │  3. EXECUTE                                           │   │
│   │     /ap_exec {scope} {iteration}                      │   │
│   │     → results.md + test-output.txt                    │   │
│   └───────────────────────────────────────────┬───────────┘   │
│                                               │               │
│   ┌───────────────────────────────────────────▼───────────┐   │
│   │  4. REVIEW                                            │   │
│   │     Orchestrator loads orchestration/review-iteration  │   │
│   │     → APPROVE / ITERATE / BLOCK / PIVOT               │   │
│   │     ⏸️ STOP for human approval                        │   │
│   └───────────┬───────┬───────┬───────┬───────────────────┘   │
│               │       │       │       │                       │
│          APPROVE  ITERATE   BLOCK   PIVOT                     │
│               │       │       │       │                       │
│               │       │       │       └──→ Human approves     │
│               │       │       │           revised criteria,   │
│               │       │       │           back to PLAN        │
│               │       │       │                               │
│               │       │       └──→ Escalate to human          │
│               │       │           (ship/pivot/abort)           │
│               │       │                                       │
│               │       └──→ Back to EXECUTE                    │
│               │           with 1-3 specific fixes             │
│               │           (max 3 sub-iterations)              │
│               │                                               │
│   ┌───────────▼───────────────────────────────────────────┐   │
│   │  5. RELEASE                                           │   │
│   │     /ap_release pr | beta | release [patch|minor|major│   │
│   │     → CHANGELOG, commit, tag, PR, optional shepherd   │   │
│   └───────────────────────────────────────────────────────┘   │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

---

## 3. Step-by-Step: Planning a New Scope

### What You Do (Human)

1. Write a requirement file in `.agent_process/requirements_docs/{category}/`
2. Open a fresh orchestrator session (Claude Code or Codex)
3. Tell it to plan the scope:
   ```
   Plan scope for requirements_docs/{category}/{requirement_id}.md
   ```
4. The orchestrator loads `orchestration/plan-scope.md` which points to the coordinator

### What the System Does

```
Human: "Plan this requirement"
  │
  ▼
orchestration/plan-scope.md (prompt template)
  │
  ├── Reads orchestration/context/base-context.md
  ├── Reads orchestration/coordinators/plan-scope.md
  ├── Reads local_environment_instructions.md
  │
  ▼
Coordinator spawns sub-agents:

  Step 01: SCOPE CHECK (hard gate)
  ┌─────────────────────────────────────────────────────┐
  │ Reads scope-sizing-rules.md for thresholds          │
  │ Reads requirement file                              │
  │ Checks: one sentence? done definition? timeframe?   │
  │ Checks: criteria count, file count, subsystems      │
  │                                                     │
  │ VERDICT: PASS → continue                            │
  │ VERDICT: FAIL → STOP, suggest splitting             │
  │                                                     │
  │ Override: scope_override: true in frontmatter       │
  │ bypasses Fail thresholds (Warning only)             │
  └─────────────────────────────────────────────────────┘
       │
       ▼ (if PASS)
  Step 02: Derive folder name from requirement ID
       │
       ▼
  PARALLEL GROUP A (run simultaneously):
    ├── Step 2.5: Query knowledge base (grep .beads/knowledge/)
    └── Step 03:  Code review (read actual files, assess feasibility)
       │
       ▼
  Step 04: Define files in scope
  Step 05: Create frozen acceptance criteria
       │
       ▼
  PARALLEL GROUP B (run simultaneously):
    ├── Step 5.5: Documentation impact assessment
    ├── Step 06:  Pre-existing issues
    └── Step 07:  Create validation script
       │
       ▼
  Step 08: AGGREGATE all outputs → iteration_plan.md (synthesis model)
       │
       ▼
  Step 8.5: Design review (conditional, if complexity: complex)
       │
       ▼
  Steps 09-12: Create folders, config, roadmap update
       │
       ▼
  HANDOFF to human for approval
```

### What You Get

- `.agent_process/work/{scope}/iteration_plan.md` — locked plan
- `.agent_process/work/{scope}/iteration_01/results.md` — placeholder
- `.agent_process/scripts/after_edit/validate-{scope}.sh` — scoped validation
- `.agent_process/work/current_iteration.conf` — session state

### What to Check Before Approving

- Are the acceptance criteria specific and testable?
- Is the file scope reasonable (4-10 files)?
- Does the technical assessment match your understanding?
- Are known patterns from the knowledge base incorporated?

---

## 4. Step-by-Step: Executing an Iteration

### What You Do

```bash
/ap_exec {scope_name} iteration_01
```

### What the System Does

```
/ap_exec scope iteration
  │
  ├── Reads local_environment_instructions.md
  ├── Reads quality-config.json
  │
  ▼
PART 1: PREFLIGHT (sub-agents)

  Step 0.5: BEADS lifecycle start (direct bash)
  Step 0.7a: Branch check (RUNS FIRST, alone)
    └── Creates scope/{scope} branch if needed
    └── Flags existing branches for human decision
  Steps 0.7b-d: (3 parallel after branch settled)
    ├── Session recovery (check for interrupted work)
    ├── Working tree check (uncommitted changes in scope files?)
    └── Git context (recent commits touching scope files)
  Step 01: Load context (read plan, handle sub-iterations)
  Step 1.25: Assess work unit decomposition (optional DAG)
  Step 1.5: Select specialist agent (pattern matching)
  │
  ▼
PART 2: IMPLEMENTATION (main session)

  Step 02: Launch selected agent(s)
    ├── Single agent for most scopes
    ├── Sub-iteration agent (focused on 1-3 fixes)
    └── Multi-agent for decomposed scopes (parallel)
  Step 03: Validate (hook fires automatically)
    └── Max 3 retries if validation fails
  Step 04: Full validation → test-output.txt
  Step 4.5: Adversarial review (fresh agent, zero context)
    └── PASS/FAIL per criterion with file:line evidence
  Step 05: /ap_iteration_results → results.md
  Step 06: Report completion to user
```

### What You Get

- `.agent_process/work/{scope}/{iteration}/results.md`
- `.agent_process/work/{scope}/{iteration}/test-output.txt`
- `.agent_process/work/{scope}/{iteration}/adversarial-review.md`

### Sub-iterations

If the review says ITERATE, you'll run:
```bash
/ap_exec {scope_name} iteration_01_a
```

The sub-iteration agent reads the 1-3 specific fixes from the review and focuses only on those. Max 3 sub-iterations (_a, _b, _c) before escalation.

---

## 5. Step-by-Step: Reviewing an Iteration

### What You Do

Open a fresh orchestrator session and tell it to review:
```
Review iteration_01 of scope {scope_name}
```

The orchestrator loads `orchestration/review-iteration.md`.

### What the System Does

```
Orchestrator: "Review this iteration"
  │
  ├── Reads context/base-context.md
  ├── Reads coordinators/review-iteration.md
  ├── Reads local_environment_instructions.md
  │
  ▼
  Step 01: Load context (read plan, results, test-output)
  Step 1.5: BEADS verify (check breadcrumbs)
  │
  ▼
  5 PARALLEL VERIFICATION GATES
  ┌──────────────────────────────────────────────────────┐
  │                                                      │
  │  Gate 1: Evaluate frozen criteria (MET/NOT MET)      │
  │  Gate 2: Code verification (read actual files)       │
  │  Gate 3: Documentation check (Zero Drift rule)       │
  │  Gate 4: Integration verification (cross-boundary)   │
  │  Gate 5: Adversarial review verification             │
  │                                                      │
  │  Each gate is an independent sub-agent.              │
  │  They cannot see each other's output.                │
  │  They all read from the same iteration artifacts.    │
  └──────────────────────┬───────────────────────────────┘
                         │
  Step 04-05: Aggregate all gate results + count attempts
                         │
  Step 06: CHOOSE DECISION (synthesis model, best available)
  ┌──────────────────────────────────────────────────────┐
  │  Reads ALL gate outputs as structured evidence       │
  │  Chooses exactly ONE:                                │
  │                                                      │
  │  ✅ APPROVE — all criteria met                       │
  │  🔄 ITERATE — fixable issues, attempts remaining     │
  │  🚫 BLOCK  — external blocker or budget exhausted    │
  │  🔀 PIVOT  — wrong approach, need human approval     │
  └──────────────────────┬───────────────────────────────┘
                         │
  ⏸️ STOP for human approval
                         │
  Steps 07-10: Post-decision actions
    ├── Update iteration_plan.md
    ├── Update requirement status
    ├── Deposit knowledge (APPROVE: code learnings, BLOCK/PIVOT: process observations)
    ├── Close BEADS epic (APPROVE/BLOCK)
    └── Suggest artifact validation
```

### Decision Rules

| Iteration | Can ITERATE? | If criteria not met |
|-----------|-------------|-------------------|
| `iteration_01` | Yes (3 remaining) | ITERATE with 1-3 fixes |
| `iteration_01_a` | Yes (2 remaining) | ITERATE with 1-3 fixes |
| `iteration_01_b` | Yes (1 remaining) | ITERATE with 1-3 fixes |
| `iteration_01_c` | **No** | Must APPROVE or BLOCK |

**After `_c`:** The system forces a decision. No `_d` allowed. Either the criteria are met (APPROVE) or they're not (BLOCK → escalate to human).

---

## 6. Step-by-Step: Releasing

### What You Do

```bash
/ap_release pr                        # PR with changelog update
/ap_release beta                      # Beta release with tag
/ap_release release minor             # Minor version release
/ap_release noscope pr                # Ad-hoc, no scope context
/ap_release pr --shepherd             # PR + CI monitoring agent
```

### What the System Does

```
/ap_release {mode}
  │
  ├── Reads local_environment_instructions.md
  ├── Reads quality-config.json
  │
  ▼
  PARALLEL: Gather context + Detect project structure
    ├── Step 01: Read scope results OR git diff (noscope)
    │            Calculate build number
    └── Step 02: Detect version files (pyproject.toml, package.json, etc.)
  │
  ▼
  Step 03: Get current version, calculate next
  Step 04: Classify changes (Added/Changed/Fixed/Removed/Breaking)
  Step 05: Update CHANGELOG.md (+ USER_CHANGELOG.md for beta/release)
  Step 06: Update version files (release mode ONLY)
  Steps 07-09: Commit → Tag → Push → PR (MUST BE SEQUENTIAL)
    └── Central repo sync (if configured)
  Step 095: PR Shepherd (CONDITIONAL — config or --shepherd flag)
    └── Monitors CI, responds to review comments, reports merge-readiness
  Step 10: Report completion
```

### Modes

| Mode | Changelog | Version Bump | Tags | PR |
|------|-----------|-------------|------|-----|
| `pr` | Under [Unreleased] | No | `build/N` | Yes |
| `beta` | [X.Y.Z-beta.N] | No | `build/N` + `vX.Y.Z-beta.N` | Yes |
| `release patch` | [X.Y.Z] | Yes (patch) | `build/N` + `vX.Y.Z` | Yes |
| `release minor` | [X.Y.Z] | Yes (minor) | `build/N` + `vX.Y.Z` | Yes |
| `release major` | [X.Y.Z] | Yes (major) | `build/N` + `vX.Y.Z` | Yes |

---

## 7. Brainstorming (Optional)

### What You Do

```bash
/ap_brainstorm "We need better error handling in the API layer"
```

### What the System Does

```
/ap_brainstorm "idea"
  │
  ▼
  Step 01: Config check
  Step 02: Gather project context (README, existing requirements, knowledge)
  │
  ▼
  Step 03: 3 PARALLEL BRAINSTORM AGENTS
  ┌────────────────────────────────────────────┐
  │  Product Strategist                        │
  │  → Problem statement, success criteria,    │
  │    scope boundaries                        │
  │                                            │
  │  Software Architect                        │
  │  → Technical feasibility, files affected,  │
  │    complexity assessment                   │
  │                                            │
  │  Devil's Advocate                          │
  │  → Assumption check, alternatives,         │
  │    failure modes, honest assessment         │
  └──────────────────┬─────────────────────────┘
                     │
  Step 04: Synthesize all 3 perspectives (synthesis model)
  Step 05: Optional design review (2-3 parallel reviewers)
  Steps 06-08: Transform to AP requirement → confirm → write file
```

### What You Get

- `.agent_process/brainstorms/{name}/brainstorm.md` — the synthesis
- `.agent_process/requirements_docs/{category}/{id}.md` — the requirement
- Roadmap updated with NOT_STARTED status

---

## 8. Configuration

### quality-config.json

Controls which features are active:

```json
{
  "pre_flight": {
    "enabled": true,
    "session_recovery": true,
    "working_tree_check": true,
    "branch_check": true,
    "git_context": true
  },
  "adversarial_review": {
    "enabled": true,
    "skip_for_trivial": true,
    "trivial_threshold_files": 2,
    "trivial_threshold_criteria": 2
  },
  "work_unit_decomposition": {
    "enabled": true,
    "trigger_threshold_files": 3,
    "trigger_threshold_layers": 2
  },
  "design_review": {
    "enabled": false,
    "min_reviewers": 2,
    "max_reviewers": 4
  },
  "knowledge_base": {
    "enabled": true,
    "deposit_on_approve": true,
    "deposit_on_block_pivot": true
  },
  "beads": {
    "enabled": true,
    "auto_install": true
  },
  "pr_shepherd": {
    "enabled": true
  }
}
```

### scope-sizing-rules.md

Configurable thresholds for the scope check gate:

| Metric | Target | Warning | Fail |
|--------|--------|---------|------|
| Criteria count | 3-7 | 8-10 | >10 |
| Files to change | 4-10 | 11-15 | >15 |
| Subsystems | 1-3 | 4 | >4 |

Override per-requirement with `scope_override: true` in frontmatter.

### local_environment_instructions.md

Project-specific customizations. Structured sections:

| Section | Purpose |
|---------|---------|
| Pre-Execution Setup | Commands before ap_exec |
| Multi-Repository Configuration | Polyrepo branch checking |
| Release Modifications | Multi-project release ordering |
| Validation Extensions | Extra validation commands |
| Notes | Other project-specific context |

Keep this file short — agents read it on every workflow run.

---

## 9. File Organization

```
.agent_process/
  orchestration/
    plan-scope.md              ← Planning entry point
    review-iteration.md        ← Review entry point
    scope-sizing-rules.md      ← Configurable thresholds
    context/
      base-context.md          ← Orchestrator onboarding
    coordinators/
      plan-scope.md            ← Planning routing (~180 lines)
      execute-preflight.md     ← Execution preflight (~110 lines)
      execute-main.md          ← Execution implementation (~220 lines)
      review-iteration.md      ← Review routing (~110 lines)
      release.md               ← Release routing (~120 lines)
      brainstorm.md            ← Brainstorm routing (~90 lines)
    steps/
      planning/                ← 12 step files (40-85 lines each)
      execution/               ← 7 step files (42-109 lines each)
      review/                  ← 9 step files (55-103 lines each)
      release/                 ← 9 step files (44-92 lines each)
      brainstorm/              ← 6 step files (30-92 lines each)
  process/                     ← Reference docs (consulted, not followed step-by-step)
  templates/                   ← Output templates
  knowledge/                   ← Accumulated project wisdom (JSONL)
  requirements_docs/           ← Requirement specifications
  work/                        ← Iteration history
    {scope}/
      iteration_plan.md
      .run/
        planning/              ← Planning step outputs
        execution/             ← Execution step outputs
        review/                ← Review step outputs
        release/               ← Release step outputs
      iteration_01/
        results.md
        test-output.txt
        adversarial-review.md
      iteration_01_a/
        results.md
        ...
  brainstorms/
    {idea_name}/
      brainstorm.md            ← Synthesis document
      .run/                    ← Brainstorm step outputs
```

### Key distinction

- **`orchestration/`** = Prompts agents load and follow step-by-step (the playbook)
- **`process/`** = Reference docs agents consult when needed (the handbook)
- **`.run/`** = Ephemeral scratch data between sub-agents (gitignored)
- **`work/{scope}/`** = Permanent iteration history (committed)

---

## 10. Troubleshooting

### Scope check keeps failing

Edit `orchestration/scope-sizing-rules.md` to adjust thresholds. Or add `scope_override: true` to the requirement's frontmatter for a one-time bypass.

### Agent skips steps

Check that the project was installed with the new coordinator files:
```bash
ls .agent_process/orchestration/coordinators/
```
If empty, delete `.agent_process/orchestration/` and reinstall.

### BEADS "access denied" in Docker

Add to `.docker-dev/docker-compose.yml`:
```yaml
environment:
  - BEADS_DOLT_SERVER_HOST=host.docker.internal
volumes:
  - ${HOME}/.config/beads:${HOME}/.config/beads:ro
```

### .run/ files from previous phases

Normal — `.run/` subfolders accumulate across phases. Each phase writes to its own subfolder (`planning/`, `execution/`, `review/`, `release/`). Latest run overwrites within each subfolder.

### Polyrepo working tree check misses changes

The default `007c` step only checks the root repo. If your project has sub-repos, add `Multi-Repository Configuration` to `local_environment_instructions.md` with the repo mapping. The preflight coordinator will check each sub-repo's working tree.

### Orchestrator calls bd during planning/review

The coordinators explicitly say "Do NOT run bd, bds, or BEADS commands." If the orchestrator still calls bd, it's likely reading project-level instructions (CLAUDE.md or metaswarm) that say "use bd for task tracking." The coordinator warning should override those — if it doesn't, the project's CLAUDE.md may need a note clarifying that bd is for the implementation agent only.
