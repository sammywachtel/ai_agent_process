# Deck 1: The Agent Process — How It Works

---

## Slide 1: The Problem

**AI agents skip critical checks when instructions are too long.**

- A 1,300-line prompt file means important steps are buried in noise
- Agents optimize for the most recent/prominent instructions
- Scope sizing checks, documentation gates, and adversarial reviews get silently skipped
- Every feature added to a monolithic prompt dilutes attention on everything else

**The fix:** Give each agent only the instructions it needs (~40-90 lines), orchestrated by a coordinator that manages sequencing and parallelism.

---

## Slide 2: The Lifecycle

```
┌─────────────┐     ┌──────────┐     ┌─────────┐     ┌────────┐     ┌─────────┐
│  BRAINSTORM  │────▶│   PLAN   │────▶│ EXECUTE │────▶│ REVIEW │────▶│ RELEASE │
│             │     │          │     │         │     │        │     │         │
│ 3 parallel  │     │ 12 steps │     │ 7 pre-  │     │5 gates │     │ 9 steps │
│ perspectives│     │ + scope  │     │ flight  │     │parallel│     │ + PR    │
│ + synthesis │     │ gate     │     │ + impl  │     │+ synth │     │ shepherd│
└─────────────┘     └──────────┘     └─────────┘     └────────┘     └─────────┘
                                          │               │
                                          │    ┌──────────┘
                                          │    │
                                          ▼    ▼
                                    ┌──────────────┐
                                    │  KNOWLEDGE   │
                                    │  BASE        │
                                    │              │
                                    │ Deposits on  │
                                    │ APPROVE,     │
                                    │ BLOCK, PIVOT │
                                    │              │
                                    │ Queried on   │
                                    │ next PLAN    │
                                    └──────────────┘
```

Each phase is its own coordinator + step files. The knowledge base compounds project wisdom across iterations.

---

## Slide 3: The Coordinator Pattern

**Every workflow follows the same architecture:**

```
┌──────────────────────────────────────────────────┐
│  SLASH COMMAND (thin wrapper, ~50-100 lines)      │
│  /ap_exec, /ap_release, etc.                      │
│  Reads local env instructions + quality config    │
│  Loads the coordinator                            │
└────────────────────┬─────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────┐
│  COORDINATOR (~80-120 lines, routing only)        │
│  Knows the step sequence + parallelism            │
│  Spawns sub-agents for each step                  │
│  Checks gate conditions between steps             │
│  Never contains step logic — only routing         │
└────────┬──────┬──────┬──────┬────────────────────┘
         │      │      │      │
         ▼      ▼      ▼      ▼
┌──────┐┌──────┐┌──────┐┌──────┐
│Step 1││Step 2││Step 3││Step 4│  ← Sub-agents
│40-90 ││40-90 ││40-90 ││40-90 │  ← Each sees ONLY its
│lines ││lines ││lines ││lines │     own instructions
└──────┘└──────┘└──────┘└──────┘
```

**Key principle:** The coordinator decides WHAT runs and WHEN. Each step file decides HOW. No step file references another step file — they communicate through output files in `.run/`.

---

## Slide 4: Data Flow Between Steps

Steps pass data via files, not context:

```
.agent_process/work/{scope}/.run/
  planning/
    01-scope-check.md       ← Step 01 writes
    03-code-review.md       ← Step 03 writes, Step 04 reads
    04-files-in-scope.md    ← Step 04 writes, Steps 055/06/07 read
    08-create-plan.md       ← Aggregator reads ALL, writes iteration_plan.md
  execution/
    007a-branch-check.md    ← Pre-flight writes
    01-context.md           ← Load context writes, main prompt reads
    015-agent-selection.md  ← Agent selection writes, implementation reads
  review/
    02-eval-criteria.md     ← Gate 1 writes  ─┐
    03-code-verify.md       ← Gate 2 writes   │
    035-doc-verify.md       ← Gate 3 writes   ├─ Aggregator reads all 5
    036-integration.md      ← Gate 4 writes   │
    037-adversarial.md      ← Gate 5 writes  ─┘
    06-decision.md          ← Synthesis reads aggregation, writes decision
```

Each phase writes to its own subfolder. Steps only read from their own phase (or from permanent artifacts like `iteration_plan.md`).

---

## Slide 5: Model Tiers

Not every step needs the most expensive model. The coordinator specifies a tier for each step:

| Tier | Purpose | Examples |
|------|---------|---------|
| **cheap** | File reads, yes/no checks, formatting | Scope check, branch check, config read, version parse |
| **capable** | Code analysis, criterion evaluation, implementation | Code review, frozen criteria, changelog, adversarial review |
| **synthesis** | Aggregating multiple inputs, high-stakes decisions | Create iteration plan, choose APPROVE/ITERATE/BLOCK/PIVOT |

```
Mapping to platforms:
  cheap    → Claude Haiku    / GPT-5.4-mini
  capable  → Claude Sonnet   / GPT-5.4
  synthesis→ Claude Opus     / GPT-5.4
```

The coordinator specifies tiers, not model IDs. Each platform maps tiers to its best available models.

---

## Slide 6: Planning Deep-Dive

```
┌───────────────────────────────────────────────────────────┐
│  plan-scope.md (coordinator, ~180 lines)                   │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐                                         │
│  │01 SCOPE CHECK│ cheap — HARD GATE                       │
│  │  FAIL → STOP │ If too large, planning stops here       │
│  └──────┬───────┘                                         │
│         │                                                 │
│  ┌──────▼───────┐                                         │
│  │02 FOLDER NAME│ cheap — derive from requirement ID      │
│  └──────┬───────┘                                         │
│         │                                                 │
│  ┌──────▼──── PARALLEL A ──────────────┐                  │
│  │ ┌─────────────┐  ┌────────────────┐ │                  │
│  │ │025 KNOWLEDGE │  │ 03 CODE REVIEW │ │                  │
│  │ │ cheap        │  │ capable        │ │                  │
│  │ │ grep KB      │  │ read files,    │ │                  │
│  │ │              │  │ assess risk    │ │                  │
│  │ └──────┬──────┘  └───────┬────────┘ │                  │
│  └────────┼─────────────────┼──────────┘                  │
│           │                 │                              │
│  ┌────────▼─────────────────▼──────────┐                  │
│  │ 04 FILES IN SCOPE → 05 CRITERIA     │ sequential       │
│  └─────────────────────┬───────────────┘                  │
│                        │                                  │
│  ┌─────────────────────▼── PARALLEL B ─────────────┐      │
│  │ ┌──────────┐ ┌──────────────┐ ┌───────────────┐│      │
│  │ │055 DOC   │ │06 PREEXISTING│ │07 VALIDATION  ││      │
│  │ │IMPACT    │ │ISSUES        │ │SCRIPT         ││      │
│  │ └──────────┘ └──────────────┘ └───────────────┘│      │
│  └─────────────────────┬───────────────────────────┘      │
│                        │                                  │
│  ┌─────────────────────▼───────────────┐                  │
│  │ 08 AGGREGATE → iteration_plan.md    │ synthesis        │
│  └─────────────────────┬───────────────┘                  │
│                        │                                  │
│  ┌─────────────────────▼───────────────┐                  │
│  │ 085 DESIGN REVIEW (conditional)     │ capable x2-4     │
│  └─────────────────────┬───────────────┘                  │
│  ┌─────────────────────▼───────────────┐                  │
│  │ 09-12 FINALIZE (folders, roadmap)   │ cheap             │
│  └─────────────────────────────────────┘                  │
└───────────────────────────────────────────────────────────┘
```

**Gate:** Step 01 is a hard gate. If the scope is too large (>10 criteria, >15 files, >4 subsystems), planning stops and the requirement must be split. Thresholds are configurable in `scope-sizing-rules.md`.

---

## Slide 7: Execution Deep-Dive

```
┌───────────────────────────────────────────────────────────┐
│  PART 1: PREFLIGHT (sub-agents, ~100 lines coordinator)    │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐                                         │
│  │ 0.5 BEADS    │ direct bash (not a sub-agent)           │
│  └──────┬───────┘                                         │
│         │                                                 │
│  ┌──────▼───────┐                                         │
│  │007a BRANCH   │ cheap — runs FIRST (sequential)         │
│  │CHECK         │ flags existing branches for human input │
│  └──────┬───────┘                                         │
│         │                                                 │
│  ┌──────▼──── 3 PARALLEL CHECKS ──────────────┐           │
│  │ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │           │
│  │ │007b      │ │007c      │ │007d GIT      │ │           │
│  │ │SESSION   │ │WORKING   │ │CONTEXT       │ │           │
│  │ │RECOVERY  │ │TREE      │ │(recent edits)│ │           │
│  │ └──────────┘ └──────────┘ └──────────────┘ │           │
│  └──────────────────┬─────────────────────────┘           │
│                     │                                     │
│  ┌──────────────────▼───────────────────────┐              │
│  │ 01 LOAD CONTEXT → 1.25 DECOMPOSE → 1.5  │ sequential   │
│  │                    AGENT SELECTION       │              │
│  └──────────────────────────────────────────┘              │
│                                                           │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
│                                                           │
│  PART 2: IMPLEMENTATION (main session, ~220 lines)         │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐                                         │
│  │ 02 IMPLEMENT │ Agent tool → specialist agent(s)        │
│  │              │ Single, sub-iteration, or multi-agent   │
│  └──────┬───────┘                                         │
│  ┌──────▼───────┐                                         │
│  │ 03 VALIDATE  │ Hook fires automatically                │
│  └──────┬───────┘                                         │
│  ┌──────▼───────┐                                         │
│  │ 04 FULL      │ Capture test-output.txt                 │
│  │ VALIDATION   │                                         │
│  └──────┬───────┘                                         │
│  ┌──────▼───────┐                                         │
│  │ 4.5 ADVERS.  │ Fresh agent, zero implementation        │
│  │ REVIEW       │ context, PASS/FAIL per criterion        │
│  └──────┬───────┘                                         │
│  ┌──────▼───────┐                                         │
│  │ 05-06 DOC +  │ /ap_iteration_results → results.md      │
│  │ REPORT       │                                         │
│  └──────────────┘                                         │
└───────────────────────────────────────────────────────────┘
```

**Hybrid architecture:** Preflight steps only need Read/Bash → sub-agents. Implementation needs Agent/Task tool → must stay in main session. The split at "preflight vs main" is the natural boundary.

---

## Slide 8: Review Deep-Dive

```
┌───────────────────────────────────────────────────────────┐
│  review-iteration.md (coordinator, ~110 lines)             │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐                                         │
│  │ 01 LOAD      │ cheap — read plan, results, test output │
│  │ CONTEXT      │                                         │
│  └──────┬───────┘                                         │
│  ┌──────▼───────┐                                         │
│  │ 1.5 BEADS    │ direct bash — verify breadcrumbs        │
│  │ VERIFY       │                                         │
│  └──────┬───────┘                                         │
│         │                                                 │
│  ┌──────▼──── 5 PARALLEL VERIFICATION GATES ──────────┐   │
│  │                                                     │   │
│  │ ┌──────────┐ ┌──────────┐ ┌──────────┐            │   │
│  │ │02 EVAL   │ │03 CODE   │ │035 DOC   │            │   │
│  │ │CRITERIA  │ │VERIFY    │ │VERIFY    │            │   │
│  │ │capable   │ │capable   │ │cheap     │            │   │
│  │ └──────────┘ └──────────┘ └──────────┘            │   │
│  │                                                     │   │
│  │ ┌──────────────┐ ┌──────────────┐                  │   │
│  │ │036 INTEGRATN │ │037 ADVERSARL │                  │   │
│  │ │VERIFY        │ │REVIEW       │                  │   │
│  │ │capable       │ │capable      │                  │   │
│  │ └──────────────┘ └──────────────┘                  │   │
│  └─────────────────────┬───────────────────────────────┘   │
│                        │                                  │
│  ┌─────────────────────▼───────────────┐                  │
│  │ 04-05 GATE AGGREGATION              │ cheap             │
│  │ Count attempts, aggregate signals   │                  │
│  └─────────────────────┬───────────────┘                  │
│                        │                                  │
│  ┌─────────────────────▼───────────────┐                  │
│  │ 06 CHOOSE DECISION ← HIGH STAKES   │ synthesis         │
│  │ ┌─────┐ ┌───────┐ ┌─────┐ ┌─────┐ │ Use BEST model    │
│  │ │ ✅  │ │  🔄   │ │ 🚫 │ │ 🔀 │ │                   │
│  │ │APRV │ │ITERATE│ │BLOCK│ │PIVOT│ │ Choose exactly ONE │
│  │ └─────┘ └───────┘ └─────┘ └─────┘ │                   │
│  └─────────────────────┬───────────────┘                  │
│                        │                                  │
│  ┌─────────────────────▼───────────────┐                  │
│  │ 07-10 POST-DECISION                 │ capable           │
│  │ Artifacts, knowledge, BEADS close   │                  │
│  └─────────────────────────────────────┘                  │
└───────────────────────────────────────────────────────────┘
```

**Biggest parallelization win:** 5 verification gates that used to run sequentially now run simultaneously. The decision step (06) uses the synthesis tier — it's the highest-stakes call in the entire workflow.

---

## Slide 9: The 4-Choice Decision Framework

Every review ends with exactly one decision:

| Decision | When | What Happens Next |
|----------|------|-------------------|
| ✅ **APPROVE** | All criteria met, validation passes | Mark complete, deposit knowledge, close BEADS epic |
| 🔄 **ITERATE** | Specific fixable issues, attempts remaining | Create sub-iteration (_a/_b/_c) with 1-3 concrete fixes |
| 🚫 **BLOCK** | External blocker or attempts exhausted | Escalate to human, deposit process knowledge |
| 🔀 **PIVOT** | Wrong approach, scope change needed | Get human approval, revise criteria |

**Iteration budget:** Maximum 3 sub-iterations (a, b, c) per major iteration. After _c: must APPROVE if criteria met, must BLOCK if not. No _d allowed.

**Frozen criteria:** Acceptance criteria are locked at iteration start. New discoveries go to backlog, not this iteration. Prevents scope creep.

---

## Slide 10: The Knowledge Loop

```
                    ┌─────────────────────────────┐
                    │     KNOWLEDGE BASE           │
                    │  .beads/knowledge/*.jsonl     │
                    │                              │
                    │  patterns.jsonl   (reusable)  │
                    │  gotchas.jsonl    (pitfalls)  │
                    │  decisions.jsonl  (trade-offs)│
                    │  anti-patterns.jsonl (avoid)  │
                    └──────┬──────────────▲────────┘
                           │              │
                   ┌───────▼───┐   ┌──────┴───────┐
                   │  QUERY    │   │   DEPOSIT     │
                   │  Step 2.5 │   │  Step 9.5/9.6 │
                   │  of PLAN  │   │  of REVIEW    │
                   └───────┬───┘   └──────▲───────┘
                           │              │
              ┌────────────▼──────────────┴────────────┐
              │                                        │
     ┌────────▼─────────┐              ┌───────────────┴──┐
     │ iteration_plan.md│              │  APPROVE: 0-3    │
     │                  │              │  code learnings   │
     │ "Known Patterns  │              │                  │
     │  & Constraints"  │              │  BLOCK/PIVOT: 0-2│
     │  section         │              │  process          │
     └──────────────────┘              │  observations     │
                                       └──────────────────┘
```

**Compound learning:** Scope 2's planner uses knowledge deposited from Scope 1's BLOCK. Each iteration makes future planning smarter — even failed ones.

---

## Slide 11: Tool Stack

```
┌─────────────────────────────────────────────────────┐
│  PLATFORMS                                           │
│  ┌─────────────┐  ┌─────────────┐                   │
│  │ Claude Code  │  │   Codex     │                   │
│  │ (Claude)     │  │ (OpenAI)    │                   │
│  │              │  │             │                   │
│  │ Has Agent/   │  │ Reads step  │                   │
│  │ Task tool    │  │ files,      │                   │
│  │ for sub-     │  │ executes    │                   │
│  │ agents       │  │ inline      │                   │
│  └─────────────┘  └─────────────┘                   │
│                                                      │
├──────────────────────────────────────────────────────┤
│  OPTIONAL INTEGRATIONS                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │   BEADS     │  │ metaswarm   │  │   Docker     │ │
│  │ (bd CLI)    │  │ (plugin)    │  │  .docker-dev │ │
│  │             │  │             │  │              │ │
│  │ Issue       │  │ Knowledge   │  │ Sandboxed    │ │
│  │ tracking,   │  │ priming,    │  │ execution,   │ │
│  │ epic life-  │  │ PR shepherd,│  │ permission   │ │
│  │ cycle, Dolt │  │ brainstorm  │  │ bypass       │ │
│  └─────────────┘  └─────────────┘  └─────────────┘ │
└──────────────────────────────────────────────────────┘
```

All integrations are optional. The framework works with just Claude Code or Codex. BEADS adds durable state tracking across sessions. metaswarm adds enhanced knowledge priming. Docker adds sandboxed execution.

---

## Slide 12: Extensibility — Local Environment Instructions

Every coordinator reads project-specific customizations before starting:

```
┌──────────────────────────────────────────────────┐
│  local_environment_instructions.md               │
│                                                  │
│  ## Pre-Execution Setup                          │
│  Commands before any ap_exec work                │
│                                                  │
│  ## Multi-Repository Configuration               │
│  Branch checking across polyrepo sub-projects    │
│                                                  │
│  ## Release Modifications                        │
│  Multi-project ordering, dependency graph        │
│                                                  │
│  ## Validation Extensions                        │
│  Extra validation beyond scoped hooks            │
│                                                  │
│  ## Notes                                        │
│  Project-specific context                        │
└──────────────────────────────────────────────────┘
```

Instructions are **additive** — they augment but never skip default steps. Sections marked `<none>` are ignored. Keeps the step files generic and reusable across all projects.
